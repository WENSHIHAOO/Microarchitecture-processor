module rd_wb
(
    //****** RD ******
    input  clk,
    //--- enable ---
    input  enableD,
    //--- register_file ---
    output [63:0] RD1D,
    output [63:0] RD2D,
    //--- control_unit ---
    input  [31:0] instrD,
    output        RegWriteD,
    output [1:0]  ResultSrcD,
    output [4:0]  MemWriteReadSizeD,
    output        JumpD,
    output        BranchD,
    output [5:0]  ALUControlD,
    output        ALUSrcD,
    output [63:0] ImmExtD,
    output [4:0]  Rs1D,
    output [4:0]  Rs2D,
    output        EcallD,
    //****** WB ******
    output enableW,
    input  [4:0]  RdW,
    input         RegWriteW,
    input  [63:0] ResultW,
    input         EcallW
);
reg [63:0] registers [32];
always_comb begin
//****** RD ******
    if(enableD) begin
        //--- register_file ---
        if(instrD[19:15]==RdW & RdW!=0 & RegWriteW) begin
            RD1D = ResultW;
        end else begin
            RD1D = registers[instrD[19:15]];
        end
        if(instrD[24:20]==RdW & RdW!=0 & RegWriteW) begin
            RD2D = ResultW;
        end else begin
            RD2D = registers[instrD[24:20]];
        end
        //--- control_unit ---
        case(instrD[6:0])
            //3, Type I
            7'b0000011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b01;
                MemWriteReadSizeD[4:3] = 2'b01;
                MemWriteReadSizeD[2:0] = instrD[14:12];
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                EcallD = 0;
                ALUControlD = 4; // load
            end
            //19, Type I
            7'b0010011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                EcallD = 0;
                case(instrD[14:12])
                    3'b000: ALUControlD = 4; // addi
                    3'b001: ALUControlD = 1; // slli
                    3'b010: ALUControlD = 17; // slti
                    3'b011: ALUControlD = 18; // sltiu
                    3'b100: ALUControlD = 14; // xori
                    3'b101: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 2; // srli
                        7'b0100000: ALUControlD = 3; // srai
                    endcase
                    end
                    3'b110: ALUControlD = 15; // ori
                    3'b111: ALUControlD = 16; // andi
                endcase
            end
            //23,55, Type U ///////////// not sure
            7'b0010111, 7'b0110111: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{32{instrD[31]}}, instrD[31:12], 12'b0}; // imm_U
                Rs1D = 0;
                Rs2D = 0;
                EcallD = 0;
                case(instrD[6:0])
                    7'b0010111: ALUControlD = 19; // auipc
                    7'b0110111: ALUControlD = 20; // lui
                endcase
            end
            //27, Type I
            7'b0011011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                EcallD = 0;
                case(instrD[14:12])
                    3'b000: ALUControlD = 36; // addiw
                    3'b001: ALUControlD = 33; // slliw 
                    3'b101: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 34; // srliw
                        7'b0100000: ALUControlD = 35; // sraiw
                    endcase
                    end
                endcase
            end
            //35, Type S
            7'b0100011: begin
                RegWriteD = 0;
                ResultSrcD = 2'b00;
                MemWriteReadSizeD[4:3] = 2'b10;
                MemWriteReadSizeD[2:0] = instrD[14:12];
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:25], instrD[11:7]}; // imm_S
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
                EcallD = 0;
                ALUControlD = 4; // save
            end
            //51, Type R
            7'b0110011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 0;
                //ImmExtD = ?;
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
                EcallD = 0;
                case(instrD[14:12])
                    3'b000: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 4; // add
                        7'b0000001: ALUControlD = 10; // mul
                        7'b0100000: ALUControlD = 5; // sub
                    endcase
                    end
                    3'b001: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 1; // sll
                        7'b0000001: ALUControlD = 11; // mulh
                    endcase
                    end
                    3'b010: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 17; // slt
                        7'b0000001: ALUControlD = 13; // mulhsu
                    endcase
                    end
                    3'b011: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 18; // sltu
                        7'b0000001: ALUControlD = 12; // mulhu
                    endcase
                    end
                    3'b100: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 14; // xor
                        7'b0000001: ALUControlD = 6; // div
                    endcase
                    end
                    3'b101: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 2; // srl
                        7'b0000001: ALUControlD = 7; // divu
                        7'b0100000: ALUControlD = 3; // sra
                    endcase
                    end
                    3'b110: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 15; // or
                        7'b0000001: ALUControlD = 8; // rem
                    endcase
                    end
                    3'b111: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 16; // and
                        7'b0000001: ALUControlD = 9; // remu
                    endcase
                    end
                endcase
            end
            //59, Type R
            7'b0111011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 0;
                //ImmExtD = ?;
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
                EcallD = 0;
                case(instrD[14:12])
                    3'b000: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 36; // addw
                        7'b0000001: ALUControlD = 42; // mulw
                        7'b0100000: ALUControlD = 37; // subw
                    endcase
                    end
                    3'b001: ALUControlD = 33; // sllw
                    3'b100: ALUControlD = 38; // divw
                    3'b101: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 34; // srlw
                        7'b0000001: ALUControlD = 39; // divuw
                        7'b0100000: ALUControlD = 35; // sraw
                    endcase
                    end
                    3'b110: ALUControlD = 40; // remw
                    3'b111: ALUControlD = 41; // remuw
                endcase
            end
            //99, Type B
            7'b1100011: begin
                RegWriteD = 0;
                ResultSrcD = 2'b00;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 1;
                ALUSrcD = 0;
                ImmExtD = {{52{instrD[31]}}, instrD[7], instrD[30:25], instrD[11:8], 1'b0}; // imm_B
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
                EcallD = 0;
                case(instrD[14:12])
                    3'b000: ALUControlD = 23; // beq
                    3'b001: ALUControlD = 24; // bne
                    3'b100: ALUControlD = 25; // blt
                    3'b101: ALUControlD = 26; // bge
                    3'b110: ALUControlD = 27; // bltu
                    3'b111: ALUControlD = 28; // bgeu 
                endcase
            end
            //103, Type I
            7'b1100111: begin
                RegWriteD = 1;
                ResultSrcD = 2'b10;
                MemWriteReadSizeD = 0;
                JumpD = 1;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                EcallD = 0;
                ALUControlD = 21; // jalr
            end
            //111, Type J
            7'b1101111: begin
                RegWriteD = 1;
                ResultSrcD = 2'b10;
                MemWriteReadSizeD = 0;
                JumpD = 1;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{44{instrD[31]}}, instrD[19:12], instrD[20], instrD[30:21], 1'b0}; // imm_J
                Rs1D = 0;
                Rs2D = 0;
                EcallD = 0;
                ALUControlD = 22; // jal
            end
            //115, Type I
            7'b1110011: begin
                RegWriteD = 0;
                ResultSrcD = 0;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 0;
                Rs1D = 0;
                Rs2D = 0;
                EcallD = 0;
                ImmExtD = 0;
                ALUControlD = 0;
                if(instrD[14:12] == 0 && instrD[31:20] == 0) begin
                    EcallD = 1; // ecall
                end
            end
            default: begin
                RegWriteD = 0;
                ResultSrcD = 0;
                MemWriteReadSizeD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 0;
                ImmExtD = 0;
                Rs1D = 0;
                Rs2D = 0;
                EcallD = 0;
                ALUControlD = 0;
                $display("Invalid op: '%b'", instrD[6:0]);
            end
        endcase
    end
end

//****** WB ******
logic [63:0] a0;
logic [63:0] a1;
logic [63:0] a2;
logic [63:0] a3;
logic [63:0] a4;
logic [63:0] a5;
logic [63:0] a6;
logic [63:0] a7;
always_ff @ (posedge clk) begin
    if(enableW) begin
        //--- WB ---
        if(RegWriteW & RdW!=0) begin // $0 is hardwired to the value zero
            registers[RdW] = ResultW;
        end
        //--- Ecall ---
        if(EcallW) begin
            a0 = registers[10];
            a1 = registers[11];
            a2 = registers[12];
            a3 = registers[13];
            a4 = registers[14];
            a5 = registers[15];
            a6 = registers[16];
            a7 = registers[17];
            do_ecall(a7, a0, a1, a2, a3, a4, a5, a6, a0);
            registers[10] = a0;
            // not done
        end
    end
end
endmodule