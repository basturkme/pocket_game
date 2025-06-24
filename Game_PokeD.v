
//=======================================================
//  Game_PokeD Top-Level Module (DÜZELTİLMİŞ)
//=======================================================

module Game_PokeD(
    input wire CLOCK_50,
    output wire [6:0] HEX0, output wire [6:0] HEX1, output wire [6:0] HEX2,
    output wire [6:0] HEX3, output wire [6:0] HEX4, output wire [6:0] HEX5,
    input wire [3:0] KEY,
    input wire [9:0] SW,
    output wire [9:0] LEDR,
    inout wire [35:0] GPIO, // <--- HATA 2 İÇİN EKLENEN PORT TANIMI
    output wire VGA_BLANK_N, output wire [7:0] VGA_B, output wire VGA_CLK,
    output wire [7:0] VGA_G, output wire VGA_HS, output wire [7:0] VGA_R,
    output wire VGA_SYNC_N, output wire VGA_VS
);

    //=======================================================
    //  Wires and Regs
    //=======================================================

    // --- Keypad (GPIO kullanımı) ---
    // Not: Bu atamalar için GPIO pinlerinin yönünün doğru ayarlandığından emin olun.
    wire key0 = ~GPIO[1];  // K0
    wire key1 = ~GPIO[3];  // K1
    wire key2 = ~GPIO[5];  // K2
    wire key3 = ~GPIO[7];  // K3
    assign GPIO[9] = 1'b0; // Genellikle keypad için bir pini topraklamak gerekir.

    // --- Clock and Reset Signals ---
    wire sys_master_reset; // <--- HATA 1 İÇİN TEMİZLENMİŞ SATIR
    wire clk_25MHz_vga;
    wire clk_60Hz_game_logic_source;
    wire clock_mode_is_key0_step;
    wire effective_game_logic_clk;
    reg  key0_on_clk50_s1, key0_on_clk50_s2;
    wire key0_debounced_ish;
    reg  key0_sync_s1_for_tick, key0_sync_s2_for_tick, key0_sync_s2_prev_for_tick;
    wire key0_clk_tick_for_game_logic;

    // --- Game Logic FSM Signals ---
    wire [1:0] game_phase_from_fsm, winner_info_from_fsm;
    wire [2:0] countdown_val_from_fsm, p1_hp_from_fsm, p2_hp_from_fsm, p1_bp_from_fsm, p2_bp_from_fsm;
    wire [6:0] game_seconds_from_fsm;
    wire all_leds_blink_cmd_top;
    wire p1_hit_confirm_to_p1_fsm, p1_block_confirm_to_p1_fsm;
    wire p2_hit_confirm_to_p2_fsm, p2_block_confirm_to_p2_fsm;
    wire software_reset_from_gamelogic;
    wire player_fsm_reset_signal;
    // --- Player FSM Signals ---
    wire [9:0] p1_actual_x_position_out, p1_current_hitbox_offset_out, p1_current_hitbox_width_out, p1_actual_hurtbox_width_out;
    wire [2:0] p1_current_state_out;
    wire p1_is_attacking_active_out, p1_is_facing_right_out, p1_is_in_recovery_out, p1_is_holding_backward_out, p1_is_actively_blocking_out;

	 
    wire [9:0] p2_actual_x_position_out, p2_current_hitbox_offset_out, p2_current_hitbox_width_out, p2_actual_hurtbox_width_out;
    wire [2:0] p2_current_state_out;
    wire p2_is_attacking_active_out, p2_is_facing_right_out, p2_is_in_recovery_out, p2_is_holding_backward_out, p2_is_actively_blocking_out;

	 
    // --- Intermediate Signals ---
    wire [9:0] p1_x_for_logic_and_vga, p1_hitbox_x1_calc, p1_hitbox_x2_calc, p1_hurtbox_x1_calc, p1_hurtbox_x2_calc;
    wire [2:0] p1_state_to_game_logic;
    wire p1_attacking_for_logic_and_vga, p1_moving_backward_to_game_logic;

    wire [9:0] p2_x_for_logic_and_vga, p2_hitbox_x1_calc, p2_hitbox_x2_calc, p2_hurtbox_x1_calc, p2_hurtbox_x2_calc;
    wire [2:0] p2_state_to_game_logic;
    wire p2_attacking_for_logic_and_vga, p2_moving_backward_to_game_logic;

    // --- CPU and Control Signals ---
    wire cpu_p2_move_left_cmd_top, cpu_p2_move_right_cmd_top, cpu_p2_attack_cmd_top, cpu_enable_signal_top;
    wire p1_move_left_ctrl, p1_move_right_ctrl, p1_attack_ctrl, p1_confirm_ctrl;
    wire p2_human_move_left_ctrl, p2_human_move_right_ctrl, p2_human_attack_ctrl;
    wire p2_move_left_selected_ctrl, p2_move_right_selected_ctrl, p2_attack_selected_ctrl;
    wire selected_mode_ctrl, i_show_hitboxes_continuously_sw;
    
    // --- VGA and HEX Signals ---
    wire [9:0] vga_driver_next_x, vga_driver_next_y;
    wire [7:0] pixel_color_from_graphics;
    reg [3:0] hex0_data_in, hex1_data_in, hex2_data_in, hex3_data_in, hex4_data_in, hex5_data_in;

    //=======================================================
    //  Structural Coding
    //=======================================================

    // --- Top-Level Assignments ---
    assign clock_mode_is_key0_step = SW[1];
    assign sys_master_reset = clock_mode_is_key0_step ? 1'b0 : ~KEY[0];
    assign i_show_hitboxes_continuously_sw = SW[5];
    assign player_fsm_reset_signal = sys_master_reset || software_reset_from_gamelogic;
    
    // --- Clocking ---
    clock_divider_functional #(.DIVISOR(2)) clk25(.clk(CLOCK_50), .reset(sys_master_reset), .clk_out(clk_25MHz_vga));
    clock_divider_functional #(.DIVISOR(833333)) clk60(.clk(CLOCK_50), .reset(sys_master_reset), .clk_out(clk_60Hz_game_logic_source));

    always @(posedge CLOCK_50 or posedge sys_master_reset) begin
        if (sys_master_reset) begin
            key0_on_clk50_s1 <= 1'b1;
            key0_on_clk50_s2 <= 1'b1;
        end else begin
            key0_on_clk50_s1 <= KEY[0];
            key0_on_clk50_s2 <= key0_on_clk50_s1;
        end
    end
    assign key0_debounced_ish = key0_on_clk50_s2;

    always @(posedge clk_60Hz_game_logic_source or posedge sys_master_reset) begin
        if (sys_master_reset) begin
            key0_sync_s1_for_tick <= 1'b1;
            key0_sync_s2_for_tick <= 1'b1;
            key0_sync_s2_prev_for_tick <= 1'b1;
        end else if (clock_mode_is_key0_step) begin
            key0_sync_s1_for_tick <= key0_debounced_ish;
            key0_sync_s2_for_tick <= key0_sync_s1_for_tick;
            key0_sync_s2_prev_for_tick <= key0_sync_s2_for_tick;
        end else begin
            key0_sync_s1_for_tick <= 1'b1;
            key0_sync_s2_for_tick <= 1'b1;
            key0_sync_s2_prev_for_tick <= 1'b1;
        end
    end
    assign key0_clk_tick_for_game_logic = clock_mode_is_key0_step ? (key0_sync_s2_prev_for_tick & ~key0_sync_s2_for_tick) : 1'b0;
    assign effective_game_logic_clk = clock_mode_is_key0_step ? key0_clk_tick_for_game_logic : clk_60Hz_game_logic_source;
    
	// --- Control Logic ---
	assign selected_mode_ctrl = SW[0]; // 0: 2-Oyuncu, 1: CPU'ya karşı

	// --- CPU Bot ---
	// CPU'nun ne zaman aktif olacağını belirleyen sinyal.
	assign cpu_enable_signal_top = (selected_mode_ctrl == 1'b1) && (game_phase_from_fsm == 2'b10);

	cpu_bot cpubot(
		  .clk_game_logic(effective_game_logic_clk),
		  .reset(sys_master_reset),
		  .enable_bot(cpu_enable_signal_top),
		  .p1_x_pos_in(p1_actual_x_position_out),
		  .p2_x_pos_in(p2_actual_x_position_out),
		  .cpu_move_left_out(cpu_p2_move_left_cmd_top),
		  .cpu_move_right_out(cpu_p2_move_right_cmd_top),
		  .cpu_attack_out(cpu_p2_attack_cmd_top)
	 );
	 
	// --- CPU veya İnsan kontrolü seçimi ---
	// SW[0]'a göre Oyuncu 2 için ya insan (keypad) ya da CPU kontrolü seçilir.
	assign p2_move_left_selected_ctrl  = (selected_mode_ctrl == 1'b0) ? p2_human_move_left_ctrl : cpu_p2_move_left_cmd_top;
	assign p2_move_right_selected_ctrl = (selected_mode_ctrl == 1'b0) ? p2_human_move_right_ctrl : cpu_p2_move_right_cmd_top;
	assign p2_attack_selected_ctrl     = (selected_mode_ctrl == 1'b0) ? p2_human_attack_ctrl : cpu_p2_attack_cmd_top;

	// --- Oyuncu 1 Kontrolleri (DE1-SoC Kartı üzerindeki tuşlar) ---
	assign p1_confirm_ctrl      = ~KEY[1];
	assign p1_attack_ctrl       = ~KEY[1];
	assign p1_move_right_ctrl   = ~KEY[2];
	assign p1_move_left_ctrl    = ~KEY[3];

	// --- Oyuncu 2 Kontrolleri (GPIO'ya bağlı harici keypad) ---
	assign p2_human_move_left_ctrl  = ~GPIO[5]; // Keypad K2
	assign p2_human_move_right_ctrl = ~GPIO[3]; // Keypad K1
	assign p2_human_attack_ctrl     = ~GPIO[1]; // Keypad K0
    // --- Module Instantiations ---
	player_fsm p1fsm(
			 .clk_game_logic(effective_game_logic_clk),
			 .reset(player_fsm_reset_signal),
			 .attack(p1_attack_ctrl),
			 .move_left(p1_move_left_ctrl),
			 .move_right(p1_move_right_ctrl),
			 .main_player(1'b1),
			 .opponent_x_pos(p2_actual_x_position_out),
			 .opponent_actual_hurtbox_width(p2_actual_hurtbox_width_out),
			 .hit_by_opponent(p1_hit_confirm_to_p1_fsm),
			 .confirmed_my_block(p1_block_confirm_to_p1_fsm),
			 .x_pos_player(p1_actual_x_position_out),
			 .player_state(p1_current_state_out),
			 .hitbox_x_offset(p1_current_hitbox_offset_out),
			 .hitbox_width(p1_current_hitbox_width_out),
			 .hurtbox_width(p1_actual_hurtbox_width_out),
			 .hitbox_active(p1_is_attacking_active_out),
			 .looking_right(p1_is_facing_right_out),
			 .is_in_recovery(p1_is_in_recovery_out),
			 .is_holding_backward(p1_is_holding_backward_out),
			 .is_actively_blocking(p1_is_actively_blocking_out),
		);
	 player_fsm p2fsm(
			 .clk_game_logic(effective_game_logic_clk),
			 .reset(player_fsm_reset_signal),
			 .attack(p2_attack_selected_ctrl),
			 .move_left(p2_move_left_selected_ctrl),
			 .move_right(p2_move_right_selected_ctrl),
			 .main_player(1'b0),
			 .opponent_x_pos(p1_actual_x_position_out),
			 .opponent_actual_hurtbox_width(p1_actual_hurtbox_width_out),
			 .hit_by_opponent(p2_hit_confirm_to_p2_fsm),
			 .confirmed_my_block(p2_block_confirm_to_p2_fsm),
			 .x_pos_player(p2_actual_x_position_out),
			 .player_state(p2_current_state_out),
			 .hitbox_x_offset(p2_current_hitbox_offset_out),
			 .hitbox_width(p2_current_hitbox_width_out),
			 .hurtbox_width(p2_actual_hurtbox_width_out),
			 .hitbox_active(p2_is_attacking_active_out),
			 .looking_right(p2_is_facing_right_out),
			 .is_in_recovery(p2_is_in_recovery_out),
			 .is_holding_backward(p2_is_holding_backward_out),
			 .is_actively_blocking(p2_is_actively_blocking_out),

		);
    assign p1_x_for_logic_and_vga = p1_actual_x_position_out;
    assign p1_attacking_for_logic_and_vga = p1_is_attacking_active_out;
    assign p1_state_to_game_logic = p1_current_state_out;
    assign p1_moving_backward_to_game_logic = p1_is_holding_backward_out;
    assign p2_x_for_logic_and_vga = p2_actual_x_position_out;
    assign p2_attacking_for_logic_and_vga = p2_is_attacking_active_out;
    assign p2_state_to_game_logic = p2_current_state_out;
    assign p2_moving_backward_to_game_logic = p2_is_holding_backward_out;

    wire signed [11:0] p1_hitbox_x1_s, p1_hitbox_x2_s;
    wire signed [11:0] p2_hitbox_x1_s, p2_hitbox_x2_s;
    
    assign p1_hurtbox_x1_calc = p1_actual_x_position_out;
    assign p1_hurtbox_x2_calc = p1_actual_x_position_out + p1_actual_hurtbox_width_out - 1;
    assign p1_hitbox_x1_s = p1_is_facing_right_out ? (p1_actual_x_position_out + p1_actual_hurtbox_width_out + p1_current_hitbox_offset_out) : (p1_actual_x_position_out - p1_current_hitbox_offset_out - p1_current_hitbox_width_out);
    assign p1_hitbox_x2_s = p1_hitbox_x1_s + p1_current_hitbox_width_out - 1;
    assign p1_hitbox_x1_calc = p1_is_attacking_active_out ? (p1_hitbox_x1_s < 0 ? 0 : p1_hitbox_x1_s[9:0]) : 10'd0;
    assign p1_hitbox_x2_calc = p1_is_attacking_active_out ? (p1_hitbox_x2_s < 0 ? 0 : p1_hitbox_x2_s[9:0]) : 10'd0;

    assign p2_hurtbox_x1_calc = p2_actual_x_position_out;
    assign p2_hurtbox_x2_calc = p2_actual_x_position_out + p2_actual_hurtbox_width_out - 1;
    assign p2_hitbox_x1_s = p2_is_facing_right_out ? (p2_actual_x_position_out + p2_actual_hurtbox_width_out + p2_current_hitbox_offset_out) : (p2_actual_x_position_out - p2_current_hitbox_offset_out - p2_current_hitbox_width_out);
    assign p2_hitbox_x2_s = p2_hitbox_x1_s + p2_current_hitbox_width_out - 1;
    assign p2_hitbox_x1_calc = p2_is_attacking_active_out ? (p2_hitbox_x1_s < 0 ? 0 : p2_hitbox_x1_s[9:0]) : 10'd0;
    assign p2_hitbox_x2_calc = p2_is_attacking_active_out ? (p2_hitbox_x2_s < 0 ? 0 : p2_hitbox_x2_s[9:0]) : 10'd0;
    
    game_logic_fsm game_logic_inst(
         .clk_game_logic(effective_game_logic_clk),
         .reset(sys_master_reset),
         .p1_confirm_in(p1_confirm_ctrl),
         .selected_mode_in(selected_mode_ctrl),
         .p1_x_in(p1_x_for_logic_and_vga),
         .p1_state_in(p1_state_to_game_logic),
         .p1_is_attacking_active_in(p1_attacking_for_logic_and_vga),
         .p1_hitbox_x1_in(p1_hitbox_x1_calc),
         .p1_hitbox_x2_in(p1_hitbox_x2_calc),
         .p1_hurtbox_x1_in(p1_hurtbox_x1_calc),
         .p1_hurtbox_x2_in(p1_hurtbox_x2_calc),
         .p1_is_moving_backward_in(p1_moving_backward_to_game_logic),
         .p1_is_actively_blocking_in(p1_is_actively_blocking_out),
         .p1_is_facing_right_in(p1_is_facing_right_out),
         .p2_x_in(p2_x_for_logic_and_vga),
         .p2_state_in(p2_state_to_game_logic),
         .p2_is_attacking_active_in(p2_attacking_for_logic_and_vga),
         .p2_hitbox_x1_in(p2_hitbox_x1_calc),
         .p2_hitbox_x2_in(p2_hitbox_x2_calc),
         .p2_hurtbox_x1_in(p2_hurtbox_x1_calc),
         .p2_hurtbox_x2_in(p2_hurtbox_x2_calc),
         .p2_is_moving_backward_in(p2_moving_backward_to_game_logic),
         .p2_is_actively_blocking_in(p2_is_actively_blocking_out),
         .p2_is_facing_right_in(p2_is_facing_right_out),
         .game_phase_out(game_phase_from_fsm),
         .countdown_value_out(countdown_val_from_fsm),
         .game_seconds_elapsed_out(game_seconds_from_fsm), // Zamanlayıcı çıkışı
         .winner_info_out(winner_info_from_fsm),
         .p1_hp_out(p1_hp_from_fsm),
         .p1_bp_out(p1_bp_from_fsm),
         .p2_hp_out(p2_hp_from_fsm),
         .p2_bp_out(p2_bp_from_fsm),
         .all_leds_blink_cmd_out(all_leds_blink_cmd_top),
         .p1_hit_confirm_out(p1_hit_confirm_to_p1_fsm),
         .p1_block_confirm_out(p1_block_confirm_to_p1_fsm),
         .p2_hit_confirm_out(p2_hit_confirm_to_p2_fsm),
         .p2_block_confirm_out(p2_block_confirm_to_p2_fsm),
         .o_software_reset(software_reset_from_gamelogic)
    );  
	 
	 vga_graphics_connector graphics_conn_inst(
			 .clk_pixel(clk_25MHz_vga),
			 .reset(sys_master_reset),
			 .i_game_phase(game_phase_from_fsm),
			 .i_p1_is_attacking(p1_attacking_for_logic_and_vga),
			 .i_p2_is_attacking(p2_attacking_for_logic_and_vga),
			 .i_p1_hp(p1_hp_from_fsm),
			 .i_p2_hp(p2_hp_from_fsm),
			 .i_p1_bp(p1_bp_from_fsm),
			 .i_p2_bp(p2_bp_from_fsm),
			 .i_winner_info(winner_info_from_fsm),
			 .i_countdown_value(game_phase_from_fsm == 2'b10 ? game_seconds_from_fsm : {4'b0, countdown_val_from_fsm}),			         // Oyun başlangıcındaki 3-bit'lik 'countdown_val_from_fsm' yerine, 
        // oyun içindeki 7-bit'lik 'game_seconds_from_fsm' sinyalini bağlıyoruz.
        // NOT: vga_graphics_connector modülü hem başlangıç sayımı hem de oyun sayacı için
        // aynı portu (i_countdown_value) kullanacak şekilde düzenlenmiştir.
			 .i_p1_hitbox_x1(p1_hitbox_x1_calc),
			 .i_p1_hitbox_x2(p1_hitbox_x2_calc),
			 .i_p1_hurtbox_x1(p1_hurtbox_x1_calc),
			 .i_p1_hurtbox_x2(p1_hurtbox_x2_calc),
			 .i_p2_hitbox_x1(p2_hitbox_x1_calc),
			 .i_p2_hitbox_x2(p2_hitbox_x2_calc),
			 .i_p2_hurtbox_x1(p2_hurtbox_x1_calc),
			 .i_p2_hurtbox_x2(p2_hurtbox_x2_calc),
			 .i_show_hitboxes_continuously(i_show_hitboxes_continuously_sw),
			 .i_p1_fsm_state(p1_current_state_out),
			 .i_p2_fsm_state(p2_current_state_out),
			 .i_p1_is_facing_right(p1_is_facing_right_out),
			 .i_p2_is_facing_right(p2_is_facing_right_out),
			 .i_p1_is_in_recovery(p1_is_in_recovery_out),
			 .i_p2_is_in_recovery(p2_is_in_recovery_out),

			 .i_vga_next_x(vga_driver_next_x),
			 .i_vga_next_y(vga_driver_next_y),
			 .o_pixel_color_data(pixel_color_from_graphics)
		);
	 
	 vga_driver vga_driver_inst(
			 .clock(clk_25MHz_vga),
			 .reset(sys_master_reset),
			 .color_in(pixel_color_from_graphics),
			 .next_x(vga_driver_next_x),
			 .next_y(vga_driver_next_y),
			 .hsync(VGA_HS),
			 .vsync(VGA_VS),
			 .red(VGA_R),
			 .green(VGA_G),
			 .blue(VGA_B),
			 .sync(VGA_SYNC_N),
			 .clk(VGA_CLK),
			 .blank(VGA_BLANK_N)
		);    
// --- 7-Segment Display Logic ---
	always@(*) begin
        reg [3:0] game_seconds_units, game_seconds_tens;
        automatic integer seconds_int = game_seconds_from_fsm;
        game_seconds_tens = (seconds_int / 10) % 10;
        game_seconds_units = seconds_int % 10;
        
        case (game_phase_from_fsm)
            2'b10: begin // Gameplay: "FIGHT "
                hex5_data_in = 4'hE; // F
                hex4_data_in = 4'h1; // I
                hex3_data_in = 4'h6; // G
                hex2_data_in = 4'h4; // H
                hex1_data_in = 4'h7; // t
                hex0_data_in = 4'hF; // Blank
            end
            2'b11: begin // Game Over
                case (winner_info_from_fsm)
                    2'b01: begin // P1 WINS: "P1  XX"
                        hex5_data_in = 4'hC; // P
                        hex4_data_in = 4'h1; // 1
                        hex3_data_in = 4'hF; // Blank
                        hex2_data_in = 4'hF; // Blank
                        hex1_data_in = game_seconds_tens;
                        hex0_data_in = game_seconds_units;
                    end
                    2'b10: begin // P2 Wins: "P2  XX"
                        hex5_data_in = 4'hC; // P
                        hex4_data_in = 4'h2; // 2
                        hex3_data_in = 4'hF; // Blank
                        hex2_data_in = 4'hF; // Blank
                        hex1_data_in = game_seconds_tens;
                        hex0_data_in = game_seconds_units;
                    end
                    default: begin // Draw: "  Eq  "
                        hex5_data_in = 4'hF; 
                        hex4_data_in = 4'hF; 
                        hex3_data_in = 4'h8; // E
                        hex2_data_in = 4'h9; // q
                        hex1_data_in = 4'hF; // Blank
                        hex0_data_in = 4'hF; 
                    end
                endcase
            end
            default: begin // Menu, Countdown
                hex5_data_in = 4'hF; hex4_data_in = 4'hF; hex3_data_in = 4'hF; hex2_data_in = 4'hF; 
                hex1_data_in = game_seconds_tens;
                hex0_data_in = game_seconds_units;
            end
        endcase
    end
    hexto7seg h0(.hex(hex0_data_in), .hexn(HEX0));
    hexto7seg h1(.hex(hex1_data_in), .hexn(HEX1));
    hexto7seg h2(.hex(hex2_data_in), .hexn(HEX2));
    hexto7seg h3(.hex(hex3_data_in), .hexn(HEX3));
    hexto7seg h4(.hex(hex4_data_in), .hexn(HEX4));
    hexto7seg h5(.hex(hex5_data_in), .hexn(HEX5));
    
    // --- LED Blinking Logic ---
    reg [24:0] blink_counter = 0;
    wire blink_signal;
    assign blink_signal = blink_counter[24];

    always @(posedge CLOCK_50 or posedge sys_master_reset) begin
        if (sys_master_reset) blink_counter <= 0;
        else blink_counter <= blink_counter + 1;
    end

    assign LEDR[9] = all_leds_blink_cmd_top ? blink_signal : (game_phase_from_fsm == 2'b10 ? (p1_hp_from_fsm >= 1) : 1'b0);
    assign LEDR[8] = all_leds_blink_cmd_top ? blink_signal : (game_phase_from_fsm == 2'b10 ? (p1_hp_from_fsm >= 2) : 1'b0);
    assign LEDR[7] = all_leds_blink_cmd_top ? blink_signal : (game_phase_from_fsm == 2'b10 ? (p1_hp_from_fsm >= 3) : 1'b0);
    
    assign LEDR[2] = all_leds_blink_cmd_top ? blink_signal : (game_phase_from_fsm == 2'b10 ? (p2_hp_from_fsm >= 1) : 1'b0);
    assign LEDR[1] = all_leds_blink_cmd_top ? blink_signal : (game_phase_from_fsm == 2'b10 ? (p2_hp_from_fsm >= 2) : 1'b0);
    assign LEDR[0] = all_leds_blink_cmd_top ? blink_signal : (game_phase_from_fsm == 2'b10 ? (p2_hp_from_fsm >= 3) : 1'b0);
    
    assign LEDR[6:3] = {4{all_leds_blink_cmd_top & blink_signal}};

endmodule