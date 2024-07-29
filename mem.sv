module mem
#(
    N = 0, // Number of ways per set
    B = 0, // Block size (bytes)
    S = 0, // Number of sets
    s = 0, // Number of set index bits
    b = 0, // Number of block offset bits
    y = 0, // Number of byte offset bits
    t = 0 // Number of tag bits
)
(
    //****** MEM ******
    input  clk,
    input         enableM,
    output        Stall_miss1,
    output        Stall_miss2,
    output        MEM_miss1,
    output        MEM_miss2,
    // Hazard
    input  [63:0] registers10,
    input  [63:0] ImmExtE1,
    input  [63:0] ImmExtE2,
    output        FrowardAM1,
    output        FrowardWM1,
    output        FrowardAM2,
    output        FrowardWM2,
    // Write
    output        write_dirty1,
    output        write_dirty2,
    output [63:0] write_dirty1_Data,
    output [63:0] write_dirty2_Data,
    // Superscalar 1
    input  [4:0]  MemWriteReadSizeM1,
    output [63:0] ALUResultM1,
    output [63:0] WriteDataM1,
    output [63:0] ReadDataM1,
    // use to print
    input  [4:0]  RdM1,
    input  [63:0] PCPlus4M1,
    // Superscalar 2
    input  [4:0]  MemWriteReadSizeM2,
    output [63:0] ALUResultM2,
    output [63:0] WriteDataM2,
    output [63:0] ReadDataM2,
    // use to print
    input  [4:0]  RdM2,
    input  [63:0] PCPlus4M2
);
reg [63:0] Data [S][N][B];
reg [t:0] Valid_Tag [S][N];
reg LRU [S];
reg Dirty [S][N];

// Superscalar 1
// check miss1
logic [t-1:0] tag1;
logic [s-1:0] set1;
logic [b-1:0] block1;
always_ff @ (posedge clk) begin
    if(enableM) begin
        if(FrowardAM1) ALUResultM1 = $signed(RD_WB.registers[10]) + $signed(ImmExtE1);
        tag1   = ALUResultM1[63      : s+b+y];
        set1   = ALUResultM1[s+b+y-1 : b+y];
        block1 = ALUResultM1[b+y-1   : y];
        // Read
        if(MemWriteReadSizeM1[3]) begin
            // Read 64 bit data
            if(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) begin
                ReadDataM1 = Data[set1][0][block1]; // 3'b011 // ld
                LRU[set1] = 1;
            end
            else if(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1)) begin
                ReadDataM1 = Data[set1][1][block1]; // 3'b011 // ld
                LRU[set1] = 0;
            end
            else begin
                Stall_miss1 = 1;
                MEM_miss1 = 1;
            end
            // Size
            if(!MEM_miss1) begin
                case(MemWriteReadSizeM1[2:0])
                    3'b000: begin
                        ReadDataM1 = {{56{ReadDataM1[8*ALUResultM1[2:0]+7]}}, ReadDataM1[8*ALUResultM1[2:0]+:8]};   // lb
                        $display("lb %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed(ALUResultM1[63:0]), ReadDataM1,ReadDataM1);
                    end
                    3'b001: begin
                        ReadDataM1 = {{48{ReadDataM1[16*ALUResultM1[2:1]+15]}}, ReadDataM1[16*ALUResultM1[2:1]+:16]}; // lh
                        $display("lh %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:1], 1'b0}), ReadDataM1,ReadDataM1);
                    end
                    3'b010: begin
                        ReadDataM1 = {{32{ReadDataM1[32*ALUResultM1[2]+31]}}, ReadDataM1[32*ALUResultM1[2]+:32]}; // lw
                        $display("lw %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:2], 2'b00}), ReadDataM1,ReadDataM1);
                    end
                    3'b100: begin
                        ReadDataM1 = {{56{1'b0}}, ReadDataM1[8*ALUResultM1[2:0]+:8]};   // lbu
                        $display("lbu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed(ALUResultM1[63:0]), ReadDataM1,ReadDataM1);
                    end
                    3'b101: begin
                        ReadDataM1 = {{48{1'b0}}, ReadDataM1[16*ALUResultM1[2:1]+:16]}; // lhu
                        $display("lhu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:1], 1'b0}), ReadDataM1,ReadDataM1);
                    end
                    3'b110: begin
                        ReadDataM1 = {{32{1'b0}}, ReadDataM1[32*ALUResultM1[2]+:32]}; // lwu
                        $display("lwu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:2], 2'b00}), ReadDataM1,ReadDataM1);
                    end
                    default: begin
                        $display("ld %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:3], 3'b000}), ReadDataM1,ReadDataM1);
                    end
                endcase
                $display("------addr(%0d): V0:%0d Data0:%0x, V1:%0d Data1:%0x", $signed({ALUResultM1[63:3], 3'b000}), 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][0][t], Data[set1][0][block1], 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][1][t], Data[set1][1][block1]);
                Stall_miss1 = 0;
            end
        end
        // Write
        if(MemWriteReadSizeM1[4]) begin
            if(FrowardWM1) WriteDataM1 = RD_WB.registers[10];
            if(!(MemWriteReadSizeM2[4] & (ALUResultM1 == ALUResultM2))) begin // If two Superscalar write at the same time.
                if(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) begin
                    Dirty[set1][0] <= 1;
                    LRU[set1] = 1;
                end
                else if(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1)) begin
                    Dirty[set1][1] <= 1;
                    LRU[set1] = 0;
                end
                else begin
                    if(Valid_Tag[set1][LRU[set1]][t]) begin
                        if(Dirty[set1][LRU[set1]]) begin
                            write_dirty1_Data <= Data[set1][LRU[set1]][block1];
                            write_dirty1 <= 1;
                        end
                    end
                    Valid_Tag[set1][LRU[set1]][t] <= 1;
                    Valid_Tag[set1][LRU[set1]][t-1:0] <= tag1;
                    Dirty[set1][LRU[set1]] <= 1;
                    LRU[set1] = !LRU[set1];
                end
                // fake-os ecall hacks work
                case(MemWriteReadSizeM1[2:0])
                    3'b000: begin
                        do_pending_write( ALUResultM1,                WriteDataM1, 1);
                        Data[set1][!LRU[set1]][block1][8*ALUResultM1[2:0]+:8]   <= WriteDataM1; // sb
                    end
                    3'b001: begin
                        do_pending_write({ALUResultM1[63:1], 1'b0},   WriteDataM1, 2);
                        Data[set1][!LRU[set1]][block1][16*ALUResultM1[2:1]+:16] <= WriteDataM1; // sh
                    end
                    3'b010: begin
                        do_pending_write({ALUResultM1[63:2], 2'b00},  WriteDataM1, 4);
                        Data[set1][!LRU[set1]][block1][32*ALUResultM1[2]+:32]   <= WriteDataM1; // sw
                    end
                    3'b011: begin
                        do_pending_write({ALUResultM1[63:3], 3'b000}, WriteDataM1, 8);
                        Data[set1][!LRU[set1]][block1]                         <= WriteDataM1; // sd
                    end
                endcase
                // use to print
                A1 <= ALUResultM1;
                W1 <= WriteDataM1;
                M1 <= MemWriteReadSizeM1;
                PC1 <= PCPlus4M1-4;
                P1 <= 1;
            end
        end
    end
end

// use to print
logic P1;
logic [63:0] PC1;
logic [63:0] A1;
logic [63:0] W1;
logic [4:0]  M1;
always_ff @ (posedge clk) begin
    if(P1) begin
        case(M1[2:0])
            3'b000: $display("sb %0x: addr(%0d) = %0d(%0x), Data:%0x", PC1, $signed(A1[63:0]),           W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
            3'b001: $display("sh %0x: addr(%0d) = %0d(%0x), Data:%0x", PC1, $signed({A1[63:1], 1'b0}),   W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
            3'b010: $display("sw %0x: addr(%0d) = %0d(%0x), Data:%0x", PC1, $signed({A1[63:2], 2'b00}),  W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
            3'b011: $display("sd %0x: addr(%0d) = %0d(%0x), Data:%0x", PC1, $signed({A1[63:3], 3'b000}), W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
        endcase
        $display("------addr(%0d): V0:%0d Data0:%0x, V1:%0d Data1:%0x", $signed({A1[63:3], 3'b000}), 
                Valid_Tag[A1[s+b+y-1 : b+y]][0][t], Data[A1[s+b+y-1 : b+y]][0][A1[b+y-1 : y]], 
                Valid_Tag[A1[s+b+y-1 : b+y]][1][t], Data[A1[s+b+y-1 : b+y]][1][A1[b+y-1 : y]]);
        P1 <= 0;
    end
end

// Superscalar 2
// check miss2
logic [t-1:0] tag2;
logic [s-1:0] set2;
logic [b-1:0] block2;
always_ff @ (posedge clk) begin
    if(enableM) begin
        if(FrowardAM2) ALUResultM2 = $signed(RD_WB.registers[10]) + $signed(ImmExtE2);
        tag2   = ALUResultM2[63      : s+b+y];
        set2   = ALUResultM2[s+b+y-1 : b+y];
        block2 = ALUResultM2[b+y-1   : y];
        // Read
        if(MemWriteReadSizeM2[3]) begin
            // Read 64 bit data
            if(Valid_Tag[set2][0][t] & (Valid_Tag[set2][0][t-1:0] == tag2)) begin
                ReadDataM2 = Data[set2][0][block2]; // 3'b011 // ld
                LRU[set2] = 1;
            end
            else if(Valid_Tag[set2][1][t] & (Valid_Tag[set2][1][t-1:0] == tag2)) begin
                ReadDataM2 = Data[set2][1][block2]; // 3'b011 // ld
                LRU[set2] = 0;
            end
            else begin
                if(MemWriteReadSizeM1[4] & (ALUResultM1[63:y] == ALUResultM2[63:y])) begin
                    // when Superscalar 1 write, Superscalar 2 read.
                    ReadDataM2 = 0;
                end else begin
                    Stall_miss2 = 1;
                    MEM_miss2 = 1;
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
            if(!MEM_miss2) begin
                case(MemWriteReadSizeM2[2:0])
                    3'b000: begin
                        ReadDataM2 = {{56{ReadDataM2[8*ALUResultM2[2:0]+7]}}, ReadDataM2[8*ALUResultM2[2:0]+:8]};   // lb
                        $display("lb %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed(ALUResultM2[63:0]), ReadDataM2,ReadDataM2);
                    end
                    3'b001: begin
                        ReadDataM2 = {{48{ReadDataM2[16*ALUResultM2[2:1]+15]}}, ReadDataM2[16*ALUResultM2[2:1]+:16]}; // lh
                        $display("lh %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:1], 1'b0}), ReadDataM2,ReadDataM2);
                    end
                    3'b010: begin
                        ReadDataM2 = {{32{ReadDataM2[32*ALUResultM2[2]+31]}}, ReadDataM2[32*ALUResultM2[2]+:32]}; // lw
                        $display("lw %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:2], 2'b00}), ReadDataM2,ReadDataM2);
                    end
                    3'b100: begin
                        ReadDataM2 = {{56{1'b0}}, ReadDataM2[8*ALUResultM2[2:0]+:8]};   // lbu
                        $display("lbu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed(ALUResultM2[63:0]), ReadDataM2,ReadDataM2);
                    end
                    3'b101: begin
                        ReadDataM2 = {{48{1'b0}}, ReadDataM2[16*ALUResultM2[2:1]+:16]}; // lhu
                        $display("lhu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:1], 1'b0}), ReadDataM2,ReadDataM2);
                    end
                    3'b110: begin
                        ReadDataM2 = {{32{1'b0}}, ReadDataM2[32*ALUResultM2[2]+:32]}; // lwu
                        $display("lwu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:2], 2'b00}), ReadDataM2,ReadDataM2);
                    end
                    default: begin
                        $display("ld %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:3], 3'b000}), ReadDataM2,ReadDataM2);
                    end
                endcase
                $display("------addr(%0d): V0:%0d Data0:%0x, V1:%0d Data1:%0x", $signed({ALUResultM2[63:3], 3'b000}), 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][0][t], Data[set2][0][block2], 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][1][t], Data[set2][1][block2]);
                Stall_miss2 = 0;
            end
        end
        // Write
        if(MemWriteReadSizeM2[4]) begin
            if(FrowardWM2) WriteDataM2 = RD_WB.registers[10];
            if(Valid_Tag[set2][0][t] & (Valid_Tag[set2][0][t-1:0] == tag2)) begin
                Dirty[set2][0] <= 1;
                LRU[set2] = 1;
            end
            else if(Valid_Tag[set2][1][t] & (Valid_Tag[set2][1][t-1:0] == tag2)) begin
                Dirty[set2][1] <= 1;
                LRU[set2] = 0;
            end
            else begin
                if(Valid_Tag[set2][LRU[set2]][t]) begin
                    if(Dirty[set2][LRU[set2]]) begin
                        write_dirty2_Data <= Data[set2][LRU[set2]][block2];
                        write_dirty2 <= 1;
                    end
                end
                Valid_Tag[set2][LRU[set2]][t] <= 1;
                Valid_Tag[set2][LRU[set2]][t-1:0] <= tag2;
                Dirty[set2][LRU[set2]] <= 1;
                LRU[set2] = !LRU[set2];
            end
            // fake-os ecall hacks work
            case(MemWriteReadSizeM2[2:0])
                3'b000: begin
                    do_pending_write( ALUResultM2,                WriteDataM2, 1);
                    Data[set2][!LRU[set2]][block2][8*ALUResultM2[2:0]+:8]   <= WriteDataM2; // sb
                end
                3'b001: begin
                    do_pending_write({ALUResultM2[63:1], 1'b0},   WriteDataM2, 2);
                    Data[set2][!LRU[set2]][block2][16*ALUResultM2[2:1]+:16] <= WriteDataM2; // sh
                end
                3'b010: begin
                    do_pending_write({ALUResultM2[63:2], 2'b00},  WriteDataM2, 4);
                    Data[set2][!LRU[set2]][block2][32*ALUResultM2[2]+:32]   <= WriteDataM2; // sw
                end
                3'b011: begin
                    do_pending_write({ALUResultM2[63:3], 3'b000}, WriteDataM2, 8);
                    Data[set2][!LRU[set2]][block2]                         <= WriteDataM2; // sd
                end
            endcase
            // use to print
            A2 <= ALUResultM2;
            W2 <= WriteDataM2;
            M2 <= MemWriteReadSizeM2;
            PC2 <= PCPlus4M2-4;
            P2 <= 1;
        end
    end
end

// use to print
logic P2;
logic [63:0] PC2;
logic [63:0] A2;
logic [63:0] W2;
logic [4:0]  M2;
always_ff @ (posedge clk) begin
    if(P2) begin
        case(M2[2:0])
            3'b000: $display("sb %0x: addr(%0d) = %0d(%0x), Data:%0x", PC2, $signed(A2[63:0]),           W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
            3'b001: $display("sh %0x: addr(%0d) = %0d(%0x), Data:%0x", PC2, $signed({A2[63:1], 1'b0}),   W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
            3'b010: $display("sw %0x: addr(%0d) = %0d(%0x), Data:%0x", PC2, $signed({A2[63:2], 2'b00}),  W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
            3'b011: $display("sd %0x: addr(%0d) = %0d(%0x), Data:%0x", PC2, $signed({A2[63:3], 3'b000}), W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
        endcase
        $display("------addr(%0d): V0:%0d Data0:%0x, V1:%0d Data1:%0x", $signed({A2[63:3], 3'b000}), 
                Valid_Tag[A2[s+b+y-1 : b+y]][0][t], Data[A2[s+b+y-1 : b+y]][0][A2[b+y-1 : y]], 
                Valid_Tag[A2[s+b+y-1 : b+y]][1][t], Data[A2[s+b+y-1 : b+y]][1][A2[b+y-1 : y]]);
        P2 <= 0;
    end
end
endmodule