module clock_divider_functional #(
    parameter DIVISOR = 10 // The factor by which to divide the input clock frequency
)(
    input wire clk,
    input wire reset,
    output reg clk_out
);

    // COUNT_LIMIT determines the number of input clock cycles for half period of clk_out
    // For clk_out to have period DIVISOR * T_clk_in,
    // it should toggle every (DIVISOR/2) * T_clk_in.
    localparam COUNT_MAX_VAL = (DIVISOR / 2) -1; // Counter counts from 0 to COUNT_MAX_VAL

    // Determine width of the counter
    // Add 1 to DIVISOR/2 before $clog2 in case DIVISOR/2 is a power of 2, to ensure enough bits.
    // e.g. if DIVISOR/2 = 1, count is 0, $clog2(1)=0, needs 1 bit.
    // if DIVISOR/2 = 2, count is 0,1, $clog2(2)=1, needs 1 bit [0:0] for value 1. No, $clog2(N) bits for values 0 to N-1.
    // Counter for values 0 to X needs $clog2(X+1) bits.
    // Here counter goes 0 to (DIVISOR/2)-1. Needs $clog2(DIVISOR/2) bits.
    reg [$clog2(DIVISOR/2) > 0 ? $clog2(DIVISOR/2)-1 : 0 :0] count;


    initial begin
        clk_out = 1'b0;
        count = 0; // Optional, good for simulation
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;
            clk_out <= 1'b0;
        end else begin
            if (count == COUNT_MAX_VAL) begin
                count <= 0;
                clk_out <= ~clk_out;
            end else begin
                count <= count + 1;
            end
        end
    end
endmodule