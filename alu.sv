module alu
#(
    B_N = 0, // Number of ways of BTB
    b_h = 0  // Number of history bits
)
(
  //****** ALU ******
  input  clk,
  input  enableE,
  input  StallE,
  output [1:0]  mode,
  output        PCSrcE1,
  output        PCSrcE2,
  output [63:0] PCTargetE,
  input  [63:0] PCD1,
  input  [63:0] num_clk,
  // Superscalar 1
  //--- hazard ---
  input  [2:0]  FrowardAE1,
  input  [2:0]  FrowardBE1,
  input  [63:0] ResultW1,
  //--- ALU ---
  input  [1:0]  XretE1,
  input         JumpE1,
  input         BranchE1,
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
  input  [1:0]  XretE2,
  input         JumpE2,
  input         BranchE2,
  input  [63:0] RD1E2,
  input  [63:0] RD2E2,
  input  [63:0] PCE2,
  input  [5:0]  ALUControlE2,
  input         ALUSrcE2,
  input  [63:0] ImmExtE2,
  output [63:0] ALUResultE2,
  output [63:0] WriteDataE2,
  input  [63:0] ALUResultM2,
  input  [4:0]  Rs1E2,
  // use to print
  input  [4:0]  RdE2,
  input  [4:0]  Rs2E2,
  input  [31:0] instrE1,
  input  [31:0] instrE2
);
logic alu_display = 0;
//****** Privileged Instruction ******
reg   [63:0] csrs [4096];
logic [63:0] SrcAE1;
logic [63:0] SrcBE1;
logic [63:0] SrcAE2;
logic [63:0] SrcBE2;
always_ff @(posedge clk) begin
  if(Rs1E2 == RdE1) SrcAE2 = ALUResultE1;
  case(ALUControlE1[5:0])
    6'b110011, 6'b110110: begin //csrrw csrrwi
      csrs[SrcBE1] <= SrcAE1;
      if(alu_display) $display("%0x: '%x'", PCE1, SrcAE1);
    end
    6'b110100, 6'b110111: begin //csrrs csrrsi
      csrs[SrcBE1] <= csrs[SrcBE1] | SrcAE1;
      if(alu_display) $display("%0x: '%x'", PCE1, csrs[SrcBE1] | SrcAE1);
    end
    6'b110101, 6'b111000:begin //csrrc csrrci
      csrs[SrcBE1] <= csrs[SrcBE1] & (~SrcAE1);
      if(alu_display) $display("%0x: '%x'", PCE1, csrs[SrcBE1] & (~SrcAE1));
    end
    6'b111001: begin //sret
      csrs[12'h100][1] <= csrs[12'h100][5];
      csrs[12'h100][5] <= 1;
      mode <= 1;
      csrs[12'h100][8] <= 0;
    end
    6'b111010: begin //mret
      csrs[12'h300][3] <= csrs[12'h300][7];
      csrs[12'h300][7] <= 1;
      mode <= csrs[12'h300][12:11];
      csrs[12'h300][12:11] <= 3;
    end
  endcase
  case(ALUControlE2[5:0])
    6'b110011, 6'b110110: begin //csrrw csrrwi
      csrs[SrcBE2] <= SrcAE2;
      if(alu_display) $display("%0x: '%x'", PCE2, SrcAE2);
    end
    6'b110100, 6'b110111: begin //csrrs csrrsi
      csrs[SrcBE2] <= csrs[SrcBE2] | SrcAE2;
      if(alu_display) $display("%0x: '%x'", PCE2, csrs[SrcBE2] | SrcAE2);
    end
    6'b110101, 6'b111000:begin //csrrc csrrci
      csrs[SrcBE2] <= csrs[SrcBE2] & (~SrcAE2);
      if(alu_display) $display("%0x: '%x'", PCE2, csrs[SrcBE2] & (~SrcAE2));
    end
    6'b111001: begin //sret
      csrs[12'h100][1] <= csrs[12'h100][5];
      csrs[12'h100][5] <= 1;
      mode <= 1;
      csrs[12'h100][8] <= 0;
    end
    6'b111010: begin //mret
      csrs[12'h300][3] <= csrs[12'h300][7];
      csrs[12'h300][7] <= 1;
      mode <= csrs[12'h300][12:11];
      csrs[12'h300][12:11] <= 3;
    end
  endcase
end
//****** Branch Prediction ******
reg          Valid [B_N];
reg[b_h-1:0] BH    [B_N]; // Branch history
reg   [63:0] BIA   [B_N]; // Branch instruction address field
reg   [63:0] BTA   [B_N]; // Branch target address field
logic [6:0]  index;
logic        exist;
logic        V; // Valid
logic [1:0]  H; // BH
logic [63:0] I; // BIA
logic [63:0] T; // BTA
always_ff @ (posedge clk) begin
  if(V & enableE & !StallE) begin
    Valid[index] <= V;
    BH[index] <= H;
    BIA[index] <= I;
    BTA[index] <= T;
    V = 0;
    //$display("BTB!!!!!!!!!!!%d, %x, %x, %x, %x", index, V, H, I, T);
  end
end
//****** ALU ******
// Superscalar 1
logic        ZeroE1;
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
    17: 010001  |   slt               49: 110001  |   ecall
    18: 010010  |   sltu              50: 110010  |   ebreak
    19: 010011  |   auipc             51: 110011  |   csrrw
    20: 010100  |   lui               52: 110100  |   csrrs
    21: 010101  |   jalr              53: 110101  |   csrrc
    22: 010110  |   jal               54: 110110  |   csrrwi
    23: 010111  |   beq               55: 110111  |   csrrsi
    24: 011000  |   bne               56: 111000  |   csrrci
    25: 011001  |   blt               57: 111001  |   sret
    26: 011010  |   bge               58: 111010  |   mret
    27: 011011  |   bltu              59: 111011  |   mnret
    28: 011100  |   bgeu              60: 111100  |   wfi
    29: 011101  |   fence             61: 111101  |   sfence.vma
    30: 011110  |   fence.i
    */
    //auipc
    if(ALUControlE1[5:0] == 19) begin
      SrcAE1 = PCE1;
    end
    //jump & branch & xret
    ZeroE1 = JumpE1 | (XretE1 > 0);
    //$display("ZeroE1, %0x, %0x, %0x", ZeroE1, JumpE1, XretE1);
    if(ALUControlE1[5:0] == 21) begin
      PCTargetE = SrcAE1 + ImmExtE1;
    end else if(ALUControlE1[5:0] > 21 & ALUControlE1[5:0] < 29) begin
      PCTargetE = PCE1 + ImmExtE1;
    end else if(ALUControlE1[5:0] == 57) begin
      PCTargetE = csrs[12'h141];
    end else if(ALUControlE1[5:0] == 58) begin
      PCTargetE = csrs[12'h341];
    end
    //--- ALU ---
    if(ALUControlE1[5]) begin
      if(ALUControlE1[4]) begin
        case(ALUControlE1[3:0])
          1: begin
            // ecall
            if(alu_display) $display("%0x: ecall", PCE1);
            //$finish;
          end
          2: begin
            // ebreak
            if(alu_display) $display("%0x: ebreak", PCE1);
            $finish;
          end
          3,4,5,6,7,8: begin
            ALUResultE1 = csrs[SrcBE1]; // csrrw,csrrs,csrrc,csrrwi,csrrsi,csrrci
            //if(SrcBE1 == 12'h180) satp = 1;
            //if(SrcBE1 == 12'h180) $finish;
            if(alu_display) $display("%0x: csrrw,csrrs,csrrc,csrrwi,csrrsi,csrrci: %0d, %0d, %0d", PCE1, csrs[SrcBE1], SrcAE1, SrcBE1);
          end
          9: begin
            // sret
            if(alu_display) $display("%0x: sret", PCE1);
          end
          10: begin
            // mret
            if(alu_display) $display("%0x: mret", PCE1);
          end
          11: begin
            // mnret
            if(alu_display) $display("%0x: mnret", PCE1);
          end
          12: begin
            // wfi
            if(alu_display) $display("%0x: wfi", PCE1);
          end
          13: begin
            // sfence.vma
            if(alu_display) $display("%0x: sfence.vma", PCE1);
          end
        endcase
      end else begin
        case(ALUControlE1[3:0])
          1:  begin
            ALUResultE1 = SrcAE1[31:0] << {1'b0, SrcBE1[4:0]}; // sllw slliw
            if(alu_display) $display("%0x: sllw slliw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], {1'b0, SrcBE1[4:0]}, ALUResultE1); 
          end
          2:  begin
            ALUResultE1 = SrcAE1[31:0] >> {1'b0, SrcBE1[4:0]}; // srlw srliw
            if(alu_display) $display("%0x: srlw srliw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], {1'b0, SrcBE1[4:0]}, ALUResultE1); 
          end
          3:  begin
            ALUResultE1 = SrcAE_sign1[31:0] >>> {1'b0, SrcBE_sign1[4:0]}; // sraw sraiw
            if(alu_display) $display("%0x: sraw sraiw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], {1'b0, SrcBE_sign1[4:0]}, ALUResultE1); 
          end
          4:  begin
            ALUResultE1 = SrcAE_sign1[31:0] + SrcBE_sign1[31:0]; // addw addiw
            if(alu_display) $display("%0x: addw addiw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1);
          end
          5:  begin
            ALUResultE1 = SrcAE_sign1[31:0] - SrcBE_sign1[31:0]; // subw
            if(alu_display) $display("%0x: subw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1); 
          end
          6:  begin
            ALUResultE1 = SrcAE_sign1[31:0] / SrcBE_sign1[31:0]; // divw
            if(alu_display) $display("%0x: divw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1); 
          end
          7:  begin
            ALUResultE1 = SrcAE1[31:0] / SrcBE1[31:0]; // divuw
            if(alu_display) $display("%0x: divuw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], SrcBE1[31:0], ALUResultE1);
          end
          8:  begin
            ALUResultE1 = SrcAE_sign1[31:0] % SrcBE_sign1[31:0]; // remw
            if(alu_display) $display("%0x: remw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1);
          end
          9:  begin
            ALUResultE1 = SrcAE1[31:0] % SrcBE1[31:0]; // remuw
            if(alu_display) $display("%0x: remuw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1[31:0], SrcBE1[31:0], ALUResultE1);
          end
          10: begin
            ALUResultE1 = SrcAE_sign1[31:0] * SrcBE_sign1[31:0]; // mulw
            if(alu_display) $display("%0x: mulw %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1[31:0], SrcBE_sign1[31:0], ALUResultE1);
          end
          default: begin
            ALUResultE1 = 0;
            if(alu_display) $display("Invalid1 %0x: '%x'", PCE1, instrE1);
          end
        endcase
        ALUResultE1 = {{32{ALUResultE1[31]}}, ALUResultE1[31:0]};
      end
    end else begin
      case(ALUControlE1[4:0])
        1: begin
          ALUResultE1 = SrcAE1 << SrcBE1[5:0]; // sll slli
          if(alu_display) $display("%0x: sll slli %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1[5:0], ALUResultE1); 
        end
        2: begin
          ALUResultE1 = SrcAE1 >> SrcBE1[5:0]; // srl srli
          if(alu_display) $display("%0x: srl srli %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1[5:0], ALUResultE1); 
        end
        3: begin
          ALUResultE1 = SrcAE_sign1 >>> SrcBE_sign1[5:0]; // sra srai
          if(alu_display) $display("%0x: sra srai %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1[5:0], ALUResultE1);
        end
        4: begin
          ALUResultE1 = SrcAE_sign1 + SrcBE_sign1; // add addi load save
          if(alu_display) $display("%0x: add addi load save %0d(s%0d): %0d + %0d = %0x: %0x", PCE1, RdE1, Rs2E1, SrcAE_sign1, SrcBE_sign1, ALUResultE1, WriteDataE1); 
        end
        5: begin
          ALUResultE1 = SrcAE_sign1 - SrcBE_sign1; // sub
          if(alu_display) $display("%0x: sub %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        6: begin
          ALUResultE1 = SrcAE_sign1 / SrcBE_sign1; // div
          if(alu_display) $display("%0x: div %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        7: begin
          ALUResultE1 = SrcAE1 / SrcBE1; // divu
          if(alu_display) $display("%0x: divu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        8: begin
          ALUResultE1 = SrcAE_sign1 % SrcBE_sign1; // rem
          if(alu_display) $display("%0x: rem %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1);
        end
        9: begin
          ALUResultE1 = SrcAE1 % SrcBE1; // remu
          if(alu_display) $display("%0x: remu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        10: begin
          ALUResultE1 = SrcAE_sign1 * SrcBE_sign1; // mul
          if(alu_display) $display("%0x: mul %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        11: begin // mulh
          long_ALUResultE1 = SrcAE_sign1 * SrcBE_sign1;
          ALUResultE1 = long_ALUResultE1[127:64];
          if(alu_display) $display("%0x: mulh %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1); 
        end
        12: begin // mulhu
          long_ALUResultE1 = SrcAE1 * SrcBE1;
          ALUResultE1 = long_ALUResultE1[127:64];
          if(alu_display) $display("%0x: mulhu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        13: begin // mulhsu
          long_ALUResultE1 = SrcAE_sign1 * SrcBE1;
          ALUResultE1 = long_ALUResultE1[127:64];
          if(alu_display) $display("%0x: mulhsu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE1, ALUResultE1); 
        end
        14: begin
          ALUResultE1 = SrcAE1 ^ SrcBE1; // xor xori
          if(alu_display) $display("%0x: xor xori %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1);
        end
        15: begin
          ALUResultE1 = SrcAE1 | SrcBE1; // or ori
          if(alu_display) $display("%0x: or ori %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        16: begin
          ALUResultE1 = SrcAE1 & SrcBE1; // and andi
          if(alu_display) $display("%0x: and andi %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1);
        end
        17: begin
          ALUResultE1 = (SrcAE_sign1 < SrcBE_sign1) ? 1 : 0; // slt slti
          if(alu_display) $display("%0x: slt slti %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE_sign1, SrcBE_sign1, ALUResultE1);
        end
        18: begin
          ALUResultE1 = (SrcAE1 < SrcBE1) ? 1 : 0; // sltu sltiu
          if(alu_display) $display("%0x: sltu sltiu %0d: %0d, %0d = %0x", PCE1, RdE1, SrcAE1, SrcBE1, ALUResultE1); 
        end
        19:  begin
          ALUResultE1 = SrcAE1 + SrcBE1; // auipc
          if(alu_display) $display("%0x: auipc %0d: 0x%0x = %0x", PCE1, RdE1, SrcBE1, ALUResultE1);
        end
        20:  begin
          ALUResultE1 = SrcBE1; // lui
          if(alu_display) $display("%0x: lui %0d: 0x%0x = %0x", PCE1, RdE1, SrcBE1, ALUResultE1);
        end
        21:  begin
          // jalr
          if(alu_display) $display("%0x: jalr %0d: 0x%0x", PCE1, RdE1, PCTargetE);
        end
        22:  begin
          // jal
          if(alu_display) $display("%0x: jal %0d: 0x%0x", PCE1, RdE1, PCTargetE);
        end
        23: begin
          ZeroE1 = (SrcAE1 == SrcBE1) ? 1 : 0; // beq
          if(alu_display) $display("%0x: beq %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE1);
        end
        24: begin
          ZeroE1 = (SrcAE1 != SrcBE1) ? 1 : 0; // bne
          if(alu_display) $display("%0x: bne %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE1);
        end
        25: begin
          ZeroE1 = (SrcAE_sign1 < SrcBE_sign1) ? 1 : 0; // blt
          if(alu_display) $display("%0x: blt %0d, %0d, 0x%0x = %0x", PCE1, SrcAE_sign1, SrcBE_sign1, PCTargetE, ZeroE1);
        end
        26: begin
          ZeroE1 = (SrcAE_sign1 >= SrcBE_sign1) ? 1 : 0; // bge
          if(alu_display) $display("%0x: bge %0d, %0d, 0x%0x = %0x", PCE1, SrcAE_sign1, SrcBE_sign1, PCTargetE, ZeroE1);
        end
        27: begin
          ZeroE1 = (SrcAE1 < SrcBE1) ? 1 : 0; // bltu
          if(alu_display) $display("%0x: bltu %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE1);
        end
        28: begin
          ZeroE1 = (SrcAE1 >= SrcBE1) ? 1 : 0; // bgeu
          if(alu_display) $display("%0x: bgeu %0d, %0d, 0x%0x = %0x", PCE1, SrcAE1, SrcBE1, PCTargetE, ZeroE1);
        end
        default: begin
          ALUResultE1 = 0;
          if(alu_display) $display("Invalid1 %0x: '%x'", PCE1, instrE1);
        end
      endcase
    end
    //****** Branch Prediction ******
    PCSrcE1 = 0;
    if(ZeroE1) begin // JumpE == 1 | (BranchE == 1 & Result of BranchE == True)
      index = B_N;
      exist = 0;
      for(int i=0; i<B_N; i++) begin
        //$display("%d: V:%d, BH:%0x, BIA:%0x, BTA:%0x", i, Valid[i], BH[i], BIA[i], BTA[i]);
        if(Valid[i]) begin
          if(BIA[i] == PCE1) begin
            if(BTA[i] == PCTargetE) begin
              if(BH[i] < 3) begin
                V = 1;
                H = BH[i]+1;
                I = BIA[i];
                T = BTA[i];
              end
            end else begin
              if(BH[i] > 1) begin
                H = BH[i]-1;
                T = BTA[i];
              end else begin
                H = 1;
                T = PCTargetE;
              end
              V = 1;
              I = BIA[i];
            end
            exist = 1;
            index = i;
            i = B_N;
          end
        end else index = i;
      end
      if(index == B_N) index = num_clk % B_N;
      if(!exist) begin
        V = 1;
        H = 1;
        I = PCE1;
        T = PCTargetE;
      end
      if(PCD1 != PCTargetE) PCSrcE1 = 1;
    end else begin // JumpE == 0 | BranchE == 0 | (BranchE == 1 & Result of BranchE == False)
      if(BranchE1) begin
        for(int i=0; i<B_N; i++) begin
          if(Valid[i] & (BIA[i] == PCE1) & (BTA[i] == PCTargetE)) begin
            if(BH[i] > 1) begin
              V = 1;
              H = BH[i]-1;
            end else begin
              V = 0;
              H = 0;
            end
            index = i;
            I = BIA[i];
            T = BTA[i];
            i = B_N;
          end
        end
        if(PCD1 != PCE1 + 4) begin
          PCSrcE1 = 1;
          PCTargetE = PCE1 + 4;
        end
      end
    end
    //PCSrcE = JumpE | (BranchE & ZeroE);
  end
end

// Superscalar 2
logic        ZeroE2;
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
    if(ALUControlE2[5:0] == 19) begin
      SrcAE2 = PCE2;
    end
    //jump & branch & xret
    ZeroE2 = JumpE2 | (XretE2 > 0);
    //$display("ZeroE2, %0x, %0x, %0x", ZeroE2, JumpE2, XretE2);
    if(ALUControlE2[5:0] == 21) begin
      PCTargetE = SrcAE2 + ImmExtE2;
    end else if(ALUControlE2[5:0] > 21 & ALUControlE2[5:0] < 29) begin
      PCTargetE = PCE2 + ImmExtE2;
    end else if(ALUControlE2[5:0] == 57) begin
      PCTargetE = csrs[12'h141];
    end else if(ALUControlE2[5:0] == 58) begin
      PCTargetE = csrs[12'h341];
    end
    //--- ALU ---
    if(ALUControlE2[5]) begin
      if(ALUControlE2[4]) begin
        case(ALUControlE2[3:0])
          1: begin
            // ecall
            if(alu_display) $display("%0x: ecall", PCE2);
          end
          2: begin
            // ebreak
            if(alu_display) $display("%0x: ebreak", PCE2);
          end
          3,4,5,6,7,8: begin
            ALUResultE2 = csrs[SrcBE2]; // csrrw,csrrs,csrrc,csrrwi,csrrsi,csrrci
            //if(SrcBE2 == 12'h180) satp = 1;
            if(alu_display) $display("%0x: csrrw,csrrs,csrrc,csrrwi,csrrsi,csrrci: %0d, %0d, %0d", PCE2, csrs[SrcBE2], SrcAE1, SrcBE1);
          end
          9: begin
            // sret
            if(alu_display) $display("%0x: sret", PCE2);
          end
          10: begin
            // mret
            if(alu_display) $display("%0x: mret", PCE2);
          end
          11: begin
            // mnret
            if(alu_display) $display("%0x: mnret", PCE2);
          end
          12: begin
            // wfi
            if(alu_display) $display("%0x: wfi", PCE2);
          end
          13: begin
            // sfence.vma
            if(alu_display) $display("%0x: sfence.vma", PCE2);
          end
        endcase
      end else begin
        case(ALUControlE2[3:0])
          1:  begin
            ALUResultE2 = SrcAE2[31:0] << {1'b0, SrcBE2[4:0]}; // sllw slliw
            if(alu_display) $display("%0x: sllw slliw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], {1'b0, SrcBE2[4:0]}, ALUResultE2); 
          end
          2:  begin
            ALUResultE2 = SrcAE2[31:0] >> {1'b0, SrcBE2[4:0]}; // srlw srliw
            if(alu_display) $display("%0x: srlw srliw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], {1'b0, SrcBE2[4:0]}, ALUResultE2); 
          end
          3:  begin
            ALUResultE2 = SrcAE_sign2[31:0] >>> {1'b0, SrcBE_sign2[4:0]}; // sraw sraiw
            if(alu_display) $display("%0x: sraw sraiw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], {1'b0, SrcBE_sign2[4:0]}, ALUResultE2); 
          end
          4:  begin
            ALUResultE2 = SrcAE_sign2[31:0] + SrcBE_sign2[31:0]; // addw addiw
            if(alu_display) $display("%0x: addw addiw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2);
          end
          5:  begin
            ALUResultE2 = SrcAE_sign2[31:0] - SrcBE_sign2[31:0]; // subw
            if(alu_display) $display("%0x: subw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2); 
          end
          6:  begin
            ALUResultE2 = SrcAE_sign2[31:0] / SrcBE_sign2[31:0]; // divw
            if(alu_display) $display("%0x: divw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2); 
          end
          7:  begin
            ALUResultE2 = SrcAE2[31:0] / SrcBE2[31:0]; // divuw
            if(alu_display) $display("%0x: divuw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], SrcBE2[31:0], ALUResultE2);
          end
          8:  begin
            ALUResultE2 = SrcAE_sign2[31:0] % SrcBE_sign2[31:0]; // remw
            if(alu_display) $display("%0x: remw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2);
          end
          9:  begin
            ALUResultE2 = SrcAE2[31:0] % SrcBE2[31:0]; // remuw
            if(alu_display) $display("%0x: remuw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2[31:0], SrcBE2[31:0], ALUResultE2);
          end
          10: begin
            ALUResultE2 = SrcAE_sign2[31:0] * SrcBE_sign2[31:0]; // mulw
            if(alu_display) $display("%0x: mulw %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2[31:0], SrcBE_sign2[31:0], ALUResultE2);
          end
          default: begin
            ALUResultE2 = 0;
            if(alu_display) $display("Invalid2 %0x: '%x'", PCE2, instrE2);
          end
        endcase
        ALUResultE2 = {{32{ALUResultE2[31]}}, ALUResultE2[31:0]};
      end
    end else begin
      case(ALUControlE2[4:0])
        1: begin
          ALUResultE2 = SrcAE2 << SrcBE2[5:0]; // sll slli
          if(alu_display) $display("%0x: sll slli %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2[5:0], ALUResultE2); 
        end
        2: begin
          ALUResultE2 = SrcAE2 >> SrcBE2[5:0]; // srl srli
          if(alu_display) $display("%0x: srl srli %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2[5:0], ALUResultE2); 
        end
        3: begin
          ALUResultE2 = SrcAE_sign2 >>> SrcBE_sign2[5:0]; // sra srai
          if(alu_display) $display("%0x: sra srai %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2[5:0], ALUResultE2);
        end
        4: begin
          ALUResultE2 = SrcAE_sign2 + SrcBE_sign2; // add addi load save
          if(alu_display) $display("%0x: add addi load save %0d(s%0d): %0d + %0d = %0x: %0x", PCE2, RdE2, Rs2E2, SrcAE_sign2, SrcBE_sign2, ALUResultE2, WriteDataE2); 
        end
        5: begin
          ALUResultE2 = SrcAE_sign2 - SrcBE_sign2; // sub
          if(alu_display) $display("%0x: sub %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        6: begin
          ALUResultE2 = SrcAE_sign2 / SrcBE_sign2; // div
          if(alu_display) $display("%0x: div %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        7: begin
          ALUResultE2 = SrcAE2 / SrcBE2; // divu
          if(alu_display) $display("%0x: divu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        8: begin
          ALUResultE2 = SrcAE_sign2 % SrcBE_sign2; // rem
          if(alu_display) $display("%0x: rem %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2);
        end
        9: begin
          ALUResultE2 = SrcAE2 % SrcBE2; // remu
          if(alu_display) $display("%0x: remu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        10: begin
          ALUResultE2 = SrcAE_sign2 * SrcBE_sign2; // mul
          if(alu_display) $display("%0x: mul %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        11: begin // mulh
          long_ALUResultE2 = SrcAE_sign2 * SrcBE_sign2;
          ALUResultE2 = long_ALUResultE2[127:64];
          if(alu_display) $display("%0x: mulh %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2); 
        end
        12: begin // mulhu
          long_ALUResultE2 = SrcAE2 * SrcBE2;
          ALUResultE2 = long_ALUResultE2[127:64];
          if(alu_display) $display("%0x: mulhu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        13: begin // mulhsu
          long_ALUResultE2 = SrcAE_sign2 * SrcBE2;
          ALUResultE2 = long_ALUResultE2[127:64];
          if(alu_display) $display("%0x: mulhsu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE2, ALUResultE2); 
        end
        14: begin
          ALUResultE2 = SrcAE2 ^ SrcBE2; // xor xori
          if(alu_display) $display("%0x: xor xori %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2);
        end
        15: begin
          ALUResultE2 = SrcAE2 | SrcBE2; // or ori
          if(alu_display) $display("%0x: or ori %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        16: begin
          ALUResultE2 = SrcAE2 & SrcBE2; // and andi
          if(alu_display) $display("%0x: and andi %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2);
        end
        17: begin
          ALUResultE2 = (SrcAE_sign2 < SrcBE_sign2) ? 1 : 0; // slt slti
          if(alu_display) $display("%0x: slt slti %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE_sign2, SrcBE_sign2, ALUResultE2);
        end
        18: begin
          ALUResultE2 = (SrcAE2 < SrcBE2) ? 1 : 0; // sltu sltiu
          if(alu_display) $display("%0x: sltu sltiu %0d: %0d, %0d = %0x", PCE2, RdE2, SrcAE2, SrcBE2, ALUResultE2); 
        end
        19:  begin
          ALUResultE2 = SrcAE2 + SrcBE2; // auipc
          if(alu_display) $display("%0x: auipc %0d: 0x%0x = %0x", PCE2, RdE2, SrcBE2, ALUResultE2);
        end
        20:  begin
          ALUResultE2 = SrcBE2; // lui
          if(alu_display) $display("%0x: lui %0d: 0x%0x = %0x", PCE2, RdE2, SrcBE2, ALUResultE2);
        end
        21:  begin
          // jalr
          if(alu_display) $display("%0x: jalr %0d: 0x%0x", PCE2, RdE2, PCTargetE);
        end
        22:  begin
          // jal
          if(alu_display) $display("%0x: jal %0d: 0x%0x", PCE2, RdE2, PCTargetE);
        end
        23: begin
          ZeroE2 = (SrcAE2 == SrcBE2) ? 1 : 0; // beq
          if(alu_display) $display("%0x: beq %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE2);
        end
        24: begin
          ZeroE2 = (SrcAE2 != SrcBE2) ? 1 : 0; // bne
          if(alu_display) $display("%0x: bne %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE2);
        end
        25: begin
          ZeroE2 = (SrcAE_sign2 < SrcBE_sign2) ? 1 : 0; // blt
          if(alu_display) $display("%0x: blt %0d, %0d, 0x%0x = %0x", PCE2, SrcAE_sign2, SrcBE_sign2, PCTargetE, ZeroE2);
        end
        26: begin
          ZeroE2 = (SrcAE_sign2 >= SrcBE_sign2) ? 1 : 0; // bge
          if(alu_display) $display("%0x: bge %0d, %0d, 0x%0x = %0x", PCE2, SrcAE_sign2, SrcBE_sign2, PCTargetE, ZeroE2);
        end
        27: begin
          ZeroE2 = (SrcAE2 < SrcBE2) ? 1 : 0; // bltu
          if(alu_display) $display("%0x: bltu %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE2);
        end
        28: begin
          ZeroE2 = (SrcAE2 >= SrcBE2) ? 1 : 0; // bgeu
          if(alu_display) $display("%0x: bgeu %0d, %0d, 0x%0x = %0x", PCE2, SrcAE2, SrcBE2, PCTargetE, ZeroE2);
        end
        default: begin
          ALUResultE2 = 0;
          if(alu_display) $display("Invalid2 %0x: '%x'", PCE2, instrE2);
        end
      endcase
    end
    //****** Branch Prediction ******
    PCSrcE2 = 0;
    if(ZeroE2) begin // JumpE == 1 | (BranchE == 1 & Result of BranchE == True）
      index = B_N;
      exist = 0;
      for(int i=0; i<B_N; i++) begin
        //$display("%d: V:%d, BH:%0x, BIA:%0x, BTA:%0x", i, Valid[i], BH[i], BIA[i], BTA[i]);
        if(Valid[i]) begin
          if(BIA[i] == PCE2) begin
            if(BTA[i] == PCTargetE) begin
              if(BH[i] < 3) begin
                V = 1;
                H = BH[i]+1;
                I = BIA[i];
                T = BTA[i];
              end
            end else begin
              if(BH[i] > 1) begin
                H = BH[i]-1;
                T = BTA[i];
              end else begin
                H = 1;
                T = PCTargetE;
              end
              V = 1;
              I = BIA[i];
            end
            exist = 1;
            index = i;
            i = B_N;
          end
        end else index = i;
      end
      if(index == B_N) index = num_clk % B_N;
      if(!exist) begin
        V = 1;
        H = 1;
        I = PCE2;
        T = PCTargetE;
      end
      if(PCD1 != PCTargetE) PCSrcE2 = 1;
    end else begin // JumpE == 0 | BranchE == 0 | (BranchE == 1 & Result of BranchE == False)
      if(BranchE2) begin
        for(int i=0; i<B_N; i++) begin
          if(Valid[i] & (BIA[i] == PCE2) & (BTA[i] == PCTargetE)) begin
            if(BH[i] > 1) begin
              V = 1;
              H = BH[i]-1;
            end else begin
              V = 0;
              H = 0;
            end
            index = i;
            I = BIA[i];
            T = BTA[i];
            i = B_N;
          end
        end
        if(PCD1 != PCE2 + 4) begin
          PCTargetE = PCE2 + 4;
          PCSrcE2 = 1;
        end
      end
    end
    //PCSrcE = JumpE | (BranchE & ZeroE);
  end
end
endmodule