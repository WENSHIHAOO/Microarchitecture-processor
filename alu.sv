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
  output [63:0] WriteDataE,
  input  [63:0] ALUResultM,
  // use to print
  input  [4:0]  RdE,
  input  [4:0]  Rs2E
);
logic                ZeroE;
logic        [63:0]  SrcAE;
logic        [63:0]  SrcBE;
logic signed [63:0]  SrcAE_sign;
logic signed [63:0]  SrcBE_sign;
logic        [127:0] long_ALUResultE;
always_comb begin
  if(enableE) begin
    //Froward
    case(FrowardAE)
      2'b00: SrcAE = RD1E;
      2'b01: SrcAE = ResultW;
      2'b10: SrcAE = ALUResultM;
    endcase
    case(FrowardBE)
      2'b00: WriteDataE = RD2E;
      2'b01: WriteDataE = ResultW;
      2'b10: WriteDataE = ALUResultM;
    endcase
    //ALUSrc
    if(ALUSrcE) begin
      SrcBE = ImmExtE;
    end else begin
      SrcBE = WriteDataE;
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
    if(ALUControlE[4:0] == 19) begin
      SrcAE = PCE;
    end
    //jump & branch
    if(ALUControlE[4:0] > 20) begin
      if(ALUControlE[4:0] == 21) begin
        PCTargetE = SrcAE + ImmExtE;
      end else begin
        PCTargetE = PCE + ImmExtE;
      end
    end
    //--- ALU ---
    if(ALUControlE[5]) begin
      case(ALUControlE[4:0])
        1:  begin
          ALUResultE = SrcAE[31:0] << {1'b0, SrcBE[4:0]}; // sllw slliw
          $display("%0x: sllw slliw %0d: %0d, %0d", PCE, RdE, SrcAE[31:0], {1'b0, SrcBE[4:0]}); 
        end
        2:  begin
          ALUResultE = SrcAE[31:0] >> {1'b0, SrcBE[4:0]}; // srlw srliw
          $display("%0x: srlw srliw %0d: %0d, %0d", PCE, RdE, SrcAE[31:0], {1'b0, SrcBE[4:0]}); 
        end
        3:  begin
          ALUResultE = SrcAE_sign[31:0] >>> {1'b0, SrcBE_sign[4:0]}; // sraw sraiw
          $display("%0x: sraw sraiw %0d: %0d, %0d", PCE, RdE, SrcAE_sign[31:0], {1'b0, SrcBE_sign[4:0]}); 
        end
        4:  begin
          ALUResultE = SrcAE_sign[31:0] + SrcBE_sign[31:0]; // addw addiw
          $display("%0x: addw addiw %0d: %0d, %0d", PCE, RdE, SrcAE_sign[31:0], SrcBE_sign[31:0]);
        end
        5:  begin
          ALUResultE = SrcAE_sign[31:0] - SrcBE_sign[31:0]; // subw
          $display("%0x: subw %0d: %0d, %0d", PCE, RdE, SrcAE_sign[31:0], SrcBE_sign[31:0]); 
        end
        6:  begin
          ALUResultE = SrcAE_sign[31:0] / SrcBE_sign[31:0]; // divw
          $display("%0x: divw %0d: %0d, %0d", PCE, RdE, SrcAE_sign[31:0], SrcBE_sign[31:0]); 
        end
        7:  begin
          ALUResultE = SrcAE[31:0] / SrcBE[31:0]; // divuw
          $display("%0x: divuw %0d: %0d, %0d", PCE, RdE, SrcAE[31:0], SrcBE[31:0]);
        end
        8:  begin
          ALUResultE = SrcAE_sign[31:0] % SrcBE_sign[31:0]; // remw
          $display("%0x: remw %0d: %0d, %0d", PCE, RdE, SrcAE_sign[31:0], SrcBE_sign[31:0]);
        end
        9:  begin
          ALUResultE = SrcAE[31:0] % SrcBE[31:0]; // remuw
          $display("%0x: remuw %0d: %0d, %0d", PCE, RdE, SrcAE[31:0], SrcBE[31:0]);
        end
        10: begin
          ALUResultE = SrcAE_sign[31:0] * SrcBE_sign[31:0]; // mulw
          $display("%0x: mulw %0d: %0d, %0d", PCE, RdE, SrcAE_sign[31:0], SrcBE_sign[31:0]);
        end
        default: begin
          ALUResultE = 0;
          $display("Invalid 1 ALUControlE[4:0]: '%b'", ALUControlE[4:0]);
        end
      endcase
      ALUResultE = {{32{ALUResultE[31]}}, ALUResultE[31:0]};
    end else begin
      case(ALUControlE[4:0])
        1: begin
          ALUResultE = SrcAE << SrcBE[5:0]; // sll slli
          $display("%0x: sll slli %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE[5:0]); 
        end
        2: begin
          ALUResultE = SrcAE >> SrcBE[5:0]; // srl srli
          $display("%0x: srl srli %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE[5:0]); 
        end
        3: begin
          ALUResultE = SrcAE_sign >>> SrcBE_sign[5:0]; // sra srai
          $display("%0x: sra srai %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE_sign[5:0]);
        end
        4: begin
          ALUResultE = SrcAE_sign + SrcBE_sign; // add addi load save
          $display("%0x: add addi load save %0d(s%0d): %0d, %0d", PCE, RdE, Rs2E, SrcAE_sign, SrcBE_sign); 
        end
        5: begin
          ALUResultE = SrcAE_sign - SrcBE_sign; // sub
          $display("%0x: sub %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE_sign); 
        end
        6: begin
          ALUResultE = SrcAE_sign / SrcBE_sign; // div
          $display("%0x: div %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE_sign); 
        end
        7: begin
          ALUResultE = SrcAE / SrcBE; // divu
          $display("%0x: divu %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE); 
        end
        8: begin
          ALUResultE = SrcAE_sign % SrcBE_sign; // rem
          $display("%0x: rem %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE_sign);
        end
        9: begin
          ALUResultE = SrcAE % SrcBE; // remu
          $display("%0x: remu %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE); 
        end
        10: begin
          ALUResultE = SrcAE_sign * SrcBE_sign; // mul
          $display("%0x: mul %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE_sign); 
        end
        11: begin // mulh
          long_ALUResultE = SrcAE_sign * SrcBE_sign;
          ALUResultE = long_ALUResultE[127:64];
          $display("%0x: mulh %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE_sign); 
        end
        12: begin // mulhu
          long_ALUResultE = SrcAE * SrcBE;
          ALUResultE = long_ALUResultE[127:64];
          $display("%0x: mulhu %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE); 
        end
        13: begin // mulhsu
          long_ALUResultE = SrcAE_sign * SrcBE;
          ALUResultE = long_ALUResultE[127:64];
          $display("%0x: mulhsu %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE); 
        end
        14: begin
          ALUResultE = SrcAE ^ SrcBE; // xor xori
          $display("%0x: xor xori %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE);
        end
        15: begin
          ALUResultE = SrcAE | SrcBE; // or ori
          $display("%0x: or ori %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE); 
        end
        16: begin
          ALUResultE = SrcAE & SrcBE; // and andi
          $display("%0x: and andi %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE);
        end
        17: begin
          ALUResultE = (SrcAE_sign < SrcBE_sign) ? 1 : 0; // slt slti
          $display("%0x: slt slti %0d: %0d, %0d", PCE, RdE, SrcAE_sign, SrcBE_sign);
        end
        18: begin
          ALUResultE = (SrcAE < SrcBE) ? 1 : 0; // sltu sltiu
          $display("%0x: sltu sltiu %0d: %0d, %0d", PCE, RdE, SrcAE, SrcBE); 
        end
        19:  begin
          ALUResultE = SrcAE + SrcBE; // auipc
          $display("%0x: auipc %0d: 0x%0x", PCE, RdE, SrcBE);
        end
        20:  begin
          ALUResultE = SrcBE; // lui
          $display("%0x: lui %0d: 0x%0x", PCE, RdE, SrcBE);
        end
        21:  begin
          // jalr
          $display("%0x: jalr %0d: 0x%0x", PCE, RdE, PCTargetE);
        end
        22:  begin
          // jal
          $display("%0x: jal %0d: 0x%0x", PCE, RdE, PCTargetE);
        end
        23: begin
          ZeroE = (SrcAE == SrcBE) ? 1 : 0; // beq
          $display("%0x: beq %0d, %0d, 0x%0x", PCE, SrcAE, SrcBE, PCTargetE);
        end
        24: begin
          ZeroE = (SrcAE != SrcBE) ? 1 : 0; // bne
          $display("%0x: bne %0d, %0d, 0x%0x", PCE, SrcAE, SrcBE, PCTargetE);
        end
        25: begin
          ZeroE = (SrcAE_sign < SrcBE_sign) ? 1 : 0; // blt
          $display("%0x: blt %0d, %0d, 0x%0x", PCE, SrcAE_sign, SrcBE_sign, PCTargetE);
        end
        26: begin
          ZeroE = (SrcAE_sign >= SrcBE_sign) ? 1 : 0; // bge
          $display("%0x: bge %0d, %0d, 0x%0x", PCE, SrcAE_sign, SrcBE_sign, PCTargetE);
        end
        27: begin
          ZeroE = (SrcAE < SrcBE) ? 1 : 0; // bltu
          $display("%0x: bltu %0d, %0d, 0x%0x", PCE, SrcAE, SrcBE, PCTargetE);
        end
        28: begin
          ZeroE = (SrcAE >= SrcBE) ? 1 : 0; // bgeu
          $display("%0x: bgeu %0d, %0d, 0x%0x", PCE, SrcAE, SrcBE, PCTargetE);
        end
        default: begin
          ALUResultE = 0;
          $display("Invalid 0 ALUControlE[4:0]: '%b'", ALUControlE[4:0]);
        end
      endcase
    end
    PCSrcE = JumpE | (BranchE & ZeroE);
  end
end
endmodule