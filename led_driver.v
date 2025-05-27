//led_driver.v
// Oyuncu sağlıklarını ve oyun sonu durumunu LED'lerde gösterir.
module led_driver (
    input wire clk, // Yanıp sönme efekti için saat (örn: clk_game_logic veya daha yavaşı)
    input wire reset,

    // Girişler
    input wire [2:0] p1_health_in, // Oyuncu 1'in kalan sağlığı (0-3)
    input wire [2:0] p2_health_in, // Oyuncu 2'nin kalan sağlığı (0-3)
    input wire blink_enable_in,    // Oyun bittiğinde yanıp sönmeyi etkinleştir (game_logic_fsm'den)
    input wire [1:0] game_phase_in,// Menüde LED'leri kapatmak için

    // Çıkışlar (Doğrudan FPGA LED pinlerine bağlanacak)
    output reg [2:0] p1_health_led_out, // P1 için 3 LED
    output reg [2:0] p2_health_led_out, // P2 için 3 LED
    output wire all_leds_physical_out // Bu, pocket_game.v'deki LED_GAME_OVER_BLINK'e bağlanabilir.
                                     // Eğer tüm LED'ler ayrı ayrı sürülüyorsa, bu çıkış gerekmeyebilir
                                     // ve yanıp sönme mantığı p1/p2_health_led_out'a uygulanır.
);

    localparam PHASE_MENU = 2'b00;
    localparam PHASE_GAMEOVER = 2'b11;

    // Yanıp sönme için sayaç (blink_enable_in aktifken)
    localparam BLINK_RATE_DIVIDER = 30; // 60Hz'de yaklaşık 0.5 saniyede bir durum değiştirir
    reg [$clog2(BLINK_RATE_DIVIDER)-1:0] blink_counter_reg;
    reg blink_state_reg; // Yanıp sönme durumu (0 veya 1)

    initial begin
        blink_counter_reg = 0;
        blink_state_reg = 0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            blink_counter_reg <= 0;
            blink_state_reg <= 1'b0;
        end else begin
            if (blink_enable_in && game_phase_in == PHASE_GAMEOVER) begin
                if (blink_counter_reg == BLINK_RATE_DIVIDER - 1) begin
                    blink_counter_reg <= 0;
                    blink_state_reg <= ~blink_state_reg;
                end else begin
                    blink_counter_reg <= blink_counter_reg + 1;
                end
            end else begin
                blink_counter_reg <= 0; // Yanıp sönme aktif değilse sayacı sıfırla
                blink_state_reg <= 1'b0;  // LED'ler normalde yanık (veya sönük, tasarıma bağlı)
            end
        end
    end

    always @(*) begin
        if (game_phase_in == PHASE_MENU) begin
            p1_health_led_out = 3'b000; // Menüde tüm LED'ler sönük
            p2_health_led_out = 3'b000;
        end else if (game_phase_in == PHASE_GAMEOVER && blink_enable_in) begin
            // Tüm LED'ler yanıp söner (sağlığa bakılmaksızın)
            p1_health_led_out = blink_state_reg ? 3'b111 : 3'b000;
            p2_health_led_out = blink_state_reg ? 3'b111 : 3'b000;
        end else begin // Oyun veya geri sayım aşaması
            // Oyuncu 1 Sağlık LED'leri (3 LED, 3 HP)
            // HP 3 -> 111, HP 2 -> 011, HP 1 -> 001, HP 0 -> 000
            case (p1_health_in)
                3'd3:    p1_health_led_out = 3'b111;
                3'd2:    p1_health_led_out = 3'b011;
                3'd1:    p1_health_led_out = 3'b001;
                default: p1_health_led_out = 3'b000;
            endcase

            // Oyuncu 2 Sağlık LED'leri
            case (p2_health_in)
                3'd3:    p2_health_led_out = 3'b111;
                3'd2:    p2_health_led_out = 3'b011;
                3'd1:    p2_health_led_out = 3'b001;
                default: p2_health_led_out = 3'b000;
            endcase
        end
    end

    // Eğer tüm LED'leri tek bir sinyalle kontrol etmek isteniyorsa:
    assign all_leds_physical_out = (game_phase_in == PHASE_GAMEOVER && blink_enable_in && blink_state_reg);

endmodule
