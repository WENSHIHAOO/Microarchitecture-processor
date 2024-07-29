module mem
#(
    N = 0, // Number of ways per set
    B = 0, // Block size (bytes)
    S = 0, // Number of sets
    s = 0, // Number of set index bits
    b = 0, // Number of block offset bits
    y = 0, // Number of byte offset bits
    t = 0, // Number of tag bits
    V_N = 0// Number of ways of Victim
)
(
    //****** MEM ******
    input  clk,
    input         enableM,
    output        Stall_miss1,
    output        Stall_miss2,
    output        MEM_miss1,
    output        MEM_miss2,
    output [63:0] MEM_addr1,
    output [63:0] MEM_addr2,
    output [63:0] Hazard_addr1,
    output [63:0] Hazard_addr2,
    output        MEM_Write1,
    output [2:0]  MEM_Size1,
    output [63:0] MEM_Data1,
    output        MEM_Write2,
    output [2:0]  MEM_Size2,
    output [63:0] MEM_Data2,
    // Superscalar 1
    input  [4:0]  MemWriteReadSizeM1,
    input  [63:0] ALUResultM1,
    input  [63:0] WriteDataM1,
    output [63:0] ReadDataM1,
    // Superscalar 2
    input  [4:0]  MemWriteReadSizeM2,
    input  [63:0] ALUResultM2,
    input  [63:0] WriteDataM2,
    output [63:0] ReadDataM2
);
reg [63:0] Data [S][N][B];
reg [t:0] Valid_Tag [S][N];
reg LRU [S];
reg Dirty [S][N];

reg [63:0] Victim [V_N][B];
reg [64:0] Victim_Valid_Addr [V_N];

// Superscalar 1
// check miss1
logic [t-1:0] tag1   = ALUResultM1[63     :s+b+y];
logic [s-1:0] set1   = ALUResultM1[s+b+y-1:b+y];
logic [b-1:0] block1 = ALUResultM1[b+y-1  :y];
// Read & Read_Write miss
always_comb begin // Write miss is written here because always_comb has no delay.
    if(enableM) begin
        // Read 64 bit data
        if(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) begin
            if(MemWriteReadSizeM1[3]) begin
                ReadDataM1 = Data[set1][0][block1]; // 3'b011 // ld
                LRU[set1] = 1;
            end
        end
        else if(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1)) begin
            if(MemWriteReadSizeM1[3]) begin
                ReadDataM1 = Data[set1][1][block1]; // 3'b011 // ld
                LRU[set1] = 0;
            end
        end
        else begin
            if(MemWriteReadSizeM1[3]) begin
                if(!((MemWriteReadSizeM2[3]|MemWriteReadSizeM2[4]) & (ALUResultM1[63:b+y]==ALUResultM2[63:b+y]))) begin // When 2 also reads this address, 1 does not miss.
                    MEM_addr1 = ALUResultM1;
                    MEM_miss1 = 1;
                    Stall_miss1 = 1; // Read 1 Stall directly.
                end
            end else if(MemWriteReadSizeM1[4]) begin
                if(!(MemWriteReadSizeM2[4] & (ALUResultM1 == ALUResultM2))) begin  // When 2 also writes this address, 1 does not miss.
                    if(MEM_miss1) Stall_miss1 = 1; // When the previous 1 miss, 1 Stall.
                    else begin // Let both axi and cpu run.
                        MEM_Write1 = 1;
                        MEM_Size1 = MemWriteReadSizeM1[2:0];
                        MEM_Data1 = WriteDataM1;
                        MEM_addr1 = ALUResultM1;
                        Hazard_addr1 = ALUResultM1; // Since write is not Stall directly, MEM_addr2 may change, so adding this hazrd is only used for write.
                        MEM_miss1 = 1;
                    end
                end
            end
        end
        // Size
        if(MemWriteReadSizeM1[3]) begin
            case(MemWriteReadSizeM1[2:0])
                3'b000: ReadDataM1 = {{56{ReadDataM1[8*ALUResultM1[2:0]+7]}}, ReadDataM1[8*ALUResultM1[2:0]+:8]};   // lb
                3'b001: ReadDataM1 = {{48{ReadDataM1[16*ALUResultM1[2:1]+15]}}, ReadDataM1[16*ALUResultM1[2:1]+:16]}; // lh
                3'b010: ReadDataM1 = {{32{ReadDataM1[32*ALUResultM1[2]+31]}}, ReadDataM1[32*ALUResultM1[2]+:32]}; // lw
                3'b100: ReadDataM1 = {{56{1'b0}}, ReadDataM1[8*ALUResultM1[2:0]+:8]};   // lbu
                3'b101: ReadDataM1 = {{48{1'b0}}, ReadDataM1[16*ALUResultM1[2:1]+:16]}; // lhu
                3'b110: ReadDataM1 = {{32{1'b0}}, ReadDataM1[32*ALUResultM1[2]+:32]}; // lwu
            endcase
            if(!MEM_miss1) Stall_miss1 = 0; // When the read 1 is complete, stop 1 Stall.
        end else if(!MEM_miss1 & MemWriteReadSizeM1[4] & !(MemWriteReadSizeM2[4] & (ALUResultM1 == ALUResultM2))) Stall_miss1 = 0; // When Write 1 is completed, and 2 not also reads this address, stop Stall.
    end
end

// Write
always_ff @ (posedge clk) begin
    if(enableM) begin
        if(MemWriteReadSizeM1[4]) begin
            if(!(MemWriteReadSizeM2[4] & (ALUResultM1 == ALUResultM2))) begin // If two Superscalar write at the same time.
                if(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) begin
                    case(MemWriteReadSizeM1[2:0])
                        3'b000: begin
                            Data[set1][0][block1][8*ALUResultM1[2:0]+:8]   <= WriteDataM1; // sb
                            do_pending_write( ALUResultM1,                WriteDataM1, 1);
                        end
                        3'b001: begin
                            Data[set1][0][block1][16*ALUResultM1[2:1]+:16] <= WriteDataM1; // sh
                            do_pending_write({ALUResultM1[63:1], 1'b0},   WriteDataM1, 2);
                        end
                        3'b010: begin
                            Data[set1][0][block1][32*ALUResultM1[2]+:32]   <= WriteDataM1; // sw
                            do_pending_write({ALUResultM1[63:2], 2'b00},  WriteDataM1, 4);
                        end
                        3'b011: begin
                            Data[set1][0][block1]                          <= WriteDataM1; // sd
                            do_pending_write({ALUResultM1[63:3], 3'b000}, WriteDataM1, 8);
                        end
                    endcase
                    Dirty[set1][0] <= 1;
                    LRU[set1] = 1;
                end
                else if(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1)) begin
                    case(MemWriteReadSizeM1[2:0])
                        3'b000: begin
                            Data[set1][1][block1][8*ALUResultM1[2:0]+:8]   <= WriteDataM1; // sb
                            do_pending_write( ALUResultM1,                WriteDataM1, 1);
                        end
                        3'b001: begin
                            Data[set1][1][block1][16*ALUResultM1[2:1]+:16] <= WriteDataM1; // sh
                            do_pending_write({ALUResultM1[63:1], 1'b0},   WriteDataM1, 2);
                        end
                        3'b010: begin
                            Data[set1][1][block1][32*ALUResultM1[2]+:32]   <= WriteDataM1; // sw
                            do_pending_write({ALUResultM1[63:2], 2'b00},  WriteDataM1, 4);
                        end
                        3'b011: begin
                            Data[set1][1][block1]                          <= WriteDataM1; // sd
                            do_pending_write({ALUResultM1[63:3], 3'b000}, WriteDataM1, 8);
                        end
                    endcase
                    Dirty[set1][1] <= 1;
                    LRU[set1] = 0;
                end
            end
        end
    end
end

// Superscalar 2
// check miss2
logic [t-1:0] tag2   = ALUResultM2[63     :s+b+y];
logic [s-1:0] set2   = ALUResultM2[s+b+y-1:b+y];
logic [b-1:0] block2 = ALUResultM2[b+y-1  :y];
// Read & Read_Write miss
always_comb begin // Write miss is written here because always_comb has no delay.
    if(enableM) begin
        // Read 64 bit data
        if(Valid_Tag[set2][0][t] & (Valid_Tag[set2][0][t-1:0] == tag2)) begin
            if(MemWriteReadSizeM2[3]) begin
                ReadDataM2 = Data[set2][0][block2]; // 3'b011 // ld
                LRU[set2] = 1;
            end
        end
        else if(Valid_Tag[set2][1][t] & (Valid_Tag[set2][1][t-1:0] == tag2)) begin
            if(MemWriteReadSizeM2[3]) begin
                ReadDataM2 = Data[set2][1][block2]; // 3'b011 // ld
                LRU[set2] = 0;
            end
        end
        else begin
            if(MemWriteReadSizeM2[3]) begin
                if(MemWriteReadSizeM1[4] & (ALUResultM1[63:y] == ALUResultM2[63:y])) ReadDataM2 = 0; // when Superscalar 1 write, Superscalar 2 read.
                else begin
                    MEM_addr2 = ALUResultM2;
                    MEM_miss2 = 1;
                    Stall_miss2 = 1; // Read 2 Stall directly.
                end
            end else if(MemWriteReadSizeM2[4]) begin
                    if(MEM_miss2) Stall_miss2 = 1; // When the previous 2 miss, 2 Stall.
                    else begin // Let both axi and cpu run.
                        MEM_Write2 = 1;
                        MEM_Size2 = MemWriteReadSizeM2[2:0];
                        MEM_Data2 = WriteDataM2;
                        MEM_addr2 = ALUResultM2; // Since write is not Stall directly, MEM_addr2 may change, so adding this hazrd is only used for write.
                        Hazard_addr2 = ALUResultM2; 
                        MEM_miss2 = 1;
                    end
            end
        end
        // when Superscalar 1 write, Superscalar 2 read.
        if(MemWriteReadSizeM1[4] & (ALUResultM1[63:y] == ALUResultM2[63:y])) begin
            case(MemWriteReadSizeM1[2:0])
                3'b000: ReadDataM2[8*ALUResultM1[2:0]+:8] = WriteDataM1;
                3'b001: ReadDataM2[16*ALUResultM1[2:1]+:16] = WriteDataM1;
                3'b010: ReadDataM2[32*ALUResultM1[2]+:32] = WriteDataM1;
                3'b011: ReadDataM2 = WriteDataM1;
            endcase
        end
        // Size
        if(MemWriteReadSizeM2[3]) begin
            case(MemWriteReadSizeM2[2:0])
                3'b000: ReadDataM2 = {{56{ReadDataM2[8*ALUResultM2[2:0]+7]}}, ReadDataM2[8*ALUResultM2[2:0]+:8]};   // lb
                3'b001: ReadDataM2 = {{48{ReadDataM2[16*ALUResultM2[2:1]+15]}}, ReadDataM2[16*ALUResultM2[2:1]+:16]}; // lh
                3'b010: ReadDataM2 = {{32{ReadDataM2[32*ALUResultM2[2]+31]}}, ReadDataM2[32*ALUResultM2[2]+:32]}; // lw
                3'b100: ReadDataM2 = {{56{1'b0}}, ReadDataM2[8*ALUResultM2[2:0]+:8]};   // lbu
                3'b101: ReadDataM2 = {{48{1'b0}}, ReadDataM2[16*ALUResultM2[2:1]+:16]}; // lhu
                3'b110: ReadDataM2 = {{32{1'b0}}, ReadDataM2[32*ALUResultM2[2]+:32]}; // lwu
            endcase
            if(!MEM_miss2) Stall_miss2 = 0; // When the read 2 is complete, stop 2 Stall.
        end else if(!MEM_miss2 & MemWriteReadSizeM2[4]) Stall_miss2 = 0; // When the write 2 is complete, stop 2 Stall.
    end
end

// Write
always_ff @ (posedge clk) begin
    if(enableM) begin
        if(MemWriteReadSizeM2[4]) begin
            if(Valid_Tag[set2][0][t] & (Valid_Tag[set2][0][t-1:0] == tag2)) begin
                case(MemWriteReadSizeM2[2:0])
                    3'b000: begin
                        Data[set2][0][block2][8*ALUResultM2[2:0]+:8]   <= WriteDataM2; // sb
                        do_pending_write( ALUResultM2,                WriteDataM2, 1);
                    end
                    3'b001: begin
                        Data[set2][0][block2][16*ALUResultM2[2:1]+:16] <= WriteDataM2; // sh
                        do_pending_write({ALUResultM2[63:1], 1'b0},   WriteDataM2, 2);
                    end
                    3'b010: begin
                        Data[set2][0][block2][32*ALUResultM2[2]+:32]   <= WriteDataM2; // sw
                        do_pending_write({ALUResultM2[63:2], 2'b00},  WriteDataM2, 4);
                    end
                    3'b011: begin
                        Data[set2][0][block2]                          <= WriteDataM2; // sd
                        do_pending_write({ALUResultM2[63:3], 3'b000}, WriteDataM2, 8);
                    end
                endcase
                Dirty[set2][0] <= 1;
                LRU[set2] = 1;
            end
            else if(Valid_Tag[set2][1][t] & (Valid_Tag[set2][1][t-1:0] == tag2)) begin
                case(MemWriteReadSizeM2[2:0])
                    3'b000: begin
                        Data[set2][1][block2][8*ALUResultM2[2:0]+:8]   <= WriteDataM2; // sb
                        do_pending_write( ALUResultM2,                WriteDataM2, 1);
                    end
                    3'b001: begin
                        Data[set2][1][block2][16*ALUResultM2[2:1]+:16] <= WriteDataM2; // sh
                        do_pending_write({ALUResultM2[63:1], 1'b0},   WriteDataM2, 2);
                    end
                    3'b010: begin
                        Data[set2][1][block2][32*ALUResultM2[2]+:32]   <= WriteDataM2; // sw
                        do_pending_write({ALUResultM2[63:2], 2'b00},  WriteDataM2, 4);
                    end
                    3'b011: begin
                        Data[set2][1][block2]                          <= WriteDataM2; // sd
                        do_pending_write({ALUResultM2[63:3], 3'b000}, WriteDataM2, 8);
                    end
                endcase
                Dirty[set2][1] <= 1;
                LRU[set2] = 0;
            end
        end
    end
end
endmodule