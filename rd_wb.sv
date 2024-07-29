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
    output        MemWriteD,
    output        JumpD,
    output        BranchD,
    output [5:0]  ALUControlD,
    output        ALUSrcD,
    output [63:0] ImmExtD,
    output [4:0]  Rs1D,
    output [4:0]  Rs2D,
    //****** WB ******
    output enableW,
    input  [4:0]  RdW,
    input         RegWriteW,
    input  [63:0] ResultW
);
reg [63:0] registers [32];
always_comb begin
//****** RD ******
    if(enableD) begin
        //--- register_file ---
        RD1D = registers[instrD[19:15]];
        RD2D = registers[instrD[24:20]];
        //--- control_unit ---
        case(instrD[6:0])
            //3, Type I
            7'b0000011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b01;
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                ALUControlD = 4; // load
            end
            //19, Type I
            7'b0010011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                case(instrD[14:12])
                    3'b000: ALUControlD = 4; // addi
                    3'b001: ALUControlD = 1; // slli
                    3'b010: ALUControlD = 17; // slti
                    3'b011: ALUControlD = 18; // sltiu
                    3'b100: ALUControlD = 14; // xori
                    3'b101: begin
                    case(instrD[31:25])
                        7'b0000000: ALUControlD = 2; // srli
                        7'b0100000: ALUControlD = 3; //srai
                    endcase
                    end
                    3'b110: ALUControlD = 15; //ori
                    3'b111: ALUControlD = 16; //andi
                endcase
            end
            //23,55, Type U ///////////// not sure
            7'b0010111, 7'b0110111: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{32{instrD[31]}}, instrD[31:12], 12'b0}; // imm_U
                Rs1D = 0;
                Rs2D = 0;
                ALUControlD = 25; // auipc lui
            end
            //27, Type I
            7'b0011011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                case(instrD[14:12])
                    3'b000: ALUControlD = 36; // addiw
                    3'b001: ALUControlD = 33; //slliw 
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
                MemWriteD = 1;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:25], instrD[11:7]}; // imm_S
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
                ALUControlD = 4; // save
            end
            //51, Type R
            7'b0110011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 0;
                //ImmExtD = ?;
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
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
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 0;
                //ImmExtD = ?;
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
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
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 1;
                ALUSrcD = 0;
                ImmExtD = {{52{instrD[31]}}, instrD[7], instrD[30:25], instrD[11:8], 1'b0}; // imm_B
                Rs1D = instrD[19:15];
                Rs2D = instrD[24:20];
                case(instrD[14:12])
                    3'b000: ALUControlD = 19; // beq
                    3'b001: ALUControlD = 20; // bne
                    3'b100: ALUControlD = 21; // blt
                    3'b101: ALUControlD = 22; // bge
                    3'b110: ALUControlD = 23; // bltu
                    3'b111: ALUControlD = 24; // bgeu 
                endcase
            end
            //103, Type I
            7'b1100111: begin
                RegWriteD = 1;
                ResultSrcD = 2'b10;
                MemWriteD = 0;
                JumpD = 1;
                BranchD = 0;
                ALUSrcD = 1;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                Rs1D = instrD[19:15];
                Rs2D = 0;
                ALUControlD = 26; // jalr
            end
            //111, Type J
            7'b1101111: begin
                RegWriteD = 1;
                ResultSrcD = 2'b10;
                MemWriteD = 0;
                JumpD = 1;
                BranchD = 0;
                //ALUSrcD = ?;
                ImmExtD = {{44{instrD[31]}}, instrD[19:12], instrD[20], instrD[30:21], 1'b0}; // imm_J
                Rs1D = 0;
                Rs2D = 0;
                ALUControlD = 26; // jal
            end
            //115, Type I
            7'b1110011: begin
                RegWriteD = 1;
                ResultSrcD = 2'b00;
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 1;
                Rs1D = instrD[19:15];
                Rs2D = 0;
                ImmExtD = {{52{instrD[31]}}, instrD[31:20]}; // imm_I
                //ALUControlD = ?;
            end
            default: begin
                RegWriteD = 0;
                ResultSrcD = 0;
                MemWriteD = 0;
                JumpD = 0;
                BranchD = 0;
                ALUSrcD = 0;
                ImmExtD = 0;
                Rs1D = 0;
                Rs2D = 0;
                ALUControlD = 0;
            end
        endcase
    end
end

//****** WB ******
always_ff @ (posedge clk) begin
    if(enableW) begin
        if(RegWriteW & RdW!=0) begin // $0 is hardwired to the value zero
            registers[RdW] = ResultW;
        end
    end
end
endmodule