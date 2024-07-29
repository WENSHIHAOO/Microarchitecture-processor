module hazard
(
    //****** Hazard_Unit ******
    input  enableD,
    input  enableE,
    input  done_eE,
    input  PCSrcE,
    output StallF,
    output StallD,
    output StallE,
    output StallM,
    output StallW,
    output FlushD,
    output FlushE,
    output FlushM,
    // Superscalar 1
    output [2:0]  FrowardAE1,
    output [2:0]  FrowardBE1,
    output        FrowardAM1,
    output        FrowardWM1,
    input  [4:0]  Rs1D1,
    input  [4:0]  Rs2D1,
    input  [4:0]  Rs1E1,
    input  [4:0]  Rs2E1,
    input  [4:0]  RdE1,
    input         ResultSrcE10,
    input  [4:0]  Rs1M1,
    input  [4:0]  Rs2M1,
    input  [4:0]  RdM1,
    input         RegWriteM1,
    input         EcallM1,
    input  [4:0]  RdW1,
    input         RegWriteW1,
    input  Stall_miss1, // load AXI MEM wait
    input  write_dirty1, // save AXI MEM wait
    // Superscalar 2
    output [2:0]  FrowardAE2,
    output [2:0]  FrowardBE2,
    output        FrowardAM2,
    output        FrowardWM2,
    input  [4:0]  Rs1D2,
    input  [4:0]  Rs2D2,
    input  [4:0]  Rs1E2,
    input  [4:0]  Rs2E2,
    input  [4:0]  RdE2,
    input         ResultSrcE20,
    input  [4:0]  Rs1M2,
    input  [4:0]  Rs2M2,
    input  [4:0]  RdM2,
    input         RegWriteM2,
    input         EcallM2,
    input  [4:0]  RdW2,
    input         RegWriteW2,
    input  Stall_miss2, // load AXI MEM wait
    input  write_dirty2 // save AXI MEM wait
);
always_comb begin
    // Forward ALU hazard 1
    if(((Rs1E1 == RdM2) & RegWriteM2) & (Rs1E1 != 0)) FrowardAE1 = 3'b110;
    else if(((Rs1E1 == RdM1) & RegWriteM1) & (Rs1E1 != 0)) FrowardAE1 = 3'b010;
    else if(((Rs1E1 == RdW2) & RegWriteW2) & (Rs1E1 != 0)) FrowardAE1 = 3'b101;
    else if(((Rs1E1 == RdW1) & RegWriteW1) & (Rs1E1 != 0)) FrowardAE1 = 3'b001;
    else FrowardAE1 = 3'b000;

    if(((Rs2E1 == RdM2) & RegWriteM2) & (Rs2E1 != 0)) FrowardBE1 = 3'b110;
    else if(((Rs2E1 == RdM1) & RegWriteM1) & (Rs2E1 != 0)) FrowardBE1 = 3'b010;
    else if(((Rs2E1 == RdW2) & RegWriteW2) & (Rs2E1 != 0)) FrowardBE1 = 3'b101;
    else if(((Rs2E1 == RdW1) & RegWriteW1) & (Rs2E1 != 0)) FrowardBE1 = 3'b001;
    else FrowardBE1 = 3'b000;

    // Forward ALU hazard 2
    if(((Rs1E2 == RdM2) & RegWriteM2) & (Rs1E2 != 0)) FrowardAE2 = 3'b110;
    else if(((Rs1E2 == RdM1) & RegWriteM1) & (Rs1E2 != 0)) FrowardAE2 = 3'b010;
    else if(((Rs1E2 == RdW2) & RegWriteW2) & (Rs1E2 != 0)) FrowardAE2 = 3'b101;
    else if(((Rs1E2 == RdW1) & RegWriteW1) & (Rs1E2 != 0)) FrowardAE2 = 3'b001;
    else FrowardAE2 = 3'b000;

    if(((Rs2E2 == RdM2) & RegWriteM2) & (Rs2E2 != 0)) FrowardBE2 = 3'b110;
    else if(((Rs2E2 == RdM1) & RegWriteM1) & (Rs2E2 != 0)) FrowardBE2 = 3'b010;
    else if(((Rs2E2 == RdW2) & RegWriteW2) & (Rs2E2 != 0)) FrowardBE2 = 3'b101;
    else if(((Rs2E2 == RdW1) & RegWriteW1) & (Rs2E2 != 0)) FrowardBE2 = 3'b001;
    else FrowardBE2 = 3'b000;
end

always_comb begin
    // Forward ecall hazard 1
    if(((Rs1M1 == 10) & done_eE)) FrowardAM1 = 1;
    else FrowardAM1 = 0;
    if(((Rs2M1 == 10) & done_eE)) FrowardWM1 = 1;
    else FrowardWM1 = 0;

    // Forward ecall hazard 2
    if(((Rs1M2 == 10) & done_eE)) FrowardAM2 = 1;
    else FrowardAM2 = 0;
    if(((Rs2M2 == 10) & done_eE)) FrowardWM2 = 1;
    else FrowardWM2 = 0;
end

logic ecallDHazard;
logic ecallEHazard;
logic loadHazard;
logic Stall;
always_comb begin
    // ecall hazard
    ecallDHazard =  ( enableD &
                    ( (EcallM1 & ((Rs1D1 == 10) | (Rs2D1 == 10))) 
                    | (EcallM1 & ((Rs1D2 == 10) | (Rs2D2 == 10))) 
                    | (EcallM2 & ((Rs1D1 == 10) | (Rs2D1 == 10)))
                    | (EcallM2 & ((Rs1D2 == 10) | (Rs2D2 == 10)))));
    ecallEHazard =   ( enableE &
                    ( (EcallM1 & ((Rs1E1 == 10) | (Rs2E1 == 10))) 
                    | (EcallM1 & ((Rs1E2 == 10) | (Rs2E2 == 10))) 
                    | (EcallM2 & ((Rs1E1 == 10) | (Rs2E1 == 10)))
                    | (EcallM2 & ((Rs1E2 == 10) | (Rs2E2 == 10)))));
    // load save hazard
    loadHazard =  enableD & 
                ( (ResultSrcE10 & ((Rs1D1 == RdE1) | (Rs2D1 == RdE1))) 
                | (ResultSrcE10 & ((Rs1D2 == RdE1) | (Rs2D2 == RdE1))) 
                | (ResultSrcE20 & ((Rs1D1 == RdE2) | (Rs2D1 == RdE2)))
                | (ResultSrcE20 & ((Rs1D2 == RdE2) | (Rs2D2 == RdE2))) );
    Stall  = Stall_miss1 | Stall_miss2 | write_dirty2 | write_dirty2;
    StallF = loadHazard | ecallDHazard | ecallEHazard | Stall;
    StallD = loadHazard | ecallDHazard | ecallEHazard | Stall;
    StallE = ecallEHazard | Stall;
    StallM = Stall;
    StallW = Stall;
    // branch hazard
    FlushD = PCSrcE;
    FlushE = PCSrcE | loadHazard | ecallDHazard;
    FlushM = ecallEHazard;
end
endmodule