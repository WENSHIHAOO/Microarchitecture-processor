`include "Sysbus.defs"
`include "If.sv"
`include "rd_wb.sv"
`include "alu.sv"
`include "mem.sv"
`include "hazard.sv"

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

//****** begin ******
wire [63:0] pc;
wire [63:0] PCF;
wire        enable;
wire        enableF;
//--- hazard ---
wire  StallF;
always_ff @ (posedge clk) begin
  if(reset) begin
      pc <= entry;
      PCF <= entry;
      enable <= 1;
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
    if(enable) begin
      if(enableF) begin
        if(!StallF) begin
          pc <= pc + 4; // 4 = 32 bits data
          PCF <= pc + 4;
        end
      end
    end 
  end
end

//****** IF ******
wire [31:0] instrF;
If IF(
  .clk(clk),
  .enable(enable),
  .enableF(enableF),
  .PCF(PCF),
  .instrF(instrF),
  .m_axi_arready(m_axi_arready),
  .m_axi_arvalid(m_axi_arvalid),
  .m_axi_araddr(m_axi_araddr),
  .m_axi_rdata(m_axi_rdata),
  .m_axi_rlast(m_axi_rlast),
  .m_axi_rvalid(m_axi_rvalid),
  .m_axi_rready(m_axi_rready)
);

//@@@ pipe_IF_RD @@@
wire  finishD;
//--- hazard ---
wire  StallD;
wire  FlushD;
//--- enable ---
wire  enableD;
//--- pipe ---
wire  [31:0] instrD;
wire  [63:0] PCD;
wire  [63:0] PCPlus4D;
always_ff @ (posedge clk) begin
  enableD <= enableF;
  if(enableF) begin
    if(!StallD) begin
      instrD <= instrF;
      PCD <= PCF;
      PCPlus4D <= PCF + 4;
    end else if(FlushD) begin
      instrD <= 0;
      PCD <= 0;
      PCPlus4D <= 0;
    end
    // Finish
    if(instrF == 0) begin
      finishD <= 1;
      enable <= 0;
    end
  end
end

//****** RD | WB ******
wire [63:0] RD1D;
wire [63:0] RD2D;
wire        RegWriteD;
wire [1:0]  ResultSrcD;
wire        MemWriteD;
wire        JumpD;
wire        BranchD;
wire [5:0]  ALUControlD;
wire        ALUSrcD;
wire [63:0] ImmExtD;
wire [4:0]  Rs1D;
wire [4:0]  Rs2D;
rd_wb RD_WB(
  //--- RD ---
  .clk(clk),
  //--- enable ---
  .enableD(enableD),
  //--- register_file ---
  .RD1D(RD1D),
  .RD2D(RD2D),
  //--- control_unit ---
  .instrD(instrD),
  .RegWriteD(RegWriteD),
  .ResultSrcD(ResultSrcD),
  .MemWriteD(MemWriteD),
  .JumpD(JumpD),
  .BranchD(BranchD),
  .ALUControlD(ALUControlD),
  .ALUSrcD(ALUSrcD),
  .ImmExtD(ImmExtD),
  .Rs1D(Rs1D),
  .Rs2D(Rs2D),
  //--- WB ---
  .enableW(enableW),
  .RdW(RdW),
  .RegWriteW(RegWriteW),
  .ResultW(ResultW)
);

//@@@ pipe_RD_ALU && pipe_WB_end @@@
wire finishE;
//--- hazard ---
wire FlushE;
//--- enable ---
wire enableE;
//--- pipe ---
wire [4:0]  RdE;
wire [63:0] PCE;
wire [63:0] PCPlus4E;
//--- register_file ---
wire [63:0] RD1E;
wire [63:0] RD2E;
//--- control_unit ---
wire        RegWriteE;
wire [1:0]  ResultSrcE;
wire        MemWriteE;
wire        JumpE;
wire        BranchE;
wire [5:0]  ALUControlE;
wire        ALUSrcE;
wire [63:0] ImmExtE;
wire [4:0]  Rs1E;
wire [4:0]  Rs2E;
always_ff @ (posedge clk) begin
  //--- pipe_RD_ALU ---
  enableE <= enableD;
  if(enableD) begin
    finishE <= finishD;
    if(FlushE) begin
      //--- control_unit ---
      RegWriteE <= 0;
      ResultSrcE <= 0;
      MemWriteE <= 0;
      JumpE <= 0;
      BranchE <= 0;
      ALUControlE <= 0;
      ALUSrcE <= 0;
      ImmExtE <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      //--- register_file ---
      RD1E <= 0;
      RD2E <= 0;
      //--- pipe ---
      RdE <= 0;
      PCE <= 0;
      PCPlus4E <= 0;
    end
    else begin
      //--- control_unit ---
      RegWriteE <= RegWriteD;
      ResultSrcE <= ResultSrcD;
      MemWriteE <= MemWriteD;
      JumpE <= JumpD;
      BranchE <= BranchD;
      ALUControlE <= ALUControlD;
      ALUSrcE <= ALUSrcD;
      ImmExtE <= ImmExtD;
      Rs1E <= Rs1D;
      Rs2E <= Rs2D;
      //--- register_file ---
      RD1E <= RD1D;
      RD2E <= RD2D;
      //--- pipe ---
      RdE <= instrD[11:7];
      PCE <= PCD;
      PCPlus4E <= PCPlus4D;
    end
  end

  //--- pipe_WB_end ---
  if(enableW) begin
    //****** Finish ******
    if(finishW) begin
      for(int i=0; i<32; i++) begin
        $display("%2.2d:  0x%x (%0d)", i, RD_WB.registers[i], RD_WB.registers[i]);
      end
      $finish;
    end
  end
end

//****** ALU ******
wire [1:0]  FrowardAE;
wire [1:0]  FrowardBE;
wire        PCSrcE;
wire [63:0] PCTargetE;
wire [63:0] ALUResultE;
wire [63:0] ALUResultM;
alu ALU(
  //--- hazard ---
  .FrowardAE(FrowardAE),
  .FrowardBE(FrowardBE),
  .ResultW(ResultW),
  //--- ALU ---
  .enableE(enableE),
  .RD1E(RD1E),
  .RD2E(RD2E),
  .PCE(PCE),
  .ALUControlE(ALUControlE),
  .ALUSrcE(ALUSrcE),
  .ImmExtE(ImmExtE),
  .JumpE(JumpE),
  .BranchE(BranchE),
  .PCSrcE(PCSrcE),
  .PCTargetE(PCTargetE),
  .ALUResultE(ALUResultE),
  .ALUResultM(ALUResultM)
);

//@@@ pipe_ALU_MEM @@@
wire enableM;
wire finishM;
wire        RegWriteM;
wire [1:0]  ResultSrcM;
wire        MemWriteM;
wire [63:0] WriteDataM;
wire [4:0]  RdM;
wire [63:0] PCPlus4M;
always_ff @ (posedge clk) begin
  enableM <= enableE;
  if(enableE) begin
    finishM <= finishE;
    ALUResultM <= ALUResultE;
    //--- pipe ---
    RegWriteM <= RegWriteE;
    ResultSrcM <= ResultSrcE;
    MemWriteM <= MemWriteE;
    WriteDataM <= RD2E;
    RdM <= RdE;
    PCPlus4M <= PCPlus4E;
  end
end

//****** MEM ******
wire [63:0] ReadDataM;
mem MEM(
  .enableM(enableM),
  .MemWriteM(MemWriteM),
  .ALUResultM(ALUResultM),
  .WriteDataM(WriteDataM),
  .ReadDataM(ReadDataM)
);

//@@@ pipe_MEM_WB @@@
wire enableW;
wire finishW;
wire        RegWriteW;
wire [4:0]  RdW;
wire [63:0] ResultW;
always_ff @ (posedge clk) begin
  enableW <= enableM;
  if(enableM) begin
    finishW <= finishM;
    case(ResultSrcM)
      2'b00: ResultW <= ALUResultM;
      2'b01: ResultW <= ReadDataM;
      2'b10: ResultW <= PCPlus4M;
    endcase
    //--- pipe ---
    RegWriteW <= RegWriteM;
    RdW <= RdM;
  end
end

//****** Hazard_Unit ******
hazard Hazard(
  .Rs1D(Rs1D),
  .Rs2D(Rs2D),
  .Rs1E(Rs1E),
  .Rs2E(Rs2E),
  .RdE(RdE),
  .PCSrcE(PCSrcE),
  .ResultSrcE0(ResultSrcE[0]),
  .RdM(RdM),
  .RegWriteM(RegWriteM),
  .RdW(RdW),
  .RegWriteW(RegWriteW),
  .StallF(StallF),
  .StallD(StallD),
  .FlushD(FlushD),
  .FlushE(FlushE),
  .FrowardAE(FrowardAE),
  .FrowardBE(FrowardBE)
);

initial begin
  $display("Initializing top, entry point = 0x%x", entry);
end
endmodule
