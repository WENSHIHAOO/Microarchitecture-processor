`include "Sysbus.defs"

module decoder
(
  input  clk,
  input  [31:0] instr,
  input  IF_ID_valid,
  output IF_ID_ready
);
  logic [6:0]  op;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [4:0]  rd;
  logic [4:0]  rs1;
  logic [4:0]  rs2;
  logic signed [11:0] imm_I;
  logic signed [11:0] imm_S;
  logic [12:0] imm_B;
  logic [31:0] imm_U;
  logic [20:0] imm_J;

  logic [31:0] pc_instr = -4;
  always_ff @ (posedge clk) begin
    if(IF_ID_valid) begin
      pc_instr = pc_instr + 4;
      IF_ID_ready = 0;
      op     = instr[6:0];
      funct3 = instr[14:12];
      funct7 = instr[31:25];
      rd     = instr[11:7];
      rs1    = instr[19:15];
      rs2    = instr[24:20];
      imm_I  = instr[31:20];
      imm_S  = {instr[31:25], instr[11:7]};
      imm_B  = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0} + pc_instr;
      imm_U  = {instr[31:12], 12'b0} + pc_instr;
      imm_J  = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0} + pc_instr;
      case(op)
        //3, Type I
        7'b0000011: begin
          case(funct3)
            3'b000: $display("%0x: %h: lb $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
            3'b001: $display("%0x: %h: lh $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
            3'b010: $display("%0x: %h: lw $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
            3'b011: $display("%0x: %h: ld $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
            3'b100: $display("%0x: %h: lbu $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
            3'b101: $display("%0x: %h: lhu $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
            3'b110: $display("%0x: %h: lwu $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
            default: $display("Invalid funct3 of op_3: '%b'", funct3);
          endcase
        end
        //19, Type I
        7'b0010011: begin
          case(funct3)
            3'b000: $display("%0x: %h: addi $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I);
            3'b001: $display("%0x: %h: slli $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I[4:0]);
            3'b010: $display("%0x: %h: slti $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I);
            3'b011: $display("%0x: %h: sltiu $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I);
            3'b100: $display("%0x: %h: xori $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I);
            3'b101: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: srli $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I[4:0]);
                7'b0100000: $display("%0x: %h: srai $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I[4:0]);
                default: $display("Invalid funct7 of funct3_101 of op_19: '%b'", funct7);
              endcase
            end
            3'b110: $display("%0x: %h: ori $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I);
            3'b111: $display("%0x: %h: andi $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I);
            default: $display("Invalid funct3 of op_19: '%b'", funct3);
          endcase
        end
        //23, Type U
        7'b0010111: $display("%0x: %h: auipc $%0d, 0x%0x", pc_instr, instr, rd, imm_U[31:12]);
        //27, Type I
        7'b0011011: begin
          case(funct3)
            3'b000: $display("%0x: %h: addiw $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I);
            3'b001: $display("%0x: %h: slliw $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I[4:0]);
            3'b101: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: srliw $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I[4:0]);
                7'b0100000: $display("%0x: %h: sraiw $%0d, $%0d, %0d", pc_instr, instr, rd, rs1, imm_I[4:0]);
                default: $display("Invalid funct7 of funct3_101 of op_27: '%b'", funct7);
              endcase
            end
            default: $display("Invalid funct3 of op_27: '%b'", funct3);
          endcase
        end
        //35, Type S
        7'b0100011: begin
          case(funct3)
            3'b000: $display("%0x: %h: sb $%0d, %0d($%0d)", pc_instr, instr, rs2, imm_S, rs1);
            3'b001: $display("%0x: %h: sh $%0d, %0d($%0d)", pc_instr, instr, rs2, imm_S, rs1);
            3'b010: $display("%0x: %h: sw $%0d, %0d($%0d)", pc_instr, instr, rs2, imm_S, rs1);
            3'b011: $display("%0x: %h: sd $%0d, %0d($%0d)", pc_instr, instr, rs2, imm_S, rs1);
            default: $display("Invalid funct3 of op_35: '%b'", funct3);
          endcase
        end
        //51, Type R
        7'b0110011: begin
          case(funct3)
            3'b000: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: add $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: mul $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0100000: $display("%0x: %h: sbu $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_000 of op_51: '%b'", funct7);
              endcase
            end
            3'b001: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: sll $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: mulh $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_001 of op_51: '%b'", funct7);
              endcase
            end
            3'b010: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: slt $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: mulhsu $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_010 of op_51: '%b'", funct7);
              endcase
            end
            3'b011: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: sltu $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: mulhu $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_011 of op_51: '%b'", funct7);
              endcase
            end
            3'b100: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: xor $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: div $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_100 of op_51: '%b'", funct7);
              endcase
            end
            3'b101: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: srl $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: divu $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0100000: $display("%0x: %h: sra $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_101 of op_51: '%b'", funct7);
              endcase
            end
            3'b110: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: or $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: rem $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_110 of op_51: '%b'", funct7);
              endcase
            end
            3'b111: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: and $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: remu $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_111 of op_51: '%b'", funct7);
              endcase
            end
            default: $display("Invalid funct3 of op_51: '%b'", funct3);
          endcase
        end
        //55, Type U
        7'b0110111: $display("%0x: %h: lui $%0d, 0x%0x", pc_instr, instr, rd, imm_U[31:12]);
        //59, Type R
        7'b0111011: begin
          case(funct3)
            3'b000: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: addw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: mulw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0100000: $display("%0x: %h: subw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_000 of op_59: '%b'", funct7);
              endcase
            end
            3'b001: $display("%0x: %h: sllw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
            3'b100: $display("%0x: %h: divw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
            3'b101: begin
              case(funct7)
                7'b0000000: $display("%0x: %h: srlw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0000001: $display("%0x: %h: divuw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                7'b0100000: $display("%0x: %h: sraw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
                default: $display("Invalid funct7 of funct3_101 of op_59: '%b'", funct7);
              endcase
            end
            3'b110: $display("%0x: %h: remw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
            3'b111: $display("%0x: %h: remuw $%0d, $%0d, $%0d", pc_instr, instr, rd, rs1, rs2);
            default: $display("Invalid funct3 of op_59: '%b'", funct3);
          endcase
        end
        //99, Type B
        7'b1100011: begin
          case(funct3)
            3'b000: $display("%0x: %h: beq $%0d, $%0d, 0x%0x", pc_instr, instr, rs1, rs2, imm_B);
            3'b001: $display("%0x: %h: bne $%0d, $%0d, 0x%0x", pc_instr, instr, rs1, rs2, imm_B);
            3'b100: $display("%0x: %h: blt $%0d, $%0d, 0x%0x", pc_instr, instr, rs1, rs2, imm_B);
            3'b101: $display("%0x: %h: bge $%0d, $%0d, 0x%0x", pc_instr, instr, rs1, rs2, imm_B);
            3'b110: $display("%0x: %h: bltu $%0d, $%0d, 0x%0x", pc_instr, instr, rs1, rs2, imm_B);
            3'b111: $display("%0x: %h: bgeu $%0d, $%0d, 0x%0x", pc_instr, instr, rs1, rs2, imm_B);
            default: $display("Invalid funct3 of op_99: '%b'", funct3);
          endcase
        end
        //103, Type I
        7'b1100111: $display("%0x: %h: jalr $%0d, %0d($%0d)", pc_instr, instr, rd, imm_I, rs1);
        //111, Type J
        7'b1101111: $display("%0x: %h: jal $%0d, 0x%0x", pc_instr, instr, rd, imm_J);
        //115, Type I
        7'b1110011: begin
          case(funct3)
            3'b000: begin
              case(imm_I)
                12'b000000000000: $display("%0x: %h: ecall", pc_instr, instr);
                12'b000000000001: $display("%0x: %h: ebreak", pc_instr, instr);
                12'b000000000010: $display("%0x: %h: uret", pc_instr, instr);
                12'b000100000010: $display("%0x: %h: sret", pc_instr, instr);
                12'b001100000010: $display("%0x: %h: mret", pc_instr, instr);
                default: $display("Invalid funct7 of funct3_000 of op_115: '%b'", funct7);
              endcase
            end
            3'b001: $display("%0x: %h: csrrw $%0d, %0d, $%0d", pc_instr, instr, rd, imm_I, rs1);
            3'b010: $display("%0x: %h: csrrs $%0d, %0d, $%0d", pc_instr, instr, rd, imm_I, rs1);
            3'b011: $display("%0x: %h: csrrc $%0d, %0d, $%0d", pc_instr, instr, rd, imm_I, rs1);
            3'b101: $display("%0x: %h: csrrwi $%0d, %0d, $%0d", pc_instr, instr, rd, imm_I, rs1);
            3'b110: $display("%0x: %h: csrrsi $%0d, %0d, $%0d", pc_instr, instr, rd, imm_I, rs1);
            3'b111: $display("%0x: %h: csrrci $%0d, %0d, $%0d", pc_instr, instr, rd, imm_I, rs1);
            default: $display("Invalid funct3 of op_115: '%b'", funct3);
          endcase
        end
        default: $display("Invalid op: '%b'", op);
      endcase
    end else begin
      IF_ID_ready = 1;
    end
  end
endmodule

module top
#(
  ID_WIDTH = 13,
  ADDR_WIDTH = 64,
  DATA_WIDTH = 64,
  STRB_WIDTH = DATA_WIDTH/8
)
(
  input  clk,
         reset,
         hz32768timer,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  [63:0] entry,
  input  [63:0] stackptr,
  input  [63:0] satp,

  // interface to connect to the bus
  output  wire [ID_WIDTH-1:0]    m_axi_awid,
  output  wire [ADDR_WIDTH-1:0]  m_axi_awaddr, // Write address. The write address gives the address of the first transfer in a write burst transaction.
  output  wire [7:0]             m_axi_awlen,  // Burst length. The burst length gives the exact number of transfers in a burst. This information determines the number of data transfers associated with the address.Burst_Length = AWLEN[7:0] + 1
  output  wire [2:0]             m_axi_awsize, // Burst size. This signal indicates the size of each transfer in the burst.Burst_Size = 2^AWSIZE[2:0]
  output  wire [1:0]             m_axi_awburst,// Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.Burst_Type: "00" = FIXED; "01" = INCR; "10" = WRAP
  output  wire                   m_axi_awlock, // Lock type. Provides additional information about the atomic characteristics of the transfer.Atomic_Access: '0' Normal; '1' Exclusive
  output  wire [3:0]             m_axi_awcache,// Memory type. This signal indicates how transactions are required to progress through a system.Memory_Attributes:□	AWCACHE[0] Bufferable□	AWCACHE[1] Cacheable□	AWCACHE[2] Read-allocate□	AWCACHE[3] Write-allocate
  output  wire [2:0]             m_axi_awprot, // Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.Access_Permissions:□	AWPROT[0] Privileged□	AWPROT[1] Non-secure□	AWPROT[2] Instruction
  output  wire                   m_axi_awvalid,// Write address valid. This signal indicates that the channel is signaling valid write address and control information.
  input   wire                   m_axi_awready,// Write address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
  output  wire [DATA_WIDTH-1:0]  m_axi_wdata,  // Write data.
  output  wire [STRB_WIDTH-1:0]  m_axi_wstrb,  // Write strobes. This signal indicates which byte lanes hold valid data. There is one write strobe bit for each eight bits of the write data bus.
  output  wire                   m_axi_wlast,  // Write last. This signal indicates the last transfer in a write burst.
  output  wire                   m_axi_wvalid, // Write valid. This signal indicates that valid write data and strobes are available.
  input   wire                   m_axi_wready, // Write ready. This signal indicates that the slave can accept the write data.
  input   wire [ID_WIDTH-1:0]    m_axi_bid,
  input   wire [1:0]             m_axi_bresp,  // Write response. This signal indicates the status of the write transaction.Response:□	"00" = OKAY□	"01" = EXOKAY□	"10" = SLVERR□	"11" = DECERR
  input   wire                   m_axi_bvalid, // Write response valid. This signal indicates that the channel is signaling a valid write response.
  output  wire                   m_axi_bready, // Response ready. This signal indicates that the master can accept a write response.
  output  wire [ID_WIDTH-1:0]    m_axi_arid,
  output  wire [ADDR_WIDTH-1:0]  m_axi_araddr, // Read address. The read address gives the address of the first transfer in a read burst transaction.
  output  wire [7:0]             m_axi_arlen,  // Burst length. The burst length gives the exact number of transfers in a burst. This information determines the number of data transfers associated with the address.Burst_Length = ARLEN[7:0] + 1
  output  wire [2:0]             m_axi_arsize, // Burst size. This signal indicates the size of each transfer in the burst.Burst_Size = 2^ARSIZE[2:0]
  output  wire [1:0]             m_axi_arburst,// Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.Burst_Type: "00" = FIXED; "01" = INCR; "10" = WRAP
  output  wire                   m_axi_arlock, // Lock type. Provides additional information about the atomic characteristics of the transfer.Atomic_Access: '0' Normal; '1' Exclusive
  output  wire [3:0]             m_axi_arcache,// Memory type. This signal indicates how transactions are required to progress through a system.Memory_Attributes:□	ARCACHE[0] Bufferable□	ARCACHE[1] Cacheable□	ARCACHE[2] Read-allocate□	ARCACHE[3] Write-allocate
  output  wire [2:0]             m_axi_arprot, // Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.Access_Permissions:□	ARPROT[0] Privileged□	ARPROT[1] Non-secure□	ARPROT[2] Instruction
  output  wire                   m_axi_arvalid,// Read address valid. This signal indicates that the channel is signaling valid read address and control information.
  input   wire                   m_axi_arready,// Read address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
  input   wire [ID_WIDTH-1:0]    m_axi_rid,
  input   wire [DATA_WIDTH-1:0]  m_axi_rdata,  // Read data.
  input   wire [1:0]             m_axi_rresp,  // Read response. This signal indicates the status of the read transfer.Response: "00" = OKAY; "01" = EXOKAY; "10" = SLVERR; “11” = DECERR
  input   wire                   m_axi_rlast,  // Read last. This signal indicates the last transfer in a read burst.
  input   wire                   m_axi_rvalid, // Read valid. This signal indicates that the channel is signaling the required read data.
  output  wire                   m_axi_rready, // Read ready. This signal indicates that the master can accept the read data and response information.
  input   wire                   m_axi_acvalid,
  output  wire                   m_axi_acready,
  input   wire [ADDR_WIDTH-1:0]  m_axi_acaddr,
  input   wire [3:0]             m_axi_acsnoop
);

  logic [63:0] pc;
  logic [63:0] instr2;
  wire [31:0] instr;
  logic [2:0]  step;
  wire IF_ID_ready;
  wire IF_ID_valid;
  
  decoder decoder(
    .clk(clk),
    .instr(instr),
    .IF_ID_valid(IF_ID_valid),
    .IF_ID_ready(IF_ID_ready)
  );

  always_ff @ (posedge clk) begin
    if (reset) begin
        pc <= entry;
        step <= 0;
        m_axi_arid <= 0; 
        m_axi_arlen <= 7;  // Burst_Length = ARLEN[7:0] +1 = 8
        m_axi_arsize <= 0; // Burst_Size = 2^ARSIZE[2:0] = 1
                           // Total bytes= Burst_Length * Burst_Size = 8 bytes = 64 bits
        m_axi_arburst <= 2;// Burst_Type: "00" = FIXED; "01" = INCR; "10" = WRAP
        m_axi_arlock <= 0; // Atomic_Access: '0' Normal; '1' Exclusive
        m_axi_arcache <= 0;// ARCACHE[0] Bufferable, ARCACHE[1] Cacheable, ARCACHE[2] Read-allocate, ARCACHE[3] Write-allocate
        m_axi_arprot <= 6; // ARPROT[0] Privileged, ARPROT[1] Non-secure, ARPROT[2] Instruction
        m_axi_arvalid <= 0;
        m_axi_rready <= 0;
    end else begin
      // PC GEN
      if(step == 0) begin
        if(m_axi_arready) begin
          if (m_axi_arvalid) begin
            m_axi_rready <= 1;
            m_axi_arvalid <= 0;
            step <= 1;
          end else begin
            IF_ID_valid <= 0;
            m_axi_araddr <= pc;
            pc <= pc + 8; // 8 = 64 bits data
            m_axi_arvalid <= 1;
          end
        end
      end 
      // Cache Read
      else if(step == 1) begin
        if (m_axi_rvalid) begin
          instr2 <= m_axi_rdata;
          step <= 2;
          // Finish
          if (m_axi_rdata == 0) begin
            $finish;
          end
        end
      end
      else if(step == 2) begin
        if (m_axi_rlast) begin
          m_axi_rready <= 0;
          step <= 3;
        end
      end
      // Decode
      else if(step == 3) begin
        if(IF_ID_ready) begin
          instr <= instr2[31:0];
          IF_ID_valid <= 1;
          step <= 4;
        end else begin
          IF_ID_valid <= 0;
        end
      end
      else if(step == 4) begin
        // Finish
        if (instr2[63:32] == 0) begin
          $finish;
        end
        if(IF_ID_ready) begin
          instr <= instr2[63:32];
          IF_ID_valid <= 1;
          step <= 0;
        end else begin
          IF_ID_valid <= 0;
        end
      end
    end
  end

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
