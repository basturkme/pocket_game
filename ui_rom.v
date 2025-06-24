// ui_rom.v
// - "P1 WINS", "P2 WINS", "DRAW" için gerekli tüm karakterler eklendi.
// - Kod formatı okunabilirlik için düzeltildi.
module ui_rom (
    input  wire [7:0] char_code, // ASCII character code
    input  wire [2:0] row_index, // Row of the character to read (0-7)
    output reg  [7:0] char_row_data // 8-bit pixel data for the selected row
);

    // Her karakter için 8 satır (8x8'lik font) saklayan bir ROM.
    // 128 ASCII karakteri için 128 * 8 = 1024 adreslik bir bellek.
    reg [7:0] font_memory [0:1023];

    // ROM'u başlangıçta karakter desenleriyle doldur
    initial begin
        integer i;
        // Önce tüm belleği temizle
        for (i = 0; i < 1024; i = i + 1) begin
            font_memory[i] = 8'b00000000;
        end

        // --- Karakter Verileri ---

        // 'M' (ASCII 8'h4D)
        font_memory[{8'h4D, 3'd0}] = 8'b10000001;
        font_memory[{8'h4D, 3'd1}] = 8'b11000011;
        font_memory[{8'h4D, 3'd2}] = 8'b10100101;
        font_memory[{8'h4D, 3'd3}] = 8'b10011001;
        font_memory[{8'h4D, 3'd4}] = 8'b10000001;
        font_memory[{8'h4D, 3'd5}] = 8'b10000001;
        font_memory[{8'h4D, 3'd6}] = 8'b10000001;
        font_memory[{8'h4D, 3'd7}] = 8'b10000001;

        // 'E' (ASCII 8'h45)
        font_memory[{8'h45, 3'd0}] = 8'b01111110;
        font_memory[{8'h45, 3'd1}] = 8'b01000000;
        font_memory[{8'h45, 3'd2}] = 8'b01000000;
        font_memory[{8'h45, 3'd3}] = 8'b01111100;
        font_memory[{8'h45, 3'd4}] = 8'b01000000;
        font_memory[{8'h45, 3'd5}] = 8'b01000000;
        font_memory[{8'h45, 3'd6}] = 8'b01000000;
        font_memory[{8'h45, 3'd7}] = 8'b01111110;

        // 'N' (ASCII 8'h4E)
        font_memory[{8'h4E, 3'd0}] = 8'b01000010;
        font_memory[{8'h4E, 3'd1}] = 8'b01100010;
        font_memory[{8'h4E, 3'd2}] = 8'b01010010;
        font_memory[{8'h4E, 3'd3}] = 8'b01001010;
        font_memory[{8'h4E, 3'd4}] = 8'b01000110;
        font_memory[{8'h4E, 3'd5}] = 8'b01000010;
        font_memory[{8'h4E, 3'd6}] = 8'b01000010;
        font_memory[{8'h4E, 3'd7}] = 8'b01000010;

        // 'U' (ASCII 8'h55)
        font_memory[{8'h55, 3'd0}] = 8'b01000010;
        font_memory[{8'h55, 3'd1}] = 8'b01000010;
        font_memory[{8'h55, 3'd2}] = 8'b01000010;
        font_memory[{8'h55, 3'd3}] = 8'b01000010;
        font_memory[{8'h55, 3'd4}] = 8'b01000010;
        font_memory[{8'h55, 3'd5}] = 8'b01000010;
        font_memory[{8'h55, 3'd6}] = 8'b01000010;
        font_memory[{8'h55, 3'd7}] = 8'b00111100;
        
        // 'G' (ASCII 8'h47)
        font_memory[{8'h47, 3'd0}] = 8'b00111100;
        font_memory[{8'h47, 3'd1}] = 8'b01000010;
        font_memory[{8'h47, 3'd2}] = 8'b01000000;
        font_memory[{8'h47, 3'd3}] = 8'b01001110;
        font_memory[{8'h47, 3'd4}] = 8'b01000010;
        font_memory[{8'h47, 3'd5}] = 8'b01000010;
        font_memory[{8'h47, 3'd6}] = 8'b01000010;
        font_memory[{8'h47, 3'd7}] = 8'b00111100;

        // 'A' (ASCII 8'h41)
        font_memory[{8'h41, 3'd0}] = 8'b00111100;
        font_memory[{8'h41, 3'd1}] = 8'b01000010;
        font_memory[{8'h41, 3'd2}] = 8'b01000010;
        font_memory[{8'h41, 3'd3}] = 8'b01000010;
        font_memory[{8'h41, 3'd4}] = 8'b01111110;
        font_memory[{8'h41, 3'd5}] = 8'b01000010;
        font_memory[{8'h41, 3'd6}] = 8'b01000010;
        font_memory[{8'h41, 3'd7}] = 8'b01000010;

        // 'O' (ASCII 8'h4F)
        font_memory[{8'h4F, 3'd0}] = 8'b00111100;
        font_memory[{8'h4F, 3'd1}] = 8'b01000010;
        font_memory[{8'h4F, 3'd2}] = 8'b01000010;
        font_memory[{8'h4F, 3'd3}] = 8'b01000010;
        font_memory[{8'h4F, 3'd4}] = 8'b01000010;
        font_memory[{8'h4F, 3'd5}] = 8'b01000010;
        font_memory[{8'h4F, 3'd6}] = 8'b01000010;
        font_memory[{8'h4F, 3'd7}] = 8'b00111100;

        // 'V' (ASCII 8'h56)
        font_memory[{8'h56, 3'd0}] = 8'b01000010;
        font_memory[{8'h56, 3'd1}] = 8'b01000010;
        font_memory[{8'h56, 3'd2}] = 8'b01000010;
        font_memory[{8'h56, 3'd3}] = 8'b01000010;
        font_memory[{8'h56, 3'd4}] = 8'b01000010;
        font_memory[{8'h56, 3'd5}] = 8'b00100100;
        font_memory[{8'h56, 3'd6}] = 8'b00011000;
        font_memory[{8'h56, 3'd7}] = 8'b00011000;

        // 'R' (ASCII 8'h52)
        font_memory[{8'h52, 3'd0}] = 8'b01111100;
        font_memory[{8'h52, 3'd1}] = 8'b01000010;
        font_memory[{8'h52, 3'd2}] = 8'b01000010;
        font_memory[{8'h52, 3'd3}] = 8'b01111100;
        font_memory[{8'h52, 3'd4}] = 8'b01001000;
        font_memory[{8'h52, 3'd5}] = 8'b01000100;
        font_memory[{8'h52, 3'd6}] = 8'b01000010;
        font_memory[{8'h52, 3'd7}] = 8'b01000010;

        // '1' (ASCII 8'h31)
        font_memory[{8'h31, 3'd0}] = 8'b00011000;
        font_memory[{8'h31, 3'd1}] = 8'b00111000;
        font_memory[{8'h31, 3'd2}] = 8'b00011000;
        font_memory[{8'h31, 3'd3}] = 8'b00011000;
        font_memory[{8'h31, 3'd4}] = 8'b00011000;
        font_memory[{8'h31, 3'd5}] = 8'b00011000;
        font_memory[{8'h31, 3'd6}] = 8'b00011000;
        font_memory[{8'h31, 3'd7}] = 8'b00111100;

        // '2' (ASCII 8'h32)
        font_memory[{8'h32, 3'd0}] = 8'b00111100;
        font_memory[{8'h32, 3'd1}] = 8'b01000010;
        font_memory[{8'h32, 3'd2}] = 8'b00000010;
        font_memory[{8'h32, 3'd3}] = 8'b00000100;
        font_memory[{8'h32, 3'd4}] = 8'b00001000;
        font_memory[{8'h32, 3'd5}] = 8'b00010000;
        font_memory[{8'h32, 3'd6}] = 8'b00100000;
        font_memory[{8'h32, 3'd7}] = 8'b01111110;

        // '3' (ASCII 8'h33)
        font_memory[{8'h33, 3'd0}] = 8'b00111100;
        font_memory[{8'h33, 3'd1}] = 8'b01000010;
        font_memory[{8'h33, 3'd2}] = 8'b00000010;
        font_memory[{8'h33, 3'd3}] = 8'b00111100;
        font_memory[{8'h33, 3'd4}] = 8'b00000010;
        font_memory[{8'h33, 3'd5}] = 8'b00000010;
        font_memory[{8'h33, 3'd6}] = 8'b01000010;
        font_memory[{8'h33, 3'd7}] = 8'b00111100;

        // ' ' (Space, ASCII 8'h20) - All blank
        font_memory[{8'h20, 3'd0}] = 8'b0; font_memory[{8'h20, 3'd1}] = 8'b0; font_memory[{8'h20, 3'd2}] = 8'b0; font_memory[{8'h20, 3'd3}] = 8'b0;
        font_memory[{8'h20, 3'd4}] = 8'b0; font_memory[{8'h20, 3'd5}] = 8'b0; font_memory[{8'h20, 3'd6}] = 8'b0; font_memory[{8'h20, 3'd7}] = 8'b0;
        
        // 'P' (ASCII 8'h50)
        font_memory[{8'h50, 3'd0}] = 8'b01111100;
        font_memory[{8'h50, 3'd1}] = 8'b01000010;
        font_memory[{8'h50, 3'd2}] = 8'b01000010;
        font_memory[{8'h50, 3'd3}] = 8'b01111100;
        font_memory[{8'h50, 3'd4}] = 8'b01000000;
        font_memory[{8'h50, 3'd5}] = 8'b01000000;
        font_memory[{8'h50, 3'd6}] = 8'b01000000;
        font_memory[{8'h50, 3'd7}] = 8'b01000000;
        
        // 'W' (ASCII 8'h57)
        font_memory[{8'h57, 3'd0}] = 8'b10000001;
        font_memory[{8'h57, 3'd1}] = 8'b10000001;
        font_memory[{8'h57, 3'd2}] = 8'b10000001;
        font_memory[{8'h57, 3'd3}] = 8'b10011001;
        font_memory[{8'h57, 3'd4}] = 8'b10100101;
        font_memory[{8'h57, 3'd5}] = 8'b11000011;
        font_memory[{8'h57, 3'd6}] = 8'b10000001;
        font_memory[{8'h57, 3'd7}] = 8'b10000001;
        
        // 'I' (ASCII 8'h49)
        font_memory[{8'h49, 3'd0}] = 8'b00111000;
        font_memory[{8'h49, 3'd1}] = 8'b00010000;
        font_memory[{8'h49, 3'd2}] = 8'b00010000;
        font_memory[{8'h49, 3'd3}] = 8'b00010000;
        font_memory[{8'h49, 3'd4}] = 8'b00010000;
        font_memory[{8'h49, 3'd5}] = 8'b00010000;
        font_memory[{8'h49, 3'd6}] = 8'b00010000;
        font_memory[{8'h49, 3'd7}] = 8'b00111000;
        
        // 'S' (ASCII 8'h53)
        font_memory[{8'h53, 3'd0}] = 8'b00111110;
        font_memory[{8'h53, 3'd1}] = 8'b01000000;
        font_memory[{8'h53, 3'd2}] = 8'b01000000;
        font_memory[{8'h53, 3'd3}] = 8'b00111100;
        font_memory[{8'h53, 3'd4}] = 8'b00000010;
        font_memory[{8'h53, 3'd5}] = 8'b00000010;
        font_memory[{8'h53, 3'd6}] = 8'b01000010;
        font_memory[{8'h53, 3'd7}] = 8'b00111100;
        
        // 'D' (ASCII 8'h44)
        font_memory[{8'h44, 3'd0}] = 8'b01111000;
        font_memory[{8'h44, 3'd1}] = 8'b01000100;
        font_memory[{8'h44, 3'd2}] = 8'b01000010;
        font_memory[{8'h44, 3'd3}] = 8'b01000010;
        font_memory[{8'h44, 3'd4}] = 8'b01000010;
        font_memory[{8'h44, 3'd5}] = 8'b01000010;
        font_memory[{8'h44, 3'd6}] = 8'b01000100;
        font_memory[{8'h44, 3'd7}] = 8'b01111000;
		  
		  // --- Sayı Karakter Verileri (0-9) ---
        // '0' (ASCII 8'h30)
        font_memory[{8'h30, 3'd0}] = 8'b00111100;
        font_memory[{8'h30, 3'd1}] = 8'b01000010;
        font_memory[{8'h30, 3'd2}] = 8'b01000110;
        font_memory[{8'h30, 3'd3}] = 8'b01001010;
        font_memory[{8'h30, 3'd4}] = 8'b01010010;
        font_memory[{8'h30, 3'd5}] = 8'b01100010;
        font_memory[{8'h30, 3'd6}] = 8'b01000010;
        font_memory[{8'h30, 3'd7}] = 8'b00111100;
        
        // '1' (ASCII 8'h31)
        font_memory[{8'h31, 3'd0}] = 8'b00011000;
        font_memory[{8'h31, 3'd1}] = 8'b00111000;
        font_memory[{8'h31, 3'd2}] = 8'b00011000;
        font_memory[{8'h31, 3'd3}] = 8'b00011000;
        font_memory[{8'h31, 3'd4}] = 8'b00011000;
        font_memory[{8'h31, 3'd5}] = 8'b00011000;
        font_memory[{8'h31, 3'd6}] = 8'b00011000;
        font_memory[{8'h31, 3'd7}] = 8'b00111100;

        // '2' (ASCII 8'h32)
        font_memory[{8'h32, 3'd0}] = 8'b00111100;
        font_memory[{8'h32, 3'd1}] = 8'b01000010;
        font_memory[{8'h32, 3'd2}] = 8'b00000010;
        font_memory[{8'h32, 3'd3}] = 8'b00000100;
        font_memory[{8'h32, 3'd4}] = 8'b00010000;
        font_memory[{8'h32, 3'd5}] = 8'b00100000;
        font_memory[{8'h32, 3'd6}] = 8'b01000000;
        font_memory[{8'h32, 3'd7}] = 8'b01111110;

        // '3' (ASCII 8'h33)
        font_memory[{8'h33, 3'd0}] = 8'b00111100;
        font_memory[{8'h33, 3'd1}] = 8'b01000010;
        font_memory[{8'h33, 3'd2}] = 8'b00000010;
        font_memory[{8'h33, 3'd3}] = 8'b00111100;
        font_memory[{8'h33, 3'd4}] = 8'b00000010;
        font_memory[{8'h33, 3'd5}] = 8'b00000010;
        font_memory[{8'h33, 3'd6}] = 8'b01000010;
        font_memory[{8'h33, 3'd7}] = 8'b00111100;
        
        // '4' (ASCII 8'h34)
        font_memory[{8'h34, 3'd0}] = 8'b00001100;
        font_memory[{8'h34, 3'd1}] = 8'b00011100;
        font_memory[{8'h34, 3'd2}] = 8'b00101100;
        font_memory[{8'h34, 3'd3}] = 8'b01001100;
        font_memory[{8'h34, 3'd4}] = 8'b01111110;
        font_memory[{8'h34, 3'd5}] = 8'b00001100;
        font_memory[{8'h34, 3'd6}] = 8'b00001100;
        font_memory[{8'h34, 3'd7}] = 8'b00001100;

        // '5' (ASCII 8'h35)
        font_memory[{8'h35, 3'd0}] = 8'b01111110;
        font_memory[{8'h35, 3'd1}] = 8'b01000000;
        font_memory[{8'h35, 3'd2}] = 8'b01000000;
        font_memory[{8'h35, 3'd3}] = 8'b01111100;
        font_memory[{8'h35, 3'd4}] = 8'b00000010;
        font_memory[{8'h35, 3'd5}] = 8'b00000010;
        font_memory[{8'h35, 3'd6}] = 8'b01000010;
        font_memory[{8'h35, 3'd7}] = 8'b00111100;

        // '6' (ASCII 8'h36)
        font_memory[{8'h36, 3'd0}] = 8'b00111100;
        font_memory[{8'h36, 3'd1}] = 8'b01000000;
        font_memory[{8'h36, 3'd2}] = 8'b01000000;
        font_memory[{8'h36, 3'd3}] = 8'b01111100;
        font_memory[{8'h36, 3'd4}] = 8'b01000010;
        font_memory[{8'h36, 3'd5}] = 8'b01000010;
        font_memory[{8'h36, 3'd6}] = 8'b01000010;
        font_memory[{8'h36, 3'd7}] = 8'b00111100;

        // '7' (ASCII 8'h37)
        font_memory[{8'h37, 3'd0}] = 8'b01111110;
        font_memory[{8'h37, 3'd1}] = 8'b00000010;
        font_memory[{8'h37, 3'd2}] = 8'b00000100;
        font_memory[{8'h37, 3'd3}] = 8'b00001000;
        font_memory[{8'h37, 3'd4}] = 8'b00010000;
        font_memory[{8'h37, 3'd5}] = 8'b00010000;
        font_memory[{8'h37, 3'd6}] = 8'b00010000;
        font_memory[{8'h37, 3'd7}] = 8'b00010000;

        // '8' (ASCII 8'h38)
        font_memory[{8'h38, 3'd0}] = 8'b00111100;
        font_memory[{8'h38, 3'd1}] = 8'b01000010;
        font_memory[{8'h38, 3'd2}] = 8'b01000010;
        font_memory[{8'h38, 3'd3}] = 8'b00111100;
        font_memory[{8'h38, 3'd4}] = 8'b01000010;
        font_memory[{8'h38, 3'd5}] = 8'b01000010;
        font_memory[{8'h38, 3'd6}] = 8'b01000010;
        font_memory[{8'h38, 3'd7}] = 8'b00111100;

        // '9' (ASCII 8'h39)
        font_memory[{8'h39, 3'd0}] = 8'b00111100;
        font_memory[{8'h39, 3'd1}] = 8'b01000010;
        font_memory[{8'h39, 3'd2}] = 8'b01000010;
        font_memory[{8'h39, 3'd3}] = 8'b00111110;
        font_memory[{8'h39, 3'd4}] = 8'b00000010;
        font_memory[{8'h39, 3'd5}] = 8'b00000010;
        font_memory[{8'h39, 3'd6}] = 8'b01000010;
        font_memory[{8'h39, 3'd7}] = 8'b00111100;
		          // <<< YENİ EKLENEN KARAKTERLER >>>
        // '[' (ASCII 8'h5B)
        font_memory[{8'h5B, 3'd0}] = 8'b00111110;
        font_memory[{8'h5B, 3'd1}] = 8'b00100000;
        font_memory[{8'h5B, 3'd2}] = 8'b00100000;
        font_memory[{8'h5B, 3'd3}] = 8'b00100000;
        font_memory[{8'h5B, 3'd4}] = 8'b00100000;
        font_memory[{8'h5B, 3'd5}] = 8'b00100000;
        font_memory[{8'h5B, 3'd6}] = 8'b00100000;
        font_memory[{8'h5B, 3'd7}] = 8'b00111110;

        // ']' (ASCII 8'h5D)
        font_memory[{8'h5D, 3'd0}] = 8'b01111100;
        font_memory[{8'h5D, 3'd1}] = 8'b00000100;
        font_memory[{8'h5D, 3'd2}] = 8'b00000100;
        font_memory[{8'h5D, 3'd3}] = 8'b00000100;
        font_memory[{8'h5D, 3'd4}] = 8'b00000100;
        font_memory[{8'h5D, 3'd5}] = 8'b00000100;
        font_memory[{8'h5D, 3'd6}] = 8'b00000100;
        font_memory[{8'h5D, 3'd7}] = 8'b01111100;
		  
		  // YENİ KARAKTER 'L'
        font_memory[{8'h4C,3'd0}]=8'h40;font_memory[{8'h4C,3'd1}]=8'h40;font_memory[{8'h4C,3'd2}]=8'h40;font_memory[{8'h4C,3'd3}]=8'h40;font_memory[{8'h4C,3'd4}]=8'h40;font_memory[{8'h4C,3'd5}]=8'h40;font_memory[{8'h4C,3'd6}]=8'h40;font_memory[{8'h4C,3'd7}]=8'h7E;
        font_memory[{8'h4F,3'd0}]=8'h3C;font_memory[{8'h4F,3'd1}]=8'h42;font_memory[{8'h4F,3'd2}]=8'h42;font_memory[{8'h4F,3'd3}]=8'h42;font_memory[{8'h4F,3'd4}]=8'h42;font_memory[{8'h4F,3'd5}]=8'h42;font_memory[{8'h4F,3'd6}]=8'h42;font_memory[{8'h4F,3'd7}]=8'h3C;
        font_memory[{8'h50,3'd0}]=8'h7C;font_memory[{8'h50,3'd1}]=8'h42;font_memory[{8'h50,3'd2}]=8'h42;font_memory[{8'h50,3'd3}]=8'h7C;font_memory[{8'h50,3'd4}]=8'h40;font_memory[{8'h50,3'd5}]=8'h40;font_memory[{8'h50,3'd6}]=8'h40;font_memory[{8'h50,3'd7}]=8'h40;
        font_memory[{8'h53,3'd0}]=8'h3E;font_memory[{8'h53,3'd1}]=8'h40;font_memory[{8'h53,3'd2}]=8'h40;font_memory[{8'h53,3'd3}]=8'h3C;font_memory[{8'h53,3'd4}]=8'h02;font_memory[{8'h53,3'd5}]=8'h02;font_memory[{8'h53,3'd6}]=8'h02;font_memory[{8'h53,3'd7}]=8'h7C;
        // YENİ KARAKTER 'T'
        font_memory[{8'h54,3'd0}]=8'h7E;font_memory[{8'h54,3'd1}]=8'h18;font_memory[{8'h54,3'd2}]=8'h18;font_memory[{8'h54,3'd3}]=8'h18;font_memory[{8'h54,3'd4}]=8'h18;font_memory[{8'h54,3'd5}]=8'h18;font_memory[{8'h54,3'd6}]=8'h18;font_memory[{8'h54,3'd7}]=8'h18;
        font_memory[{8'h57,3'd0}]=8'h42;font_memory[{8'h57,3'd1}]=8'h42;font_memory[{8'h57,3'd2}]=8'h42;font_memory[{8'h57,3'd3}]=8'h5A;font_memory[{8'h57,3'd4}]=8'h66;font_memory[{8'h57,3'd5}]=8'h42;font_memory[{8'h57,3'd6}]=8'h42;font_memory[{8'h57,3'd7}]=8'h42;
        // YENİ KARAKTER 'o'
        font_memory[{8'h6F,3'd0}]=8'h00;font_memory[{8'h6F,3'd1}]=8'h00;font_memory[{8'h6F,3'd2}]=8'h3C;font_memory[{8'h6F,3'd3}]=8'h42;font_memory[{8'h6F,3'd4}]=8'h42;font_memory[{8'h6F,3'd5}]=8'h42;font_memory[{8'h6F,3'd6}]=8'h42;font_memory[{8'h6F,3'd7}]=8'h3C;
        // YENİ KARAKTER 'r'
        font_memory[{8'h72,3'd0}]=8'h00;font_memory[{8'h72,3'd1}]=8'h00;font_memory[{8'h72,3'd2}]=8'h5C;font_memory[{8'h72,3'd3}]=8'h62;font_memory[{8'h72,3'd4}]=8'h40;font_memory[{8'h72,3'd5}]=8'h40;font_memory[{8'h72,3'd6}]=8'h40;font_memory[{8'h72,3'd7}]=8'h40;
        // Boşluk karakteri
        font_memory[{8'h20, 3'd0}] = 8'h00; font_memory[{8'h20, 3'd1}] = 8'h00; font_memory[{8'h20, 3'd2}] = 8'h00; font_memory[{8'h20, 3'd3}] = 8'h00; font_memory[{8'h20, 3'd4}] = 8'h00; font_memory[{8'h20, 3'd5}] = 8'h00; font_memory[{8'h20, 3'd6}] = 8'h00; font_memory[{8'h20, 3'd7}] = 8'h00;
    end

    always @(*) begin
        char_row_data = font_memory[{char_code[6:0], row_index}];
    end

endmodule
