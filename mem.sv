module mem
(
    //****** MEM ******
    input         enableM,
    input         MemWriteM,
    input  [63:0] ALUResultM,
    input  [63:0] WriteDataM,
    output [63:0] ReadDataM
);
always_comb begin
    if(enableM) begin
        if(MemWriteM) begin
        end
    end
end
endmodule