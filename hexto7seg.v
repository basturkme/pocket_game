module hexto7seg (output reg [6:0] hexn, input [3:0] hex);
	
	always @ (hex) begin
		case (hex)     //6543210
			0 : hexn = 7'b1000000;
			1 : hexn = 7'b1111001;
			2 : hexn = 7'b0100100;
			3 : hexn = 7'b0110000;
			4 : hexn = 7'b0011001;
			5 : hexn = 7'b0010010;
			6 : hexn = 7'b0000010;
			7 : hexn = 7'b1111000;
			8 : hexn = 7'b0000000;
			9 : hexn = 7'b0010000;
			10 : hexn = 7'b0001000;
			11 : hexn = 7'b0000011;
			12 : hexn = 7'b1000110;
			13 : hexn = 7'b0100001;
			14 : hexn = 7'b0000110;
			15 : hexn = 7'b0001110;
		endcase
	end

endmodule
