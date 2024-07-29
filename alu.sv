module alu
(
  //****** ALU ******
  //--- hazard ---
  input  [1:0]  FrowardAE,
  input  [1:0]  FrowardBE,
  input  [63:0] ResultW,
  //--- ALU ---
  input  enableE,
  input  [63:0] RD1E,
  input  [63:0] RD2E,
  input  [63:0] PCE,
  input  [5:0]  ALUControlE,
  input         ALUSrcE,
  input  [63:0] ImmExtE,
  input         JumpE,
  input         BranchE,
  output        PCSrcE,
  output [63:0] PCTargetE,
  output [63:0] ALUResultE,
  input  [63:0] ALUResultM
);
logic                ZeroE;
logic        [63:0]  SrcAE;
logic        [63:0]  SrcBE;
logic signed [63:0]  SrcAE_sign;
logic signed [63:0]  SrcBE_sign;
logic        [127:0] long_ALUResultE;
always_comb begin
  if(enableE) begin
    ZeroE = 0;
    case(FrowardAE)
      2'b00: SrcAE = RD1E;
      2'b01: SrcAE = ResultW;
      2'b10: SrcAE = ALUResultM;
    endcase

    if(ALUSrcE) begin
      SrcBE = ImmExtE;
    end else begin
        case(FrowardBE)
        2'b00: SrcBE = RD2E;
        2'b01: SrcBE = ResultW;
        2'b10: SrcBE = ALUResultM;
      endcase
    end
    SrcAE_sign = SrcAE;
    SrcBE_sign = SrcBE;
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
    19: 010011  |   beq
    20: 010100  |   bne
    21: 010101  |   blt
    22: 010110  |   bge
    23: 010111  |   bltu
    24: 011000  |   bgeu
    25: 011001  |   auipc lui
    26: 011010  |   jal jalr
    */
    if(ALUControlE[5]) begin
      case(ALUControlE[4:0])
        1:  ALUResultE = SrcAE[31:0] << {1'b0, SrcBE[4:0]}; // sllw slliw
        2:  ALUResultE = SrcAE[31:0] >> {1'b0, SrcBE[4:0]}; // srlw srliw
        3:  ALUResultE = SrcAE_sign[31:0] >>> {1'b0, SrcBE_sign[4:0]}; // sraw sraiw
        4:  ALUResultE = SrcAE_sign[31:0] + SrcBE_sign[31:0]; // addw addiw
        5:  ALUResultE = SrcAE_sign[31:0] - SrcBE_sign[31:0]; // subw
        6:  ALUResultE = SrcAE_sign[31:0] / SrcBE_sign[31:0]; // divw
        7:  ALUResultE = SrcAE[31:0] / SrcBE[31:0]; // divuw
        8:  ALUResultE = SrcAE_sign[31:0] % SrcBE_sign[31:0]; // remw
        9:  ALUResultE = SrcAE[31:0] % SrcBE[31:0]; // remuw
        10: ALUResultE = SrcAE_sign[31:0] * SrcBE_sign[31:0]; // mulw
        default: ALUResultE = 0;
      endcase
      ALUResultE = {{32{ALUResultE[31]}}, ALUResultE[31:0]};
    end else begin
      case(ALUControlE[4:0])
        1: ALUResultE = SrcAE << SrcBE[5:0]; // sll slli
        2: ALUResultE = SrcAE >> SrcBE[5:0]; // srl srli
        3: ALUResultE = SrcAE_sign >>> SrcBE_sign[5:0]; // sra srai
        4: ALUResultE = SrcAE_sign + SrcBE_sign; // add addi load save
        5: ALUResultE = SrcAE_sign - SrcBE_sign; // sub
        6: ALUResultE = SrcAE_sign / SrcBE_sign; // div
        7: ALUResultE = SrcAE / SrcBE; // divu
        8: ALUResultE = SrcAE_sign % SrcBE_sign; // rem
        9: ALUResultE = SrcAE % SrcBE; // remu
        10: ALUResultE = SrcAE_sign * SrcBE_sign; // mul
        11: begin // mulh
          long_ALUResultE = SrcAE_sign * SrcBE_sign;
          ALUResultE = long_ALUResultE[127:64];
        end
        12: begin // mulhu
          long_ALUResultE = SrcAE * SrcBE;
          ALUResultE = long_ALUResultE[127:64];
        end
        13: begin // mulhsu
          long_ALUResultE = SrcAE_sign * SrcBE;
          ALUResultE = long_ALUResultE[127:64];
        end
        14: ALUResultE = SrcAE ^ SrcBE; // xor xori
        15: ALUResultE = SrcAE | SrcBE; // or ori
        16: ALUResultE = SrcAE & SrcBE; // and andi
        17: ALUResultE = (SrcAE_sign < SrcBE_sign) ? 1 : 0; // slt slti
        18: ALUResultE = (SrcAE < SrcBE) ? 1 : 0; // sltu sltiu
        19: ZeroE = (SrcAE == SrcBE) ? 1 : 0; // beq
        20: ZeroE = (SrcAE != SrcBE) ? 1 : 0; // bne
        21: ZeroE = (SrcAE_sign < SrcBE_sign) ? 1 : 0; // blt
        22: ZeroE = (SrcAE_sign >= SrcBE_sign) ? 1 : 0; // bge
        23: ZeroE = (SrcAE < SrcBE) ? 1 : 0; // bltu
        24: ZeroE = (SrcAE >= SrcBE) ? 1 : 0; // bgeu
        //25:  auipc lui
        //26:  jal jalr
        default: ALUResultE = 0;
      endcase
    end
    PCTargetE = 0;
    PCSrcE = JumpE | (BranchE & ZeroE);
  end
end
endmodule