module If
#(
    N = 0, // Number of ways per set
    B = 0, // Block size (bytes)
    S = 0, // Number of sets
    s = 0, // Number of set index bits
    b = 0, // Number of block offset bits
    y = 0, // Number of byte offset bits
    t = 0  // Number of tag bits
)
(
    //****** IF ******
    input  clk,
    input         enable,
    output        enableF,
    output        IF_miss,
    output        pc8,
    output [63:0] IF_addr,
    // Superscalar 1
    input  [63:0] PCF1,
    output [31:0] instrF1,
    // Superscalar 2
    input  [63:0] PCF2,
    output [31:0] instrF2
);
reg [63:0] Data [S][N][B];
reg [t:0] Valid_Tag [S][N];
reg LRU [S];

reg [63:0] Victim [32][B];
reg [64:0] Victim_Valid_Addr [32];

// Superscalar 1
logic [t-1:0] tag1   = PCF1[63      : s+b+y];
logic [s-1:0] set1   = PCF1[s+b+y-1 : b+y];
logic [b-1:0] block1 = PCF1[b+y-1   : y];
// Superscalar 2
logic [t-1:0] tag2   = PCF2[63      : s+b+y];
logic [s-1:0] set2   = PCF2[s+b+y-1 : b+y];
logic [b-1:0] block2 = PCF2[b+y-1   : y];
always_comb begin
    if(enable) begin
        // Superscalar 1
        //$display("IF: addr(%0d): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d addr1:%0x, Data1:%0x", $signed({PCF1[63:3], 3'b000}), 
        //    Valid_Tag[PCF1[s+b+y-1 : b+y]][0][t], {Valid_Tag[PCF1[s+b+y-1 : b+y]][0][t-1:0], PCF1[s+b+y-1 : 0]}, Data[PCF1[s+b+y-1 : b+y]][0][PCF1[b+y-1 : y]], 
        //    Valid_Tag[PCF1[s+b+y-1 : b+y]][1][t], {Valid_Tag[PCF1[s+b+y-1 : b+y]][1][t-1:0], PCF1[s+b+y-1 : 0]}, Data[PCF1[s+b+y-1 : b+y]][1][PCF1[b+y-1 : y]]);
        if(Valid_Tag[set1][0][t] & (Valid_Tag[set1][0][t-1:0] == tag1)) begin
            //$display("IF: addr(%0d): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d addr1:%0x, Data1:%0x", $signed({PCF1[63:3], 3'b000}), 
            //Valid_Tag[PCF1[s+b+y-1 : b+y]][0][t], {Valid_Tag[PCF1[s+b+y-1 : b+y]][0][t-1:0], PCF1[s+b+y-1 : 0]}, Data[PCF1[s+b+y-1 : b+y]][0][PCF1[b+y-1 : y]], 
            //Valid_Tag[PCF1[s+b+y-1 : b+y]][1][t], {Valid_Tag[PCF1[s+b+y-1 : b+y]][1][t-1:0], PCF1[s+b+y-1 : 0]}, Data[PCF1[s+b+y-1 : b+y]][1][PCF1[b+y-1 : y]]);
            if(PCF1[2]) begin
                instrF1 = Data[set1][0][block1][63:32];
            end else begin
                instrF1 = Data[set1][0][block1][31:0];
            end
            LRU[set1] = 1;
            IF_miss = 0;
        end
        else if(Valid_Tag[set1][1][t] & (Valid_Tag[set1][1][t-1:0] == tag1)) begin
            //$display("IF: addr(%0d): V0:%0d, addr0:%0x, Data0:%0x, V1:%0d addr1:%0x, Data1:%0x", $signed({PCF1[63:3], 3'b000}), 
            //Valid_Tag[PCF1[s+b+y-1 : b+y]][0][t], {Valid_Tag[PCF1[s+b+y-1 : b+y]][0][t-1:0], PCF1[s+b+y-1 : 0]}, Data[PCF1[s+b+y-1 : b+y]][0][PCF1[b+y-1 : y]], 
            //Valid_Tag[PCF1[s+b+y-1 : b+y]][1][t], {Valid_Tag[PCF1[s+b+y-1 : b+y]][1][t-1:0], PCF1[s+b+y-1 : 0]}, Data[PCF1[s+b+y-1 : b+y]][1][PCF1[b+y-1 : y]]);
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
        // Superscalar 2
        if(!IF_miss) begin
            enableF = 1;
            case(instrF1[6:0])
                //0,Finish //99,Type B //103,//115,Type I //111,Type J
                0, 7'b1100011, 7'b1100111, 7'b1110011, 7'b1101111: begin
                    instrF2 = 0;
                end
                default: begin
                    if(Valid_Tag[set2][0][t] & (Valid_Tag[set2][0][t-1:0] == tag2)) begin
                        if(PCF2[2]) begin
                            instrF2 = Data[set2][0][block2][63:32];
                        end else begin
                            instrF2 = Data[set2][0][block2][31:0];
                        end
                        LRU[set2] = 1;
                    end
                    else if(Valid_Tag[set2][1][t] & (Valid_Tag[set2][1][t-1:0] == tag2)) begin
                        if(PCF2[2]) begin
                            instrF2 = Data[set2][1][block2][63:32];
                        end else begin
                            instrF2 = Data[set2][1][block2][31:0];
                        end
                        LRU[set2] = 0;
                    end
                    else begin
                        instrF2 = 0;
                    end
                end
            endcase
        end
        // pc8 = pc + 8
        if(instrF2 != 0) begin // Superscalar 2 not use AXI
            case(instrF1[6:0]) // compare rd, rs1, rs2.
                //3,19,27,Type I //23,55,Type U //51,59,Type R
                7'b0000011, 7'b0010011, 7'b0011011, 7'b0010111, 7'b0110111, 7'b0110011, 7'b0111011: begin
                    case(instrF2[6:0])
                        //3,19,27,103,Type I
                        7'b0000011, 7'b0010011, 7'b0011011, 7'b1100111: begin
                            if(instrF1[11:7] == instrF2[19:15]) begin
                                instrF2 = 0;
                                pc8 = 0;
                            end else begin
                                pc8 = 1;
                            end
                        end
                        //35,Type S //51,59,Type R //99,Type B
                        7'b0100011, 7'b0110011, 7'b0111011, 7'b1100011: begin
                            if(instrF1[11:7] == instrF2[19:15] | instrF1[11:7] == instrF2[24:20]) begin
                                instrF2 = 0;
                                pc8 = 0;
                            end else begin
                                pc8 = 1;
                            end
                        end
                        default: begin
                            pc8 = 1;
                        end
                    endcase
                end
                default: begin
                    pc8 = 1;
                end
            endcase
        end else begin
            pc8 = 0;
        end
    end
end
endmodule