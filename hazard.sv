module hazard
(
    //****** Hazard_Unit ******
    input  reg enableD,
    input  reg PCSrcE1,
    input  reg PCSrcE2,
    output reg StallF,
    output reg StallD,
    output reg StallE,
    output reg StallM,
    output reg StallW,
    output reg FlushD,
    output reg FlushE,
    // Superscalar 1
    input  reg        EcallE1,
    input  reg        EcallM1,
    output reg [2:0]  FrowardAE1,
    output reg [2:0]  FrowardBE1,
    input  reg [4:0]  Rs1D1,
    input  reg [4:0]  Rs2D1,
    input  reg [4:0]  Rs1E1,
    input  reg [4:0]  Rs2E1,
    input  reg [4:0]  RdE1,
    input  reg        ResultSrcE10,
    input  reg [4:0]  RdM1,
    input  reg        RegWriteM1,
    input  reg [4:0]  RdW1,
    input  reg        RegWriteW1,
    input  reg Stall_miss1, // AXI MEM wait
    // Superscalar 2
    input  reg        EcallE2,
    input  reg        EcallM2,
    output reg [2:0]  FrowardAE2,
    output reg [2:0]  FrowardBE2,
    input  reg [4:0]  Rs1D2,
    input  reg [4:0]  Rs2D2,
    input  reg [4:0]  Rs1E2,
    input  reg [4:0]  Rs2E2,
    input  reg [4:0]  RdE2,
    input  reg        ResultSrcE20,
    input  reg [4:0]  RdM2,
    input  reg        RegWriteM2,
    input  reg [4:0]  RdW2,
    input  reg        RegWriteW2,
    input  reg Stall_miss2 // AXI MEM wait
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

logic ecallHazard;
logic loadHazard;
logic Stall;
always_comb begin
    // AXI MEM wait
    Stall  = Stall_miss1 | Stall_miss2;
    // ecall hazard
    ecallHazard =  enableD &
                ( ((EcallE1 | EcallM1) & ((Rs1D1 == 10) | (Rs2D1 == 10))) 
                | ((EcallE1 | EcallM1) & ((Rs1D2 == 10) | (Rs2D2 == 10))) 
                | ((EcallE2 | EcallM2) & ((Rs1D1 == 10) | (Rs2D1 == 10)))
                | ((EcallE2 | EcallM2) & ((Rs1D2 == 10) | (Rs2D2 == 10))) );
    // load save hazard
    loadHazard =  enableD & 
                ( (ResultSrcE10 & ((Rs1D1 == RdE1) | (Rs2D1 == RdE1))) 
                | (ResultSrcE10 & ((Rs1D2 == RdE1) | (Rs2D2 == RdE1))) 
                | (ResultSrcE20 & ((Rs1D1 == RdE2) | (Rs2D1 == RdE2)))
                | (ResultSrcE20 & ((Rs1D2 == RdE2) | (Rs2D2 == RdE2))) );
    StallF = loadHazard | ecallHazard | Stall;
    StallD = loadHazard | ecallHazard | Stall;
    StallE = Stall;
    StallM = Stall;
    StallW = Stall;
    // branch hazard
    FlushD = !Stall & (PCSrcE1 | PCSrcE2);
    FlushE = !Stall & (PCSrcE1 | PCSrcE2 | loadHazard | ecallHazard);
end
endmodule