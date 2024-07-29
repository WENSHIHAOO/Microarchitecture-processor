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
  // Superscalar 2
  //--- hazard ---
  input  [2:0]  FrowardAE2,
  input  [2:0]  FrowardBE2,
  input  [63:0] ResultW2,
  //--- ALU ---
  input  [63:0] RD1E2,
  input  [63:0] RD2E2,
  input  [63:0] PCE2,
  input  [5:0]  ALUControlE2,
  input         ALUSrcE2,
  input  [63:0] ImmExtE2,
  output [63:0] ALUResultE2,
  output [63:0] WriteDataE2,
  input  [63:0] ALUResultM2,
  // use to print
  input  [4:0]  RdE2,
  input  [4:0]  Rs2E2
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
      3'b101: SrcAE1 = ResultW2;
      3'b010: SrcAE1 = ALUResultM1;
      3'b110: SrcAE1 = ALUResultM2;
    endcase
    case(FrowardBE1)
      3'b000: WriteDataE1 = RD2E1;
      3'b001: WriteDataE1 = ResultW1;
      3'b101: WriteDataE1 = ResultW2;
      3'b010: WriteDataE1 = ALUResultM1;
      3'b110: WriteDataE1 = ALUResultM2;
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
        1:  begin
          ALUResultE1 = SrcAE1[31:0] << {1'b0, SrcBE1[4:0]}; // sllw slliw
          $display("%0x: sllw slliw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], {1'b0, SrcBE1[4:0]}, ALUResultE1); 
        end
        2:  begin
          ALUResultE1 = SrcAE1[31:0] >> {1'b0, SrcBE1[4:0]}; // srlw srliw
          $display("%0x: srlw srliw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], {1'b0, SrcBE1[4:0]}, ALUResultE1); 
        end
        3:  begin
          ALUResultE1 = SrcAE_sign1[31:0] >>> {1'b0, SrcBE_sign1[4:0]}; // sraw sraiw
          $display("%0x: sraw sraiw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], {1'b0, SrcBE_sign1[4:0]}, ALUResultE1); 
        end
        4:  begin
          ALUResultE1 = SrcAE_sign1[31:0] + SrcBE_sign1[31:0]; // addw addiw
          $display("%0x: addw addiw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1);
        end
        5:  begin
          ALUResultE1 = SrcAE_sign1[31:0] - SrcBE_sign1[31:0]; // subw
          $display("%0x: subw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1); 
        end
        6:  begin
          ALUResultE1 = SrcAE_sign1[31:0] / SrcBE_sign1[31:0]; // divw
          $display("%0x: divw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1); 
        end
        7:  begin
          ALUResultE1 = SrcAE1[31:0] / SrcBE1[31:0]; // divuw
          $display("%0x: divuw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], SrcBE1[31:0], ALUResultE1);
        end
        8:  begin
          ALUResultE1 = SrcAE_sign1[31:0] % SrcBE_sign1[31:0]; // remw
          $display("%0x: remw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1);
        end
        9:  begin
          ALUResultE1 = SrcAE1[31:0] % SrcBE1[31:0]; // remuw
          $display("%0x: remuw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], SrcBE1[31:0], ALUResultE1);
        end
        10: begin
          ALUResultE1 = SrcAE_sign1[31:0] * SrcBE_sign1[31:0]; // mulw
          $display("%0x: mulw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1);
        end
        default: begin
          ALUResultE1 = 0;
          $display("alu invalid 11 ALUControlE[4:0]: '%b'", ALUControlE1[4:0]);
        end
      endcase
      ALUResultE1 = {{32{ALUResultE1[31]}}, ALUResultE1[31:0]};
    end else begin
      case(ALUControlE1[4:0])
        1: begin
          ALUResultE1 = SrcAE1 << SrcBE1[5:0]; // sll slli
          $display("%0x: sll slli %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1[5:0], ALUResultE1); 
        end
        2: begin
          ALUResultE1 = SrcAE1 >> SrcBE1[5:0]; // srl srli
          $display("%0x: srl srli %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1[5:0], ALUResultE1); 
        end
        3: begin
          ALUResultE1 = SrcAE_sign1 >>> SrcBE_sign1[5:0]; // sra srai
          $display("%0x: sra srai %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1[5:0], ALUResultE1);
        end
        4: begin
          ALUResultE1 = SrcAE_sign1 + SrcBE_sign1; // add addi load save
          $display("%0x: add addi load save %0d(s%0d): %0d, %0d = %0x", PCE1, RdE1, Rs2E1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        5: begin
          ALUResultE1 = SrcAE_sign1 - SrcBE_sign1; // sub
          $display("%0x: sub %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        6: begin
          ALUResultE1 = SrcAE_sign1 / SrcBE_sign1; // div
          $display("%0x: div %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        7: begin
          ALUResultE1 = SrcAE1 / SrcBE1; // divu
          $display("%0x: divu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        8: begin
          ALUResultE1 = SrcAE_sign1 % SrcBE_sign1; // rem
          $display("%0x: rem %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1);
        end
        9: begin
          ALUResultE1 = SrcAE1 % SrcBE1; // remu
          $display("%0x: remu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        10: begin
          ALUResultE1 = SrcAE_sign1 * SrcBE_sign1; // mul
          $display("%0x: mul %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        11: begin // mulh
          long_ALUResultE1 = SrcAE_sign1 * SrcBE_sign1;
          ALUResultE1 = long_ALUResultE1[127:64];
          $display("%0x: mulh %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        12: begin // mulhu
          long_ALUResultE1 = SrcAE1 * SrcBE1;
          ALUResultE1 = long_ALUResultE1[127:64];
          $display("%0x: mulhu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        13: begin // mulhsu
          long_ALUResultE1 = SrcAE_sign1 * SrcBE1;
          ALUResultE1 = long_ALUResultE1[127:64];
          $display("%0x: mulhsu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE1, ALUResultE1); 
        end
        14: begin
          ALUResultE1 = SrcAE1 ^ SrcBE1; // xor xori
          $display("%0x: xor xori %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1);
        end
        15: begin
          ALUResultE1 = SrcAE1 | SrcBE1; // or ori
          $display("%0x: or ori %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        16: begin
          ALUResultE1 = SrcAE1 & SrcBE1; // and andi
          $display("%0x: and andi %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1);
        end
        17: begin
          ALUResultE1 = (SrcAE_sign1 < SrcBE_sign1) ? 1 : 0; // slt slti
          $display("%0x: slt slti %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1);
        end
        18: begin
          ALUResultE1 = (SrcAE1 < SrcBE1) ? 1 : 0; // sltu sltiu
          $display("%0x: sltu sltiu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        19:  begin
          ALUResultE1 = SrcAE1 + SrcBE1; // auipc
          $display("%0x: auipc %0d: 0x%0x = %0x", PCE1, RdE1, SrcBE1, ALUResultE1);
        end
        20:  begin
          ALUResultE1 = SrcBE1; // lui
          $display("%0x: lui %0d: 0x%0x = %0x", PCE1, RdE1, SrcBE1, ALUResultE1);
        end
        21:  begin
          // jalr
          $display("%0x: jalr %0d: 0x%0x", PCE1, RdE1, PCTargetE);
        end
        22:  begin
          // jal
          $display("%0x: jal %0d: 0x%0x", PCE1, RdE1, PCTargetE);
        end
        23: begin
          ZeroE = (SrcAE1 == SrcBE1) ? 1 : 0; // beq
          $display("%0x: beq %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE);
        end
        24: begin
          ZeroE = (SrcAE1 != SrcBE1) ? 1 : 0; // bne
          $display("%0x: bne %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE);
        end
        25: begin
          ZeroE = (SrcAE_sign1 < SrcBE_sign1) ? 1 : 0; // blt
          $display("%0x: blt %0d, %0d, 0x%0x = %0x", PCE1, SrcAE_sign1, SrcBE_sign1, PCTargetE, ZeroE);
        end
        26: begin
          ZeroE = (SrcAE_sign1 >= SrcBE_sign1) ? 1 : 0; // bge
          $display("%0x: bge %0d, %0d, 0x%0x = %0x", PCE1, SrcAE_sign1, SrcBE_sign1, PCTargetE, ZeroE);
        end
        27: begin
          ZeroE = (SrcAE1 < SrcBE1) ? 1 : 0; // bltu
          $display("%0x: bltu %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE);
        end
        28: begin
          ZeroE = (SrcAE1 >= SrcBE1) ? 1 : 0; // bgeu
          $display("%0x: bgeu %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE);
        end
        default: begin
          ALUResultE1 = 0;
          $display("alu invalid 10 ALUControlE[4:0]: '%b'", ALUControlE1[4:0]);
        end
      endcase
    end
    PCSrcE = JumpE | (BranchE & ZeroE);
  end
end

// Superscalar 2
logic        [63:0]  SrcAE2;
logic        [63:0]  SrcBE2;
logic signed [63:0]  SrcAE_sign2;
logic signed [63:0]  SrcBE_sign2;
logic        [127:0] long_ALUResultE2;
always_comb begin
  if(enableE) begin
    //Froward
    case(FrowardAE2)
      3'b000: SrcAE2 = RD1E2;
      3'b001: SrcAE2 = ResultW1;
      3'b101: SrcAE2 = ResultW2;
      3'b010: SrcAE2 = ALUResultM1;
      3'b110: SrcAE2 = ALUResultM2;
    endcase
    case(FrowardBE2)
      3'b000: WriteDataE2 = RD2E2;
      3'b001: WriteDataE2 = ResultW1;
      3'b101: WriteDataE2 = ResultW2;
      3'b010: WriteDataE2 = ALUResultM1;
      3'b110: WriteDataE2 = ALUResultM2;
    endcase
    //ALUSrc
    if(ALUSrcE2) begin
      SrcBE2 = ImmExtE2;
    end else begin
      SrcBE2 = WriteDataE2;
    end
    SrcAE_sign2 = SrcAE2;
    SrcBE_sign2 = SrcBE2;
    //auipc
    if(ALUControlE2[4:0] == 19) begin
      SrcAE2 = PCE2;
    end
    //jump & branch
    if(ALUControlE2[4:0] > 20) begin
      if(ALUControlE2[4:0] == 21) begin
        PCTargetE = SrcAE2 + ImmExtE2;
      end else begin
        PCTargetE = PCE2 + ImmExtE2;
      end
    end
    //--- ALU ---
    if(ALUControlE2[5]) begin
      case(ALUControlE2[4:0])
        1:  begin
          ALUResultE2 = SrcAE2[31:0] << {1'b0, SrcBE2[4:0]}; // sllw slliw
          $display("%0x: sllw slliw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], {1'b0, SrcBE2[4:0]}, ALUResultE2); 
        end
        2:  begin
          ALUResultE2 = SrcAE2[31:0] >> {1'b0, SrcBE2[4:0]}; // srlw srliw
          $display("%0x: srlw srliw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], {1'b0, SrcBE2[4:0]}, ALUResultE2); 
        end
        3:  begin
          ALUResultE2 = SrcAE_sign2[31:0] >>> {1'b0, SrcBE_sign2[4:0]}; // sraw sraiw
          $display("%0x: sraw sraiw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], {1'b0, SrcBE_sign2[4:0]}, ALUResultE2); 
        end
        4:  begin
          ALUResultE2 = SrcAE_sign2[31:0] + SrcBE_sign2[31:0]; // addw addiw
          $display("%0x: addw addiw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2);
        end
        5:  begin
          ALUResultE2 = SrcAE_sign2[31:0] - SrcBE_sign2[31:0]; // subw
          $display("%0x: subw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2); 
        end
        6:  begin
          ALUResultE2 = SrcAE_sign2[31:0] / SrcBE_sign2[31:0]; // divw
          $display("%0x: divw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2); 
        end
        7:  begin
          ALUResultE2 = SrcAE2[31:0] / SrcBE2[31:0]; // divuw
          $display("%0x: divuw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], SrcBE2[31:0], ALUResultE2);
        end
        8:  begin
          ALUResultE2 = SrcAE_sign2[31:0] % SrcBE_sign2[31:0]; // remw
          $display("%0x: remw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2);
        end
        9:  begin
          ALUResultE2 = SrcAE2[31:0] % SrcBE2[31:0]; // remuw
          $display("%0x: remuw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], SrcBE2[31:0], ALUResultE2);
        end
        10: begin
          ALUResultE2 = SrcAE_sign2[31:0] * SrcBE_sign2[31:0]; // mulw
          $display("%0x: mulw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2);
        end
        default: begin
          ALUResultE2 = 0;
          $display("alu invalid 21 ALUControlE[4:0]: '%b'", ALUControlE2[4:0]);
        end
      endcase
      ALUResultE2 = {{32{ALUResultE2[31]}}, ALUResultE2[31:0]};
    end else begin
      case(ALUControlE2[4:0])
        1: begin
          ALUResultE2 = SrcAE2 << SrcBE2[5:0]; // sll slli
          $display("%0x: sll slli %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2[5:0], ALUResultE2); 
        end
        2: begin
          ALUResultE2 = SrcAE2 >> SrcBE2[5:0]; // srl srli
          $display("%0x: srl srli %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2[5:0], ALUResultE2); 
        end
        3: begin
          ALUResultE2 = SrcAE_sign2 >>> SrcBE_sign2[5:0]; // sra srai
          $display("%0x: sra srai %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2[5:0], ALUResultE2);
        end
        4: begin
          ALUResultE2 = SrcAE_sign2 + SrcBE_sign2; // add addi load save
          $display("%0x: add addi load save %0d(s%0d): %0d, %0d = %0x", PCE2, RdE2, Rs2E2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        5: begin
          ALUResultE2 = SrcAE_sign2 - SrcBE_sign2; // sub
          $display("%0x: sub %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        6: begin
          ALUResultE2 = SrcAE_sign2 / SrcBE_sign2; // div
          $display("%0x: div %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        7: begin
          ALUResultE2 = SrcAE2 / SrcBE2; // divu
          $display("%0x: divu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        8: begin
          ALUResultE2 = SrcAE_sign2 % SrcBE_sign2; // rem
          $display("%0x: rem %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2);
        end
        9: begin
          ALUResultE2 = SrcAE2 % SrcBE2; // remu
          $display("%0x: remu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        10: begin
          ALUResultE2 = SrcAE_sign2 * SrcBE_sign2; // mul
          $display("%0x: mul %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        11: begin // mulh
          long_ALUResultE2 = SrcAE_sign2 * SrcBE_sign2;
          ALUResultE2 = long_ALUResultE2[127:64];
          $display("%0x: mulh %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        12: begin // mulhu
          long_ALUResultE2 = SrcAE2 * SrcBE2;
          ALUResultE2 = long_ALUResultE2[127:64];
          $display("%0x: mulhu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        13: begin // mulhsu
          long_ALUResultE2 = SrcAE_sign2 * SrcBE2;
          ALUResultE2 = long_ALUResultE2[127:64];
          $display("%0x: mulhsu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE2, ALUResultE2); 
        end
        14: begin
          ALUResultE2 = SrcAE2 ^ SrcBE2; // xor xori
          $display("%0x: xor xori %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2);
        end
        15: begin
          ALUResultE2 = SrcAE2 | SrcBE2; // or ori
          $display("%0x: or ori %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        16: begin
          ALUResultE2 = SrcAE2 & SrcBE2; // and andi
          $display("%0x: and andi %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2);
        end
        17: begin
          ALUResultE2 = (SrcAE_sign2 < SrcBE_sign2) ? 1 : 0; // slt slti
          $display("%0x: slt slti %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2);
        end
        18: begin
          ALUResultE2 = (SrcAE2 < SrcBE2) ? 1 : 0; // sltu sltiu
          $display("%0x: sltu sltiu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        19:  begin
          ALUResultE2 = SrcAE2 + SrcBE2; // auipc
          $display("%0x: auipc %0d: 0x%0x = %0x", PCE2, RdE2, SrcBE2, ALUResultE2);
        end
        20:  begin
          ALUResultE2 = SrcBE2; // lui
          $display("%0x: lui %0d: 0x%0x = %0x", PCE2, RdE2, SrcBE2, ALUResultE2);
        end
        21:  begin
          // jalr
          $display("%0x: jalr %0d: 0x%0x", PCE2, RdE2, PCTargetE);
        end
        22:  begin
          // jal
          $display("%0x: jal %0d: 0x%0x", PCE2, RdE2, PCTargetE);
        end
        23: begin
          ZeroE = (SrcAE2 == SrcBE2) ? 1 : 0; // beq
          $display("%0x: beq %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE);
        end
        24: begin
          ZeroE = (SrcAE2 != SrcBE2) ? 1 : 0; // bne
          $display("%0x: bne %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE);
        end
        25: begin
          ZeroE = (SrcAE_sign2 < SrcBE_sign2) ? 1 : 0; // blt
          $display("%0x: blt %0d, %0d, 0x%0x = %0x", PCE2, SrcAE_sign2, SrcBE_sign2, PCTargetE, ZeroE);
        end
        26: begin
          ZeroE = (SrcAE_sign2 >= SrcBE_sign2) ? 1 : 0; // bge
          $display("%0x: bge %0d, %0d, 0x%0x = %0x", PCE2, SrcAE_sign2, SrcBE_sign2, PCTargetE, ZeroE);
        end
        27: begin
          ZeroE = (SrcAE2 < SrcBE2) ? 1 : 0; // bltu
          $display("%0x: bltu %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE);
        end
        28: begin
          ZeroE = (SrcAE2 >= SrcBE2) ? 1 : 0; // bgeu
          $display("%0x: bgeu %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE);
        end
        default: begin
          ALUResultE2 = 0;
          $display("alu invalid 20 ALUControlE[4:0]: '%b'", ALUControlE2[4:0]);
        end
      endcase
    end
    PCSrcE = JumpE | (BranchE & ZeroE);
  end
end
endmodule