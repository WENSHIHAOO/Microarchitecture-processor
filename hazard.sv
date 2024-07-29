module hazard
(
    //****** Hazard_Unit ******
    input  [4:0] Rs1D,
    input  [4:0] Rs2D,
    input  [4:0] Rs1E,
    input  [4:0] Rs2E,
    input  [4:0] RdE,
    input        PCSrcE,
    input        ResultSrcE0,
    input  [4:0] RdM,
    input        RegWriteM,
    input  [4:0] RdW,
    input        RegWriteW,
    output StallF,
    output StallD,
    output FlushD,
    output FlushE,
    output [1:0] FrowardAE,
    output [1:0] FrowardBE
);
always_comb begin
    // Forward hazard
    if(((Rs1E == RdM) & RegWriteM) & (Rs1E != 0)) begin
        FrowardAE = 2'b10;
    end else if(((Rs1E == RdW) && RegWriteW) && (Rs1E != 0)) begin
        FrowardAE = 2'b01;
    end else begin
        FrowardAE = 2'b00;
    end
    if(((Rs2E == RdM) & RegWriteM) & (Rs2E != 0)) begin
        FrowardBE = 2'b10;
    end else if(((Rs2E == RdW) && RegWriteW) && (Rs2E != 0)) begin
        FrowardBE = 2'b01;
    end else begin
        FrowardBE = 2'b00;
    end
    // load hazard
    StallF = ResultSrcE0 & ((Rs1D == RdE) | (Rs2D == RdE));
    StallD = StallF;
    // branch hazard
    FlushD = PCSrcE;
    FlushE = PCSrcE | StallF; // FlushE = StallF is load hazard
end
endmodule