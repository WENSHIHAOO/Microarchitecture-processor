module mem
(
    //****** MEM ******
    input  clk,
    input         enableM,
    input  [4:0]  MemWriteReadSizeM,
    input  [63:0] ALUResultM,
    input  [63:0] WriteDataM,
    output [63:0] ReadDataM,
    output        Stall,
    output        write_dirty,
    output [63:0] write_dirty_Data,
    // Write
    output [63:0] m_axi_awaddr,
    output        m_axi_awvalid,
    input         m_axi_awready,
    output [63:0] m_axi_wdata,
    output [7:0]  m_axi_wstrb,
    output        m_axi_wlast,
    output        m_axi_wvalid,
    input         m_axi_wready,
    // use to print
    input  [4:0]  RdM,
    input  [63:0] PCPlus4M
);
localparam C = 4 * 1024;      // Cache size (bytes), not including overhead such as the valid, tag, LRU, and dirty bits
localparam N = 2;             // Number of ways per set
localparam B = 8;             // Block size (bytes)
localparam S = 256; //C/(N*B) // Number of sets
reg [63:0] Data [S][N][B];
localparam m = 64;              // Number of physical address bits
localparam s = 8; //log2(S)     // Number of set index bits
localparam b = 3; //log2(B)     // Number of block offset bits
localparam y = 3;               // Number of byte offset bits
localparam t = m - (s + b + y); // Number of tag bits
reg [t:0] Valid_Tag [S][N];
reg LRU [S];
reg Dirty [S][N];

// check miss
logic miss;
logic [t-1:0] tag = ALUResultM[63:14];
logic [s-1:0] set = ALUResultM[13:6];
logic [b-1:0] block = ALUResultM[5:3];
logic step;
// Read
always_comb begin
    if(enableM) begin
        if(MemWriteReadSizeM[3]) begin
            // Read 64 bit data
            if(Valid_Tag[set][0][t] & (Valid_Tag[set][0][t-1:0] == tag)) begin
                ReadDataM = Data[set][0][block]; // 3'b011 // ld
                LRU[set] = 1;
            end
            else if(Valid_Tag[set][1][t] & (Valid_Tag[set][1][t-1:0] == tag)) begin
                ReadDataM = Data[set][1][block]; // 3'b011 // ld
                LRU[set] = 0;
            end
            else begin
                miss = 1;
                Stall = 1;
            end
            // Size
            if(!miss) begin
                case(MemWriteReadSizeM[2:0])
                    3'b000: begin
                        ReadDataM = {{56{ReadDataM[8*ALUResultM[2:0]+7]}}, ReadDataM[8*ALUResultM[2:0]+:8]};   // lb
                        $display("lb %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M-4, RdM, $signed(ALUResultM[12:0]), ReadDataM,ReadDataM);
                    end
                    3'b001: begin
                        ReadDataM = {{48{ReadDataM[16*ALUResultM[2:1]+15]}}, ReadDataM[16*ALUResultM[2:1]+:16]}; // lh
                        $display("lh %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M-4, RdM, $signed({ALUResultM[12:1], 1'b0}), ReadDataM,ReadDataM);
                    end
                    3'b010: begin
                        ReadDataM = {{32{ReadDataM[32*ALUResultM[2]+31]}}, ReadDataM[32*ALUResultM[2]+:32]}; // lw
                        $display("lw %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M-4, RdM, $signed({ALUResultM[12:2], 2'b00}), ReadDataM,ReadDataM);
                    end
                    3'b100: begin
                        ReadDataM = {{56{1'b0}}, ReadDataM[8*ALUResultM[2:0]+:8]};   // lbu
                        $display("lbu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M-4, RdM, $signed(ALUResultM[12:0]), ReadDataM,ReadDataM);
                    end
                    3'b101: begin
                        ReadDataM = {{48{1'b0}}, ReadDataM[16*ALUResultM[2:1]+:16]}; // lhu
                        $display("lhu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M-4, RdM, $signed({ALUResultM[12:1], 1'b0}), ReadDataM,ReadDataM);
                    end
                    3'b110: begin
                        ReadDataM = {{32{1'b0}}, ReadDataM[32*ALUResultM[2]+:32]}; // lwu
                        $display("lwu %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M-4, RdM, $signed({ALUResultM[12:2], 2'b00}), ReadDataM,ReadDataM);
                    end
                    default: begin
                        $display("ld %0x: x%0d = addr(%0d) = %0d(%0x)", PCPlus4M-4, RdM, $signed({ALUResultM[12:3], 3'b000}), ReadDataM,ReadDataM);
                    end
                endcase
                $display("------addr(%0d): Data0:%0x, Data1:%0x", $signed({ALUResultM[12:3], 3'b000}), Data[set][0][block], Data[set][1][block]);
                Stall = 0;
            end
        end
    end
end

// Write
always_ff @ (posedge clk) begin
    if(enableM) begin
        if(MemWriteReadSizeM[4]) begin
            if(Valid_Tag[set][0][t] & (Valid_Tag[set][0][t-1:0] == tag)) begin
                Dirty[set][0] <= 1;
                LRU[set] = 1;
            end
            else if(Valid_Tag[set][1][t] & (Valid_Tag[set][1][t-1:0] == tag)) begin
                Dirty[set][1] <= 1;
                LRU[set] = 0;
            end
            else begin
                if(Valid_Tag[set][LRU[set]][t]) begin
                    if(Dirty[set][LRU[set]]) begin
                        write_dirty_Data <= Data[set][LRU[set]][block];
                        write_dirty <= 1;
                    end
                end
                Valid_Tag[set][LRU[set]][t] <= 1;
                Valid_Tag[set][LRU[set]][t-1:0] <= tag;
                Dirty[set][LRU[set]] <= 1;
                LRU[set] = !LRU[set];
            end
            // fake-os ecall hacks work
            case(MemWriteReadSizeM[2:0])
                3'b000: begin
                    do_pending_write( ALUResultM,                WriteDataM, 1);
                    Data[set][!LRU[set]][block][8*ALUResultM[2:0]+:8]   <= WriteDataM; // sb
                end
                3'b001: begin
                    do_pending_write({ALUResultM[63:1], 1'b0},   WriteDataM, 2);
                    Data[set][!LRU[set]][block][16*ALUResultM[2:1]+:16] <= WriteDataM; // sh
                end
                3'b010: begin
                    do_pending_write({ALUResultM[63:2], 2'b00},  WriteDataM, 4);
                    Data[set][!LRU[set]][block][32*ALUResultM[2]+:32]   <= WriteDataM; // sw
                end
                3'b011: begin
                    do_pending_write({ALUResultM[63:3], 3'b000}, WriteDataM, 8);
                    Data[set][!LRU[set]][block]                         <= WriteDataM; // sd
                end
            endcase
            // use to print
            A = ALUResultM;
            W = WriteDataM;
            M = MemWriteReadSizeM;
            PC = PCPlus4M-4;
            P = 1;
        end
    end
end

// use to print
logic P;
logic [63:0] PC;
logic [63:0] A;
logic [63:0] W;
logic [4:0]  M;
always_ff @ (posedge clk) begin
    if(P) begin
        case(M[2:0])
            3'b000: $display("sb %0x: addr(%0d) = %0d(%0x), Data:%0x", PC, $signed(A[12:0]),           W,W, Data[A[13:6]][!LRU[A[13:6]]][A[5:3]]);
            3'b001: $display("sh %0x: addr(%0d) = %0d(%0x), Data:%0x", PC, $signed({A[12:1], 1'b0}),   W,W, Data[A[13:6]][!LRU[A[13:6]]][A[5:3]]);
            3'b010: $display("sw %0x: addr(%0d) = %0d(%0x), Data:%0x", PC, $signed({A[12:2], 2'b00}),  W,W, Data[A[13:6]][!LRU[A[13:6]]][A[5:3]]);
            3'b011: $display("sd %0x: addr(%0d) = %0d(%0x), Data:%0x", PC, $signed({A[12:3], 3'b000}), W,W, Data[A[13:6]][!LRU[A[13:6]]][A[5:3]]);
        endcase
        $display("------addr(%0d): Data0:%0x, Data1:%0x", $signed({A[12:3], 3'b000}), Data[A[13:6]][0][A[5:3]], Data[A[13:6]][1][A[5:3]]);
        P = 0;
    end
end
endmodule