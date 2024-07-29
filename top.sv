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
localparam C = 16 * 1024;                // Cache size (bytes), not including overhead such as the valid, tag, LRU, and dirty bits
localparam N = 2;                        // Number of ways per set
localparam B = 8;                        // Block size (bytes)
localparam S = 1024; //C/(N*B)           // Number of sets
localparam s = 10;   //log2(S)           // Number of set index bits
localparam b = 3;    //log2(B)           // Number of block offset bits
localparam y = 3;                        // Number of byte offset bits
localparam t = ADDR_WIDTH - (s + b + y); // Number of tag bits
//--- AXI Read Data ---
wire  IF_miss;
wire  MEM_miss1;
wire  MEM_miss2;
wire  [63:0]  IF_addr;
wire  [63:0]  MEM_addr1;
wire  [63:0]  MEM_addr2;
wire  [63:0]  Hazard_addr1;
wire  [63:0]  Hazard_addr2;
wire          MEM_Write1;
wire  [2:0]   MEM_Size1;
wire  [63:0]  MEM_Data1;
wire          MEM_Write2;
wire  [2:0]   MEM_Size2;
wire  [63:0]  MEM_Data2;
logic [1:0]   fetch_i_d;
logic [1:0]   step;
logic [t-1:0] tag;
logic [s-1:0] set;
logic [b+y-1:0] block_y;
logic [2:0]   block_offset;
logic [63:0]  write_addr;
logic [63:0]  write_Data [B];
always_ff @ (posedge clk) begin
  if(step==0 & !reset & m_axi_arready) begin
    if(MEM_miss1) begin
      fetch_i_d <= 1;
      tag <= MEM_addr1[63     :s+b+y];
      set <= MEM_addr1[s+b+y-1:b+y];
      block_y <= MEM_addr1[b+y-1:0];
      m_axi_araddr <= (MEM_addr1[63:b+y] << (b+y));
      m_axi_arvalid <= 1;
      m_axi_rready <= 1;
      step <= 1;
    end else if(MEM_miss2) begin
      fetch_i_d <= 2;
      tag <= MEM_addr2[63     :s+b+y];
      set <= MEM_addr2[s+b+y-1:b+y];
      block_y <= MEM_addr2[b+y-1:0];
      m_axi_araddr <= (MEM_addr2[63:b+y] << (b+y));
      m_axi_arvalid <= 1;
      m_axi_rready <= 1;
      step <= 1;
    end else if(IF_miss) begin
      fetch_i_d <= 3;
      tag <= IF_addr[63     :s+b+y];
      set <= IF_addr[s+b+y-1:b+y];
      m_axi_araddr <= (IF_addr[63:b+y] << (b+y));
      m_axi_arvalid <= 1;
      m_axi_rready <= 1;
      step <= 1;
    end
  end
  // Data Read
  else if(step == 1) begin
    m_axi_arvalid <= 0;
    if(m_axi_rvalid) begin
      case (fetch_i_d)
        1, 2: begin
          if((block_offset==0) & MEM.Dirty[set][MEM.LRU[set]]) begin
            write_addr <= {{MEM.Valid_Tag[set][MEM.LRU[set]][t-1:0],set} << (b+y)};
            write_Data[0] <= MEM.Data[set][MEM.LRU[set]][0];
            write_Data[1] <= MEM.Data[set][MEM.LRU[set]][1];
            write_Data[2] <= MEM.Data[set][MEM.LRU[set]][2];
            write_Data[3] <= MEM.Data[set][MEM.LRU[set]][3];
            write_Data[4] <= MEM.Data[set][MEM.LRU[set]][4];
            write_Data[5] <= MEM.Data[set][MEM.LRU[set]][5];
            write_Data[6] <= MEM.Data[set][MEM.LRU[set]][6];
            write_Data[7] <= MEM.Data[set][MEM.LRU[set]][7];
          end
          MEM.Data[set][MEM.LRU[set]][block_offset] <= m_axi_rdata;
          $display("Read MEM%d: araddr:%0x, data:%0x", fetch_i_d, m_axi_araddr, m_axi_rdata);
        end
        3: begin
          IF.Data[set][IF.LRU[set]][block_offset] <= m_axi_rdata;
          $display("Read IF: araddr:%0x, data:%0x", m_axi_araddr, m_axi_rdata);
        end
      endcase
      block_offset <= block_offset + 1;
      if (m_axi_rlast) begin
        m_axi_rready <= 0;
        m_axi_acready <= 1;
        step <= 2;
      end
    end
  end
  // Check Snoop
  else if(step == 2) begin
    if(m_axi_acvalid && (m_axi_acsnoop == 4'hd)) begin
      $display("0: ac 0x%x == ar 0x%x", m_axi_acaddr, m_axi_araddr);
      if(IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t] & (IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t-1:0] == m_axi_acaddr[63 : s+b+y])) begin
        IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t] <= 0;
        $display("IF:acaddr0: %0x; 0: %0x; 1: %0x", m_axi_acaddr[63 : s+b+y], IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t-1:0], IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t-1:0]);
      end else if(IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t] & (IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t-1:0] == m_axi_acaddr[63 : s+b+y])) begin
        IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t] <= 0;
        $display("IF:acaddr1: %0x; 0: %0x; 1: %0x", m_axi_acaddr[63 : s+b+y], IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t-1:0], IF.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t-1:0]);
      end
      if(MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t] & (MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t-1:0] == m_axi_acaddr[63 : s+b+y])) begin
        MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t] <= 0;
        MEM.Dirty[m_axi_acaddr[s+b+y-1 : b+y]][0] <= 0;
        $display("MEM:acaddr0: %0x; 0: %0x; 1: %0x", m_axi_acaddr[63 : s+b+y], MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t-1:0], MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t-1:0]);
      end else if(MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t] & (MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t-1:0] == m_axi_acaddr[63 : s+b+y])) begin
        MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t] <= 0;
        MEM.Dirty[m_axi_acaddr[s+b+y-1 : b+y]][1] <= 0;
        $display("MEM:acaddr1: %0x; 0: %0x; 1: %0x", m_axi_acaddr[63 : s+b+y], MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][0][t-1:0], MEM.Valid_Tag[m_axi_acaddr[s+b+y-1 : b+y]][1][t-1:0]);
      end
    end else begin
      $display("1: ac 0x%x == ar 0x%x", m_axi_acaddr, m_axi_araddr);
      case (fetch_i_d)
        1, 2: begin
          if(MEM.Dirty[set][MEM.LRU[set]]) begin
            // AXI Write Data
            write_step <= 1;
          end
          if(fetch_i_d == 1) begin
            MEM_miss1 = 0;
            if(MEM_Write1) begin
              MEM_Write1 = 0;
              case(MEM_Size1)
                3'b000: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]][8*block_y[2:0]+:8]   <= MEM_Data1; // sb
                  do_pending_write({tag, set, block_y}, MEM_Data1, 1);
                end
                3'b001: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]][16*block_y[2:1]+:16] <= MEM_Data1; // sh
                  do_pending_write({tag, set, block_y[5:1], 1'b0}, MEM_Data1, 2);
                end
                3'b010: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]][32*block_y[2]+:32]   <= MEM_Data1; // sw
                  do_pending_write({tag, set, block_y[5:2], 2'b00}, MEM_Data1, 4);
                end
                3'b011: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]]                      <= MEM_Data1; // sd
                  do_pending_write({tag, set, block_y[5:3], 3'b000}, MEM_Data1, 8);
                end
              endcase
              MEM.Dirty[set][MEM.LRU[set]] <= 1;
            end else MEM.Dirty[set][MEM.LRU[set]] <= 0;
            // hazard
            if(MEM_miss2 & ((Hazard_addr2[63:b+y]<<(b+y))==m_axi_araddr)) begin
              if(MEM_Write2) begin
                MEM_Write2 = 0;
                case(MEM_Size2)
                  3'b000: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr2[b+y-1:y]][8*Hazard_addr2[2:0]+:8]   <= MEM_Data2; // sb
                    do_pending_write(Hazard_addr2, MEM_Data2, 1);
                  end
                  3'b001: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr2[b+y-1:y]][16*Hazard_addr2[2:1]+:16] <= MEM_Data2; // sh
                    do_pending_write({Hazard_addr2[63:1], 1'b0}, MEM_Data2, 2);
                  end
                  3'b010: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr2[b+y-1:y]][32*Hazard_addr2[2]+:32]   <= MEM_Data2; // sw
                    do_pending_write({Hazard_addr2[63:2], 2'b00}, MEM_Data2, 4);
                  end
                  3'b011: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr2[b+y-1:y]]                           <= MEM_Data2; // sd
                    do_pending_write({Hazard_addr2[63:3], 3'b000}, MEM_Data2, 8);
                  end
                endcase
                MEM.Dirty[set][MEM.LRU[set]] <= 1;
              end else MEM.Dirty[set][MEM.LRU[set]] <= 0;
              MEM_miss2 = 0;
              Stall_miss2 = 0;
            end
          end else begin
            MEM_miss2 = 0;
            if(MEM_Write2) begin
              MEM_Write2 = 0;
              case(MEM_Size2)
                3'b000: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]][8*block_y[2:0]+:8]   <= MEM_Data2; // sb
                  do_pending_write({tag, set, block_y}, MEM_Data2, 1);
                end
                3'b001: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]][16*block_y[2:1]+:16] <= MEM_Data2; // sh
                  do_pending_write({tag, set, block_y[5:1], 1'b0}, MEM_Data2, 2);
                end
                3'b010: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]][32*block_y[2]+:32]   <= MEM_Data2; // sw
                  do_pending_write({tag, set, block_y[5:2], 2'b00}, MEM_Data2, 4);
                end
                3'b011: begin
                  MEM.Data[set][MEM.LRU[set]][block_y[b+y-1:y]]                      <= MEM_Data2; // sd
                  do_pending_write({tag, set, block_y[5:3], 3'b000}, MEM_Data2, 8);
                end
              endcase
              MEM.Dirty[set][MEM.LRU[set]] <= 1;
            end else MEM.Dirty[set][MEM.LRU[set]] <= 0;
            // hazard
            if(MEM_miss1 & ((Hazard_addr1[63:b+y]<<(b+y))==m_axi_araddr)) begin
              if(MEM_Write1) begin
                MEM_Write1 = 0;
                case(MEM_Size1)
                  3'b000: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr1[b+y-1:y]][8*Hazard_addr1[2:0]+:8]   <= MEM_Data1; // sb
                    do_pending_write(Hazard_addr1, MEM_Data1, 1);
                  end
                  3'b001: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr1[b+y-1:y]][16*Hazard_addr1[2:1]+:16] <= MEM_Data1; // sh
                    do_pending_write({Hazard_addr1[63:1], 1'b0}, MEM_Data1, 2);
                  end
                  3'b010: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr1[b+y-1:y]][32*Hazard_addr1[2]+:32]   <= MEM_Data1; // sw
                    do_pending_write({Hazard_addr1[63:2], 2'b00}, MEM_Data1, 4);
                  end
                  3'b011: begin
                    MEM.Data[set][MEM.LRU[set]][Hazard_addr1[b+y-1:y]]                           <= MEM_Data1; // sd
                    do_pending_write({Hazard_addr1[63:3], 3'b000}, MEM_Data1, 8);
                  end
                endcase
                MEM.Dirty[set][MEM.LRU[set]] <= 1;
              end else MEM.Dirty[set][MEM.LRU[set]] <= 0;
              MEM_miss1 = 0;
              Stall_miss1 = 0;
            end
          end
          MEM.Valid_Tag[set][MEM.LRU[set]][t] <= 1;
          MEM.Valid_Tag[set][MEM.LRU[set]][t-1:0] <= tag;
          MEM.LRU[set] = !MEM.LRU[set];
        end
        3: begin
          IF.Valid_Tag[set][IF.LRU[set]][t] <= 1;
          IF.Valid_Tag[set][IF.LRU[set]][t-1:0] <= tag;
          IF.LRU[set] = !IF.LRU[set];
          //IF_miss = 0;
        end
      endcase
      block_offset <= 0;
      m_axi_acready <= 0;
      step <= 0;
    end
  end
end

//--- AXI Write Data ---
wire  [1:0]  write_step;
logic [2:0]  write_block_offset;
always_ff @ (posedge clk) begin
  // Address Write
  if(write_step == 1) begin
    if(m_axi_awready) begin
      m_axi_wlast <= 0;
      m_axi_awaddr <= write_addr;
      m_axi_awvalid <= 1;
      write_step <= 2;
    end
  end
  // Data Write
  else if(write_step == 2) begin
    if(m_axi_wready) begin
      $display("Write: awaddr:%0x, data:%0x", m_axi_awaddr, write_Data[write_block_offset]);
      m_axi_awvalid <= 0;
      m_axi_wdata <= write_Data[write_block_offset];
      m_axi_wvalid <= 1;
      write_block_offset <= write_block_offset + 1;
      if(write_block_offset == 7) begin
        m_axi_wlast <= 1;
        write_step <= 3;
      end
    end
  end
  // Done Write
  else if(write_step == 3) begin
    write_block_offset <= 0;
    m_axi_wvalid <= 0;
    write_step <= 0;
  end
end

//****** begin ******
wire [63:0] pc;
wire        pc8;
// Superscalar 1
wire [63:0] PCF1;
// Superscalar 2
wire [63:0] PCF2;
wire        enable;
wire        enableF;
// hazard
wire  StallF;
// jump & branch
wire        j_b;
wire        PCSrcE;
wire [63:0] PCTargetE;
always_ff @ (posedge clk) begin
  if(reset) begin
    RD_WB.registers[2] = stackptr;
    enable <= 1;
    pc = entry;
    // Superscalar 1
    PCF1 <= entry;
    // Superscalar 2
    PCF2 <= entry + 4;
    // Write
    m_axi_awid <= 0;
    m_axi_awlen <= 7;  // Burst_Length = ARLEN[7:0] +1 = 8
    m_axi_awsize <= 3; // Burst_Size = 2^ARSIZE[2:0] = 8
                       // Total bytes= Burst_Length * Burst_Size = 64 bytes
    m_axi_awburst <= 1;// Burst_Type: "00" = FIXED; "01" = INCR; "10" = WRAP
    m_axi_awlock <= 0; // Atomic_Access: '0' Normal; '1' Exclusive
    m_axi_awcache <= 0;// ARCACHE[0] Bufferable, ARCACHE[1] Cacheable, ARCACHE[2] Read-allocate, ARCACHE[3] Write-allocate
    m_axi_awprot <= 6; // ARPROT[0] Privileged, ARPROT[1] Non-secure, ARPROT[2] Instruction
    m_axi_wstrb <= 8'b11111111;
    m_axi_awvalid <= 0;
    m_axi_wvalid <= 0;
    m_axi_bready <= 1;
    // Read
    m_axi_arid <= 1; 
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
      if(PCSrcE & (PCTargetE > 0)) begin
        $display();
        if(enableF & !StallF) j_b = 1;
        pc = PCTargetE;
        // Superscalar 1
        PCF1 <= pc;
        // Superscalar 2
        PCF2 <= pc + 4;
      end
      //@@@ pipe_begin_IF @@@
      if(enableF) begin
        if(!StallF) begin
          if(j_b) begin
            j_b = 0;
          end else begin
            if(pc8) begin
              pc = pc + 8; // 8 bytes = 64 bits data
            end else begin
              pc = pc + 4; // 4 bytes = 32 bits data
            end
            // Superscalar 1
            PCF1 <= pc;
            // Superscalar 2
            PCF2 <= pc + 4;
          end
        end
      end
    end 
  end
end

//****** IF ******
// Superscalar 1
wire [31:0] instrF1;
// Superscalar 2
wire [31:0] instrF2;
If #(.N(N),
     .B(B),
     .S(S),
     .s(s),
     .b(b),
     .y(y),
     .t(t)
)IF(
  .clk(clk),
  .enable(enable),
  .enableF(enableF),
  .IF_miss(IF_miss),
  .pc8(pc8),
  .IF_addr(IF_addr),
  // Superscalar 1
  .PCF1(PCF1),
  .instrF1(instrF1),
  // Superscalar 2
  .PCF2(PCF2),
  .instrF2(instrF2)
);

//@@@ pipe_IF_RD @@@
wire  JumpD;
wire  BranchD;
wire  finishD;
//--- hazard ---
wire  StallD;
wire  FlushD;
//--- enable ---
wire  enableD;
//--- pipe ---
// Superscalar 1
wire  [31:0] instrD1;
wire  [63:0] PCD1;
wire  [63:0] PCPlus4D1;
// Superscalar 2
wire  [31:0] instrD2;
wire  [63:0] PCD2;
wire  [63:0] PCPlus4D2;
// use to print
wire  [63:0] num_clk;
always_ff @ (posedge clk) begin
  if(!StallD) enableD <= enableF;
  if(FlushD) begin
    JumpD = 0;
    BranchD = 0;
    // Superscalar 1
    instrD1 <= 0;
    PCD1 <= 0;
    PCPlus4D1 <= 0;
    // Superscalar 2
    instrD2 <= 0;
    PCD2 <= 0;
    PCPlus4D2 <= 0;
  end else if(enableF) begin
    if(!FlushD & !StallD) begin
      JumpD = 0;
      BranchD = 0;
      // Superscalar 1
      instrD1 <= instrF1;
      PCD1 <= PCF1;
      PCPlus4D1 <= PCF1 + 4;
      // Superscalar 2
      instrD2 <= instrF2;
      PCD2 <= PCF2;
      PCPlus4D2 <= PCF2 + 4;
    end
    // Finish
    if(instrF1 == 0) begin
      finishD <= 1;
      enable <= 0;
    end
  end
  // use to print
  num_clk <= num_clk+1;
end

//****** RD | WB ******
// Superscalar 1
wire [63:0] RD1D1;
wire [63:0] RD2D1;
wire        RegWriteD1;
wire [1:0]  ResultSrcD1;
wire [4:0]  MemWriteReadSizeD1;
wire [5:0]  ALUControlD1;
wire        ALUSrcD1;
wire [63:0] ImmExtD1;
wire [4:0]  Rs1D1;
wire [4:0]  Rs2D1;
wire [4:0]  RdD1;
wire        EcallD1;
// Superscalar 2
wire [63:0] RD1D2;
wire [63:0] RD2D2;
wire        RegWriteD2;
wire [1:0]  ResultSrcD2;
wire [4:0]  MemWriteReadSizeD2;
wire [5:0]  ALUControlD2;
wire        ALUSrcD2;
wire [63:0] ImmExtD2;
wire [4:0]  Rs1D2;
wire [4:0]  Rs2D2;
wire [4:0]  RdD2;
wire        EcallD2;
rd_wb RD_WB(
  //****** RD ******
  //--- enable ---
  .enableD(enableD),
  .JumpD(JumpD),
  .BranchD(BranchD),
  // Superscalar 1
  //--- register_file ---
  .RD1D1(RD1D1),
  .RD2D1(RD2D1),
  //--- control_unit ---
  .instrD1(instrD1),
  .RegWriteD1(RegWriteD1),
  .ResultSrcD1(ResultSrcD1),
  .MemWriteReadSizeD1(MemWriteReadSizeD1),
  .ALUControlD1(ALUControlD1),
  .ALUSrcD1(ALUSrcD1),
  .ImmExtD1(ImmExtD1),
  .Rs1D1(Rs1D1),
  .Rs2D1(Rs2D1),
  .RdD1(RdD1),
  .EcallD1(EcallD1),
  // Superscalar 2
  //--- register_file ---
  .RD1D2(RD1D2),
  .RD2D2(RD2D2),
  //--- control_unit ---
  .instrD2(instrD2),
  .RegWriteD2(RegWriteD2),
  .ResultSrcD2(ResultSrcD2),
  .MemWriteReadSizeD2(MemWriteReadSizeD2),
  .ALUControlD2(ALUControlD2),
  .ALUSrcD2(ALUSrcD2),
  .ImmExtD2(ImmExtD2),
  .Rs1D2(Rs1D2),
  .Rs2D2(Rs2D2),
  .RdD2(RdD2),
  .EcallD2(EcallD2),
  //****** WB ******
  .enableW(enableW),
  // Superscalar 1
  .RdW1(RdW1),
  .RegWriteW1(RegWriteW1),
  .ResultW1(ResultW1),
  .EcallW1(EcallW1),
  // Superscalar 2
  .RdW2(RdW2),
  .RegWriteW2(RegWriteW2),
  .ResultW2(ResultW2),
  .EcallW2(EcallW2),
  // use to print
  .PCD1(PCD1),
  .PCD2(PCD2),
  .num_clk(num_clk)
);

//@@@ pipe_RD_ALU && pipe_WB_end @@@
wire finishE;
//--- hazard ---
wire StallE;
wire FlushE;
//--- enable ---
wire enableE;
wire JumpE;
wire BranchE;
// Superscalar 1
//--- pipe ---
wire [4:0]  RdE1;
wire [63:0] PCE1;
wire [63:0] PCPlus4E1;
//--- register_file ---
wire [63:0] RD1E1;
wire [63:0] RD2E1;
//--- control_unit ---
wire        RegWriteE1;
wire [1:0]  ResultSrcE1;
wire [4:0]  MemWriteReadSizeE1;
wire [5:0]  ALUControlE1;
wire        ALUSrcE1;
wire [63:0] ImmExtE1;
wire [4:0]  Rs1E1;
wire [4:0]  Rs2E1;
wire        EcallE1;
// Superscalar 2
//--- pipe ---
wire [4:0]  RdE2;
wire [63:0] PCE2;
wire [63:0] PCPlus4E2;
//--- register_file ---
wire [63:0] RD1E2;
wire [63:0] RD2E2;
//--- control_unit ---
wire        RegWriteE2;
wire [1:0]  ResultSrcE2;
wire [4:0]  MemWriteReadSizeE2;
wire [5:0]  ALUControlE2;
wire        ALUSrcE2;
wire [63:0] ImmExtE2;
wire [4:0]  Rs1E2;
wire [4:0]  Rs2E2;
wire        EcallE2;
// use to print
wire [31:0] instrE1;
wire [31:0] instrE2;
always_ff @ (posedge clk) begin
  //--- pipe_RD_ALU ---
  if(!StallE) enableE <= enableD;
  if(FlushE) begin
    JumpE <= 0;
    BranchE <= 0;
    // Superscalar 1
    //--- control_unit ---
    RegWriteE1 <= 0;
    ResultSrcE1 <= 0;
    MemWriteReadSizeE1 <= 0;
    ALUControlE1 <= 0;
    ALUSrcE1 <= 0;
    ImmExtE1 <= 0;
    Rs1E1 <= 0;
    Rs2E1 <= 0;
    EcallE1 <= 0;
    //--- register_file ---
    RD1E1 <= 0;
    RD2E1 <= 0;
    //--- pipe ---
    RdE1 <= 0;
    PCE1 <= 0;
    PCPlus4E1 <= 0;
    // Superscalar 2
    //--- control_unit ---
    RegWriteE2 <= 0;
    ResultSrcE2 <= 0;
    MemWriteReadSizeE2 <= 0;
    ALUControlE2 <= 0;
    ALUSrcE2 <= 0;
    ImmExtE2 <= 0;
    Rs1E2 <= 0;
    Rs2E2 <= 0;
    EcallE2 <= 0;
    //--- register_file ---
    RD1E2 <= 0;
    RD2E2 <= 0;
    //--- pipe ---
    RdE2 <= 0;
    PCE2 <= 0;
    PCPlus4E2 <= 0;
    // use to print
    instrE1 <= 0;
    instrE2 <= 0;
  end else if(enableD) begin
    if(!FlushE & !StallE) begin
      finishE <= finishD;
      JumpE <= JumpD;
      BranchE <= BranchD;
      // Superscalar 1
      //--- control_unit ---
      RegWriteE1 <= RegWriteD1;
      ResultSrcE1 <= ResultSrcD1;
      MemWriteReadSizeE1 <= MemWriteReadSizeD1;
      ALUControlE1 <= ALUControlD1;
      ALUSrcE1 <= ALUSrcD1;
      ImmExtE1 <= ImmExtD1;
      Rs1E1 <= Rs1D1;
      Rs2E1 <= Rs2D1;
      EcallE1 <= EcallD1;
      //--- register_file ---
      RD1E1 <= RD1D1;
      RD2E1 <= RD2D1;
      //--- pipe ---
      RdE1 <= RdD1;
      PCE1 <= PCD1;
      PCPlus4E1 <= PCPlus4D1;
      // Superscalar 2
      //--- control_unit ---
      RegWriteE2 <= RegWriteD2;
      ResultSrcE2 <= ResultSrcD2;
      MemWriteReadSizeE2 <= MemWriteReadSizeD2;
      ALUControlE2 <= ALUControlD2;
      ALUSrcE2 <= ALUSrcD2;
      ImmExtE2 <= ImmExtD2;
      Rs1E2 <= Rs1D2;
      Rs2E2 <= Rs2D2;
      EcallE2 <= EcallD2;
      //--- register_file ---
      RD1E2 <= RD1D2;
      RD2E2 <= RD2D2;
      //--- pipe ---
      RdE2 <= RdD2;
      PCE2 <= PCD2;
      PCPlus4E2 <= PCPlus4D2;
      // use to print
      instrE1 <= instrD1;
      instrE2 <= instrD2;
    end
  end

  //--- pipe_WB_end ---
  if(enableW) begin
    if(!StallW) begin
      if(RdW1==10 | RdW2==10) begin
          for(int i=0; i<32; i++) begin
              $display("%2.2d:  0x%x (%0d)", i, RD_WB.registers[i], RD_WB.registers[i]);
          end
      end
    end
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
// Superscalar 1
wire [2:0]  FrowardAE1;
wire [2:0]  FrowardBE1;
wire [63:0] ALUResultE1;
wire [63:0] WriteDataE1;
wire [63:0] ALUResultM1;
// Superscalar 2
wire [2:0]  FrowardAE2;
wire [2:0]  FrowardBE2;
wire [63:0] ALUResultE2;
wire [63:0] WriteDataE2;
wire [63:0] ALUResultM2;
alu ALU(
  .enableE(enableE),
  .PCSrcE(PCSrcE),
  .PCTargetE(PCTargetE),
  .JumpE(JumpE),
  .BranchE(BranchE),
  // Superscalar 1
  //--- hazard ---
  .FrowardAE1(FrowardAE1),
  .FrowardBE1(FrowardBE1),
  .ResultW1(ResultW1),
  //--- ALU ---
  .RD1E1(RD1E1),
  .RD2E1(RD2E1),
  .PCE1(PCE1),
  .ALUControlE1(ALUControlE1),
  .ALUSrcE1(ALUSrcE1),
  .ImmExtE1(ImmExtE1),
  .ALUResultE1(ALUResultE1),
  .WriteDataE1(WriteDataE1),
  .ALUResultM1(ALUResultM1),
  // use to print
  .RdE1(RdE1),
  .Rs2E1(Rs2E1),
  // Superscalar 2
  //--- hazard ---
  .FrowardAE2(FrowardAE2),
  .FrowardBE2(FrowardBE2),
  .ResultW2(ResultW2),
  //--- ALU ---
  .RD1E2(RD1E2),
  .RD2E2(RD2E2),
  .PCE2(PCE2),
  .ALUControlE2(ALUControlE2),
  .ALUSrcE2(ALUSrcE2),
  .ImmExtE2(ImmExtE2),
  .ALUResultE2(ALUResultE2),
  .WriteDataE2(WriteDataE2),
  .ALUResultM2(ALUResultM2),
  // use to print
  .RdE2(RdE2),
  .Rs2E2(Rs2E2),
  .instrE1(instrE1),
  .instrE2(instrE2)
);

//@@@ pipe_ALU_MEM @@@
wire finishM;
//--- hazard ---
wire StallM;
//--- enable ---
wire enableM;
// Superscalar 1
wire        RegWriteM1;
wire [1:0]  ResultSrcM1;
wire [4:0]  MemWriteReadSizeM1;
wire [63:0] WriteDataM1;
wire [4:0]  RdM1;
wire [63:0] PCPlus4M1;
wire        EcallM1;
// Superscalar 2
wire        RegWriteM2;
wire [1:0]  ResultSrcM2;
wire [4:0]  MemWriteReadSizeM2;
wire [63:0] WriteDataM2;
wire [4:0]  RdM2;
wire [63:0] PCPlus4M2;
wire        EcallM2;
always_ff @ (posedge clk) begin
  if(!StallM) enableM <= enableE;
  if(enableE) begin
    if(!StallM) begin
      finishM <= finishE;
      // Superscalar 1
      ALUResultM1 = ALUResultE1;
      //--- pipe ---
      RegWriteM1 <= RegWriteE1;
      ResultSrcM1 <= ResultSrcE1;
      MemWriteReadSizeM1 <= MemWriteReadSizeE1;
      WriteDataM1 = WriteDataE1;
      RdM1 <= RdE1;
      PCPlus4M1 <= PCPlus4E1;
      EcallM1 <= EcallE1;
      // Superscalar 2
      ALUResultM2 = ALUResultE2;
      //--- pipe ---
      RegWriteM2 <= RegWriteE2;
      ResultSrcM2 <= ResultSrcE2;
      MemWriteReadSizeM2 <= MemWriteReadSizeE2;
      WriteDataM2 = WriteDataE2;
      RdM2 <= RdE2;
      PCPlus4M2 <= PCPlus4E2;
      EcallM2 <= EcallE2;
    end
  end
end

//****** MEM ******
wire        Stall_miss1;
wire        Stall_miss2;
// Superscalar 1
wire [63:0] ReadDataM1;
// Superscalar 2
wire [63:0] ReadDataM2;
mem #(.N(N),
      .B(B),
      .S(S),
      .s(s),
      .b(b),
      .y(y),
      .t(t)
)MEM(
  .clk(clk),
  .enableM(enableM),
  .Stall_miss1(Stall_miss1),
  .Stall_miss2(Stall_miss2),
  .MEM_miss1(MEM_miss1),
  .MEM_miss2(MEM_miss2),
  .MEM_addr1(MEM_addr1),
  .MEM_addr2(MEM_addr2),
  .Hazard_addr1(Hazard_addr1),
  .Hazard_addr2(Hazard_addr2),
  .MEM_Write1(MEM_Write1),
  .MEM_Size1(MEM_Size1),
  .MEM_Data1(MEM_Data1),
  .MEM_Write2(MEM_Write2),
  .MEM_Size2(MEM_Size2),
  .MEM_Data2(MEM_Data2),
  // Superscalar 1
  .MemWriteReadSizeM1(MemWriteReadSizeM1),
  .ALUResultM1(ALUResultM1),
  .WriteDataM1(WriteDataM1),
  .ReadDataM1(ReadDataM1),
  // use to print
  .RdM1(RdM1),
  .PCPlus4M1(PCPlus4M1),
  // Superscalar 2
  .MemWriteReadSizeM2(MemWriteReadSizeM2),
  .ALUResultM2(ALUResultM2),
  .WriteDataM2(WriteDataM2),
  .ReadDataM2(ReadDataM2),
  // use to print
  .RdM2(RdM2),
  .PCPlus4M2(PCPlus4M2)
);

//@@@ pipe_MEM_WB @@@
wire finishW;
//--- hazard ---
wire StallW;
//--- enable ---
wire enableW;
// Superscalar 1
wire        RegWriteW1;
wire [4:0]  RdW1;
wire [63:0] ResultW1;
wire        EcallW1;
// Superscalar 2
wire        RegWriteW2;
wire [4:0]  RdW2;
wire [63:0] ResultW2;
wire        EcallW2;
always_ff @ (posedge clk) begin
  if(!StallW) enableW <= enableM;
  if(enableM) begin
    if(!StallW) begin
      finishW <= finishM;
      // Superscalar 1
      case(ResultSrcM1)
        2'b00: ResultW1 <= ALUResultM1;
        2'b01: ResultW1 <= ReadDataM1;
        2'b10: ResultW1 <= PCPlus4M1;
      endcase
      //--- pipe ---
      RegWriteW1 <= RegWriteM1;
      RdW1 <= RdM1;
      EcallW1 <= EcallM1;
      // Superscalar 2
      case(ResultSrcM2)
        2'b00: ResultW2 <= ALUResultM2;
        2'b01: ResultW2 <= ReadDataM2;
        2'b10: ResultW2 <= PCPlus4M2;
      endcase
      //--- pipe ---
      RegWriteW2 <= RegWriteM2;
      RdW2 <= RdM2;
      EcallW2 <= EcallM2;
    end
  end
end

//****** Hazard_Unit ******
hazard Hazard(
  .enableD(enableD),
  .PCSrcE(PCSrcE),
  .StallF(StallF),
  .StallD(StallD),
  .StallE(StallE),
  .StallM(StallM),
  .StallW(StallW),
  .FlushD(FlushD),
  .FlushE(FlushE),
  // Superscalar 1
  .EcallE1(EcallE1),
  .EcallM1(EcallM1),
  .FrowardAE1(FrowardAE1),
  .FrowardBE1(FrowardBE1),
  .Rs1D1(Rs1D1),
  .Rs2D1(Rs2D1),
  .Rs1E1(Rs1E1),
  .Rs2E1(Rs2E1),
  .RdE1(RdE1),
  .ResultSrcE10(ResultSrcE1[0]),
  .RdM1(RdM1),
  .RegWriteM1(RegWriteM1),
  .RdW1(RdW1),
  .RegWriteW1(RegWriteW1),
  .Stall_miss1(Stall_miss1), // AXI MEM wait
  // Superscalar 2
  .EcallE2(EcallE2),
  .EcallM2(EcallM2),
  .FrowardAE2(FrowardAE2),
  .FrowardBE2(FrowardBE2),
  .Rs1D2(Rs1D2),
  .Rs2D2(Rs2D2),
  .Rs1E2(Rs1E2),
  .Rs2E2(Rs2E2),
  .RdE2(RdE2),
  .ResultSrcE20(ResultSrcE2[0]),
  .RdM2(RdM2),
  .RegWriteM2(RegWriteM2),
  .RdW2(RdW2),
  .RegWriteW2(RegWriteW2),
  .Stall_miss2(Stall_miss2) // AXI MEM wait
);

initial begin
  $display("Initializing top, entry point = 0x%x", entry);
end
endmodule
