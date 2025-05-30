//=======================================================
//  PokeD_Game Top Level (Düzeltilmiş Hitbox Hesaplaması)
//=======================================================

module Game_PokeD(
    // ... (Giriş/Çıkış portlarınız aynı kalacak) ...
    input wire CLOCK_50,
    output wire [6:0] HEX0, output wire [6:0] HEX1, output wire [6:0] HEX2,
    output wire [6:0] HEX3, output wire [6:0] HEX4, output wire [6:0] HEX5,
    input wire [3:0] KEY,
    output wire LEDR_P1_HP0, LEDR_P1_HP1, LEDR_P1_HP2,
    output wire LEDR_P2_HP0, LEDR_P2_HP1, LEDR_P2_HP2,
    output wire LEDR_ALL_BLINK,
    input wire [9:0] SW,
    output wire VGA_BLANK_N, output wire [7:0] VGA_B, output wire VGA_CLK,
    output wire [7:0] VGA_G, output wire VGA_HS, output wire [7:0] VGA_R,
    output wire VGA_SYNC_N, output wire VGA_VS
);

//=======================================================
//  REG/WIRE declarations (önceki gibi)
//=======================================================
wire sys_master_reset;
wire clk_25MHz_vga;
wire clk_60Hz_game_logic_source;
wire clock_mode_is_key0_step;
wire effective_game_logic_clk;
reg  key0_on_clk50_s1, key0_on_clk50_s2;
wire key0_debounced_ish;
reg  key0_sync_s1_for_tick, key0_sync_s2_for_tick;
reg  key0_sync_s2_prev_for_tick;
wire key0_clk_tick_for_game_logic;

// ... (Diğer tüm wire tanımlamalarınız aynı kalır) ...
wire [1:0] game_phase_from_fsm;
wire [2:0] countdown_val_from_fsm;
wire [6:0] game_seconds_from_fsm;
wire [1:0] winner_info_from_fsm;
wire [2:0] p1_hp_from_fsm, p2_hp_from_fsm;
wire [2:0] p1_bp_from_fsm, p2_bp_from_fsm;
wire p1_hit_confirm_to_p1_fsm, p1_block_confirm_to_p1_fsm;
wire p2_hit_confirm_to_p2_fsm, p2_block_confirm_to_p2_fsm;
wire all_leds_blink_cmd_top;

wire [9:0] p1_actual_x_position_out; // Player FSM'den gelen sol kenar X
wire [2:0] p1_current_state_out;
wire       p1_is_attacking_active_out; // Player FSM'den: o_hitbox_active
wire [9:0] p1_current_hitbox_offset_out; // Player FSM'den: hitbox'ın oyuncu önünden mesafesi
wire [9:0] p1_current_hitbox_width_out;  // Player FSM'den: hitbox genişliği
wire [9:0] p1_actual_hurtbox_width_out;  // Player FSM'den: oyuncu/hurtbox genişliği
wire       p1_is_facing_right_out;

wire [9:0] p2_actual_x_position_out;
wire [2:0] p2_current_state_out;
wire       p2_is_attacking_active_out;
wire [9:0] p2_current_hitbox_offset_out;
wire [9:0] p2_current_hitbox_width_out;
wire [9:0] p2_actual_hurtbox_width_out;
wire       p2_is_facing_right_out;

wire [9:0] p1_x_for_logic_and_vga;
wire [2:0] p1_state_to_game_logic;
wire       p1_attacking_for_logic_and_vga;
wire [9:0] p1_hitbox_x1_calc, p1_hitbox_x2_calc;
wire [9:0] p1_hurtbox_x1_calc, p1_hurtbox_x2_calc;
wire       p1_moving_backward_to_game_logic;

wire [9:0] p2_x_to_game_logic_and_vga;
wire [2:0] p2_state_to_game_logic;
wire       p2_attacking_for_logic_and_vga;
wire [9:0] p2_hitbox_x1_calc, p2_hitbox_x2_calc;
wire [9:0] p2_hurtbox_x1_calc, p2_hurtbox_x2_calc;
wire       p2_moving_backward_to_game_logic;

wire cpu_p2_move_left_cmd_top, cpu_p2_move_right_cmd_top, cpu_p2_attack_cmd_top;
wire cpu_enable_signal_top;
wire p1_move_left_ctrl, p1_move_right_ctrl, p1_attack_ctrl, p1_confirm_ctrl;
wire p2_move_left_selected_ctrl, p2_move_right_selected_ctrl, p2_attack_selected_ctrl;
wire selected_mode_ctrl;
wire [9:0] vga_driver_next_x, vga_driver_next_y;
wire [7:0] pixel_color_from_graphics;
wire i_show_hitboxes_continuously_sw; // SW[5]'ten

//=======================================================
//  Structural coding
//=======================================================

assign clock_mode_is_key0_step = SW[1];
assign sys_master_reset = clock_mode_is_key0_step ? 1'b0 : ~KEY[0];
assign i_show_hitboxes_continuously_sw = SW[5]; // Hitbox toggle için SW[5]

// ... (Saat üretimi, KEY[0] tick, buton atamaları, CPU bot, P2 giriş seçimi önceki gibi) ...
clock_divider_functional #(.DIVISOR(2)) clock_divider_25MHz_inst (
    .clk(CLOCK_50), .reset(sys_master_reset), .clk_out(clk_25MHz_vga)
);
clock_divider_functional #(.DIVISOR(833333)) clock_divider_60Hz_inst (
    .clk(CLOCK_50), .reset(sys_master_reset), .clk_out(clk_60Hz_game_logic_source)
);

always @(posedge CLOCK_50 or posedge sys_master_reset) begin
    if (sys_master_reset) begin key0_on_clk50_s1 <= 1'b1; key0_on_clk50_s2 <= 1'b1; end
    else begin key0_on_clk50_s1 <= KEY[0]; key0_on_clk50_s2 <= key0_on_clk50_s1; end
end
assign key0_debounced_ish = key0_on_clk50_s2;

always @(posedge clk_60Hz_game_logic_source or posedge sys_master_reset) begin
    if (sys_master_reset) begin
        key0_sync_s1_for_tick <= 1'b1; key0_sync_s2_for_tick <= 1'b1; key0_sync_s2_prev_for_tick <= 1'b1;
    end else begin
        if (clock_mode_is_key0_step) begin
            key0_sync_s1_for_tick <= key0_debounced_ish; key0_sync_s2_for_tick <= key0_sync_s1_for_tick; key0_sync_s2_prev_for_tick <= key0_sync_s2_for_tick;
        end else begin
            key0_sync_s1_for_tick <= 1'b1; key0_sync_s2_for_tick <= 1'b1; key0_sync_s2_prev_for_tick <= 1'b1;
        end
    end
end
assign key0_clk_tick_for_game_logic = clock_mode_is_key0_step ? (key0_sync_s2_prev_for_tick & ~key0_sync_s2_for_tick) : 1'b0;
assign effective_game_logic_clk = clock_mode_is_key0_step ? key0_clk_tick_for_game_logic : clk_60Hz_game_logic_source;

assign selected_mode_ctrl    = SW[0];
assign p1_confirm_ctrl       = ~KEY[1];
assign p1_attack_ctrl        = ~KEY[1];
assign p1_move_right_ctrl    = ~KEY[2];
assign p1_move_left_ctrl     = ~KEY[3];
assign p2_human_move_left_ctrl  = SW[4];
assign p2_human_move_right_ctrl = SW[3];
assign p2_human_attack_ctrl     = SW[2];

assign cpu_enable_signal_top = (selected_mode_ctrl == 1'b1) && (game_phase_from_fsm == 2'b10);
cpu_bot cpu_bot_inst (
    .clk_game_logic(effective_game_logic_clk), .reset(sys_master_reset),
    .enable_bot(cpu_enable_signal_top),
    .p1_x_pos_in(p1_actual_x_position_out), .p2_x_pos_in(p2_actual_x_position_out),
    .cpu_move_left_out(cpu_p2_move_left_cmd_top), .cpu_move_right_out(cpu_p2_move_right_cmd_top),
    .cpu_attack_out(cpu_p2_attack_cmd_top)
);
assign p2_move_left_selected_ctrl  = (selected_mode_ctrl == 1'b0) ? p2_human_move_left_ctrl  : cpu_p2_move_left_cmd_top;
assign p2_move_right_selected_ctrl = (selected_mode_ctrl == 1'b0) ? p2_human_move_right_ctrl : cpu_p2_move_right_cmd_top;
assign p2_attack_selected_ctrl     = (selected_mode_ctrl == 1'b0) ? p2_human_attack_ctrl     : cpu_p2_attack_cmd_top;


// --- Player 1 FSM ---
player_fsm player1_fsm_instance (
    .clk_game_logic(effective_game_logic_clk), .reset(sys_master_reset),
    .i_move_left(p1_move_left_ctrl), .i_move_right(p1_move_right_ctrl), .i_attack(p1_attack_ctrl),
    .i_opponent_x_pos(p2_actual_x_position_out),
    // .i_my_current_x_pos(p1_actual_x_position_out), // player_fsm kendi o_x_pos'unu kullanır
    .i_am_player1(1'b1),
    .i_hit_by_opponent(p1_hit_confirm_to_p1_fsm), .i_blocked_attack(p1_block_confirm_to_p1_fsm),
    .o_x_pos(p1_actual_x_position_out), .o_player_state(p1_current_state_out),
    .o_hitbox_active(p1_is_attacking_active_out),
    .o_hitbox_x_offset(p1_current_hitbox_offset_out), .o_hitbox_width(p1_current_hitbox_width_out),
    .o_hurtbox_width(p1_actual_hurtbox_width_out), .o_facing_right(p1_is_facing_right_out)
);

// --- Player 2 FSM ---
player_fsm player2_fsm_instance (
    .clk_game_logic(effective_game_logic_clk), .reset(sys_master_reset),
    .i_move_left(p2_move_left_selected_ctrl), .i_move_right(p2_move_right_selected_ctrl), .i_attack(p2_attack_selected_ctrl),
    .i_opponent_x_pos(p1_actual_x_position_out),
    // .i_my_current_x_pos(p2_actual_x_position_out),
    .i_am_player1(1'b0),
    .i_hit_by_opponent(p2_hit_confirm_to_p2_fsm), .i_blocked_attack(p2_block_confirm_to_p2_fsm),
    .o_x_pos(p2_actual_x_position_out), .o_player_state(p2_current_state_out),
    .o_hitbox_active(p2_is_attacking_active_out),
    .o_hitbox_x_offset(p2_current_hitbox_offset_out), .o_hitbox_width(p2_current_hitbox_width_out),
    .o_hurtbox_width(p2_actual_hurtbox_width_out), .o_facing_right(p2_is_facing_right_out)
);

// Player FSM çıkışlarından game_logic ve vga_graphics için ara sinyaller
assign p1_x_for_logic_and_vga       = p1_actual_x_position_out;
assign p1_attacking_for_logic_and_vga = p1_is_attacking_active_out;
assign p1_state_to_game_logic       = p1_current_state_out;
assign p1_moving_backward_to_game_logic = (p1_current_state_out == 3'b010); // Örnek: player_fsm'deki S_MOVE_LEFT durumu

assign p2_x_for_logic_and_vga       = p2_actual_x_position_out;
assign p2_attacking_for_logic_and_vga = p2_is_attacking_active_out;
assign p2_state_to_game_logic       = p2_current_state_out;
assign p2_moving_backward_to_game_logic = (p2_current_state_out == 3'b010);


// --- Hitbox ve Hurtbox Koordinat Hesaplamaları (DÜZELTİLMİŞ) ---
// pX_actual_x_position_out: oyuncunun sol kenarı
// pX_actual_hurtbox_width_out: oyuncunun genişliği
// pX_current_hitbox_offset_out: hitbox'ın oyuncunun ÖN KENARINDAN olan mesafesi (boşluk)
// pX_current_hitbox_width_out: hitbox'ın kendi genişliği
// pX_is_facing_right_out: oyuncunun baktığı yön

// Player 1 Hurtbox
assign p1_hurtbox_x1_calc = p1_actual_x_position_out;
assign p1_hurtbox_x2_calc = p1_actual_x_position_out + p1_actual_hurtbox_width_out - 1;

// Player 1 Hitbox
assign p1_hitbox_x1_calc = p1_is_attacking_active_out ?
                               (p1_is_facing_right_out ?
                                   (p1_actual_x_position_out + p1_actual_hurtbox_width_out + p1_current_hitbox_offset_out) : // Sağa bakarken: P1'in sağ kenarı + offset
                                   (p1_actual_x_position_out - p1_current_hitbox_offset_out - p1_current_hitbox_width_out)      // Sola bakarken: P1'in sol kenarı - offset - hitbox genişliği
                               ) : 10'h000; // Saldırmıyorsa
assign p1_hitbox_x2_calc = p1_is_attacking_active_out ?
                               (p1_is_facing_right_out ?
                                   (p1_hitbox_x1_calc + p1_current_hitbox_width_out - 1) : // Sağa bakarken: x1 + genişlik - 1
                                   (p1_actual_x_position_out - p1_current_hitbox_offset_out - 1)         // Sola bakarken: P1'in sol kenarı - offset - 1
                               ) : 10'h000; // Saldırmıyorsa (x1'den küçük veya eşit olmalı)

// Player 2 Hurtbox
assign p2_hurtbox_x1_calc = p2_actual_x_position_out;
assign p2_hurtbox_x2_calc = p2_actual_x_position_out + p2_actual_hurtbox_width_out - 1;

// Player 2 Hitbox
assign p2_hitbox_x1_calc = p2_is_attacking_active_out ?
                               (p2_is_facing_right_out ?
                                   (p2_actual_x_position_out + p2_actual_hurtbox_width_out + p2_current_hitbox_offset_out) :
                                   (p2_actual_x_position_out - p2_current_hitbox_offset_out - p2_current_hitbox_width_out)
                               ) : 10'h000;
assign p2_hitbox_x2_calc = p2_is_attacking_active_out ?
                               (p2_is_facing_right_out ?
                                   (p2_hitbox_x1_calc + p2_current_hitbox_width_out - 1) :
                                   (p2_actual_x_position_out - p2_current_hitbox_offset_out - 1)
                               ) : 10'h000;


// --- Game Logic FSM ---
game_logic_fsm game_logic_inst ( /* ... port bağlantıları önceki gibi ... */
    .clk_game_logic(effective_game_logic_clk), .reset(sys_master_reset),
    .p1_confirm_in(p1_confirm_ctrl), .selected_mode_in(selected_mode_ctrl),
    .p1_x_in(p1_x_for_logic_and_vga), .p1_state_in(p1_state_to_game_logic),
    .p1_is_attacking_active_in(p1_attacking_for_logic_and_vga),
    .p1_hitbox_x1_in(p1_hitbox_x1_calc), .p1_hitbox_x2_in(p1_hitbox_x2_calc),
    .p1_hurtbox_x1_in(p1_hurtbox_x1_calc), .p1_hurtbox_x2_in(p1_hurtbox_x2_calc),
    .p1_is_moving_backward_in(p1_moving_backward_to_game_logic),
    .p2_x_in(p2_x_for_logic_and_vga), .p2_state_in(p2_state_to_game_logic),
    .p2_is_attacking_active_in(p2_attacking_for_logic_and_vga),
    .p2_hitbox_x1_in(p2_hitbox_x1_calc), .p2_hitbox_x2_in(p2_hitbox_x2_calc),
    .p2_hurtbox_x1_in(p2_hurtbox_x1_calc), .p2_hurtbox_x2_in(p2_hurtbox_x2_calc),
    .p2_is_moving_backward_in(p2_moving_backward_to_game_logic),
    // ... (game_logic_fsm'in diğer çıkış ve girişleri)
    .game_phase_out(game_phase_from_fsm),
    .countdown_value_out(countdown_val_from_fsm), .game_seconds_elapsed_out(game_seconds_from_fsm),
    .winner_info_out(winner_info_from_fsm),
    .p1_hp_out(p1_hp_from_fsm), .p1_bp_out(p1_bp_from_fsm),
    .p2_hp_out(p2_hp_from_fsm), .p2_bp_out(p2_bp_from_fsm),
    .all_leds_blink_cmd_out(all_leds_blink_cmd_top),
    .p1_hit_confirm_out(p1_hit_confirm_to_p1_fsm), .p1_block_confirm_out(p1_block_confirm_to_p1_fsm),
    .p2_hit_confirm_out(p2_hit_confirm_to_p2_fsm), .p2_block_confirm_out(p2_block_confirm_to_p2_fsm)
);

// --- VGA Graphics Connector ---
vga_graphics_connector graphics_conn_inst (
    .clk_pixel(clk_25MHz_vga), .reset(sys_master_reset),
    .i_game_phase(game_phase_from_fsm),
    .i_p1_is_attacking(p1_attacking_for_logic_and_vga),
    .i_p2_is_attacking(p2_attacking_for_logic_and_vga),

    .i_p1_hitbox_x1(p1_hitbox_x1_calc), .i_p1_hitbox_x2(p1_hitbox_x2_calc),
    .i_p1_hurtbox_x1(p1_hurtbox_x1_calc), .i_p1_hurtbox_x2(p1_hurtbox_x2_calc),
    .i_p2_hitbox_x1(p2_hitbox_x1_calc), .i_p2_hitbox_x2(p2_hitbox_x2_calc),
    .i_p2_hurtbox_x1(p2_hurtbox_x1_calc), .i_p2_hurtbox_x2(p2_hurtbox_x2_calc),

    .i_show_hitboxes_continuously(i_show_hitboxes_continuously_sw),

    // YENİ GİRİŞLER: Oyuncu FSM durumları
    .i_p1_fsm_state(p1_current_state_out),
    .i_p2_fsm_state(p2_current_state_out),

    .i_vga_next_x(vga_driver_next_x),
    .i_vga_next_y(vga_driver_next_y),
    .o_pixel_color_data(pixel_color_from_graphics)
);

// --- VGA Driver (önceki gibi) ---
vga_driver vga_driver_inst ( /* ... port bağlantıları ... */
    .clock(clk_25MHz_vga), .reset(sys_master_reset),
    .color_in(pixel_color_from_graphics),
    .next_x(vga_driver_next_x), .next_y(vga_driver_next_y),
    .hsync(VGA_HS), .vsync(VGA_VS),
    .red(VGA_R), .green(VGA_G), .blue(VGA_B),
    .sync(VGA_SYNC_N), .clk(VGA_CLK), .blank(VGA_BLANK_N)
);

// --- 7-Segment Display Driver (önceki gibi) ---
SevenSegmentDisplay_module seven_seg_display_inst ( /* ... port bağlantıları ... */
    .reset(sys_master_reset), .i_game_phase(game_phase_from_fsm),
    .i_sw0_current_mode_selection(selected_mode_ctrl), .i_winner_info(winner_info_from_fsm),
    .i_elapsed_time_seconds(game_seconds_from_fsm),
    .o_hex5_pattern(HEX5), .o_hex4_pattern(HEX4), .o_hex3_pattern(HEX3),
    .o_hex2_pattern(HEX2), .o_hex1_pattern(HEX1), .o_hex0_pattern(HEX0)
);

// --- LED Output (önceki gibi) ---
LED_Output_module led_output_inst ( /* ... port bağlantıları ... */
    .clk_game_logic(effective_game_logic_clk), .reset(sys_master_reset),
    .i_p1_hp(p1_hp_from_fsm), .i_p2_hp(p2_hp_from_fsm),
    .i_game_phase(game_phase_from_fsm),
    .o_led_p1_hp_0(LEDR_P1_HP0), .o_led_p1_hp_1(LEDR_P1_HP1), .o_led_p1_hp_2(LEDR_P1_HP2),
    .o_led_p2_hp_0(LEDR_P2_HP0), .o_led_p2_hp_1(LEDR_P2_HP1), .o_led_p2_hp_2(LEDR_P2_HP2)
);
assign LEDR_ALL_BLINK = all_leds_blink_cmd_top;

endmodule
