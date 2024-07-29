module If
(
    //****** IF ******
    input         enable,
    output        enableF,
    input  [63:0] PCF,
    output [31:0] instrF
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

// check miss
logic miss;
logic [t-1:0] tag = PCF[63:14];
logic [s-1:0] set = PCF[13:6];
logic [b-1:0] block = PCF[5:3];
always_comb begin
    if(enable) begin
        if(Valid_Tag[set][0][t] & (Valid_Tag[set][0][t-1:0] == tag)) begin
            if(PCF[2]) begin
                instrF = Data[set][0][block][63:32];
            end else begin
                instrF = Data[set][0][block][31:0];
            end
            LRU[set] = 1;
            enableF = 1;
        end
        else if(Valid_Tag[set][1][t] & (Valid_Tag[set][1][t-1:0] == tag)) begin
            if(PCF[2]) begin
                instrF = Data[set][1][block][63:32];
            end else begin
                instrF = Data[set][1][block][31:0];
            end
            LRU[set] = 0;
            enableF = 1;
        end
        else begin
            enableF = 0;
            miss = 1;
        end
    end else begin
        enableF = 0;
    end
end
endmodule