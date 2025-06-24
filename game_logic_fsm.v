// game_logic_fsm.v
// - 99 saniyelik oyun sayacı (game_seconds_elapsed_out) eklendi.
// - Sayaç artık 0'dan 99'a ileri sayıyor.
// - Süre bittiğinde kazananı belirler.
// - Yeni oyun başladığında oyuncu pozisyonlarını sıfırlamak için o_software_reset çıkışı ekler.
module game_logic_fsm (
    input wire clk_game_logic,
    input wire reset,
    input wire p1_confirm_in,
    input wire selected_mode_in,
    input wire [9:0] p1_x_in,
    input wire [2:0] p1_state_in,
    input wire p1_is_attacking_active_in,
    input wire [9:0] p1_hitbox_x1_in,
    input wire [9:0] p1_hitbox_x2_in,
    input wire [9:0] p1_hurtbox_x1_in,
    input wire [9:0] p1_hurtbox_x2_in,
    input wire p1_is_moving_backward_in,
    input wire p1_is_actively_blocking_in,
    input wire p1_is_facing_right_in,
    input wire [9:0] p2_x_in,
    input wire [2:0] p2_state_in,
    input wire p2_is_attacking_active_in,
    input wire [9:0] p2_hitbox_x1_in,
    input wire [9:0] p2_hitbox_x2_in,
    input wire [9:0] p2_hurtbox_x1_in,
    input wire [9:0] p2_hurtbox_x2_in,
    input wire p2_is_moving_backward_in,
    input wire p2_is_actively_blocking_in,
    input wire p2_is_facing_right_in,
    output reg [1:0] game_phase_out,
    output reg [2:0] countdown_value_out,
    output reg [6:0] game_seconds_elapsed_out, // 99'a kadar sayabilmesi için 7-bit
    output reg [1:0] winner_info_out,
    output reg [2:0] p1_hp_out,
    output reg [2:0] p1_bp_out,
    output reg [2:0] p2_hp_out,
    output reg [2:0] p2_bp_out,
    output reg all_leds_blink_cmd_out,
    output reg p1_hit_confirm_out,
    output reg p1_block_confirm_out,
    output reg p2_hit_confirm_out,
    output reg p2_block_confirm_out,
    output reg o_software_reset
);

    localparam PHASE_MENU        = 2'b00;
    localparam PHASE_COUNTDOWN   = 2'b01;
    localparam PHASE_GAMEPLAY    = 2'b10;
    localparam PHASE_GAMEOVER    = 2'b11;

    localparam P_STATE_HITSTUN   = 3'b110;
    localparam P_STATE_BLOCKSTUN = 3'b111;

    localparam MAX_HEALTH = 3;
    localparam MAX_BLOCK  = 3;
    localparam COUNTDOWN_INTERVAL_FRAMES = 60; // 60Hz'de 1 saniye
    localparam GAME_TIMER_MAX_SECONDS = 99;

    reg [15:0] frame_counter_reg;
    reg [5:0] sixty_hz_tick_counter_reg;
    reg p1_got_hit_this_frame, p1_got_blocked_this_frame;
    reg p2_got_hit_this_frame, p2_got_blocked_this_frame;
	
	// --- KENAR TETİKLEME İÇİN YENİ REGISTER'LAR --- //
    reg p1_confirm_in_s1;
    reg p1_confirm_in_s2;
    wire p1_confirm_rising_edge;
	
	// Sinyali iki register'dan geçirerek senkronize ediyoruz ve gürültüyü azaltıyoruz.
    // Düşen kenar yerine yükselen kenar kullanıyoruz çünkü p1_confirm_in = ~KEY[1] (active-low).
    // Tuşa basıldığında (0 olduğunda) p1_confirm_in 1 olur. Bu yükselen kenarı yakalarız.
    assign p1_confirm_rising_edge = p1_confirm_in_s1 && ~p1_confirm_in_s2;


    initial begin
        game_phase_out = PHASE_MENU;
        p1_hp_out = MAX_HEALTH;
        p1_bp_out = MAX_BLOCK;
        p2_hp_out = MAX_HEALTH;
        p2_bp_out = MAX_BLOCK;
        countdown_value_out = 3;
        game_seconds_elapsed_out = 0; // <--- DEĞİŞTİRİLDİ (Başlangıç değeri 0)
        winner_info_out = 2'b00;
        all_leds_blink_cmd_out = 1'b0;
        frame_counter_reg = 0;
        sixty_hz_tick_counter_reg = 0;
        o_software_reset = 1'b0;
		p1_confirm_in_s1 = 0;
        p1_confirm_in_s2 = 0;
    end

    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            game_phase_out <= PHASE_MENU;
            p1_hp_out <= MAX_HEALTH;
            p1_bp_out <= MAX_BLOCK;
            p2_hp_out <= MAX_HEALTH;
            p2_bp_out <= MAX_BLOCK;
            countdown_value_out <= 3;
            game_seconds_elapsed_out <= 0; // <--- DEĞİŞTİRİLDİ (Reset değeri 0)
            winner_info_out <= 2'b00;
            all_leds_blink_cmd_out <= 1'b0;
            frame_counter_reg <= 0;
            sixty_hz_tick_counter_reg <= 0;
            p1_hit_confirm_out <= 1'b0;
            p1_block_confirm_out <= 1'b0;
            p2_hit_confirm_out <= 1'b0;
            p2_block_confirm_out <= 1'b0;
			p1_confirm_in_s1 <= 0;
            p1_confirm_in_s2 <= 0;
            o_software_reset <= 1'b1;

        end else begin
            o_software_reset <= 1'b0;
			// --- KENAR TETİKLEME REGISTER GÜNCELLEMESİ --- //
            p1_confirm_in_s1 <= p1_confirm_in;
            p1_confirm_in_s2 <= p1_confirm_in_s1;
            p1_hit_confirm_out <= 1'b0;
            p1_block_confirm_out <= 1'b0;
            p2_hit_confirm_out <= 1'b0;
            p2_block_confirm_out <= 1'b0;
            p1_got_hit_this_frame <= 1'b0;
            p1_got_blocked_this_frame <= 1'b0;
            p2_got_hit_this_frame <= 1'b0;
            p2_got_blocked_this_frame <= 1'b0;
            all_leds_blink_cmd_out <= (game_phase_out == PHASE_GAMEOVER);

            case (game_phase_out)
                PHASE_MENU: begin
                    if (p1_confirm_rising_edge) begin
                        game_phase_out <= PHASE_COUNTDOWN;
                        p1_hp_out <= MAX_HEALTH;
                        p1_bp_out <= MAX_BLOCK;
                        p2_hp_out <= MAX_HEALTH;
                        p2_bp_out <= MAX_BLOCK;
                        countdown_value_out <= 3;
                        game_seconds_elapsed_out <= 0; // <--- DEĞİŞTİRİLDİ (Oyun başlangıcında sayacı sıfırla)
                        winner_info_out <= 2'b00;
                        o_software_reset <= 1'b1;
                    end
                end
                PHASE_COUNTDOWN: begin
                    if (frame_counter_reg == COUNTDOWN_INTERVAL_FRAMES - 1) begin
                        frame_counter_reg <= 0;
                        if (countdown_value_out > 0) begin
                            countdown_value_out <= countdown_value_out - 1;
                        end else begin
                            game_phase_out <= PHASE_GAMEPLAY;
                        end
                    end else begin
                        frame_counter_reg <= frame_counter_reg + 1;
                    end
                end
                PHASE_GAMEPLAY: begin
                    // --- ZAMAN SAYACI MANTIĞI (İLERİ SAYIM) --- // <--- DEĞİŞTİRİLDİ
                    if (sixty_hz_tick_counter_reg == 59) begin
                        sixty_hz_tick_counter_reg <= 0;
                        if (game_seconds_elapsed_out < GAME_TIMER_MAX_SECONDS) begin // Süre dolmadıysa
                            game_seconds_elapsed_out <= game_seconds_elapsed_out + 1; // Sayacı 1 artır
                        end else begin // Süre dolduysa (99'a ulaşıldıysa)
									// <<< YENİ KURAL: Süre bittiğinde HP'ye bakılmaksızın her zaman berabere biter.
									winner_info_out <= 2'b11;      // Her zaman 'Draw' (Berabere) sonucunu ver
									game_phase_out <= PHASE_GAMEOVER;
                        end
                    end else begin
                        sixty_hz_tick_counter_reg <= sixty_hz_tick_counter_reg + 1;
                    end

                    // --- Vuruş/Blok Mantığı --- (Değişiklik yok)
                    if (p1_is_attacking_active_in && (p1_hitbox_x2_in >= p2_hurtbox_x1_in && p1_hitbox_x1_in <= p2_hurtbox_x2_in)) begin
                        if (p2_is_actively_blocking_in && p2_bp_out > 0) begin
                            if (!p2_got_blocked_this_frame && p2_state_in != P_STATE_BLOCKSTUN && p2_state_in != P_STATE_HITSTUN) begin
                                p2_bp_out <= p2_bp_out - 1;
                                p2_block_confirm_out <= 1'b1;
                                p2_got_blocked_this_frame <= 1'b1;
                            end
                        end else begin
                            if (!p2_got_hit_this_frame && p2_state_in != P_STATE_HITSTUN && p2_state_in != P_STATE_BLOCKSTUN) begin
                                if (p2_hp_out > 0) p2_hp_out <= p2_hp_out - 1;
                                p2_hit_confirm_out <= 1'b1;
                                p2_got_hit_this_frame <= 1'b1;
                            end
                        end
                    end

                    if (p2_is_attacking_active_in && !p1_got_hit_this_frame && !p1_got_blocked_this_frame && (p2_hitbox_x2_in >= p1_hurtbox_x1_in && p2_hitbox_x1_in <= p1_hurtbox_x2_in)) begin
                        if (p1_is_actively_blocking_in && p1_bp_out > 0) begin
                            if (!p1_got_blocked_this_frame && p1_state_in != P_STATE_BLOCKSTUN && p1_state_in != P_STATE_HITSTUN) begin
                                p1_bp_out <= p1_bp_out - 1;
                                p1_block_confirm_out <= 1'b1;
                                p1_got_blocked_this_frame <= 1'b1;
                            end
                        end else begin
                            if (!p1_got_hit_this_frame && p1_state_in != P_STATE_HITSTUN && p1_state_in != P_STATE_BLOCKSTUN) begin
                                if (p1_hp_out > 0) p1_hp_out <= p1_hp_out - 1;
                                p1_hit_confirm_out <= 1'b1;
                                p1_got_hit_this_frame <= 1'b1;
                            end
                        end
                    end

                    // --- Oyun Bitiş Kontrolü (HP'ye göre) ---
                    if (p1_hp_out == 0 || p2_hp_out == 0) begin
                        if (p1_hp_out == 0 && p2_hp_out == 0) winner_info_out <= 2'b11; // Draw
                        else if (p2_hp_out == 0) winner_info_out <= 2'b01; // P1 Wins
                        else if (p1_hp_out == 0) winner_info_out <= 2'b10; // P2 Wins
                        game_phase_out <= PHASE_GAMEOVER;
                    end
                end
                PHASE_GAMEOVER: begin
                    if (p1_confirm_rising_edge) begin
                        game_phase_out <= PHASE_MENU;
                    end
                end
                default: game_phase_out <= PHASE_MENU;
            endcase
        end
    end
endmodule