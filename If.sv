module If
#(
    N = 0, // Number of ways per set
    B = 0, // Block size (bytes)
    S = 0, // Number of sets
    s = 0, // Number of set index bits
    b = 0, // Number of block offset bits
    y = 0, // Number of byte offset bits
    t = 0, // Number of tag bits
    V_N = 0// Number of ways of Victim
)
(
    //****** IF ******
    input  clk,
    input         enable,
    output        enableF,
    output        IF_miss,
    output [63:0] IF_addr,
    // Superscalar 1
    input  [63:0] PCF1,
    output [31:0] instrF1
);
reg [63:0] Data [S][N][B];
reg [t:0] Valid_Tag [S][N];
reg LRU [S];

reg [63:0] Victim [V_N][B];
reg [64:0] Victim_Valid_Addr [V_N];

// Superscalar 1
logic [t-1:0] tag1   = PCF1[63      : s+b+y];
logic [s-1:0] set1   = PCF1[s+b+y-1 : b+y];
logic [b-1:0] block1 = PCF1[b+y-1   : y];
always_comb begin
    if(enable) begin
        // Superscalar 1
        if(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) begin
            if(PCF1[2]) begin
                instrF1 = Data[set1][0][block1][63:32];
            end else begin
                instrF1 = Data[set1][0][block1][31:0];
            end
            LRU[set1] = 1;
            IF_miss = 0;
        end
        else if(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1)) begin
            if(PCF1[2]) begin
                instrF1 = Data[set1][1][block1][63:32];
            end else begin
                instrF1 = Data[set1][1][block1][31:0];
            end
            LRU[set1] = 0;
            IF_miss = 0;
        end
        else begin
            IF_addr = PCF1;
            enableF = 0;
            IF_miss = 1;
        end
        if(!IF_miss) enableF = 1;
    end
end
endmodule