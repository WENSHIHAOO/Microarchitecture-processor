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
    // Superscalar 1
    input  [4:0]  MemWriteReadSizeM1,
    input  [63:0] ALUResultM1,
    input  [63:0] WriteDataM1,
    output [63:0] ReadDataM1,
    output [63:0] MEM_addr1,
    // use to print
    input  [4:0]  RdM1,
    input  [63:0] PCPlus4M1,
    // Superscalar 2
    input  [4:0]  MemWriteReadSizeM2,
    input  [63:0] ALUResultM2,
    input  [63:0] WriteDataM2,
    output [63:0] ReadDataM2,
    output [63:0] MEM_addr2,
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
logic [t-1:0] tag1   = ALUResultM1[63      : s+b+y];
logic [s-1:0] set1   = ALUResultM1[s+b+y-1 : b+y];
logic [b-1:0] block1 = ALUResultM1[b+y-1   : y];
// Read
always_comb begin
    if(enableM) begin
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
                if(!((MemWriteReadSizeM2[3]|MemWriteReadSizeM2[4]) & (ALUResultM1[63:b+y]==ALUResultM2[63:b+y]))) begin
                    $display("read miss------addr: %0d(%0x): V0:%0d addr0:%0x, Data0:%0x, V1:%0d addr1:%0x, Data1:%0x", $signed({ALUResultM1[63:3], 3'b000}),{ALUResultM1[63:3], 3'b000}, 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][0][t], {Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][0][t-1:0],ALUResultM1[s+b+y-1 : 0]}, Data[set1][0][block1], 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][1][t], {Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][1][t-1:0],ALUResultM1[s+b+y-1 : 0]}, Data[set1][1][block1]);
                    MEM_addr1 = ALUResultM1;
                    MEM_miss1 = 1;
                    Stall_miss1 = 1;
                end
            end
            // Size
            if(!MEM_miss1) begin
                case(MemWriteReadSizeM1[2:0])
                    3'b000: begin
                        ReadDataM1 = {{56{ReadDataM1[8*ALUResultM1[2:0]+7]}}, ReadDataM1[8*ALUResultM1[2:0]+:8]};   // lb
                        $display("lb %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed(ALUResultM1[63:0]),ALUResultM1[63:0], ReadDataM1,ReadDataM1);
                    end
                    3'b001: begin
                        ReadDataM1 = {{48{ReadDataM1[16*ALUResultM1[2:1]+15]}}, ReadDataM1[16*ALUResultM1[2:1]+:16]}; // lh
                        $display("lh %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:1], 1'b0}),{ALUResultM1[63:1], 1'b0}, ReadDataM1,ReadDataM1);
                    end
                    3'b010: begin
                        ReadDataM1 = {{32{ReadDataM1[32*ALUResultM1[2]+31]}}, ReadDataM1[32*ALUResultM1[2]+:32]}; // lw
                        $display("lw %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:2], 2'b00}),{ALUResultM1[63:2], 2'b00}, ReadDataM1,ReadDataM1);
                    end
                    3'b100: begin
                        ReadDataM1 = {{56{1'b0}}, ReadDataM1[8*ALUResultM1[2:0]+:8]};   // lbu
                        $display("lbu %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed(ALUResultM1[63:0]),ALUResultM1[63:0], ReadDataM1,ReadDataM1);
                    end
                    3'b101: begin
                        ReadDataM1 = {{48{1'b0}}, ReadDataM1[16*ALUResultM1[2:1]+:16]}; // lhu
                        $display("lhu %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:1], 1'b0}),{ALUResultM1[63:1], 1'b0}, ReadDataM1,ReadDataM1);
                    end
                    3'b110: begin
                        ReadDataM1 = {{32{1'b0}}, ReadDataM1[32*ALUResultM1[2]+:32]}; // lwu
                        $display("lwu %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:2], 2'b00}),{ALUResultM1[63:2], 2'b00}, ReadDataM1,ReadDataM1);
                    end
                    default: begin
                        $display("ld %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M1-4, RdM1, $signed({ALUResultM1[63:3], 3'b000}),{ALUResultM1[63:3], 3'b000}, ReadDataM1,ReadDataM1);
                    end
                endcase
                $display("------addr: %0d(%0x): V0:%0d addr0:%0x, Data0:%0x, V1:%0d addr1:%0x, Data1:%0x", $signed({ALUResultM1[63:3], 3'b000}),{ALUResultM1[63:3], 3'b000}, 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][0][t], {Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][0][t-1:0],ALUResultM1[s+b+y-1 : 0]}, Data[set1][0][block1], 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][1][t], {Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][1][t-1:0],ALUResultM1[s+b+y-1 : 0]}, Data[set1][1][block1]);
                Stall_miss1 = 0;
            end
        end
    end
end

// Write
always_comb begin
    if(MemWriteReadSizeM1[4]) begin
        if(!(MemWriteReadSizeM2[4] & (ALUResultM1 == ALUResultM2))) begin 
            if(!(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) & !(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1))) begin
                if(!((MemWriteReadSizeM2[3]|MemWriteReadSizeM2[4]) & (ALUResultM1[63:b+y]==ALUResultM2[63:b+y]))) begin
                    $display("write miss------addr: %0d(%0x): V0:%0d addr0:%0x, Data0:%0x, V1:%0d addr1:%0x, Data1:%0x", $signed({ALUResultM1[63:3], 3'b000}),{ALUResultM1[63:3], 3'b000}, 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][0][t], {Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][0][t-1:0],ALUResultM1[s+b+y-1 : 0]}, Data[set1][0][block1], 
                        Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][1][t], {Valid_Tag[ALUResultM1[s+b+y-1 : b+y]][1][t-1:0],ALUResultM1[s+b+y-1 : 0]}, Data[set1][1][block1]);
                    MEM_addr1 = ALUResultM1;
                    MEM_miss1 = 1;
                    Stall_miss1 = 1;
                end
            end
            if(!MEM_miss1) begin
                case(MemWriteReadSizeM1[2:0])
                    3'b000: do_pending_write( ALUResultM1,                WriteDataM1, 1);
                    3'b001: do_pending_write({ALUResultM1[63:1], 1'b0},   WriteDataM1, 2);
                    3'b010: do_pending_write({ALUResultM1[63:2], 2'b00},  WriteDataM1, 4);
                    3'b011: do_pending_write({ALUResultM1[63:3], 3'b000}, WriteDataM1, 8);
                endcase
                Stall_miss1 = 0;
            end
        end
    end
end
always_ff @ (posedge clk) begin
    if(enableM) begin
        if(MemWriteReadSizeM1[4]) begin
            if(!(MemWriteReadSizeM2[4] & (ALUResultM1 == ALUResultM2))) begin // If two Superscalar write at the same time.
                if(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) begin
                    case(MemWriteReadSizeM1[2:0])
                        3'b000: Data[set1][0][block1][8*ALUResultM1[2:0]+:8]   <= WriteDataM1; // sb
                        3'b001: Data[set1][0][block1][16*ALUResultM1[2:1]+:16] <= WriteDataM1; // sh
                        3'b010: Data[set1][0][block1][32*ALUResultM1[2]+:32]   <= WriteDataM1; // sw
                        3'b011: Data[set1][0][block1]                          <= WriteDataM1; // sd
                    endcase
                    Dirty[set1][0] <= 1;
                    LRU[set1] = 1;
                    // use to print
                    P1 <= 1;
                end
                else if(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1)) begin
                    case(MemWriteReadSizeM1[2:0])
                        3'b000: Data[set1][1][block1][8*ALUResultM1[2:0]+:8]   <= WriteDataM1; // sb
                        3'b001: Data[set1][1][block1][16*ALUResultM1[2:1]+:16] <= WriteDataM1; // sh
                        3'b010: Data[set1][1][block1][32*ALUResultM1[2]+:32]   <= WriteDataM1; // sw
                        3'b011: Data[set1][1][block1]                          <= WriteDataM1; // sd
                    endcase
                    Dirty[set1][1] <= 1;
                    LRU[set1] = 0;
                    // use to print
                    P1 <= 1;
                end
                // use to print
                A1 <= ALUResultM1;
                W1 <= WriteDataM1;
                M1 <= MemWriteReadSizeM1;
                PC1 <= PCPlus4M1-4;
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
            3'b000: $display("sb %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC1, $signed(A1[63:0]),A1[63:0],           W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
            3'b001: $display("sh %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC1, $signed({A1[63:1], 1'b0}),{A1[63:1], 1'b0},   W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
            3'b010: $display("sw %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC1, $signed({A1[63:2], 2'b00}),{A1[63:2], 2'b00},  W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
            3'b011: $display("sd %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC1, $signed({A1[63:3], 3'b000}),{A1[63:3], 3'b000}, W1,W1, Data[A1[s+b+y-1 : b+y]][!LRU[A1[s+b+y-1 : b+y]]][A1[b+y-1 : y]]);
        endcase
        $display("------addr: %0d(%0x): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d addr1:%0x, Data1:%0x", $signed({A1[63:3], 3'b000}),{A1[63:3], 3'b000}, 
                Valid_Tag[A1[s+b+y-1 : b+y]][0][t], {Valid_Tag[A1[s+b+y-1 : b+y]][0][t-1:0], A1[s+b+y-1 : 0]}, Data[A1[s+b+y-1 : b+y]][0][A1[b+y-1 : y]], 
                Valid_Tag[A1[s+b+y-1 : b+y]][1][t], {Valid_Tag[A1[s+b+y-1 : b+y]][1][t-1:0], A1[s+b+y-1 : 0]}, Data[A1[s+b+y-1 : b+y]][1][A1[b+y-1 : y]]);
        P1 <= 0;
    end
end

// Superscalar 2
// check miss2
logic [t-1:0] tag2   = ALUResultM2[63      : s+b+y];
logic [s-1:0] set2   = ALUResultM2[s+b+y-1 : b+y];
logic [b-1:0] block2 = ALUResultM2[b+y-1   : y];
// Read
always_comb begin
    if(enableM) begin
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
                    $display("read miss------addr: %0d(%0x): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d, addr1:%0x, Data1:%0x", $signed({ALUResultM2[63:3], 3'b000}),{ALUResultM2[63:3], 3'b000}, 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][0][t], {Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][0][t-1:0], ALUResultM2[s+b+y-1 : 0]}, Data[set2][0][block2], 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][1][t], {Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][1][t-1:0], ALUResultM2[s+b+y-1 : 0]}, Data[set2][1][block2]);
                    MEM_addr2 = ALUResultM2;
                    MEM_miss2 = 1;
                    Stall_miss2 = 1;
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
                        $display("lb %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed(ALUResultM2[63:0]),ALUResultM2[63:0], ReadDataM2,ReadDataM2);
                    end
                    3'b001: begin
                        ReadDataM2 = {{48{ReadDataM2[16*ALUResultM2[2:1]+15]}}, ReadDataM2[16*ALUResultM2[2:1]+:16]}; // lh
                        $display("lh %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:1], 1'b0}),{ALUResultM2[63:1], 1'b0}, ReadDataM2,ReadDataM2);
                    end
                    3'b010: begin
                        ReadDataM2 = {{32{ReadDataM2[32*ALUResultM2[2]+31]}}, ReadDataM2[32*ALUResultM2[2]+:32]}; // lw
                        $display("lw %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:2], 2'b00}),{ALUResultM2[63:2], 2'b00}, ReadDataM2,ReadDataM2);
                    end
                    3'b100: begin
                        ReadDataM2 = {{56{1'b0}}, ReadDataM2[8*ALUResultM2[2:0]+:8]};   // lbu
                        $display("lbu %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed(ALUResultM2[63:0]),ALUResultM2[63:0], ReadDataM2,ReadDataM2);
                    end
                    3'b101: begin
                        ReadDataM2 = {{48{1'b0}}, ReadDataM2[16*ALUResultM2[2:1]+:16]}; // lhu
                        $display("lhu %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:1], 1'b0}),{ALUResultM2[63:1], 1'b0}, ReadDataM2,ReadDataM2);
                    end
                    3'b110: begin
                        ReadDataM2 = {{32{1'b0}}, ReadDataM2[32*ALUResultM2[2]+:32]}; // lwu
                        $display("lwu %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:2], 2'b00}),{ALUResultM2[63:2], 2'b00}, ReadDataM2,ReadDataM2);
                    end
                    default: begin
                        $display("ld %0x: x%0d = addr: %0d(%0x) = %0d(%0x)", PCPlus4M2-4, RdM2, $signed({ALUResultM2[63:3], 3'b000}),{ALUResultM2[63:3], 3'b000}, ReadDataM2,ReadDataM2);
                    end
                endcase
                $display("------addr: %0d(%0x): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d, addr1:%0x, Data1:%0x", $signed({ALUResultM2[63:3], 3'b000}),{ALUResultM2[63:3], 3'b000}, 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][0][t], {Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][0][t-1:0], ALUResultM2[s+b+y-1 : 0]}, Data[set2][0][block2], 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][1][t], {Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][1][t-1:0], ALUResultM2[s+b+y-1 : 0]}, Data[set2][1][block2]);
                Stall_miss2 = 0;
            end
        end
    end
end

// Write
always_comb begin
    if(enableM) begin
        if(MemWriteReadSizeM2[4]) begin
            if(!(Valid_Tag[set2][0][t] & (Valid_Tag[set2][0][t-1:0] == tag2)) & !(Valid_Tag[set2][1][t] & (Valid_Tag[set2][1][t-1:0] == tag2))) begin
                $display("write miss------addr: %0d(%0x): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d, addr1:%0x, Data1:%0x", $signed({ALUResultM2[63:3], 3'b000}),{ALUResultM2[63:3], 3'b000}, 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][0][t], {Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][0][t-1:0], ALUResultM2[s+b+y-1 : 0]}, Data[set2][0][block2], 
                        Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][1][t], {Valid_Tag[ALUResultM2[s+b+y-1 : b+y]][1][t-1:0], ALUResultM2[s+b+y-1 : 0]}, Data[set2][1][block2]);
                MEM_addr2 = ALUResultM2;
                MEM_miss2 = 1;
                Stall_miss2 = 1;
            end
            if(!MEM_miss2) begin
                case(MemWriteReadSizeM2[2:0])
                    3'b000: do_pending_write( ALUResultM2,                WriteDataM2, 1);
                    3'b001: do_pending_write({ALUResultM2[63:1], 1'b0},   WriteDataM2, 2);
                    3'b010: do_pending_write({ALUResultM2[63:2], 2'b00},  WriteDataM2, 4);
                    3'b011: do_pending_write({ALUResultM2[63:3], 3'b000}, WriteDataM2, 8);
                endcase
                Stall_miss2 = 0;
            end
        end
    end
end
always_ff @ (posedge clk) begin
    if(enableM) begin
        if(MemWriteReadSizeM2[4]) begin
            if(Valid_Tag[set2][0][t] & (Valid_Tag[set2][0][t-1:0] == tag2)) begin
                case(MemWriteReadSizeM2[2:0])
                    3'b000: Data[set2][0][block2][8*ALUResultM2[2:0]+:8]   <= WriteDataM2; // sb
                    3'b001: Data[set2][0][block2][16*ALUResultM2[2:1]+:16] <= WriteDataM2; // sh
                    3'b010: Data[set2][0][block2][32*ALUResultM2[2]+:32]   <= WriteDataM2; // sw
                    3'b011: Data[set2][0][block2]                          <= WriteDataM2; // sd
                endcase
                Dirty[set2][0] <= 1;
                LRU[set2] = 1;
                // use to print
                P2 <= 1;
            end
            else if(Valid_Tag[set2][1][t] & (Valid_Tag[set2][1][t-1:0] == tag2)) begin
                case(MemWriteReadSizeM2[2:0])
                    3'b000: Data[set2][1][block2][8*ALUResultM2[2:0]+:8]   <= WriteDataM2; // sb
                    3'b001: Data[set2][1][block2][16*ALUResultM2[2:1]+:16] <= WriteDataM2; // sh
                    3'b010: Data[set2][1][block2][32*ALUResultM2[2]+:32]   <= WriteDataM2; // sw
                    3'b011: Data[set2][1][block2]                          <= WriteDataM2; // sd
                endcase
                Dirty[set2][1] <= 1;
                LRU[set2] = 0;
                // use to print
                P2 <= 1;
            end
            // use to print
                A2 <= ALUResultM2;
                W2 <= WriteDataM2;
                M2 <= MemWriteReadSizeM2;
                PC2 <= PCPlus4M2-4;
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
            3'b000: $display("sb %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC2, $signed(A2[63:0]),A2[63:0],           W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
            3'b001: $display("sh %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC2, $signed({A2[63:1], 1'b0}),{A2[63:1], 1'b0},   W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
            3'b010: $display("sw %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC2, $signed({A2[63:2], 2'b00}),{A2[63:2], 2'b00},  W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
            3'b011: $display("sd %0x: addr: %0d(%0x) = %0d(%0x), Data:%0x", PC2, $signed({A2[63:3], 3'b000}),{A2[63:3], 3'b000}, W2,W2, Data[A2[s+b+y-1 : b+y]][!LRU[A2[s+b+y-1 : b+y]]][A2[b+y-1 : y]]);
        endcase
        $display("------addr: %0d(%0x): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d, addr1:%0x, Data1:%0x", $signed({A2[63:3], 3'b000}),{A2[63:3], 3'b000}, 
                Valid_Tag[A2[s+b+y-1 : b+y]][0][t], {Valid_Tag[A2[s+b+y-1 : b+y]][0][t-1:0], A2[s+b+y-1 : 0]}, Data[A2[s+b+y-1 : b+y]][0][A2[b+y-1 : y]], 
                Valid_Tag[A2[s+b+y-1 : b+y]][1][t], {Valid_Tag[A2[s+b+y-1 : b+y]][1][t-1:0], A2[s+b+y-1 : 0]}, Data[A2[s+b+y-1 : b+y]][1][A2[b+y-1 : y]]);
        P2 <= 0;
    end
end
endmodule