module If
(
    //****** IF ******
    input         clk,
    input         enable,
    output        enableF,
    input  [63:0] PCF,
    output [31:0] instrF,
    input         m_axi_arready,
    output        m_axi_arvalid,
    output [63:0] m_axi_araddr,
    input  [63:0] m_axi_rdata,
    input         m_axi_rlast,
    input         m_axi_rvalid,
    output        m_axi_rready
);
localparam C = 4 * 1024;      // Cache size (bytes), not including overhead such as the valid, tag, and LRU bits
localparam N = 2;             // Number of ways per set
localparam B = 8;             // Block size (bytes)
localparam S = 256; //C/(N*B) // Number of sets
reg [63:0] Data [S][N][B];
localparam m = 64;              // Number of physical address bits
localparam s = 8; //log2(S)     // Number of set index bits
localparam b = 3; //log2(B)     // Number of block offset bits
localparam y = 3;               // Number of byte offset bits
localparam t = m - (s + b + y); // Number of tag bits
reg [t:0] Valid_Tag [S][N];
reg LRU [S];

logic hit;
logic step;
logic [t-1:0] tag = PCF[63:14];
logic [s-1:0] set = PCF[13:6];
logic [b-1:0] block = PCF[5:3];
logic         half = PCF[2];
logic [b-1:0] block_offset;
// fetch data
always_ff @ (posedge clk) begin
    if(!hit) begin
        if(step == 0) begin
            if(m_axi_arready) begin
                if (m_axi_arvalid) begin
                    m_axi_rready <= 1;
                    m_axi_arvalid <= 0;
                    block_offset <= block;
                    step <= 1;
                end else begin
                    m_axi_araddr <= PCF;
                    m_axi_arvalid <= 1;
                end
            end
        end
        // Cache Read
        else if(step == 1) begin
            if (m_axi_rvalid) begin
                Data[set][LRU[set]][block_offset] <= m_axi_rdata;
                block_offset <= block_offset + 1;
                if (m_axi_rlast) begin
                    LRU[set] <= !LRU[set];
                    m_axi_rready <= 0;
                    step <= 0;
                    hit = 1;
                end
                if(!Valid_Tag[set][LRU[set]][t]) begin
                    Valid_Tag[set][LRU[set]][t] <= 1;
                    Valid_Tag[set][LRU[set]][t-1:0] <= tag;
                end
            end
        end
    end
end

// check hit
always_comb begin
    if(enable) begin
        if(Valid_Tag[set][0][t] & (Valid_Tag[set][0][t-1:0] == tag)) begin
            if(half) begin
                instrF = Data[set][0][block][63:32];
            end else begin
                instrF = Data[set][0][block][31:0];
            end
            enableF = 1;
        end
        else if(Valid_Tag[set][1][t] & (Valid_Tag[set][1][t-1:0] == tag)) begin
            if(half) begin
                instrF = Data[set][1][block][63:32];
            end else begin
                instrF = Data[set][1][block][31:0];
            end
            enableF = 1;
        end
        else begin
            enableF = 0;
            hit = 0;
        end
    end else begin
        enableF = 0;
    end
end
endmodule