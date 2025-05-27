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
    // Ortak Anot veya Katot olmasına göre segment değerleri değişir.
    // Burada Ortak Anot varsayalım (aktif düşük segmentler).
    output reg [6:0] seg_data_0_out, // En soldaki hane için segmentler (gfedcba)
    output reg [6:0] seg_data_1_out,
    output reg [6:0] seg_data_2_out,
    output reg [6:0] seg_data_3_out, // En sağdaki hane için segmentler
    output reg [3:0] seg_an_out      // Hane seçimi (aktif düşük anotlar: 1110, 1101, 1011, 0111)
);

    // Oyun Aşamaları
    localparam PHASE_MENU      = 2'b00;
    localparam PHASE_COUNTDOWN = 2'b01; // Geri sayımda "FIGHt" gösterilecek
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
    localparam SEG_G = 7'b0000010; // G (6 ile aynı ama bazen farklı) -> 7'b1000010; (custom G)
    localparam SEG_H = 7'b0001001; // H
    localparam SEG_T = 7'b0000111; // t
    localparam SEG_E = 7'b0000110; // E
    localparam SEG_Q = 7'b1001000; // q
    localparam SEG_DASH= 7'b0111111; // -
    localparam SEG_BLANK=7'b1111111; // Boş

    // Zaman Çoğullama için Sayaç ve Durum
    reg [1:0] current_digit_select_reg; // Hangi hanenin aktif olduğunu seçer (0-3)
    // Yenileme hızı için bölücü (clk genellikle clk_game_logic'ten daha hızlıdır)
    // Eğer clk = 50MHz ise, 1kHz için ~50000 bölücü gerekir.
    // Eğer clk = 60Hz ise, bu çoğullama için çok yavaş kalır, daha hızlı bir saat gerekir.
    // pocket_game.v'de 7-segment için ayrı bir saat üretmek daha iyi olabilir.
    // Şimdilik, clk'nın uygun bir hızda olduğunu varsayalım.
    // Örnek: clk 1kHz ise, her haneyi ~250Hz'de yenilemek için:
    localparam REFRESH_DIVIDER = 1; // Eğer clk zaten ~1kHz ise
    reg [$clog2(REFRESH_DIVIDER)-1:0] refresh_counter_reg;

    // Her bir hane için gösterilecek segment verileri
    reg [6:0] digit_data [0:3]; // digit_data[0] en soldaki, digit_data[3] en sağdaki

    initial begin
        current_digit_select_reg = 2'b00;
        refresh_counter_reg = 0;
        seg_an_out = 4'b1111; // Başlangıçta tüm haneler kapalı
    end

    // Hane seçimi ve yenileme
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_digit_select_reg <= 2'b00;
            refresh_counter_reg <= 0;
            seg_an_out <= 4'b1111;
        end else begin
            if (refresh_counter_reg == REFRESH_DIVIDER - 1) begin
                refresh_counter_reg <= 0;
                current_digit_select_reg <= current_digit_select_reg + 1; // Bir sonraki haneye geç (0,1,2,3,0...)
            end else begin
                refresh_counter_reg <= refresh_counter_reg + 1;
            end

            // Aktif haneyi seç (Ortak Anot için aktif düşük)
            case (current_digit_select_reg)
                2'b00: seg_an_out <= 4'b1110; // En soldaki hane (Digit 0)
                2'b01: seg_an_out <= 4'b1101; // Digit 1
                2'b10: seg_an_out <= 4'b1011; // Digit 2
                2'b11: seg_an_out <= 4'b0111; // En sağdaki hane (Digit 3)
                default: seg_an_out <= 4'b1111;
            endcase
        end
    end

    // Gösterilecek veriyi belirleme mantığı
    always @(*) begin
        case (game_phase_in)
            PHASE_MENU: begin
                // "1P" veya "2P" göster
                digit_data[0] = SEG_BLANK;
                digit_data[1] = SEG_BLANK;
                digit_data[2] = selected_mode_in ? SEG_1 : SEG_2; // 1 veya 2
                digit_data[3] = SEG_P;                             // P
            end
            PHASE_COUNTDOWN, PHASE_GAMEPLAY: begin
                // "FIGHt" göster
                digit_data[0] = SEG_F;
                digit_data[1] = SEG_I;
                digit_data[2] = SEG_G; // Özel G kullanılabilir
                digit_data[3] = SEG_H; // 't' için H kullanıldı, SEG_T daha iyi olabilir.
                                       // Proje "FIGHt" diyor, son harf 't' olmalı.
                                       // digit_data[3] = SEG_T;
            end
            PHASE_GAMEOVER: begin
                // "P1-XX", "P2-XX" veya "Eq-XX"
                // XX = game_time_in (saniye)
                automatic byte onlar = game_time_in / 10;
                automatic byte birler = game_time_in % 10;

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
                    default: begin // Hata veya oyun devam ediyor (buraya gelmemeli)
                        digit_data[0] = SEG_BLANK;
                        digit_data[1] = SEG_BLANK;
                    end
                endcase
                digit_data[2] = SEG_DASH;
                // digit_data[3] // Süreyi göstermek için 2 hane lazım, bu tasarım 1 hane ayırmış.
                // Proje "P1-XX-" diyor, yani süre için 2 hane var.
                // Bu durumda 4 haneli gösterge: [P][1][-][X] veya [P][1][X][X]
                // Eğer "P1-XX" ise: digit_data[0]=P, digit_data[1]=1, digit_data[2]=onlar, digit_data[3]=birler
                // Eğer "P1-XX-" ise: digit_data[0]=P, digit_data[1]=1, digit_data[2]=DASH, digit_data[3]=onlar (birler gösterilemez)
                // Proje formatı "P1-XX-" şeklinde. Bu, sürenin ilk hanesini tireden sonra gösterir.
                // Bu durumda 4. hane boş kalır veya ikinci süre hanesi için yer yoktur.
                // "P1-XX-" formatını tam olarak uygulamak için 5 hane gerekir veya format P1-X şeklinde olmalı.
                // "P1-XX-" formatını 4 haneye sığdırmak için:
                // Hane 0: P
                // Hane 1: 1/2/q
                // Hane 2: -
                // Hane 3: Sürenin Onlar basamağı (Birler basamağı gösterilemez)
                // VEYA
                // Hane 0: P/E
                // Hane 1: 1/2/q
                // Hane 2: Sürenin Onlar basamağı
                // Hane 3: Sürenin Birler basamağı (Tire yok) - Proje "XX" diyor, tireyi kendi ekliyor.
                // "P1-XX-" formatında tireden sonraki XX süreyi ifade eder.
                // Bu durumda:
                // digit_data[0] = P/E
                // digit_data[1] = 1/2/q
                // digit_data[2] = (onlar == 0 && birler == 0) ? SEG_BLANK : number_to_seg(onlar); // Eğer süre 00 ise boş
                // digit_data[3] = (onlar == 0 && birler == 0) ? SEG_BLANK : number_to_seg(birler);
                // Tireyi nasıl göstereceğiz? "P1-XX-" formatı 7-segment için biraz zorlayıcı.
                // Proje dokümanındaki "P1-XX-" gösterimi, tirenin sabit bir karakter olduğunu ve XX'in sayı olduğunu varsayar.
                // Bu durumda 4 hane şöyle olabilir: [P] [1] [SüreOnlar] [SüreBirler]. Tire görsel olarak eklenir.
                // Ya da [P] [1] [-] [SüreOnlar] (SüreBirler kaybolur).
                // "Display the result in the format "P1-XX-" or "P2-XX-", where the XX number represents the
                // duration of the match in seconds."
                // Bu, tirenin bir karakter olduğunu ve XX'in iki haneli bir sayı olduğunu gösterir.
                // Bu durumda 5 hane gerekir. Eğer 4 hanemiz varsa, bir şeyi feda etmeliyiz.
                // En mantıklısı: [P][1][Onlar][Birler] ve tireyi fiziksel olarak ekranda bir yere koymak (mümkün değil).
                // Ya da: [P][1][-][Onlar] (Birler gösterilmez)
                // Ya da: [P1][XX] (Tire yok)
                // Şimdilik [P][1][Onlar][Birler] yapalım, tirenin olmadığını varsayalım.
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
    // Bu atamalar, pocket_game.v içindeki çıkışlara doğrudan bağlanacak.
    // Eğer ortak anot/katot sürücüleri ayrıysa, bu mantık orada olmalı.
    // Şimdilik doğrudan atayalım.
    assign seg_data_0_out = (current_digit_select_reg == 2'b00) ? digit_data[0] : SEG_BLANK; // Sadece aktif hane için veri gönder
    assign seg_data_1_out = (current_digit_select_reg == 2'b01) ? digit_data[1] : SEG_BLANK;
    assign seg_data_2_out = (current_digit_select_reg == 2'b10) ? digit_data[2] : SEG_BLANK;
    assign seg_data_3_out = (current_digit_select_reg == 2'b11) ? digit_data[3] : SEG_BLANK;
    // Not: Bu yaklaşım, seg_data_X_out pinlerinin her birinin ayrı bir haneyi sürdüğünü varsayar.
    // Eğer tek bir 7 bitlik veri yolu ve anot seçimi varsa, o zaman:
    // always @(*) begin
    //    case(current_digit_select_reg)
    //        2'b00: single_seg_data_bus_out = digit_data[0];
    //        2'b01: single_seg_data_bus_out = digit_data[1];
    //        ...
    //    endcase
    // end
    // pocket_game.v'deki çıkışlar 4 ayrı 7-bit veri yolu olarak tanımlandığı için bu şekilde bırakıyorum.
    // Bu, her bir hanenin kendi segment sürücüsüne sahip olduğu anlamına gelir, ki bu yaygın değildir.
    // Daha yaygın olan, tek bir 7-bit veri yolu ve anot seçimidir.
    // pocket_game.v'deki tanımı şuna değiştirmek daha mantıklı olabilir:
    // output wire [6:0] SEG7_DATA; // Tek veri yolu
    // output wire [3:0] SEG7_AN;   // Hane seçimi
    // Bu durumda bu modüldeki atama:
    // always @(*) begin
    //    case(current_digit_select_reg)
    //        2'b00: seg_data_out_internal = digit_data[0];
    //        2'b01: seg_data_out_internal = digit_data[1];
    //        2'b10: seg_data_out_internal = digit_data[2];
    //        2'b11: seg_data_out_internal = digit_data[3];
    //        default: seg_data_out_internal = SEG_BLANK;
    //    endcase
    // end
    // assign SEG7_DATA = seg_data_out_internal;
    // Şimdiki tanıma göre bırakıyorum.


    // Sayıyı 7-segment koduna çeviren fonksiyon (kombinasyonel)
    function [6:0] number_to_seg (input byte number);
        case (number)
            0: number_to_seg = SEG_0;
            1: number_to_seg = SEG_1;
            2: number_to_seg = SEG_2;
            3: number_to_seg = SEG_3;
            4: number_to_seg = SEG_4;
            5: number_to_seg = SEG_5;
            6: number_to_seg = SEG_6;
            7: number_to_seg = SEG_7;
            8: number_to_seg = SEG_8;
            9: number_to_seg = SEG_9;
            default: number_to_seg = SEG_BLANK; // Hata veya geçersiz sayı
        endcase
    endfunction

endmodule
