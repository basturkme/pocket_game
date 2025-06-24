// input_handler.v (Düzeltilmiş ve tek atımlık palslar eklenmiş)
module input_handler (
    input wire clk, // System clock (e.g., 50MHz for debouncer)
    input wire reset,

    // Player 1 Raw Inputs (e.g., from FPGA KEYs)
    input wire p1_raw_move_left_key,
    input wire p1_raw_move_right_key,
    input wire p1_raw_attack_key,
    input wire p1_raw_confirm_key, // Eklenen menü onay butonu

    // Player 2 Raw Inputs (e.g., from external keypad via GPIO)
    input wire p2_raw_move_left_key,
    input wire p2_raw_move_right_key,
    input wire p2_raw_attack_key,

    // Player 1 Debounced Outputs (Basılı tutma durumu)
    output wire p1_move_left,
    output wire p1_move_right,
    output wire p1_attack,
    output wire p1_confirm, // Eklenen menü onay butonu debounced çıktısı

    // Player 1 Single Pulse Outputs (Yükselen kenar algılama)
    output wire p1_move_left_pulse,
    output wire p1_move_right_pulse,
    output wire p1_attack_pulse,
    output wire p1_confirm_pulse, // Eklenen menü onay butonu tek pals çıktısı

    // Player 2 Debounced Outputs (Basılı tutma durumu)
    output wire p2_move_left,
    output wire p2_move_right,
    output wire p2_attack,

    // Player 2 Single Pulse Outputs (Yükselen kenar algılama)
    output wire p2_move_left_pulse,
    output wire p2_move_right_pulse,
    output wire p2_attack_pulse
);

    // DEBOUNCE_THRESHOLD: 50MHz için 20ms debounce (50,000,000 * 0.020 = 1,000,000)
    parameter DEBOUNCE_THRESHOLD = 1_000_000;

    // Genişletilmiş buton listesi
    // 0: p1_raw_move_left_key
    // 1: p1_raw_move_right_key
    // 2: p1_raw_attack_key
    // 3: p1_raw_confirm_key (YENİ)
    // 4: p2_raw_move_left_key
    // 5: p2_raw_move_right_key
    // 6: p2_raw_attack_key
    generate
        genvar i;
        for (i = 0; i < 7; i = i + 1) begin : debounce_loop
            // Sayacın ve durum register'larının bit genişliğini dinamik olarak ayarla
            reg [$clog2(DEBOUNCE_THRESHOLD)-1:0] debounce_counter_reg;
            reg raw_synced_state_reg; // Raw input'ı senkronize etmek için (1. FF)
            reg raw_prev_synced_state_reg; // Raw input'ı senkronize etmek için (2. FF)
            reg debounced_out_reg;
            reg debounced_prev_state_reg;

            // O anki işlenen raw key girişi
            wire current_raw_key_input;

            assign current_raw_key_input = (i == 0) ? p1_raw_move_left_key :
                                           (i == 1) ? p1_raw_move_right_key :
                                           (i == 2) ? p1_raw_attack_key :
                                           (i == 3) ? p1_raw_confirm_key : // Yeni buton
                                           (i == 4) ? p2_raw_move_left_key :
                                           (i == 5) ? p2_raw_move_right_key :
                                                          p2_raw_attack_key;

            // Sequential logic for debouncer
            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    raw_synced_state_reg    <= 1'b1; // Raw input'ın aktif düşük ve bırakılmış olduğunu varsay
                    raw_prev_synced_state_reg <= 1'b1; // Aynı şekilde
                    debounce_counter_reg    <= 0;
                    debounced_out_reg       <= 1'b0; // Debounce çıktısı başlangıçta basılı değil
                    debounced_prev_state_reg <= 1'b0;
                end else begin
                    // Input Synchronization (2-FF synchronizer)
                    raw_synced_state_reg    <= current_raw_key_input;
                    raw_prev_synced_state_reg <= raw_synced_state_reg;

                    // Store previous debounced state for edge detection
                    debounced_prev_state_reg <= debounced_out_reg;

                    // Debounce logic
                    // Eğer senkronize edilmiş raw input, debounced output'tan farklıysa (değişim var)
                    if (raw_prev_synced_state_reg != (~debounced_out_reg)) begin // Not: ~debounced_out_reg, çünkü debounced_out_reg aktif yüksek, raw ise aktif düşük
                        debounce_counter_reg <= 0; // Sayacı sıfırla, değişimi beklemeye başla
                    end else if (debounce_counter_reg < DEBOUNCE_THRESHOLD -1 ) begin
                        // Sayıcı dolmadıysa devam et
                        debounce_counter_reg <= debounce_counter_reg + 1;
                    end else begin
                        // Sayıcı doldu, input stabil. Debounced state'i güncelle (aktif düşükten aktif yükseğe çevir)
                        debounced_out_reg <= ~raw_prev_synced_state_reg;
                    end
                end
            end

            // Assign outputs (debounced and pulse)
            // assign ile sürekli atama, reg olarak tanımlanan output'ları kullanırken syntax hatası verebilir.
            // Output'ları wire yapıp assign ile bağlayabiliriz, veya generate bloğu içinde assign'ı if-else ile reg'lere bağlayabiliriz.
            // En temiz yol, output'ları wire yapıp assign ile bağlamak.

            // Tek atımlık pals (yükselen kenar)
            wire single_pulse_output = (debounced_out_reg == 1'b1) && (debounced_prev_state_reg == 1'b0);

            // Çıkışlara atama
            // Bu kısmı da if/else if ile yapalım, böylece tek bir if bloğu içinde hepsi atanır
            if (i == 0) begin
                assign p1_move_left = debounced_out_reg;
                assign p1_move_left_pulse = single_pulse_output;
            end else if (i == 1) begin
                assign p1_move_right = debounced_out_reg;
                assign p1_move_right_pulse = single_pulse_output;
            end else if (i == 2) begin
                assign p1_attack = debounced_out_reg;
                assign p1_attack_pulse = single_pulse_output;
            end else if (i == 3) begin // Yeni onay butonu
                assign p1_confirm = debounced_out_reg;
                assign p1_confirm_pulse = single_pulse_output;
            end else if (i == 4) begin
                assign p2_move_left = debounced_out_reg;
                assign p2_move_left_pulse = single_pulse_output;
            end else if (i == 5) begin
                assign p2_move_right = debounced_out_reg;
                assign p2_move_right_pulse = single_pulse_output;
            end else begin // i == 6
                assign p2_attack = debounced_out_reg;
                assign p2_attack_pulse = single_pulse_output;
            end

        end // end of for loop block
    endgenerate
endmodule