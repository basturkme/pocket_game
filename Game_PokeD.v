///=======================================================
//  PokeD_Game Top Level (cpu_bot instantiated here)
//=======================================================

module Game_PokeD(

    //////////// CLOCK //////////
    input wire CLOCK_50,

    //////////// SEG7 //////////
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,

    //////////// KEY //////////
    input wire [3:0] KEY, // KEY[0] reset, KEY[3:1] P1 kontrolleri (KEY[1] hem onay hem atak)

    //////////// LED //////////
    output wire LEDR_P1_HP0, LEDR_P1_HP1, LEDR_P1_HP2,
    output wire LEDR_P2_HP0, LEDR_P2_HP1, LEDR_P2_HP2,
    output wire LEDR_ALL_BLINK,

    //////////// SW //////////
    input wire [9:0] SW, // SW[0] mod, SW[1] P1 onay (KEY[1] yerine kullanılabilir), SW[4:2] P2 kontrolleri

    //////////// VGA //////////
    output wire VGA_BLANK_N,
    output wire [7:0] VGA_B,
    output wire VGA_CLK,
    output wire [7:0] VGA_G,
    output wire VGA_HS,
    output wire [7:0] VGA_R,
    output wire VGA_SYNC_N,
    output wire VGA_VS
);

//=======================================================
//  REG/WIRE declarations
//=======================================================

wire system_reset;
wire clk_25MHz_vga;
wire clk_60Hz_game_logic;

// game_logic_fsm çıkışları
wire [1:0] game_phase_from_fsm;
wire [2:0] countdown_val_from_fsm;
wire [6:0] game_seconds_from_fsm;
wire [1:0] winner_info_from_fsm;
wire [2:0] p1_hp_from_fsm, p2_hp_from_fsm;
wire [2:0] p1_bp_from_fsm, p2_bp_from_fsm;
wire p1_hit_confirm_to_p1_fsm, p1_block_confirm_to_p1_fsm; // P1 FSM'e geri bildirim
wire p2_hit_confirm_to_p2_fsm, p2_block_confirm_to_p2_fsm; // P2 FSM'e geri bildirim
wire all_leds_blink_cmd_top;

// --- Player 1 FSM çıkışları için wire'lar ---
wire [9:0] p1_actual_x_position_out;
wire [2:0] p1_current_state_out;
wire       p1_is_attacking_active_out; // Bu hem game_logic'e hem vga_graphics'e gidecek
wire [9:0] p1_current_hitbox_offset_out;
wire [9:0] p1_current_hitbox_width_out;
wire [9:0] p1_actual_hurtbox_width_out;
// wire [9:0] p1_actual_hurtbox_height_out; // game_logic_fsm bunu kullanmıyor
wire       p1_is_facing_right_out;

// --- Player 2 FSM çıkışları için wire'lar ---
wire [9:0] p2_actual_x_position_out;
wire [2:0] p2_current_state_out;
wire       p2_is_attacking_active_out; // Bu hem game_logic'e hem vga_graphics'e gidecek
wire [9:0] p2_current_hitbox_offset_out;
wire [9:0] p2_current_hitbox_width_out;
wire [9:0] p2_actual_hurtbox_width_out;
// wire [9:0] p2_actual_hurtbox_height_out; // game_logic_fsm bunu kullanmıyor
wire       p2_is_facing_right_out;

// --- Player FSM çıkışlarından game_logic_fsm girişlerine gidecek hesaplanmış/atanmış wire'lar ---
// Bu wire'lar aynı zamanda vga_graphics_connector'a da bağlanacak (pozisyon ve saldırı durumu)
wire [9:0] p1_x_to_game_logic_and_vga;       // p1_actual_x_position_out'tan
wire [2:0] p1_state_to_game_logic;           // p1_current_state_out'tan
wire       p1_attacking_to_game_logic_and_vga; // p1_is_attacking_active_out'tan
wire [9:0] p1_hitbox_x1_to_game_logic;
wire [9:0] p1_hitbox_x2_to_game_logic;
wire [9:0] p1_hurtbox_x1_to_game_logic;
wire [9:0] p1_hurtbox_x2_to_game_logic;
wire       p1_moving_backward_to_game_logic; // Bu player_fsm'den gelmeli (o_player_state'ten türetilebilir veya direkt çıkış)

wire [9:0] p2_x_to_game_logic_and_vga;
wire [2:0] p2_state_to_game_logic;
wire       p2_attacking_to_game_logic_and_vga;
wire [9:0] p2_hitbox_x1_to_game_logic;
wire [9:0] p2_hitbox_x2_to_game_logic;
wire [9:0] p2_hurtbox_x1_to_game_logic;
wire [9:0] p2_hurtbox_x2_to_game_logic;
wire       p2_moving_backward_to_game_logic;


// CPU Bot çıkışları
wire cpu_p2_move_left_cmd_top;
wire cpu_p2_move_right_cmd_top;
wire cpu_p2_attack_cmd_top;
wire cpu_enable_signal_top;

// Oyuncu Girişleri (Butonlardan gelenler)
wire p1_move_left_ctrl, p1_move_right_ctrl, p1_attack_ctrl, p1_confirm_ctrl;
wire p2_move_left_selected_ctrl, p2_move_right_selected_ctrl, p2_attack_selected_ctrl;
wire selected_mode_ctrl;

// VGA Arayüzü
wire [9:0] vga_driver_next_x, vga_driver_next_y;
wire [7:0] pixel_color_from_graphics;


//=======================================================
//  Structural coding
//=======================================================

assign system_reset = ~KEY[0];

// --- Saat Üreteçleri ---
clock_divider_functional #(.DIVISOR(2)) clock_divider_25MHz_inst (
    .clk(CLOCK_50), .reset(system_reset), .clk_out(clk_25MHz_vga)
);
clock_divider_functional #(.DIVISOR(833333)) clock_divider_60Hz_inst ( // 50M / 833333 = ~60Hz
    .clk(CLOCK_50), .reset(system_reset), .clk_out(clk_60Hz_game_logic)
);

// --- Giriş Atamaları (Butonlar ve Switch'ler) ---
assign selected_mode_ctrl    = SW[0];
assign p1_confirm_ctrl       = ~KEY[1]; // KEY[1] Player 1 Onay
// assign p1_attack_ctrl        = ~KEY[1]; // Eğer KEY[1] hem onay hem atak ise. Ayrı butonlar daha iyi olur.
                                        // Şimdilik player_fsm'in i_attack girişine ne bağlanacağına karar verilmeli.
                                        // Varsayalım KEY[1] sadece onay, atak için ayrı bir şey lazım.
                                        // Eğer KEY[1] atak ise, p1_confirm_ctrl için SW[1] kullanılabilir.
                                        // Kullanıcı KEY[3:1] P1 kontrolleri dedi. KEY[1] o zaman atak/onay.
assign p1_attack_ctrl        = ~KEY[1]; // KEY[1] P1 Atak
assign p1_move_right_ctrl    = ~KEY[2]; // KEY[2] P1 Sağ
assign p1_move_left_ctrl     = ~KEY[3]; // KEY[3] P1 Sol


wire p2_human_move_left_ctrl, p2_human_move_right_ctrl, p2_human_attack_ctrl;
assign p2_human_move_left_ctrl  = SW[4]; // SW[4] P2 Sol
assign p2_human_move_right_ctrl = SW[3]; // SW[3] P2 Sağ
assign p2_human_attack_ctrl     = SW[2]; // SW[2] P2 Atak

// --- CPU Bot ---
assign cpu_enable_signal_top = (selected_mode_ctrl == 1'b1) && (game_phase_from_fsm == 2'b10);

cpu_bot cpu_bot_inst (
    .clk_game_logic(clk_60Hz_game_logic),
    .reset(system_reset),
    .enable_bot(cpu_enable_signal_top),
    .p1_x_pos_in(p1_actual_x_position_out), // CPU, P1'in gerçek pozisyonunu görür
    .p2_x_pos_in(p2_actual_x_position_out), // CPU, P2'nin gerçek pozisyonunu görür
    .cpu_move_left_out(cpu_p2_move_left_cmd_top),
    .cpu_move_right_out(cpu_p2_move_right_cmd_top),
    .cpu_attack_out(cpu_p2_attack_cmd_top)
);

// Player 2 için giriş seçimi (insan veya CPU)
assign p2_move_left_selected_ctrl  = (selected_mode_ctrl == 1'b0) ? p2_human_move_left_ctrl  : cpu_p2_move_left_cmd_top;
assign p2_move_right_selected_ctrl = (selected_mode_ctrl == 1'b0) ? p2_human_move_right_ctrl : cpu_p2_move_right_cmd_top;
assign p2_attack_selected_ctrl     = (selected_mode_ctrl == 1'b0) ? p2_human_attack_ctrl     : cpu_p2_attack_cmd_top;


// --- Player 1 FSM ---
player_fsm player1_fsm_instance (
    .clk_game_logic(clk_60Hz_game_logic),
    .reset(system_reset),
    .i_move_left(p1_move_left_ctrl),
    .i_move_right(p1_move_right_ctrl),
    .i_attack(p1_attack_ctrl),
    // .i_up(p1_up_ctrl), // Eğer zıplama varsa
    .i_opponent_x_pos(p2_actual_x_position_out), // P2'nin pozisyonu
    .i_my_current_x_pos(p1_actual_x_position_out), // Kendi pozisyonunun geri beslemesi (Player FSM içinde yönetiliyorsa bu port gerekmeyebilir)
    .i_am_player1(1'b1),
    .i_hit_by_opponent(p1_hit_confirm_to_p1_fsm),
    .i_blocked_attack(p1_block_confirm_to_p1_fsm),

    .o_x_pos(p1_actual_x_position_out),
    .o_player_state(p1_current_state_out),
    .o_hitbox_active(p1_is_attacking_active_out),
    .o_hitbox_x_offset(p1_current_hitbox_offset_out),
    .o_hitbox_width(p1_current_hitbox_width_out),
    .o_hurtbox_width(p1_actual_hurtbox_width_out),
    // .o_hurtbox_height(p1_actual_hurtbox_height_out), // game_logic_fsm bunu kullanmıyor
    .o_facing_right(p1_is_facing_right_out)
);

// --- Player 2 FSM ---
player_fsm player2_fsm_instance (
    .clk_game_logic(clk_60Hz_game_logic),
    .reset(system_reset),
    .i_move_left(p2_move_left_selected_ctrl),  // İnsan veya CPU'dan gelen seçilmiş giriş
    .i_move_right(p2_move_right_selected_ctrl),// İnsan veya CPU'dan gelen seçilmiş giriş
    .i_attack(p2_attack_selected_ctrl),      // İnsan veya CPU'dan gelen seçilmiş giriş
    // .i_up(p2_up_ctrl), // Eğer zıplama varsa
    .i_opponent_x_pos(p1_actual_x_position_out), // P1'in pozisyonu
    .i_my_current_x_pos(p2_actual_x_position_out),
    .i_am_player1(1'b0),
    .i_hit_by_opponent(p2_hit_confirm_to_p2_fsm),
    .i_blocked_attack(p2_block_confirm_to_p2_fsm),

    .o_x_pos(p2_actual_x_position_out),
    .o_player_state(p2_current_state_out),
    .o_hitbox_active(p2_is_attacking_active_out),
    .o_hitbox_x_offset(p2_current_hitbox_offset_out),
    .o_hitbox_width(p2_current_hitbox_width_out),
    .o_hurtbox_width(p2_actual_hurtbox_width_out),
    // .o_hurtbox_height(p2_actual_hurtbox_height_out),
    .o_facing_right(p2_is_facing_right_out)
);

// --- Player FSM Çıkışlarından Ara Sinyallere Atamalar ---
assign p1_x_to_game_logic_and_vga        = p1_actual_x_position_out;
assign p1_state_to_game_logic            = p1_current_state_out;
assign p1_attacking_to_game_logic_and_vga  = p1_is_attacking_active_out;
// p1_is_moving_backward_to_game_logic: Bu, p1_current_state_out'a göre atanmalı veya player_fsm'den ayrı bir çıkış olmalı
// Örnek: player_fsm'deki P_STATE_MOVE_B (3'b010) durumuna göre:
assign p1_moving_backward_to_game_logic  = (p1_current_state_out == 3'b010); // Veya player_fsm'den direct output

assign p2_x_to_game_logic_and_vga        = p2_actual_x_position_out;
assign p2_state_to_game_logic            = p2_current_state_out;
assign p2_attacking_to_game_logic_and_vga  = p2_is_attacking_active_out;
assign p2_moving_backward_to_game_logic  = (p2_current_state_out == 3'b010); // Veya player_fsm'den direct output


// --- Hitbox ve Hurtbox Koordinat Hesaplamaları ---
// Player 1 (o_x_pos'un sol kenar olduğu varsayımıyla)
assign p1_hurtbox_x1_to_game_logic = p1_actual_x_position_out;
assign p1_hurtbox_x2_to_game_logic = p1_actual_x_position_out + p1_actual_hurtbox_width_out - 1;

assign p1_hitbox_x1_to_game_logic = p1_is_attacking_active_out ?
                               (p1_is_facing_right_out ?
                                   (p1_actual_x_position_out + p1_current_hitbox_offset_out) :
                                   (p1_actual_x_position_out - p1_current_hitbox_offset_out - p1_current_hitbox_width_out)) :
                               10'd0; // Saldırmıyorsa geçersiz koordinat
assign p1_hitbox_x2_to_game_logic = p1_is_attacking_active_out ?
                               (p1_is_facing_right_out ?
                                   (p1_actual_x_position_out + p1_current_hitbox_offset_out + p1_current_hitbox_width_out - 1) :
                                   (p1_actual_x_position_out - p1_current_hitbox_offset_out - 1)) :
                               10'd0; // Saldırmıyorsa geçersiz koordinat (x1'den küçük)

// Player 2 (o_x_pos'un sol kenar olduğu varsayımıyla)
assign p2_hurtbox_x1_to_game_logic = p2_actual_x_position_out;
assign p2_hurtbox_x2_to_game_logic = p2_actual_x_position_out + p2_actual_hurtbox_width_out - 1;

assign p2_hitbox_x1_to_game_logic = p2_is_attacking_active_out ?
                               (p2_is_facing_right_out ?
                                   (p2_actual_x_position_out + p2_current_hitbox_offset_out) :
                                   (p2_actual_x_position_out - p2_current_hitbox_offset_out - p2_current_hitbox_width_out)) :
                               10'd0;
assign p2_hitbox_x2_to_game_logic = p2_is_attacking_active_out ?
                               (p2_is_facing_right_out ?
                                   (p2_actual_x_position_out + p2_current_hitbox_offset_out + p2_current_hitbox_width_out - 1) :
                                   (p2_actual_x_position_out - p2_current_hitbox_offset_out - 1)) :
                               10'd0;


// --- Game Logic FSM ---
game_logic_fsm game_logic_inst (
    .clk_game_logic(clk_60Hz_game_logic), .reset(system_reset),
    .p1_confirm_in(p1_confirm_ctrl), .selected_mode_in(selected_mode_ctrl),

    .p1_x_in(p1_x_to_game_logic_and_vga), .p1_state_in(p1_state_to_game_logic),
    .p1_is_attacking_active_in(p1_attacking_to_game_logic_and_vga),
    .p1_hitbox_x1_in(p1_hitbox_x1_to_game_logic), .p1_hitbox_x2_in(p1_hitbox_x2_to_game_logic),
    .p1_hurtbox_x1_in(p1_hurtbox_x1_to_game_logic), .p1_hurtbox_x2_in(p1_hurtbox_x2_to_game_logic),
    .p1_is_moving_backward_in(p1_moving_backward_to_game_logic),

    .p2_x_in(p2_x_to_game_logic_and_vga), .p2_state_in(p2_state_to_game_logic),
    .p2_is_attacking_active_in(p2_attacking_to_game_logic_and_vga),
    .p2_hitbox_x1_in(p2_hitbox_x1_to_game_logic), .p2_hitbox_x2_in(p2_hitbox_x2_to_game_logic),
    .p2_hurtbox_x1_in(p2_hurtbox_x1_to_game_logic), .p2_hurtbox_x2_in(p2_hurtbox_x2_to_game_logic),
    .p2_is_moving_backward_in(p2_moving_backward_to_game_logic),

    .game_phase_out(game_phase_from_fsm),
    .countdown_value_out(countdown_val_from_fsm),
    .game_seconds_elapsed_out(game_seconds_from_fsm),
    .winner_info_out(winner_info_from_fsm),
    .p1_hp_out(p1_hp_from_fsm), .p1_bp_out(p1_bp_from_fsm),
    .p2_hp_out(p2_hp_from_fsm), .p2_bp_out(p2_bp_from_fsm),
    .all_leds_blink_cmd_out(all_leds_blink_cmd_top),
    .p1_hit_confirm_out(p1_hit_confirm_to_p1_fsm), .p1_block_confirm_out(p1_block_confirm_to_p1_fsm),
    .p2_hit_confirm_out(p2_hit_confirm_to_p2_fsm), .p2_block_confirm_out(p2_block_confirm_to_p2_fsm)
);

// --- VGA Graphics Connector ---
vga_graphics_connector graphics_conn_inst (
    .clk_pixel(clk_25MHz_vga), .reset(system_reset),
    .i_game_phase(game_phase_from_fsm),
    .i_p1_x_pos(p1_x_to_game_logic_and_vga), // Player 1 FSM'den gelen pozisyon
    .i_p2_x_pos(p2_x_to_game_logic_and_vga), // Player 2 FSM'den gelen pozisyon
    .i_p1_is_attacking(p1_attacking_to_game_logic_and_vga), // Player 1 FSM'den
    .i_p2_is_attacking(p2_attacking_to_game_logic_and_vga), // Player 2 FSM'den
    .i_vga_next_x(vga_driver_next_x), 
    .i_vga_next_y(vga_driver_next_y),
    .o_pixel_color_data(pixel_color_from_graphics)
);

// --- VGA Driver (Sizin sağladığınız modül) ---
vga_driver vga_driver_inst (
    .clock(clk_25MHz_vga), .reset(system_reset),
    .color_in(pixel_color_from_graphics),
    .next_x(vga_driver_next_x), .next_y(vga_driver_next_y),
    .hsync(VGA_HS), .vsync(VGA_VS),
    .red(VGA_R), .green(VGA_G), .blue(VGA_B),
    .sync(VGA_SYNC_N), .clk(VGA_CLK), .blank(VGA_BLANK_N)
);

// --- 7-Segment Display Driver ---
SevenSegmentDisplay_module seven_seg_display_inst (
    .reset(system_reset),
    .i_game_phase(game_phase_from_fsm),
    .i_sw0_current_mode_selection(selected_mode_ctrl),
    .i_winner_info(winner_info_from_fsm),
    .i_elapsed_time_seconds(game_seconds_from_fsm),
    .o_hex5_pattern(HEX5),
    .o_hex4_pattern(HEX4),
    .o_hex3_pattern(HEX3),
    .o_hex2_pattern(HEX2),
    .o_hex1_pattern(HEX1),
    .o_hex0_pattern(HEX0)
);

// --- LED Output ---
LED_Output_module led_output_inst (
    .clk_game_logic(clk_60Hz_game_logic), .reset(system_reset),
    .i_p1_hp(p1_hp_from_fsm), .i_p2_hp(p2_hp_from_fsm),
    .i_game_phase(game_phase_from_fsm), // game_logic_fsm'den gelen oyun aşaması
    .o_led_p1_hp_0(LEDR_P1_HP0), .o_led_p1_hp_1(LEDR_P1_HP1), .o_led_p1_hp_2(LEDR_P1_HP2),
    .o_led_p2_hp_0(LEDR_P2_HP0), .o_led_p2_hp_1(LEDR_P2_HP1), .o_led_p2_hp_2(LEDR_P2_HP2)
    // Eğer LED_Output_module all_leds_blink_cmd_top'ı işleyecekse, buraya input olarak eklenmeli
    // .i_all_leds_blink_cmd(all_leds_blink_cmd_top)
);

assign LEDR_ALL_BLINK = all_leds_blink_cmd_top;

endmodule