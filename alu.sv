module alu
(
  //****** ALU ******
  input  enableE,
  output        PCSrcE,
  output [63:0] PCTargetE,
  input         JumpE,
  input         BranchE,
  // Superscalar 1
  //--- hazard ---
  input  [2:0]  FrowardAE1,
  input  [2:0]  FrowardBE1,
  input  [63:0] ResultW1,
  //--- ALU ---
  input  [63:0] RD1E1,
  input  [63:0] RD2E1,
  input  [63:0] PCE1,
  input  [5:0]  ALUControlE1,
  input         ALUSrcE1,
  input  [63:0] ImmExtE1,
  output [63:0] ALUResultE1,
  output [63:0] WriteDataE1,
  input  [63:0] ALUResultM1,
  // use to print
  input  [4:0]  RdE1,
  input  [4:0]  Rs2E1,
  input  [31:0] instrE1
);
logic                ZeroE;
// Superscalar 1
logic        [63:0]  SrcAE1;
logic        [63:0]  SrcBE1;
logic signed [63:0]  SrcAE_sign1;
logic signed [63:0]  SrcBE_sign1;
logic        [127:0] long_ALUResultE1;
always_comb begin
  if(enableE) begin
    //Froward
    case(FrowardAE1)
      3'b000: SrcAE1 = RD1E1;
      3'b001: SrcAE1 = ResultW1;
      3'b010: SrcAE1 = ALUResultM1;
    endcase
    case(FrowardBE1)
      3'b000: WriteDataE1 = RD2E1;
      3'b001: WriteDataE1 = ResultW1;
      3'b010: WriteDataE1 = ALUResultM1;
    endcase
    //ALUSrc
    if(ALUSrcE1) begin
      SrcBE1 = ImmExtE1;
    end else begin
      SrcBE1 = WriteDataE1;
    end
    SrcAE_sign1 = SrcAE1;
    SrcBE_sign1 = SrcBE1;
    /*
    1 : 000001  |   sll		          	33: 100001  |   sllw
    2 : 000010  |   srl		          	34: 100010  |   srlw
    3 : 000011  |   sra		          	35: 100011  |   sraw
    4 : 000100  |   add load save     36: 100100  |   addw
    5 : 000101  |   sub		            37: 100101  |   subw
    6 : 000110  |   div		          	38: 100110  |   divw
    7 : 000111  |   divu	           	39: 100111  |   divuw
    8 : 001000  |   rem		            40: 101000  |   remw
    9 : 001001  |   remu	           	41: 101001  |   remuw
    10: 001010  |   mul		            42: 101010  |   mulw
    11: 001011  |   mulh
    12: 001100  |   mulhu
    13: 001101  |   mulhsu
    14: 001110  |   xor
    15: 001111  |   or
    16: 010000  |   and
    17: 010001  |   slt
    18: 010010  |   sltu
    19: 010011  |   auipc
    20: 010100  |   lui
    21: 010101  |   jalr
    22: 010110  |   jal
    23: 010111  |   beq
    24: 011000  |   bne
    25: 011001  |   blt
    26: 011010  |   bge
    27: 011011  |   bltu
    28: 011100  |   bgeu
    */
    //auipc
    if(ALUControlE1[4:0] == 19) begin
      SrcAE1 = PCE1;
    end
    //jump & branch
    if(ALUControlE1[4:0] > 20) begin
      if(ALUControlE1[4:0] == 21) begin
        PCTargetE = SrcAE1 + ImmExtE1;
      end else begin
        PCTargetE = PCE1 + ImmExtE1;
      end
    end
    //--- ALU ---
    if(ALUControlE1[5]) begin
      case(ALUControlE1[4:0])
        1:  ALUResultE1 = SrcAE1[31:0] << {1'b0, SrcBE1[4:0]}; // sllw slliw
        2:  ALUResultE1 = SrcAE1[31:0] >> {1'b0, SrcBE1[4:0]}; // srlw srliw
        3:  ALUResultE1 = SrcAE_sign1[31:0] >>> {1'b0, SrcBE_sign1[4:0]}; // sraw sraiw
        4:  ALUResultE1 = SrcAE_sign1[31:0] + SrcBE_sign1[31:0]; // addw addiw
        5:  ALUResultE1 = SrcAE_sign1[31:0] - SrcBE_sign1[31:0]; // subw
        6:  ALUResultE1 = SrcAE_sign1[31:0] / SrcBE_sign1[31:0]; // divw
        7:  ALUResultE1 = SrcAE1[31:0] / SrcBE1[31:0]; // divuw
        8:  ALUResultE1 = SrcAE_sign1[31:0] % SrcBE_sign1[31:0]; // remw
        9:  ALUResultE1 = SrcAE1[31:0] % SrcBE1[31:0]; // remuw
        10: ALUResultE1 = SrcAE_sign1[31:0] * SrcBE_sign1[31:0]; // mulw
        default: ALUResultE1 = 0;
      endcase
      ALUResultE1 = {{32{ALUResultE1[31]}}, ALUResultE1[31:0]};
    end else begin
      case(ALUControlE1[4:0])
        1: ALUResultE1 = SrcAE1 << SrcBE1[5:0]; // sll slli
        2: ALUResultE1 = SrcAE1 >> SrcBE1[5:0]; // srl srli
        3: ALUResultE1 = SrcAE_sign1 >>> SrcBE_sign1[5:0]; // sra srai
        4: ALUResultE1 = SrcAE_sign1 + SrcBE_sign1; // add addi load save
        5: ALUResultE1 = SrcAE_sign1 - SrcBE_sign1; // sub
        6: ALUResultE1 = SrcAE_sign1 / SrcBE_sign1; // div
        7: ALUResultE1 = SrcAE1 / SrcBE1; // divu
        8: ALUResultE1 = SrcAE_sign1 % SrcBE_sign1; // rem
        9: ALUResultE1 = SrcAE1 % SrcBE1; // remu
        10: ALUResultE1 = SrcAE_sign1 * SrcBE_sign1; // mul
        11: begin // mulh
          long_ALUResultE1 = SrcAE_sign1 * SrcBE_sign1;
          ALUResultE1 = long_ALUResultE1[127:64];
        end
        12: begin // mulhu
          long_ALUResultE1 = SrcAE1 * SrcBE1;
          ALUResultE1 = long_ALUResultE1[127:64];
        end
        13: begin // mulhsu
          long_ALUResultE1 = SrcAE_sign1 * SrcBE1;
          ALUResultE1 = long_ALUResultE1[127:64];
        end
        14: ALUResultE1 = SrcAE1 ^ SrcBE1; // xor xori
        15: ALUResultE1 = SrcAE1 | SrcBE1; // or ori
        16: ALUResultE1 = SrcAE1 & SrcBE1; // and andi
        17: ALUResultE1 = (SrcAE_sign1 < SrcBE_sign1) ? 1 : 0; // slt slti
        18: ALUResultE1 = (SrcAE1 < SrcBE1) ? 1 : 0; // sltu sltiu
        19:  ALUResultE1 = SrcAE1 + SrcBE1; // auipc
        20:  ALUResultE1 = SrcBE1; // lui
        //21:  // jalr
        //22:  // jal
        23: ZeroE = (SrcAE1 == SrcBE1) ? 1 : 0; // beq
        24: ZeroE = (SrcAE1 != SrcBE1) ? 1 : 0; // bne
        25: ZeroE = (SrcAE_sign1 < SrcBE_sign1) ? 1 : 0; // blt
        26: ZeroE = (SrcAE_sign1 >= SrcBE_sign1) ? 1 : 0; // bge
        27: ZeroE = (SrcAE1 < SrcBE1) ? 1 : 0; // bltu
        28: ZeroE = (SrcAE1 >= SrcBE1) ? 1 : 0; // bgeu
        default: ALUResultE1 = 0;
      endcase
    end
    PCSrcE = JumpE | (BranchE & ZeroE);
  end
end
endmodule