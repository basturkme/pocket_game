// cpu_bot.v
// Tek oyunculu modda CPU kontrollü rakibin davranışlarını yönetir.
module cpu_bot (
    input wire clk_game_logic, // Oyun mantığı saati
    input wire reset,
    input wire enable_bot,     // Botun aktif olup olmadığını belirler (1P modunda 1)

    // Oyun durumu girişleri (botun karar vermesi için)
    input wire [9:0] p1_x_pos_in,      // Rakip (Oyuncu 1) X konumu
    input wire [9:0] p2_x_pos_in,      // Kendi (CPU/Oyuncu 2) X konumu
    // input wire [2:0] p1_state_in,   // Rakibin durumu (saldırı, blok vb.)
    // input wire p1_is_attacking_in, // Rakip saldırıyor mu?

    // CPU tarafından üretilen hareket çıkışları
    output reg cpu_move_left_out,
    output reg cpu_move_right_out,
    output reg cpu_attack_out
);

    // CPU davranış parametreleri
    localparam ACTION_INTERVAL = 30; // Yaklaşık 0.5 saniyede bir eylem değiştir (60Hz'de)
    localparam ATTACK_CHANCE_DIVISOR = 3; // Saldırı olasılığı (1/X)
    localparam MIN_DISTANCE_TO_ADVANCE = 80; // Rakibe yaklaşmak için minimum mesafe farkı

    reg [$clog2(ACTION_INTERVAL)-1:0] action_timer_reg;
    reg [31:0] random_seed; // Basit bir sözde rastgele sayı üreteci için tohum

    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            cpu_move_left_out <= 1'b0;
            cpu_move_right_out <= 1'b0;
            cpu_attack_out <= 1'b0;
            action_timer_reg <= 0;
            random_seed <= 32'hDEADBEEF; // Başlangıç tohumu
        end else begin
            if (enable_bot) begin
                // Basit LFSR tabanlı sözde rastgele sayı üreteci
                random_seed <= (random_seed << 1) | ^(random_seed & 32'h8000001B); // LFSR (örnek polinom)

                if (action_timer_reg == ACTION_INTERVAL - 1) begin
                    action_timer_reg <= 0;

                    // Karar verme mantığı
                    // 1. Saldırı kararı
                    if (random_seed % ATTACK_CHANCE_DIVISOR == 0) begin
                        cpu_attack_out <= 1'b1;
                    end else begin
                        cpu_attack_out <= 1'b0;
                    end

                    // 2. Hareket kararı (saldırmıyorsa)
                    if (!cpu_attack_out) begin
                        // Rakibe göre konum
                        if (p2_x_pos_in < p1_x_pos_in - MIN_DISTANCE_TO_ADVANCE) begin // CPU solda ve uzakta
                            cpu_move_right_out <= (random_seed[1:0] != 2'b00); // %75 sağa git
                            cpu_move_left_out <= 1'b0;
                        end else if (p2_x_pos_in > p1_x_pos_in + MIN_DISTANCE_TO_ADVANCE) begin // CPU sağda ve uzakta
                            cpu_move_left_out <= (random_seed[1:0] != 2'b00); // %75 sola git
                            cpu_move_right_out <= 1'b0;
                        end else begin // Yakın mesafede
                            // Rastgele hareket veya pozisyon koruma
                            case (random_seed[3:2])
                                2'b00: begin cpu_move_left_out <= 1'b0; cpu_move_right_out <= 1'b0; end // Dur
                                2'b01: begin cpu_move_left_out <= 1'b1; cpu_move_right_out <= 1'b0; end // Sola
                                2'b10: begin cpu_move_left_out <= 1'b0; cpu_move_right_out <= 1'b1; end // Sağa
                                default: begin cpu_move_left_out <= 1'b0; cpu_move_right_out <= 1'b0; end // Dur
                            endcase
                        end
                    end else // Saldırıyorsa hareket etme
                        cpu_move_left_out <= 1'b0;
                        cpu_move_right_out <= 1'b0;
                    end
                end 
				
					 /*else begin
                    action_timer_reg <= action_timer_reg + 1;
                    // Mevcut eylemi bir süre devam ettir (saldırı hariç)
                    if (cpu_attack_out && action_timer_reg > (ACTION_INTERVAL/4)) begin // Saldırıyı kısa tut
                        cpu_attack_out <= 1'b0;
                    end*/
                
            end /*else begin // Bot aktif değilse
                cpu_move_left_out <= 1'b0;
                cpu_move_right_out <= 1'b0;
                cpu_attack_out <= 1'b0;
                action_timer_reg <= 0;
            end*/
        
    end

endmodule
