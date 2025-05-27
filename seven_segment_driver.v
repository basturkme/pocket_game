// seven_segment_driver.v
// Oyun bilgilerini 7-segment göstergede gösterir.
// 4 haneli bir gösterge için zaman çoğullama kullanır.
module seven_segment_driver (
    input wire clk, // Gösterge yenileme/çoğullama için saat (örn: ~1kHz)
    input wire reset,

    // game_logic_fsm'den Gelen Bilgiler
    input wire [1:0] game_phase_in,
    input wire selected_mode_in, // 0: 2P, 1: 1P
    input wire [1:0] winner_info_in, // 00:None, 01:P1, 10:P2, 11:Draw
    input wire [6:0] game_time_in,   // Saniye (0-99)

    // 7-Segment Çıkışları (Fiziksel pinlere)
    output reg [6:0] seg_data_0_out,
    output reg [6:0] seg_data_1_out,
    output reg [6:0] seg_data_2_out,
    output reg [6:0] seg_data_3_out,
    output reg [3:0] seg_an_out
);

    // Oyun Aşamaları
    localparam PHASE_MENU      = 2'b00;
    localparam PHASE_COUNTDOWN = 2'b01;
    localparam PHASE_GAMEPLAY  = 2'b10;
    localparam PHASE_GAMEOVER  = 2'b11;

    // 7-Segment Kodları (Ortak Anot için, gfedcba)
    localparam SEG_0 = 7'b1000000; // 0
    localparam SEG_1 = 7'b1111001; // 1
    localparam SEG_2 = 7'b0100100; // 2
    localparam SEG_3 = 7'b0110000; // 3
    localparam SEG_4 = 7'b0011001; // 4
    localparam SEG_5 = 7'b0010010; // 5
    localparam SEG_6 = 7'b0000010; // 6
    localparam SEG_7 = 7'b1111000; // 7
    localparam SEG_8 = 7'b0000000; // 8
    localparam SEG_9 = 7'b0010000; // 9
    localparam SEG_P = 7'b0001100; // P
    localparam SEG_F = 7'b0001110; // F
    localparam SEG_I = 7'b1111001; // I (1 ile aynı)
    localparam SEG_G = 7'b1000010; // G (custom G)
    localparam SEG_H = 7'b0001001; // H
    localparam SEG_T = 7'b0000111; // t
    localparam SEG_E = 7'b0000110; // E
    localparam SEG_Q = 7'b1001000; // q
    localparam SEG_DASH= 7'b0111111; // -
    localparam SEG_BLANK=7'b1111111; // Boş

    reg [1:0] current_digit_select_reg;
    localparam REFRESH_DIVIDER = 1; // Eğer clk zaten ~1kHz ise
    reg [$clog2(REFRESH_DIVIDER == 0 ? 1 : REFRESH_DIVIDER)-1:0] refresh_counter_reg; // REFRESH_DIVIDER 0 olamaz, $clog2(0) tanımsız.
                                                                                    // Güvenlik için (REFRESH_DIVIDER == 0 ? 1 : REFRESH_DIVIDER) eklendi.

    reg [6:0] digit_data [0:3];

    // 'automatic' olmadan 'onlar' ve 'birler' için bildirimler
    // Bu değişkenler kombinasyonel blok içinde atandığı için 'reg' olmalı.
    // Boyutları, game_time_in'den türetilecek değerlere uygun olmalı.
    // game_time_in [6:0] (0-99) olduğu için onlar ve birler en fazla 9 olabilir, yani 4 bit yeterli.
    // Ancak 'byte' türü (8 bit) Verilog-2001 ile geldi, daha eski standartlarda
    // 'integer' veya uygun boyutta 'reg' kullanılır.
    // 'byte' yerine 'reg [3:0]' veya 'integer' kullanabiliriz.
    // Basitlik için 'integer' kullanalım, sentezleyici bunu optimize edecektir.
    // Ya da daha spesifik olarak 'reg [3:0]'
    reg [3:0] onlar;
    reg [3:0] birler;

    initial begin
        current_digit_select_reg = 2'b00;
        refresh_counter_reg = 0;
        seg_an_out = 4'b1111;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_digit_select_reg <= 2'b00;
            refresh_counter_reg <= 0;
            seg_an_out <= 4'b1111;
        end else begin
            if (refresh_counter_reg == REFRESH_DIVIDER - 1) begin
                refresh_counter_reg <= 0;
                current_digit_select_reg <= current_digit_select_reg + 1;
            end else begin
                refresh_counter_reg <= refresh_counter_reg + 1;
            end

            case (current_digit_select_reg)
                2'b00: seg_an_out <= 4'b1110;
                2'b01: seg_an_out <= 4'b1101;
                2'b10: seg_an_out <= 4'b1011;
                2'b11: seg_an_out <= 4'b0111;
                default: seg_an_out <= 4'b1111;
            endcase
        end
    end

    always @(*) begin
        // 'onlar' ve 'birler' değerleri burada atanır.
        // Bu değişkenler artık modül seviyesinde bildirildiği için
        // 'automatic' anahtar kelimesine gerek yoktur.
        onlar = game_time_in / 10;
        birler = game_time_in % 10;

        case (game_phase_in)
            PHASE_MENU: begin
                digit_data[0] = SEG_BLANK;
                digit_data[1] = SEG_BLANK;
                digit_data[2] = selected_mode_in ? SEG_1 : SEG_2;
                digit_data[3] = SEG_P;
            end
            PHASE_COUNTDOWN, PHASE_GAMEPLAY: begin
                digit_data[0] = SEG_F;
                digit_data[1] = SEG_I;
                digit_data[2] = SEG_G;
                // Proje "FIGHt" diyor, son harf 't' olmalı.
                digit_data[3] = SEG_T;
            end
            PHASE_GAMEOVER: begin
                // Proje dokümanındaki "P1-XX-" formatını 4 haneye sığdırmak için
                // [P/E][1/2/q][Onlar][Birler] formatını kullanıyoruz. Tire gösterilmiyor.
                case (winner_info_in)
                    2'b01: begin // P1 kazandı
                        digit_data[0] = SEG_P;
                        digit_data[1] = SEG_1;
                    end
                    2'b10: begin // P2 kazandı
                        digit_data[0] = SEG_P;
                        digit_data[1] = SEG_2;
                    end
                    2'b11: begin // Berabere
                        digit_data[0] = SEG_E;
                        digit_data[1] = SEG_Q;
                    end
                    default: begin
                        digit_data[0] = SEG_BLANK;
                        digit_data[1] = SEG_BLANK;
                    end
                endcase
                // digit_data[2] = SEG_DASH; // Tire için yer yok, bu satır kaldırıldı.
                // Süreyi kalan 2 hanede göster:
                digit_data[2] = number_to_seg(onlar);
                digit_data[3] = number_to_seg(birler);
            end
            default: begin
                digit_data[0] = SEG_BLANK;
                digit_data[1] = SEG_BLANK;
                digit_data[2] = SEG_BLANK;
                digit_data[3] = SEG_BLANK;
            end
        endcase
    end

		 // Aktif haneye karşılık gelen segment verisini çıkışa ata
	always @(*) begin
		 // seg_data_0_out için
		 if (current_digit_select_reg == 2'b00) begin
			  seg_data_0_out = digit_data[0];
		 end else begin
			  seg_data_0_out = SEG_BLANK;
		 end

		 // seg_data_1_out için
		 if (current_digit_select_reg == 2'b01) begin
			  seg_data_1_out = digit_data[1];
		 end else begin
			  seg_data_1_out = SEG_BLANK;
		 end

		 // seg_data_2_out için
		 if (current_digit_select_reg == 2'b10) begin
			  seg_data_2_out = digit_data[2];
		 end else begin
			  seg_data_2_out = SEG_BLANK;
		 end

		 // seg_data_3_out için
		 if (current_digit_select_reg == 2'b11) begin
			  seg_data_3_out = digit_data[3];
		 end else begin
			  seg_data_3_out = SEG_BLANK;
		 end
	end

    function [6:0] number_to_seg (input [3:0] number); // 'byte' yerine [3:0] veya integer kullanılabilir.
        case (number)
            4'd0: number_to_seg = SEG_0;
            4'd1: number_to_seg = SEG_1;
            4'd2: number_to_seg = SEG_2;
            4'd3: number_to_seg = SEG_3;
            4'd4: number_to_seg = SEG_4;
            4'd5: number_to_seg = SEG_5;
            4'd6: number_to_seg = SEG_6;
            4'd7: number_to_seg = SEG_7;
            4'd8: number_to_seg = SEG_8;
            4'd9: number_to_seg = SEG_9;
            default: number_to_seg = SEG_BLANK;
        endcase
    endfunction

endmodule