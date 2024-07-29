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

//--- AXI Read Data ---
logic fetch_i_d;
wire  read_dirty;
logic [1:0]  step;
logic [2:0]  block_offset;
logic [63:0] write_Data [8];
always_ff @ (posedge clk) begin
  if(step == 0) begin
    if(MEM.miss) begin
      step <= 1;
      fetch_i_d <= 0;
    end else if(IF.miss) begin
      step <= 1;
      fetch_i_d <= 1;
    end
  end
  // Address Read
  else if(step == 1) begin
    if(m_axi_arready) begin
      if(m_axi_arvalid) begin
        m_axi_rready <= 1;
        m_axi_arvalid <= 0;
        block_offset <= 0;
        step <= 2;
      end else begin
        if(fetch_i_d) begin
          m_axi_araddr <= (PCF[63:6] << 6);
        end else begin
          $display("MEM");
          m_axi_araddr <= (ALUResultM[63:6] << 6);
          if(MEM.Dirty[MEM.set][MEM.LRU[MEM.set]]) begin
            write_Data[0] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][0];
            write_Data[1] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][1];
            write_Data[2] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][2];
            write_Data[3] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][3];
            write_Data[4] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][4];
            write_Data[5] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][5];
            write_Data[6] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][6];
            write_Data[7] = MEM.Data[MEM.set][MEM.LRU[MEM.set]][7];
          end
        end
        m_axi_arvalid <= 1;
      end
    end
  end
  // Data Read
  else if(step == 2) begin
    if(m_axi_rvalid) begin
      if(fetch_i_d) begin
        IF.Data[IF.set][IF.LRU[IF.set]][block_offset] <= m_axi_rdata;
      end else begin
        MEM.Data[MEM.set][MEM.LRU[MEM.set]][block_offset] <= m_axi_rdata;
      end
      block_offset <= block_offset + 1;
      if (m_axi_rlast) begin
        m_axi_rready <= 0;
        m_axi_acready <= 1;
        step <= 3;
      end
    end
  end
  // Check Snoop
  else if(step == 3) begin
    if(m_axi_acvalid && (m_axi_acsnoop == 4'hd)) begin
      $display("0: ac 0x%x == ar 0x%x", m_axi_acaddr, m_axi_araddr);
    end else begin
      $display("1: ac 0x%x == ar 0x%x", m_axi_acaddr, m_axi_araddr);
      if(fetch_i_d) begin
        IF.Valid_Tag[IF.set][IF.LRU[IF.set]][50] <= 1;
        IF.Valid_Tag[IF.set][IF.LRU[IF.set]][49:0] <= IF.tag;
        IF.LRU[IF.set] = !IF.LRU[IF.set];
        IF.miss = 0;
      end else begin
        MEM.Valid_Tag[MEM.set][MEM.LRU[MEM.set]][50] <= 1;
        MEM.Valid_Tag[MEM.set][MEM.LRU[MEM.set]][49:0] <= MEM.tag;
        MEM.LRU[MEM.set] = !MEM.LRU[MEM.set];
        if(MEM.Dirty[MEM.set][MEM.LRU[MEM.set]]) begin
          MEM.Dirty[MEM.set][MEM.LRU[MEM.set]] <= 0;
          read_dirty <= 1;
        end else begin
          MEM.miss = 0;
        end
      end
    end
    m_axi_acready <= 0;
    step <= 0;
  end
end

//--- AXI Write Data ---
logic dirty_r_w;
wire  write_dirty;
wire  [1:0]  write_step;
wire  [63:0] write_dirty_Data;
logic [2:0]  write_block_offset;
always_ff @ (posedge clk) begin
  if(write_step == 0) begin
    if(read_dirty) begin
      write_step <= 1;
      dirty_r_w <= 0;
    end else if(write_dirty) begin
      write_step <= 1;
      dirty_r_w <= 1;
    end
  end
  // Address Write
  else if(write_step == 1) begin
    $display("write");
    if(m_axi_awready) begin
      m_axi_awvalid <= 0;
      write_block_offset <= 0;
      write_step <= 2;
    end else begin
      m_axi_awvalid <= 1;
      if(dirty_r_w) begin
        m_axi_awlen <= 0;
        m_axi_awsize <= MemWriteReadSizeM[2:0];
        case(MemWriteReadSizeM[2:0])
          3'b000: m_axi_awaddr <=  ALUResultM[63:0];
          3'b001: m_axi_awaddr <= (ALUResultM[63:1] << 1);
          3'b010: m_axi_awaddr <= (ALUResultM[63:2] << 2);
          3'b011: m_axi_awaddr <= (ALUResultM[63:3] << 3);
        endcase
      end else begin
        m_axi_awlen <= 7;
        m_axi_awsize <= 3;
        m_axi_awaddr <= (ALUResultM[63:6] << 6);
      end
    end
  end
  // Data Write
  else if(write_step == 2) begin
    if(m_axi_wready) begin
      if(dirty_r_w) begin
        m_axi_wdata <= write_dirty_Data;
        m_axi_wvalid <= 1;
        m_axi_wlast <= 1;
        write_dirty <= 0;
        write_step <= 3;
      end else begin
        m_axi_wdata <= write_Data[write_block_offset];
        m_axi_wvalid <= 1;
        write_block_offset <= write_block_offset + 1;
        if(write_block_offset == 8) begin
          m_axi_wlast <= 1;
          read_dirty <= 0;
          MEM.miss = 0;
          write_step <= 3;
        end
      end
    end
  end
  // Done Write
  else if(write_step == 3) begin
    m_axi_wvalid <= 0;
    write_step <= 0;
  end
end

//****** begin ******
wire [63:0] pc;
wire [63:0] PCF;
wire        enable;
wire        enableF;
// hazard
wire  StallF;
// jump & branch
wire        PCSrcE;
wire [63:0] PCTargetE;
always_ff @ (posedge clk) begin
  if(reset) begin
    pc <= entry;
    PCF <= entry;
    enable <= 1;
    // Write
    m_axi_awid <= 0;
    m_axi_awburst <= 1;// Burst_Type: "00" = FIXED; "01" = INCR; "10" = WRAP
    m_axi_awlock <= 0; // Atomic_Access: '0' Normal; '1' Exclusive
    m_axi_awcache <= 0;// ARCACHE[0] Bufferable, ARCACHE[1] Cacheable, ARCACHE[2] Read-allocate, ARCACHE[3] Write-allocate
    m_axi_awprot <= 6; // ARPROT[0] Privileged, ARPROT[1] Non-secure, ARPROT[2] Instruction
    m_axi_wstrb <= 8'b11111111;
    m_axi_awvalid <= 0;
    m_axi_wvalid <= 0;
    m_axi_bready <= 1;
    // Read
    m_axi_arid <= 0; 
    m_axi_arlen <= 7;  // Burst_Length = ARLEN[7:0] +1 = 8
    m_axi_arsize <= 3; // Burst_Size = 2^ARSIZE[2:0] = 8
                       // Total bytes= Burst_Length * Burst_Size = 64 bytes
    m_axi_arburst <= 2;// Burst_Type: "00" = FIXED; "01" = INCR; "10" = WRAP
    m_axi_arlock <= 0; // Atomic_Access: '0' Normal; '1' Exclusive
    m_axi_arcache <= 0;// ARCACHE[0] Bufferable, ARCACHE[1] Cacheable, ARCACHE[2] Read-allocate, ARCACHE[3] Write-allocate
    m_axi_arprot <= 6; // ARPROT[0] Privileged, ARPROT[1] Non-secure, ARPROT[2] Instruction
    m_axi_arvalid <= 0;
    m_axi_rready <= 0;
    m_axi_acready <= 0;
  end else begin
    if(enable) begin
      //@@@ pipe_begin_IF @@@
      if(enableF) begin
        if(!StallF) begin
          if(PCSrcE) begin
            pc <= PCTargetE;
            PCF <= PCTargetE;
            $display();
          end else begin
            pc <= pc + 4; // 4 = 32 bits data
            PCF <= pc + 4;
          end
        end
      end
    end 
  end
end

//****** IF ******
wire [31:0] instrF;
If IF(
  .enable(enable),
  .enableF(enableF),
  .PCF(PCF),
  .instrF(instrF)
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
  if(enableD) begin
    if(!StallD) begin
      instrD <= instrF;
      PCD <= PCF;
      PCPlus4D <= PCF + 4;
    end
    if(FlushD) begin
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
wire [4:0]  MemWriteReadSizeD;
wire        JumpD;
wire        BranchD;
wire [5:0]  ALUControlD;
wire        ALUSrcD;
wire [63:0] ImmExtD;
wire [4:0]  Rs1D;
wire [4:0]  Rs2D;
wire        EcallD;
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
  .MemWriteReadSizeD(MemWriteReadSizeD),
  .JumpD(JumpD),
  .BranchD(BranchD),
  .ALUControlD(ALUControlD),
  .ALUSrcD(ALUSrcD),
  .ImmExtD(ImmExtD),
  .Rs1D(Rs1D),
  .Rs2D(Rs2D),
  .EcallD(EcallD),
  //--- WB ---
  .enableW(enableW),
  .RdW(RdW),
  .RegWriteW(RegWriteW),
  .ResultW(ResultW),
  .EcallW(EcallW)
);

//@@@ pipe_RD_ALU && pipe_WB_end @@@
wire finishE;
//--- hazard ---
wire StallE;
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
wire [4:0]  MemWriteReadSizeE;
wire        JumpE;
wire        BranchE;
wire [5:0]  ALUControlE;
wire        ALUSrcE;
wire [63:0] ImmExtE;
wire [4:0]  Rs1E;
wire [4:0]  Rs2E;
wire        EcallE;
always_ff @ (posedge clk) begin
  //--- pipe_RD_ALU ---
  enableE <= enableD;
  if(enableE) begin
    finishE <= finishD;
    if(!StallE) begin
      //--- control_unit ---
      RegWriteE <= RegWriteD;
      ResultSrcE <= ResultSrcD;
      MemWriteReadSizeE <= MemWriteReadSizeD;
      JumpE <= JumpD;
      BranchE <= BranchD;
      ALUControlE <= ALUControlD;
      ALUSrcE <= ALUSrcD;
      ImmExtE <= ImmExtD;
      Rs1E <= Rs1D;
      Rs2E <= Rs2D;
      EcallE <= EcallD;
      //--- register_file ---
      RD1E <= RD1D;
      RD2E <= RD2D;
      //--- pipe ---
      RdE <= instrD[11:7];
      PCE <= PCD;
      PCPlus4E <= PCPlus4D;
    end

    if(FlushE) begin
      //--- control_unit ---
      RegWriteE <= 0;
      ResultSrcE <= 0;
      MemWriteReadSizeE <= 0;
      JumpE <= 0;
      BranchE <= 0;
      ALUControlE <= 0;
      ALUSrcE <= 0;
      ImmExtE <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      EcallE <= 0;
      //--- register_file ---
      RD1E <= 0;
      RD2E <= 0;
      //--- pipe ---
      RdE <= 0;
      PCE <= 0;
      PCPlus4E <= 0;
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
wire [63:0] ALUResultE;
wire [63:0] WriteDataE;
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
  .WriteDataE(WriteDataE),
  .ALUResultM(ALUResultM),
  // use to print
  .RdE(RdE),
  .Rs2E(Rs2E)
);

//@@@ pipe_ALU_MEM @@@
wire finishM;
//--- hazard ---
wire StallM;
//--- enable ---
wire enableM;
wire        RegWriteM;
wire [1:0]  ResultSrcM;
wire [4:0]  MemWriteReadSizeM;
wire [63:0] WriteDataM;
wire [4:0]  RdM;
wire [63:0] PCPlus4M;
wire        EcallM;
always_ff @ (posedge clk) begin
  enableM <= enableE;
  if(enableM) begin
    finishM <= finishE;
    if(!StallM) begin
      ALUResultM <= ALUResultE;
      //--- pipe ---
      RegWriteM <= RegWriteE;
      ResultSrcM <= ResultSrcE;
      MemWriteReadSizeM <= MemWriteReadSizeE;
      WriteDataM <= WriteDataE;
      RdM <= RdE;
      PCPlus4M <= PCPlus4E;
      EcallM <= EcallE;
    end
  end
end

//****** MEM ******
wire        Stall;
wire [63:0] ReadDataM;
mem MEM(
  .clk(clk),
  .enableM(enableM),
  .MemWriteReadSizeM(MemWriteReadSizeM),
  .ALUResultM(ALUResultM),
  .WriteDataM(WriteDataM),
  .ReadDataM(ReadDataM),
  .Stall(Stall),
  .write_dirty(write_dirty),
  .write_dirty_Data(write_dirty_Data),
  // Write
  .m_axi_awaddr(m_axi_awaddr),
  .m_axi_awvalid(m_axi_awvalid),
  .m_axi_awready(m_axi_awready),
  .m_axi_wdata(m_axi_wdata),
  .m_axi_wstrb(m_axi_wstrb),
  .m_axi_wlast(m_axi_wlast),
  .m_axi_wvalid(m_axi_wvalid),
  .m_axi_wready(m_axi_wready),
  // use to print
  .RdM(RdM),
  .PCPlus4M(PCPlus4M)
);

//@@@ pipe_MEM_WB @@@
wire finishW;
//--- hazard ---
wire StallW;
//--- enable ---
wire enableW;
wire        RegWriteW;
wire [4:0]  RdW;
wire [63:0] ResultW;
wire        EcallW;
always_ff @ (posedge clk) begin
  enableW <= enableM;
  if(enableW) begin
    finishW <= finishM;
    if(!StallW) begin
      case(ResultSrcM)
        2'b00: ResultW <= ALUResultM;
        2'b01: ResultW <= ReadDataM;
        2'b10: ResultW <= PCPlus4M;
      endcase
      //--- pipe ---
      RegWriteW <= RegWriteM;
      RdW <= RdM;
      EcallW <= EcallM;
    end
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
  .Stall(Stall),
  .StallF(StallF),
  .StallD(StallD),
  .StallE(StallE),
  .StallM(StallM),
  .StallW(StallW),
  .FlushD(FlushD),
  .FlushE(FlushE),
  .FrowardAE(FrowardAE),
  .FrowardBE(FrowardBE)
);

initial begin
  $display("Initializing top, entry point = 0x%x", entry);
end
endmodule
