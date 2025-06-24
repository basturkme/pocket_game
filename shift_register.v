module shift_register #(parameter W = 16)(
    input clk, reset, load, shift_left, shift_enable, serial_in_left, serial_in_right,
    input [W-1:0] data_in,   // parallel input
    output reg [W-1:0] data_out
);

    always @(posedge clk) begin
        if (reset) begin
            data_out <= 0;
        end 
		  else if (load) begin
            data_out <= data_in;
        end 
		  else if (shift_enable) begin
            if (shift_left)
                data_out <= {data_out[W-2:0], serial_in_left};  // shift left
            else
                data_out <= {serial_in_right, data_out[W-1:1]}; // shift right
        end
    end

endmodule
