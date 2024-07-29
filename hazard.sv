module hazard
(
    //****** Hazard_Unit ******
    input  enableD,
    input  PCSrcE,
    output StallF,
    output StallD,
    output StallE,
    output StallM,
    output StallW,
    output FlushD,
    output FlushE,
    // Superscalar 1
    input         EcallE1,
    input         EcallM1,
    output [2:0]  FrowardAE1,
    output [2:0]  FrowardBE1,
    input  [4:0]  Rs1D1,
    input  [4:0]  Rs2D1,
    input  [4:0]  Rs1E1,
    input  [4:0]  Rs2E1,
    input  [4:0]  RdE1,
    input         ResultSrcE10,
    input  [4:0]  RdM1,
    input         RegWriteM1,
    input  [4:0]  RdW1,
    input         RegWriteW1,
    input  Stall_miss1 // AXI MEM wait
);
always_comb begin
    // Forward ALU hazard 1
    if(((Rs1E1 == RdM1) & RegWriteM1) & (Rs1E1 != 0)) FrowardAE1 = 3'b010;
    else if(((Rs1E1 == RdW1) & RegWriteW1) & (Rs1E1 != 0)) FrowardAE1 = 3'b001;
    else FrowardAE1 = 3'b000;

    if(((Rs2E1 == RdM1) & RegWriteM1) & (Rs2E1 != 0)) FrowardBE1 = 3'b010;
    else if(((Rs2E1 == RdW1) & RegWriteW1) & (Rs2E1 != 0)) FrowardBE1 = 3'b001;
    else FrowardBE1 = 3'b000;
end

logic ecallHazard;
logic loadHazard;
logic Stall;
always_comb begin
    // AXI MEM wait
    Stall  = Stall_miss1;
    // ecall hazard
    ecallHazard =  enableD & ((EcallE1 | EcallM1) & ((Rs1D1 == 10) | (Rs2D1 == 10)));
    // load save hazard
    loadHazard =  enableD & (ResultSrcE10 & ((Rs1D1 == RdE1) | (Rs2D1 == RdE1)));
    StallF = loadHazard | ecallHazard | Stall;
    StallD = loadHazard | ecallHazard | Stall;
    StallE = Stall;
    StallM = Stall;
    StallW = Stall;
    // branch hazard
    FlushD = !Stall & PCSrcE;
    FlushE = !Stall & (PCSrcE | loadHazard | ecallHazard);
end
endmodule