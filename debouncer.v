// debouncer.v
// Bu modül, fiziksel bir buton girişinden gelen zıplamaları filtreler (debounces)
// ve kararlı bir buton durumu ile tek atımlık bir pals sinyali üretir.

module debouncer (
    input wire       clk,       // Sistem saati (genellikle daha hızlı bir saat, örneğin 50MHz veya 100MHz)
    input wire       reset,     // Asenkron veya senkron reset (aktif yüksek)
    input wire       btn_in,    // Fiziksel buton girişi (zıplamalı sinyal)

    output wire      btn_out,   // Debounce edilmiş, kararlı buton durumu (basılıysa HIGH, değilse LOW)
    output wire      btn_single_pulse // Butona her basıldığında sadece bir clock döngüsü boyunca HIGH olan pals
);

    // Parametreler
    // DEBOUNCE_TIME_MS: Debounce süresi milisaniye cinsinden (örneğin 20ms)
    // CLK_FREQ_HZ: clk giriş saatinin frekansı (Hz cinsinden)
    // Bu parametreleri ana modülünüzde instantiate ederken geçirmelisiniz.
    // Örnek: debouncer #(.DEBOUNCE_TIME_MS(20), .CLK_FREQ_HZ(50_000_000)) my_debouncer (...);

    // Default değerler, eğer instantiate ederken belirtilmezse kullanılır
    parameter DEBOUNCE_TIME_MS = 20;    // 20 milisaniye (genellikle yeterli)
    parameter CLK_FREQ_HZ      = 50_000_000; // 50 MHz varsayımı

    // Sayacın ulaşması gereken maksimum değer.
    // COUNT_MAX = (CLK_FREQ_HZ / 1000) * DEBOUNCE_TIME_MS
    // Örn: 50MHz ve 20ms için -> (50,000,000 / 1000) * 20 = 50,000 * 20 = 1,000,000
    localparam DEBOUNCE_CNT_MAX = (CLK_FREQ_HZ / 1000) * DEBOUNCE_TIME_MS;

    // Sayacın bit genişliğini belirle
    // $clog2(N) = N'i temsil etmek için gereken minimum bit sayısıdır.
    // DEBOUNCE_CNT_MAX sayısını tutabilecek bit sayısı.
    // 1 milyonu tutmak için $clog2(1_000_000) = 20 bit gerekir.
    localparam COUNT_WIDTH = (DEBOUNCE_CNT_MAX > 0) ? $clog2(DEBOUNCE_CNT_MAX + 1) : 1;

    // Dahili register'lar
    reg  [COUNT_WIDTH-1:0] debounce_counter; // Debounce süresini sayan sayaç
    reg                    btn_in_sync1;    // Buton girişini senkronize etmek için ilk flip-flop
    reg                    btn_in_sync2;    // İkinci senkronizasyon aşaması (daha güvenli)
    reg                    btn_state;       // Debounce edilmiş, kararlı buton durumu
    reg                    btn_prev_state;  // Bir önceki clock cycle'daki debounced buton durumu

    // Buton girişini sisteme senkronize etme (Cross-Clock Domain (CDC) geçişi için)
    // Asenkron bir giriş olan btn_in'i clk domainine güvenli bir şekilde aktarır.
    // İki flip-flop kullanmak, glitches ve metastable durumları önlemek için standarttır.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_in_sync1 <= 1'b0;
            btn_in_sync2 <= 1'b0;
        end else begin
            btn_in_sync1 <= btn_in;
            btn_in_sync2 <= btn_in_sync1;
        end
    end

    // Debounce mantığı
    // Bu always bloğu, debounced buton durumunu (btn_state) günceller.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            debounce_counter <= 0;
            btn_state <= 1'b0; // Reset'te buton basılı değil
            btn_prev_state <= 1'b0;
        end else begin
            // Bir önceki debounced durumu kaydet, yükselen kenar tespiti için
            btn_prev_state <= btn_state;

            // Eğer senkronize edilmiş buton girişi mevcut debounced durumdan farklıysa,
            // yani butonun durumu değişiyorsa (zıplamalar veya gerçek bir basış/bırakma)
            if (btn_in_sync2 != btn_state) begin
                // Sayıcıyı artır
                if (debounce_counter == DEBOUNCE_CNT_MAX - 1) begin
                    // Sayıcı, debounce süresi boyunca stabil kaldığını gösterdi
                    btn_state <= btn_in_sync2; // Debounced durumu güncelle
                    debounce_counter <= 0;     // Sayıcıyı sıfırla
                end else begin
                    // Henüz debounce süresi dolmadı, saymaya devam et
                    debounce_counter <= debounce_counter + 1;
                end
            end else begin
                // Butonun durumu stabil (değişmiyor), sayıcıyı sıfırla
                // Bu, butona uzun süre basılı tutulduğunda sayacın dolmasını önler.
                debounce_counter <= 0;
            end
        end
    end

    // Çıkış atamaları
    // btn_out: Debounce edilmiş, kararlı buton durumu
    assign btn_out = btn_state;

    // btn_single_pulse: Yükselen kenar algılama (basış anında bir clock cycle HIGH)
    // Bu, menü seçimi, oyun başlatma gibi tek seferlik eylemler için idealdir.
    assign btn_single_pulse = (btn_state == 1'b1) && (btn_prev_state == 1'b0);

endmodule