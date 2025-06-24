// hexto7seg.v
// - DÜZELTME: "FIGHT", "P1", "P2", "Eq" için gerekli tüm
//   7-segment desenleri eklendi ve düzenlendi.
module hexto7seg (
    output reg [6:0] hexn, 
    input [3:0] hex
);
	
	always @ (hex) begin
		case (hex)      // Segments: gfedcba
			// --- Sayılar ---
			4'h0: hexn = 7'b1000000; // 0
			4'h1: hexn = 7'b1111001; // 1
			4'h2: hexn = 7'b0100100; // 2
			4'h3: hexn = 7'b0110000; // 3
			
			// --- "FIGHT" için Harfler ---
			4'hE: hexn = 7'b0001110; // F
			// I -> 1 ile aynı (4'h1)
			4'h6: hexn = 7'b0000010; // G
			4'h4: hexn = 7'b0011001; // h
			4'h7: hexn = 7'b0000111; // t
			
			// --- "P1/P2/Eq" için Harfler ---
			4'hC: hexn = 7'b0001100; // P
			4'h8: hexn = 7'b0000110; // E
			4'h9: hexn = 7'b0011000; // q

			// --- Diğerleri ---
			4'hA: hexn = 7'b0001000; // A
			4'hD: hexn = 7'b0100001; // d
			4'hF: hexn = 7'b1111111; // BLANK (boş)
			
			default: hexn = 7'b1111111; // Bilinmeyen karakter için ekranı kapat
		endcase
	end

endmodule