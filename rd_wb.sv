module rd_wb
(
    //****** RD ******
    //--- enable ---
    input  enableD,
    output JumpD,
    output BranchD,
    // Superscalar 1
    //--- register_file ---
    output [63:0] RD1D1,
    output [63:0] RD2D1,
    //--- control_unit ---
    input  [31:0] instrD1,
    output        RegWriteD1,
    output [1:0]  ResultSrcD1,
    output [4:0]  MemWriteReadSizeD1,
    output [5:0]  ALUControlD1,
    output        ALUSrcD1,
    output [63:0] ImmExtD1,
    output [4:0]  Rs1D1,
    output [4:0]  Rs2D1,
    output [4:0]  RdD1,
    output        EcallD1,
    //****** WB ******
    output enableW,
    output m_axi_acready,
    // Superscalar 1
    input  [4:0]  RdW1,
    input         RegWriteW1,
    input  [63:0] ResultW1,
    input         EcallW1,
    // use to print
    input  [63:0] PCD1,
    input  [63:0] num_clk,
    input  [63:0] num_instr,
    input  [63:0] num_axi
);
//****** RD ******
//--- control_unit ---
// Superscalar 1
always_comb begin
    if(enableD) begin
        RegWriteD1 = 0;
        ResultSrcD1 = 2'b00;
        MemWriteReadSizeD1 = 0;
        ALUSrcD1 = 0;
        ImmExtD1 = 0;
        Rs1D1 = 0;
        Rs2D1 = 0;
        RdD1 = 0;
        EcallD1 = 0;
        ALUControlD1 = 0;
        case(instrD1[6:0])
            //3, Type I
            7'b0000011: begin
                RegWriteD1 = 1;
                ResultSrcD1 = 2'b01;
                MemWriteReadSizeD1[4:3] = 2'b01;
                MemWriteReadSizeD1[2:0] = instrD1[14:12];
                ALUSrcD1 = 1;
                ImmExtD1 = {{52{instrD1[31]}}, instrD1[31:20]}; // imm_I
                Rs1D1 = instrD1[19:15];
                RdD1 = instrD1[11:7];
                ALUControlD1 = 4; // load
            end
            //19, Type I
            7'b0010011: begin
                RegWriteD1 = 1;
                ALUSrcD1 = 1;
                ImmExtD1 = {{52{instrD1[31]}}, instrD1[31:20]}; // imm_I
                Rs1D1 = instrD1[19:15];
                RdD1 = instrD1[11:7];
                case(instrD1[14:12])
                    3'b000: ALUControlD1 = 4; // addi
                    3'b001: ALUControlD1 = 1; // slli
                    3'b010: ALUControlD1 = 17; // slti
                    3'b011: ALUControlD1 = 18; // sltiu
                    3'b100: ALUControlD1 = 14; // xori
                    3'b101: begin
                    case(instrD1[31:26]) // NOT [31:25]
                        7'b000000: ALUControlD1 = 2; // srli // NOT 7'b0000000
                        7'b010000: ALUControlD1 = 3; // srai // NOT 7'b0100000
                    endcase
                    end
                    3'b110: ALUControlD1 = 15; // ori
                    3'b111: ALUControlD1 = 16; // andi
                endcase
            end
            //23,55, Type U ///////////// not sure
            7'b0010111, 7'b0110111: begin
                RegWriteD1 = 1;
                ALUSrcD1 = 1;
                ImmExtD1 = {{32{instrD1[31]}}, instrD1[31:12], 12'b0}; // imm_U
                RdD1 = instrD1[11:7];
                case(instrD1[6:0])
                    7'b0010111: ALUControlD1 = 19; // auipc
                    7'b0110111: ALUControlD1 = 20; // lui
                endcase
            end
            //27, Type I
            7'b0011011: begin
                RegWriteD1 = 1;
                ALUSrcD1 = 1;
                ImmExtD1 = {{52{instrD1[31]}}, instrD1[31:20]}; // imm_I
                Rs1D1 = instrD1[19:15];
                RdD1 = instrD1[11:7];
                case(instrD1[14:12])
                    3'b000: ALUControlD1 = 36; // addiw
                    3'b001: ALUControlD1 = 33; // slliw 
                    3'b101: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 34; // srliw
                        7'b0100000: ALUControlD1 = 35; // sraiw
                    endcase
                    end
                endcase
            end
            //35, Type S
            7'b0100011: begin
                MemWriteReadSizeD1[4:3] = 2'b10;
                MemWriteReadSizeD1[2:0] = instrD1[14:12];
                ALUSrcD1 = 1;
                ImmExtD1 = {{52{instrD1[31]}}, instrD1[31:25], instrD1[11:7]}; // imm_S
                Rs1D1 = instrD1[19:15];
                Rs2D1 = instrD1[24:20];
                RdD1 = instrD1[11:7];
                ALUControlD1 = 4; // save
            end
            //51, Type R
            7'b0110011: begin
                RegWriteD1 = 1;
                Rs1D1 = instrD1[19:15];
                Rs2D1 = instrD1[24:20];
                RdD1 = instrD1[11:7];
                case(instrD1[14:12])
                    3'b000: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 4; // add
                        7'b0000001: ALUControlD1 = 10; // mul
                        7'b0100000: ALUControlD1 = 5; // sub
                    endcase
                    end
                    3'b001: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 1; // sll
                        7'b0000001: ALUControlD1 = 11; // mulh
                    endcase
                    end
                    3'b010: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 17; // slt
                        7'b0000001: ALUControlD1 = 13; // mulhsu
                    endcase
                    end
                    3'b011: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 18; // sltu
                        7'b0000001: ALUControlD1 = 12; // mulhu
                    endcase
                    end
                    3'b100: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 14; // xor
                        7'b0000001: ALUControlD1 = 6; // div
                    endcase
                    end
                    3'b101: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 2; // srl
                        7'b0000001: ALUControlD1 = 7; // divu
                        7'b0100000: ALUControlD1 = 3; // sra
                    endcase
                    end
                    3'b110: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 15; // or
                        7'b0000001: ALUControlD1 = 8; // rem
                    endcase
                    end
                    3'b111: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 16; // and
                        7'b0000001: ALUControlD1 = 9; // remu
                    endcase
                    end
                endcase
            end
            //59, Type R
            7'b0111011: begin
                RegWriteD1 = 1;
                Rs1D1 = instrD1[19:15];
                Rs2D1 = instrD1[24:20];
                RdD1 = instrD1[11:7];
                case(instrD1[14:12])
                    3'b000: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 36; // addw
                        7'b0000001: ALUControlD1 = 42; // mulw
                        7'b0100000: ALUControlD1 = 37; // subw
                    endcase
                    end
                    3'b001: ALUControlD1 = 33; // sllw
                    3'b100: ALUControlD1 = 38; // divw
                    3'b101: begin
                    case(instrD1[31:25])
                        7'b0000000: ALUControlD1 = 34; // srlw
                        7'b0000001: ALUControlD1 = 39; // divuw
                        7'b0100000: ALUControlD1 = 35; // sraw
                    endcase
                    end
                    3'b110: ALUControlD1 = 40; // remw
                    3'b111: ALUControlD1 = 41; // remuw
                endcase
            end
            //99, Type B
            7'b1100011: begin
                BranchD = 1;
                ImmExtD1 = {{52{instrD1[31]}}, instrD1[7], instrD1[30:25], instrD1[11:8], 1'b0}; // imm_B
                Rs1D1 = instrD1[19:15];
                Rs2D1 = instrD1[24:20];
                case(instrD1[14:12])
                    3'b000: ALUControlD1 = 23; // beq
                    3'b001: ALUControlD1 = 24; // bne
                    3'b100: ALUControlD1 = 25; // blt
                    3'b101: ALUControlD1 = 26; // bge
                    3'b110: ALUControlD1 = 27; // bltu
                    3'b111: ALUControlD1 = 28; // bgeu 
                endcase
            end
            //103, Type I
            7'b1100111: begin
                RegWriteD1 = 1;
                ResultSrcD1 = 2'b10;
                JumpD = 1;
                ALUSrcD1 = 1;
                ImmExtD1 = {{52{instrD1[31]}}, instrD1[31:20]}; // imm_I
                Rs1D1 = instrD1[19:15];
                RdD1 = instrD1[11:7];
                ALUControlD1 = 21; // jalr
            end
            //111, Type J
            7'b1101111: begin
                RegWriteD1 = 1;
                ResultSrcD1 = 2'b10;
                JumpD = 1;
                ALUSrcD1 = 1;
                ImmExtD1 = {{44{instrD1[31]}}, instrD1[19:12], instrD1[20], instrD1[30:21], 1'b0}; // imm_J
                RdD1 = instrD1[11:7];
                ALUControlD1 = 22; // jal
            end
            //115, Type I
            7'b1110011: begin
                if(instrD1[14:12] == 0 && instrD1[31:20] == 0) begin
                    EcallD1 = 1; // ecall
                end
            end
        endcase
    end
end

//****** WB_RD ******
//--- register_file ---
logic [63:0] a0;
logic [63:0] a1;
logic [63:0] a2;
logic [63:0] a3;
logic [63:0] a4;
logic [63:0] a5;
logic [63:0] a6;
logic [63:0] a7;
reg [63:0] registers [32]; // $0 is hardwired to the value zero
always_comb begin
    //--- WB ---
    if(enableW) begin
        // Superscalar 1
        if(RegWriteW1 & RdW1!=0) registers[RdW1] = ResultW1;
        //--- Ecall ---
        if(EcallW1) begin
            a0 = registers[10];
            a1 = registers[11];
            a2 = registers[12];
            a3 = registers[13];
            a4 = registers[14];
            a5 = registers[15];
            a6 = registers[16];
            a7 = registers[17];
            //$display("ecall: %0x, %0x, %0x, %0x, %0x, %0x, %0x, %0x, %0x", a7, a0, a1, a2, a3, a4, a5, a6, a0);
            do_ecall(a7, a0, a1, a2, a3, a4, a5, a6, a0);
            registers[10] = a0;
            m_axi_acready = 1;
            // use to print
            if(a7 == 231) $display("num_clk:%0d  .  num_instr:%0d  .  num_axi:%0d", num_clk, num_instr, num_axi);
        end
    end

    //--- RD ---
    if(enableD) begin
        // Superscalar 1
        RD1D1 = registers[instrD1[19:15]];
        RD2D1 = registers[instrD1[24:20]];
    end
end
endmodule