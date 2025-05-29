// cpu_bot.v
// Tek oyunculu modda CPU kontrollü rakibin davranışlarını yönetir.
// Sizin LFSR_16 modülünüzü kullanır.
module cpu_bot (
    input wire clk_game_logic, // Oyun mantığı saati
    input wire reset,
    input wire enable_bot,      // Botun aktif olup olmadığını belirler (1P modunda 1)

    // Oyun durumu girişleri (botun karar vermesi için)
    input wire [9:0] p1_x_pos_in,   // Rakip (Oyuncu 1) X konumu
    input wire [9:0] p2_x_pos_in,   // Kendi (CPU/Oyuncu 2) X konumu

    // CPU tarafından üretilen hareket çıkışları
    output reg cpu_move_left_out,
    output reg cpu_move_right_out,
    output reg cpu_attack_out
);

    // CPU davranış parametreleri
    localparam ACTION_INTERVAL = 30; // Yaklaşık 0.5 saniyede bir eylem değiştir (60Hz'de)
    // ATTACK_CHANCE_DIVISOR = 3; // Saldırı olasılığı (1/X) - LFSR bitleri ile değiştirilecek
    localparam MIN_DISTANCE_TO_ADVANCE = 80; // Rakibe yaklaşmak için minimum mesafe farkı
    localparam LFSR_SEED_VALUE = 16'hACE1; // LFSR için başlangıç tohumu (0 olmamalı)

    reg [$clog2(ACTION_INTERVAL)-1:0] action_timer_reg;
    
    // LFSR Modülünün Instantiate Edilmesi
    wire [15:0] lfsr_pseudo_random_value; // LFSR çıkışı
    reg load_lfsr_on_reset;          // LFSR'a tohum yüklemek için sinyal

    LFSR_16 lfsr_unit (
        .clk(clk_game_logic),
        .reset(reset),                // shift_register'ı sıfırlar
        .enable(enable_bot),          // Bot aktifken LFSR çalışır
        .load_seed(load_lfsr_on_reset), // Reset sırasında tohumu yükle
        .seed(LFSR_SEED_VALUE),
        .LFSR_out(lfsr_pseudo_random_value)
    );

    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            cpu_move_left_out <= 1'b0;
            cpu_move_right_out <= 1'b0;
            cpu_attack_out <= 1'b0;
            action_timer_reg <= 0;
            load_lfsr_on_reset <= 1'b1; // Reset sırasında LFSR'a tohum yükle
        end else begin
            load_lfsr_on_reset <= 1'b0; // Reset sonrası yüklemeyi bırak

            if (enable_bot) begin
                // action_timer_reg LFSR'dan bağımsız olarak sayar
                if (action_timer_reg == ACTION_INTERVAL - 1) begin
                    action_timer_reg <= 0;

                    // Karar verme mantığı LFSR çıkışını kullanır
                    // 1. Saldırı kararı (Örnek: LFSR'ın belirli bitleri 1 ise %25 olasılık)
                    if (lfsr_pseudo_random_value[15:14] == 2'b11) begin // Yaklaşık %25 şans
                        cpu_attack_out <= 1'b1;
                    end else begin
                        cpu_attack_out <= 1'b0;
                    end

                    // 2. Hareket kararı (saldırmıyorsa)
                    if (!cpu_attack_out) begin
                        // Rakibe göre konum
                        if (p2_x_pos_in < p1_x_pos_in - MIN_DISTANCE_TO_ADVANCE) begin // CPU solda ve uzakta
                            // %75 sağa git, %25 dur (LFSR bitlerini kullanarak)
                            cpu_move_right_out <= (lfsr_pseudo_random_value[1:0] != 2'b00); 
                            cpu_move_left_out <= 1'b0;
                        end else if (p2_x_pos_in > p1_x_pos_in + MIN_DISTANCE_TO_ADVANCE) begin // CPU sağda ve uzakta
                            // %75 sola git, %25 dur
                            cpu_move_left_out <= (lfsr_pseudo_random_value[1:0] != 2'b00); 
                            cpu_move_right_out <= 1'b0;
                        end else begin // Yakın mesafede
                            // Rastgele hareket veya pozisyon koruma
                            case (lfsr_pseudo_random_value[3:2]) // LFSR'dan 2 bit kullan
                                2'b00: begin cpu_move_left_out <= 1'b0; cpu_move_right_out <= 1'b0; end // Dur
                                2'b01: begin cpu_move_left_out <= 1'b1; cpu_move_right_out <= 1'b0; end // Sola
                                2'b10: begin cpu_move_left_out <= 1'b0; cpu_move_right_out <= 1'b1; end // Sağa
                                default: begin cpu_move_left_out <= 1'b0; cpu_move_right_out <= 1'b0; end // Dur (veya başka bir hareket)
                            endcase
                        end
                    end else begin // Saldırıyorsa hareket etme
                        cpu_move_left_out <= 1'b0;
                        cpu_move_right_out <= 1'b0;
                    end
                end else begin
                    action_timer_reg <= action_timer_reg + 1;
                     // Saldırıyı bir süre sonra bitir, eğer devam ediyorsa (örneğin 5 frame sonra)
                    if (cpu_attack_out && action_timer_reg > 5) begin 
                         cpu_attack_out <= 1'b0;
                    end
                end
            end else begin // Bot aktif değilse
                cpu_move_left_out <= 1'b0;
                cpu_move_right_out <= 1'b0;
                cpu_attack_out <= 1'b0;
                action_timer_reg <= 0;
            end
        end
    end
endmodule