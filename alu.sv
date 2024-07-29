module alu
#(
    B_N = 0, // Number of ways of BTB
    B_H = 0  // Number of history bits
)
(
  //****** ALU ******
  input  clk,
  input  enableE,
  input  StallE,
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
  // Superscalar 2
  //--- hazard ---
  input  [2:0]  FrowardAE2,
  input  [2:0]  FrowardBE2,
  input  [63:0] ResultW2,
  //--- ALU ---
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
  input  [63:0] ALUResultM2
);
//****** Branch Prediction ******
reg          Valid [B_N];
reg[B_H-1:0] BH    [B_N]; // Branch history
reg   [63:0] BIA   [B_N]; // Branch instruction address field
reg   [63:0] BTA   [B_N]; // Branch target address field
logic [6:0]  index;
logic        exist;
logic        B;
logic        V; // Valid
logic [1:0]  H; // BH
logic [63:0] I; // BIA
logic [63:0] T; // BTA
always_ff @ (posedge clk) begin
  if(B & enableE & !StallE) begin
    B = 0;
    Valid[index] <= V;
    BH[index] <= H;
    BIA[index] <= I;
    BTA[index] <= T;
  end
end
//****** ALU ******
// Superscalar 1
logic        ZeroE1;
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
    if(ALUSrcE1) SrcBE1 = ImmExtE1;
    else SrcBE1 = WriteDataE1;
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
    if(ALUControlE1[4:0] == 19) SrcAE1 = PCE1;
    //jump & branch
    ZeroE1 = JumpE1;
    if(ALUControlE1[4:0] > 20) begin
      if(ALUControlE1[4:0] == 21) PCTargetE = SrcAE1 + ImmExtE1;
      else PCTargetE = PCE1 + ImmExtE1;
    end
    //--- ALU ---
    if(ALUControlE1[5]) begin
      case(ALUControlE1[4:0])
        1: ALUResultE1 = SrcAE1[31:0] << {1'b0, SrcBE1[4:0]}; // sllw slliw
        2: ALUResultE1 = SrcAE1[31:0] >> {1'b0, SrcBE1[4:0]}; // srlw srliw
        3: ALUResultE1 = SrcAE_sign1[31:0] >>> {1'b0, SrcBE_sign1[4:0]}; // sraw sraiw
        4: ALUResultE1 = SrcAE_sign1[31:0] + SrcBE_sign1[31:0]; // addw addiw
        5: ALUResultE1 = SrcAE_sign1[31:0] - SrcBE_sign1[31:0]; // subw
        6: ALUResultE1 = SrcAE_sign1[31:0] / SrcBE_sign1[31:0]; // divw
        7: ALUResultE1 = SrcAE1[31:0] / SrcBE1[31:0]; // divuw
        8: ALUResultE1 = SrcAE_sign1[31:0] % SrcBE_sign1[31:0]; // remw
        9: ALUResultE1 = SrcAE1[31:0] % SrcBE1[31:0]; // remuw
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
        19: ALUResultE1 = SrcAE1 + SrcBE1; // auipc
        20: ALUResultE1 = SrcBE1; // lui
        //21: // jalr
        //22: // jal
        23: ZeroE1 = (SrcAE1 == SrcBE1) ? 1 : 0; // beq
        24: ZeroE1 = (SrcAE1 != SrcBE1) ? 1 : 0; // bne
        25: ZeroE1 = (SrcAE_sign1 < SrcBE_sign1) ? 1 : 0; // blt
        26: ZeroE1 = (SrcAE_sign1 >= SrcBE_sign1) ? 1 : 0; // bge
        27: ZeroE1 = (SrcAE1 < SrcBE1) ? 1 : 0; // bltu
        28: ZeroE1 = (SrcAE1 >= SrcBE1) ? 1 : 0; // bgeu
        default: ALUResultE1 = 0;
      endcase
    end
    //****** Branch Prediction ******
    PCSrcE1 = 0;
    if(ZeroE1) begin // JumpE == 1 | (BranchE == 1 & Result of BranchE == True)
      index = B_N;
      exist = 0;
      for(int i=0; i<B_N; i++) begin
        if(Valid[i]) begin
          if(BIA[i] == PCE1) begin
            if(BTA[i] == PCTargetE) begin
              if(BH[i] < 3) begin
                B = 1;
                V = 1;
                H = BH[i]+1;
                I = BIA[i];
                T = BTA[i];
              end
            end
            exist = 1;
            index = i;
            break;
          end
        end else index = i;
      end
      if(index == B_N) index = num_clk % B_N;
      if(!exist) begin
        B = 1;
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
            B = 1;
            I = BIA[i];
            T = BTA[i];
            break;
          end
        end
        if(PCD1 != PCE1 + 4) begin
          PCSrcE1 = 1;
          PCTargetE = PCE1 + 4;
        end
      end
    end
  end
end

// Superscalar 2
logic        ZeroE2;
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
    if(ALUSrcE2) SrcBE2 = ImmExtE2;
    else SrcBE2 = WriteDataE2;
    SrcAE_sign2 = SrcAE2;
    SrcBE_sign2 = SrcBE2;
    //auipc
    if(ALUControlE2[4:0] == 19) SrcAE2 = PCE2;
    //jump & branch
    ZeroE2 = JumpE2;
    if(ALUControlE2[4:0] > 20) begin
      if(ALUControlE2[4:0] == 21) PCTargetE = SrcAE2 + ImmExtE2;
      else PCTargetE = PCE2 + ImmExtE2;
    end
    //--- ALU ---
    if(ALUControlE2[5]) begin
      case(ALUControlE2[4:0])
        1: ALUResultE2 = SrcAE2[31:0] << {1'b0, SrcBE2[4:0]}; // sllw slliw
        2: ALUResultE2 = SrcAE2[31:0] >> {1'b0, SrcBE2[4:0]}; // srlw srliw
        3: ALUResultE2 = SrcAE_sign2[31:0] >>> {1'b0, SrcBE_sign2[4:0]}; // sraw sraiw
        4: ALUResultE2 = SrcAE_sign2[31:0] + SrcBE_sign2[31:0]; // addw addiw
        5: ALUResultE2 = SrcAE_sign2[31:0] - SrcBE_sign2[31:0]; // subw
        6: ALUResultE2 = SrcAE_sign2[31:0] / SrcBE_sign2[31:0]; // divw
        7: ALUResultE2 = SrcAE2[31:0] / SrcBE2[31:0]; // divuw
        8: ALUResultE2 = SrcAE_sign2[31:0] % SrcBE_sign2[31:0]; // remw
        9: ALUResultE2 = SrcAE2[31:0] % SrcBE2[31:0]; // remuw
        10: ALUResultE2 = SrcAE_sign2[31:0] * SrcBE_sign2[31:0]; // mulw
        default: ALUResultE2 = 0;
      endcase
      ALUResultE2 = {{32{ALUResultE2[31]}}, ALUResultE2[31:0]};
    end else begin
      case(ALUControlE2[4:0])
        1: ALUResultE2 = SrcAE2 << SrcBE2[5:0]; // sll slli
        2: ALUResultE2 = SrcAE2 >> SrcBE2[5:0]; // srl srli
        3: ALUResultE2 = SrcAE_sign2 >>> SrcBE_sign2[5:0]; // sra srai
        4: ALUResultE2 = SrcAE_sign2 + SrcBE_sign2; // add addi load save
        5: ALUResultE2 = SrcAE_sign2 - SrcBE_sign2; // sub
        6: ALUResultE2 = SrcAE_sign2 / SrcBE_sign2; // div
        7: ALUResultE2 = SrcAE2 / SrcBE2; // divu
        8: ALUResultE2 = SrcAE_sign2 % SrcBE_sign2; // rem
        9: ALUResultE2 = SrcAE2 % SrcBE2; // remu
        10: ALUResultE2 = SrcAE_sign2 * SrcBE_sign2; // mul
        11: begin // mulh
          long_ALUResultE2 = SrcAE_sign2 * SrcBE_sign2;
          ALUResultE2 = long_ALUResultE2[127:64];
        end
        12: begin // mulhu
          long_ALUResultE2 = SrcAE2 * SrcBE2;
          ALUResultE2 = long_ALUResultE2[127:64];
        end
        13: begin // mulhsu
          long_ALUResultE2 = SrcAE_sign2 * SrcBE2;
          ALUResultE2 = long_ALUResultE2[127:64];
        end
        14: ALUResultE2 = SrcAE2 ^ SrcBE2; // xor xori
        15: ALUResultE2 = SrcAE2 | SrcBE2; // or ori
        16: ALUResultE2 = SrcAE2 & SrcBE2; // and andi
        17: ALUResultE2 = (SrcAE_sign2 < SrcBE_sign2) ? 1 : 0; // slt slti
        18: ALUResultE2 = (SrcAE2 < SrcBE2) ? 1 : 0; // sltu sltiu
        19: ALUResultE2 = SrcAE2 + SrcBE2; // auipc
        20: ALUResultE2 = SrcBE2; // lui
        //21: // jalr
        //22: // jal
        23: ZeroE2 = (SrcAE2 == SrcBE2) ? 1 : 0; // beq
        24: ZeroE2 = (SrcAE2 != SrcBE2) ? 1 : 0; // bne
        25: ZeroE2 = (SrcAE_sign2 < SrcBE_sign2) ? 1 : 0; // blt
        26: ZeroE2 = (SrcAE_sign2 >= SrcBE_sign2) ? 1 : 0; // bge
        27: ZeroE2 = (SrcAE2 < SrcBE2) ? 1 : 0; // bltu
        28: ZeroE2 = (SrcAE2 >= SrcBE2) ? 1 : 0; // bgeu
        default: ALUResultE2 = 0;
      endcase
    end
    //****** Branch Prediction ******
    PCSrcE2 = 0;
    if(ZeroE2) begin // JumpE == 1 | (BranchE == 1 & Result of BranchE == True）
      index = B_N;
      exist = 0;
      for(int i=0; i<B_N; i++) begin
        if(Valid[i]) begin
          if(BIA[i] == PCE2) begin
            if(BTA[i] == PCTargetE) begin
              if(BH[i] < 3) begin
                B = 1;
                V = 1;
                H = BH[i]+1;
                I = BIA[i];
                T = BTA[i];
              end
            end
            exist = 1;
            index = i;
            break;
          end
        end else index = i;
      end
      if(index == B_N) index = num_clk % B_N;
      if(!exist) begin
        B = 1;
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
            B = 1;
            I = BIA[i];
            T = BTA[i];
            break;
          end
        end
        if(PCD1 != PCE2 + 4) begin
          PCTargetE = PCE2 + 4;
          PCSrcE2 = 1;
        end
      end
    end
  end
end
endmodule