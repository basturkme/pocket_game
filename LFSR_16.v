module LFSR_16 (
    input clk, reset, enable, load_seed,
    input [15:0] seed,
    output wire [15:0] LFSR_out
);
    wire feedback;
    assign feedback = LFSR_out[0] ^ LFSR_out[2] ^ LFSR_out[3] ^ LFSR_out[5]; // XOR

    shift_register #(.W(16)) my_shift_register (
        .clk(clk),
        .reset(reset),
        .load(load_seed),
        .shift_left(1'b0),                 // Shift right
        .shift_enable(enable),
        .serial_in_left(1'b0),          // No shifting left
        .serial_in_right(feedback),    
        .data_in(seed),
        .data_out(LFSR_out)
    );

endmodule
