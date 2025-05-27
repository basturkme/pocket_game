// debouncer.v
// Genel amaçlı sektirme önleyici alt modül
module debouncer (
    input wire clk,             // Saat girişi
    input wire reset,           // Aktif yüksek reset
    input wire raw_in,          // Ham (sektirmeli) giriş
    output reg debounced_out    // Sektirme önlemesi yapılmış çıkış
);
    // Sektirme Önleme Süresi (saat döngüsü cinsinden)
    // input_handler'a gelen clk, clk_game_logic (60Hz) ise,
    // 60Hz * 0.020s (20ms) = 1.2 -> ~2 saat döngüsü.
    // DEBOUNCE_CLOCKS = 2 ise ~33ms olur.
    localparam DEBOUNCE_CLOCKS = 2; // Kullanılan saate göre ayarlanabilir

    reg [$clog2(DEBOUNCE_CLOCKS+1)-1:0] counter_reg; // Sayaç
    reg internal_state_reg; // Sektirme önlenmiş girişin dahili olarak saklanan durumu

    initial begin
        debounced_out = 1'b0;
        counter_reg = 0;
        internal_state_reg = 1'b0; // Butonların başlangıçta basılmadığını varsayalım
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            debounced_out <= 1'b0;
            counter_reg <= 0;
            internal_state_reg <= 1'b0;
        end else begin
            if (raw_in == internal_state_reg) begin
                // Giriş stabil veya mevcut dahili duruma geri döndü
                counter_reg <= 0;
            end else begin
                // Giriş, dahili durumdan farklılaştı (potansiyel sektirme)
                if (counter_reg < DEBOUNCE_CLOCKS) begin
                    counter_reg <= counter_reg + 1;
                end else begin
                    // Sayaç doldu, giriş DEBOUNCE_CLOCKS süresince farklı kaldı
                    internal_state_reg <= raw_in; // Dahili durumu güncelle
                    debounced_out <= raw_in;      // Sektirme önlenmiş çıkışı güncelle
                    counter_reg <= 0;             // Sayacı sıfırla
                end
            end
        end
    end
endmodule