// Oyunun genel akışını, vuruş tespitini, skor tutmayı ve oyun aşamalarını yönetir.
// CPU Bot modülü ARTIK BURADA DEĞİL, ÜST SEVİYEDE.
module game_logic_fsm (
    input wire clk_game_logic,
    input wire reset,

    // Girişler
    input wire p1_confirm_in,           // Oyuncu 1 onay butonu (menü, oyun sonu)
    input wire selected_mode_in,        // Seçilen oyun modu (0: 2P, 1: 1P vs CPU)

    // Oyuncu 1 Bilgileri
    input wire [9:0] p1_x_in,
    input wire [2:0] p1_state_in,       // player_fsm'den gelen durum
    input wire p1_is_attacking_active_in,
    input wire [9:0] p1_hitbox_x1_in,
    input wire [9:0] p1_hitbox_x2_in,
    input wire [9:0] p1_hurtbox_x1_in,
    input wire [9:0] p1_hurtbox_x2_in,
    input wire p1_is_moving_backward_in, // Bloklama için

    // Oyuncu 2 Bilgileri (Bunlar Player 2 FSM'inden gelen sonuçlar)
    input wire [9:0] p2_x_in,
    input wire [2:0] p2_state_in,
    input wire p2_is_attacking_active_in,
    input wire [9:0] p2_hitbox_x1_in,
    input wire [9:0] p2_hitbox_x2_in,
    input wire [9:0] p2_hurtbox_x1_in,
    input wire [9:0] p2_hurtbox_x2_in,
    input wire p2_is_moving_backward_in, // Bloklama için

    // Çıkışlar
    output reg [1:0] game_phase_out,           // 00:MENU, 01:COUNTDOWN, 10:GAMEPLAY, 11:GAMEOVER
    output reg [2:0] countdown_value_out,      // Geri sayım için (3,2,1,0 -> 0 "START" demek)
    output reg [6:0] game_seconds_elapsed_out,
    output reg [1:0] winner_info_out,          // 00:None, 01:P1, 10:P2, 11:Draw
    output reg [2:0] p1_hp_out,
    output reg [2:0] p1_bp_out,
    output reg [2:0] p2_hp_out,
    output reg [2:0] p2_bp_out,
    output reg all_leds_blink_cmd_out,     // LED sürücüsüne komut

    // Player FSM'lere geri bildirim (vuruş/blok onayı)
    output reg p1_hit_confirm_out,
    output reg p1_block_confirm_out,
    output reg p2_hit_confirm_out,
    output reg p2_block_confirm_out
    // CPU komut çıkışları kaldırıldı
);

    // Oyun Aşamaları
    localparam PHASE_MENU      = 2'b00;
    localparam PHASE_COUNTDOWN = 2'b01;
    localparam PHASE_GAMEPLAY  = 2'b10;
    localparam PHASE_GAMEOVER  = 2'b11;

    // Oyuncu Durumları
    localparam P_STATE_IDLE      = 3'b000;
    localparam P_STATE_MOVE_B    = 3'b010; 
    localparam P_STATE_HITSTUN   = 3'b110;
    localparam P_STATE_BLOCKSTUN = 3'b111;

    // Sağlık/Blok Puanları
    localparam MAX_HEALTH = 3;
    localparam MAX_BLOCK  = 3;

    // Zamanlayıcılar
    localparam COUNTDOWN_INTERVAL_FRAMES = 60; 
    localparam GAME_TIMER_MAX_SECONDS = 99;

    // Dahili Kaydediciler
    reg [15:0] frame_counter_reg; 
    reg [5:0] sixty_hz_tick_counter_reg; 

    reg p1_got_hit_this_frame;
    reg p1_got_blocked_this_frame;
    reg p2_got_hit_this_frame;
    reg p2_got_blocked_this_frame;

    // CPU bot instantiate kısmı ve cpu_enable_signal_internal kaldırıldı.

    initial begin
        game_phase_out = PHASE_MENU;
        p1_hp_out = MAX_HEALTH;
        p1_bp_out = MAX_BLOCK;
        p2_hp_out = MAX_HEALTH;
        p2_bp_out = MAX_BLOCK;
        countdown_value_out = 3; 
        game_seconds_elapsed_out = 0;
        winner_info_out = 2'b00;
        all_leds_blink_cmd_out = 1'b0;
        frame_counter_reg = 0;
        sixty_hz_tick_counter_reg = 0;
    end

    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            game_phase_out <= PHASE_MENU;
            p1_hp_out <= MAX_HEALTH;
            p1_bp_out <= MAX_BLOCK;
            p2_hp_out <= MAX_HEALTH;
            p2_bp_out <= MAX_BLOCK;
            countdown_value_out <= 3;
            game_seconds_elapsed_out <= 0;
            winner_info_out <= 2'b00;
            all_leds_blink_cmd_out <= 1'b0;
            frame_counter_reg <= 0;
            sixty_hz_tick_counter_reg <= 0;
            p1_hit_confirm_out <= 1'b0;
            p1_block_confirm_out <= 1'b0;
            p2_hit_confirm_out <= 1'b0;
            p2_block_confirm_out <= 1'b0;
        end else begin
            p1_hit_confirm_out <= 1'b0;
            p1_block_confirm_out <= 1'b0;
            p2_hit_confirm_out <= 1'b0;
            p2_block_confirm_out <= 1'b0;

            p1_got_hit_this_frame = 1'b0;
            p1_got_blocked_this_frame = 1'b0;
            p2_got_hit_this_frame = 1'b0;
            p2_got_blocked_this_frame = 1'b0;

            all_leds_blink_cmd_out <= (game_phase_out == PHASE_GAMEOVER); 

            case (game_phase_out)
                PHASE_MENU: begin
                    if (p1_confirm_in) begin
                        game_phase_out <= PHASE_COUNTDOWN;
                        countdown_value_out <= 3; 
                        frame_counter_reg <= 0;   
                        p1_hp_out <= MAX_HEALTH;
                        p1_bp_out <= MAX_BLOCK;
                        p2_hp_out <= MAX_HEALTH;
                        p2_bp_out <= MAX_BLOCK;
                        game_seconds_elapsed_out <= 0;
                        sixty_hz_tick_counter_reg <= 0;
                        winner_info_out <= 2'b00;
                    end
                end
                PHASE_COUNTDOWN: begin
                    if (frame_counter_reg == COUNTDOWN_INTERVAL_FRAMES - 1) begin
                        frame_counter_reg <= 0;
                        if (countdown_value_out == 0) begin 
                            game_phase_out <= PHASE_GAMEPLAY;
                        end else if (countdown_value_out == 1) begin 
                            countdown_value_out <= 0;
                        end else begin
                            countdown_value_out <= countdown_value_out - 1;
                        end
                    end else begin
                        frame_counter_reg <= frame_counter_reg + 1;
                    end
                end
                PHASE_GAMEPLAY: begin
                    // --- Oyun Zamanlayıcısı ---
                    if (sixty_hz_tick_counter_reg == 59) begin
                        sixty_hz_tick_counter_reg <= 0;
                        if (game_seconds_elapsed_out < GAME_TIMER_MAX_SECONDS) begin
                            game_seconds_elapsed_out <= game_seconds_elapsed_out + 1;
                        end else begin
                            if (p1_hp_out > p2_hp_out) winner_info_out <= 2'b01; 
                            else if (p2_hp_out > p1_hp_out) winner_info_out <= 2'b10; 
                            else winner_info_out <= 2'b11; 
                            game_phase_out <= PHASE_GAMEOVER;
                        end
                    end else begin
                        sixty_hz_tick_counter_reg <= sixty_hz_tick_counter_reg + 1;
                    end

                    // --- Vuruş Tespiti ---
                    // Oyuncu 1, Oyuncu 2'ye saldırıyor
                    if (p1_is_attacking_active_in) begin
                        if (p1_hitbox_x2_in >= p2_hurtbox_x1_in && p1_hitbox_x1_in <= p2_hurtbox_x2_in) begin
                            if (p2_is_moving_backward_in && p2_bp_out > 0) begin 
                                if (!p2_got_blocked_this_frame && p2_state_in != P_STATE_BLOCKSTUN && p2_state_in != P_STATE_HITSTUN) begin
                                    p2_bp_out <= p2_bp_out - 1;
                                    p2_block_confirm_out <= 1'b1; 
                                    p2_got_blocked_this_frame = 1'b1;
                                end
                            end else begin 
                                if (!p2_got_hit_this_frame && p2_state_in != P_STATE_HITSTUN && p2_state_in != P_STATE_BLOCKSTUN) begin
                                    if (p2_hp_out > 0) p2_hp_out <= p2_hp_out - 1;
                                    p2_hit_confirm_out <= 1'b1; 
                                    p2_got_hit_this_frame = 1'b1;
                                end
                            end
                        end
                    end

                    // Oyuncu 2, Oyuncu 1'e saldırıyor
                    if (p2_is_attacking_active_in && !p1_got_hit_this_frame && !p1_got_blocked_this_frame) begin 
                        if (p2_hitbox_x2_in >= p1_hurtbox_x1_in && p2_hitbox_x1_in <= p1_hurtbox_x2_in) begin
                            if (p1_is_moving_backward_in && p1_bp_out > 0) begin 
                                if (p1_state_in != P_STATE_BLOCKSTUN && p1_state_in != P_STATE_HITSTUN) begin
                                    p1_bp_out <= p1_bp_out - 1;
                                    p1_block_confirm_out <= 1'b1;
                                    p1_got_blocked_this_frame = 1'b1;
                                end
                            end else begin 
                                if (p1_state_in != P_STATE_HITSTUN && p1_state_in != P_STATE_BLOCKSTUN) begin
                                    if (p1_hp_out > 0) p1_hp_out <= p1_hp_out - 1;
                                    p1_hit_confirm_out <= 1'b1;
                                    p1_got_hit_this_frame = 1'b1;
                                end
                            end
                        end
                    end

                    // --- Oyun Bitti Koşullarını Kontrol Et (HP ile) ---
                    if (p1_hp_out == 0 && p2_hp_out == 0) begin
                        winner_info_out <= 2'b11; 
                        game_phase_out <= PHASE_GAMEOVER;
                    end else if (p2_hp_out == 0) begin
                        winner_info_out <= 2'b01; 
                        game_phase_out <= PHASE_GAMEOVER;
                    end else if (p1_hp_out == 0) begin
                        winner_info_out <= 2'b10; 
                        game_phase_out <= PHASE_GAMEOVER;
                    end
                end
                PHASE_GAMEOVER: begin
                    if (p1_confirm_in) begin
                        game_phase_out <= PHASE_MENU;
                    end
                end
                default: game_phase_out <= PHASE_MENU;
            endcase
        end
    end
endmodule