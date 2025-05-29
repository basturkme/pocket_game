// player_fsm.v
// Adapted to follow a two-process FSM style (combinational next-state/output logic, sequential state/register update)
// with explicit begin-end for all procedural blocks.
module player_fsm (
    input wire       clk_game_logic, // 60Hz game clock
    input wire       reset,

    // Control Inputs from Input Handler
    input wire       i_move_left,
    input wire       i_move_right,
    input wire       i_attack,

    // Game Environment Inputs
    input wire [9:0] i_opponent_x_pos,
    input wire [9:0] i_my_current_x_pos, // Feedback of this FSM's o_x_pos
    input wire       i_am_player1,
    input wire       i_hit_by_opponent,
    input wire       i_blocked_attack,

    // Outputs
    output reg [9:0] o_x_pos,
    output reg [3:0] o_player_state,    // Current state of the player
    output reg       o_hitbox_active,
    output reg [9:0] o_hitbox_x_offset,
    output reg [9:0] o_hitbox_width,
    output wire [7:0] o_hurtbox_width,   // Player sprite width
    output wire [7:0] o_hurtbox_height,  // Player sprite height
    output reg       o_facing_right
	 
);

    // Parameters (same as before)
    localparam SCREEN_WIDTH = 640;
    localparam PLAYER_SPRITE_WIDTH = 64;
    localparam PLAYER_SPRITE_HEIGHT = 240;
    localparam MOVE_SPEED_FWD = 3;
    localparam MOVE_SPEED_BWD = 2;

    localparam STATE_IDLE           = 4'd0;
    localparam STATE_MOVING_FWD     = 4'd1;
    localparam STATE_MOVING_BWD     = 4'd2;
    localparam STATE_ATTACK_STARTUP = 4'd3;
    localparam STATE_ATTACK_ACTIVE  = 4'd4;
    localparam STATE_ATTACK_RECOVERY= 4'd5;
    localparam STATE_HITSTUN        = 4'd6;
    localparam STATE_BLOCKSTUN      = 4'd7;

    localparam N_ATTK_STARTUP_FRAMES   = 5;
    localparam N_ATTK_ACTIVE_FRAMES    = 2;
    localparam N_ATTK_RECOVERY_FRAMES  = 16;
    localparam N_ATTK_DEFENDER_HITSTUN_FRAMES   = N_ATTK_RECOVERY_FRAMES - 1;
    localparam N_ATTK_DEFENDER_BLOCKSTUN_FRAMES = N_ATTK_RECOVERY_FRAMES - 3;

    localparam D_ATTK_STARTUP_FRAMES   = 4;
    localparam D_ATTK_ACTIVE_FRAMES    = 3;
    localparam D_ATTK_RECOVERY_FRAMES  = 15;
    localparam D_ATTK_DEFENDER_HITSTUN_FRAMES   = D_ATTK_RECOVERY_FRAMES - 1;
    localparam D_ATTK_DEFENDER_BLOCKSTUN_FRAMES = D_ATTK_RECOVERY_FRAMES - 3;

    localparam N_ATTK_HITBOX_WIDTH      = 30;
    localparam D_ATTK_HITBOX_WIDTH      = 20;

    // Current state and internal registers
    reg [3:0] current_player_state_reg; // Internal current state
    reg [9:0] x_pos_reg;
    reg [7:0] state_timer_reg;
    reg       hitbox_active_reg;
    reg [9:0] hitbox_x_offset_reg;
    reg [9:0] hitbox_width_reg;
    reg       facing_right_reg;
    reg       current_attack_is_directional_type_reg;

    // Next state and next values for internal registers (calculated combinationally)
    reg [3:0] next_player_state_calc;
    reg [9:0] x_pos_next_calc;
    reg [7:0] state_timer_next_calc;
    reg       hitbox_active_next_calc;
    reg [9:0] hitbox_x_offset_next_calc;
    reg [9:0] hitbox_width_next_calc;
    reg       facing_right_next_calc;
    reg       current_attack_is_directional_type_next_calc;
	 
	 assign o_hurtbox_width = PLAYER_SPRITE_WIDTH;
		assign o_hurtbox_height = PLAYER_SPRITE_HEIGHT;


    // Sequential block: Update current state and registers from next values
    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            current_player_state_reg <= STATE_IDLE;
            x_pos_reg <= (i_am_player1) ? 100 : SCREEN_WIDTH - 100 - PLAYER_SPRITE_WIDTH;
            state_timer_reg <= 0;
            hitbox_active_reg <= 1'b0;
            hitbox_x_offset_reg <= 0;
            hitbox_width_reg <= 0;
            facing_right_reg <= i_am_player1;
            current_attack_is_directional_type_reg <= 1'b0;

            o_x_pos <= (i_am_player1) ? 100 : SCREEN_WIDTH - 100 - PLAYER_SPRITE_WIDTH;
            o_player_state <= STATE_IDLE;
            o_hitbox_active <= 1'b0;
            o_hitbox_x_offset <= 0;
            o_hitbox_width <= 0;
            o_facing_right <= i_am_player1;
        end else begin
            current_player_state_reg <= next_player_state_calc;
            x_pos_reg <= x_pos_next_calc;
            state_timer_reg <= state_timer_next_calc;
            hitbox_active_reg <= hitbox_active_next_calc;
            hitbox_x_offset_reg <= hitbox_x_offset_next_calc;
            hitbox_width_reg <= hitbox_width_next_calc;
            facing_right_reg <= facing_right_next_calc;
            current_attack_is_directional_type_reg <= current_attack_is_directional_type_next_calc;

            o_player_state <= current_player_state_reg;
            o_x_pos <= x_pos_reg;
            o_hitbox_active <= hitbox_active_reg;
            o_hitbox_x_offset <= hitbox_x_offset_reg;
            o_hitbox_width <= hitbox_width_reg;
            o_facing_right <= facing_right_reg;
        end
    end
    
    // Assign constant outputs
    assign o_hurtbox_width = PLAYER_SPRITE_WIDTH;
    assign o_hurtbox_height = PLAYER_SPRITE_HEIGHT;


    // Combinational block: Calculate next state and next values for registers/outputs
    always @(*) begin
        next_player_state_calc = current_player_state_reg;
        x_pos_next_calc = x_pos_reg; 
        state_timer_next_calc = state_timer_reg;
        hitbox_active_next_calc = hitbox_active_reg;
        hitbox_x_offset_next_calc = hitbox_x_offset_reg;
        hitbox_width_next_calc = hitbox_width_reg;
        facing_right_next_calc = facing_right_reg;
        current_attack_is_directional_type_next_calc = current_attack_is_directional_type_reg;

        if (x_pos_reg < i_opponent_x_pos) begin
            facing_right_next_calc = 1'b1;
        end else if (x_pos_reg > i_opponent_x_pos) begin
            facing_right_next_calc = 1'b0;
        end
        // else facing_right_next_calc remains its current value (facing_right_reg)

        hitbox_active_next_calc = 1'b0; // Default off, enabled only in ATTACK_ACTIVE

        case (current_player_state_reg)
            STATE_IDLE: begin
                if (i_hit_by_opponent) begin
                    next_player_state_calc = STATE_HITSTUN;
                    state_timer_next_calc = N_ATTK_DEFENDER_HITSTUN_FRAMES - 1;
                end else if (i_blocked_attack) begin
                    next_player_state_calc = STATE_BLOCKSTUN;
                    state_timer_next_calc = N_ATTK_DEFENDER_BLOCKSTUN_FRAMES - 1;
                end else if (i_attack) begin
                    next_player_state_calc = STATE_ATTACK_STARTUP;
                    current_attack_is_directional_type_next_calc = (i_move_left || i_move_right);
                    state_timer_next_calc = (current_attack_is_directional_type_next_calc ? D_ATTK_STARTUP_FRAMES : N_ATTK_STARTUP_FRAMES) - 1;
                end else if (i_move_left || i_move_right) begin
                    if ((facing_right_next_calc && i_move_right) || (!facing_right_next_calc && i_move_left)) begin
                        next_player_state_calc = STATE_MOVING_FWD;
                    end else begin
                        next_player_state_calc = STATE_MOVING_BWD;
                    end
                end
            end

            STATE_MOVING_FWD: begin
                reg [9:0] temp_next_x_fwd;
                if ((facing_right_next_calc && i_move_right) || (!facing_right_next_calc && i_move_left)) begin
                    if (facing_right_next_calc) begin
                        temp_next_x_fwd = x_pos_reg + MOVE_SPEED_FWD;
                        if (temp_next_x_fwd + PLAYER_SPRITE_WIDTH < i_opponent_x_pos) begin
                            x_pos_next_calc = temp_next_x_fwd;
                        end else begin
                            x_pos_next_calc = i_opponent_x_pos - PLAYER_SPRITE_WIDTH;
                        end
                    end else begin
                        temp_next_x_fwd = x_pos_reg - MOVE_SPEED_FWD;
                        if (temp_next_x_fwd > i_opponent_x_pos + PLAYER_SPRITE_WIDTH) begin
                            x_pos_next_calc = temp_next_x_fwd;
                        end else begin
                            x_pos_next_calc = i_opponent_x_pos + PLAYER_SPRITE_WIDTH;
                        end
                    end
                end

                if (i_hit_by_opponent) begin
                    next_player_state_calc = STATE_HITSTUN; 
                    state_timer_next_calc = N_ATTK_DEFENDER_HITSTUN_FRAMES - 1;
                end else if (i_blocked_attack) begin
                    next_player_state_calc = STATE_BLOCKSTUN; 
                    state_timer_next_calc = N_ATTK_DEFENDER_BLOCKSTUN_FRAMES - 1;
                end else if (i_attack) begin
                    next_player_state_calc = STATE_ATTACK_STARTUP; 
                    current_attack_is_directional_type_next_calc = 1'b1;
                    state_timer_next_calc = D_ATTK_STARTUP_FRAMES - 1;
                end else if (!((facing_right_next_calc && i_move_right) || (!facing_right_next_calc && i_move_left))) begin
                    if ((facing_right_next_calc && i_move_left) || (!facing_right_next_calc && i_move_right)) begin
                        next_player_state_calc = STATE_MOVING_BWD;
                    end else begin 
                        next_player_state_calc = STATE_IDLE; 
                    end
                end
            end

            STATE_MOVING_BWD: begin
                if ((facing_right_next_calc && i_move_left) || (!facing_right_next_calc && i_move_right)) begin
                     if (facing_right_next_calc) begin
                        if (x_pos_reg >= MOVE_SPEED_BWD) begin
                            x_pos_next_calc = x_pos_reg - MOVE_SPEED_BWD; 
                        end else begin
                            x_pos_next_calc = 0;
                        end
                    end else begin
                        if (x_pos_reg <= SCREEN_WIDTH - PLAYER_SPRITE_WIDTH - MOVE_SPEED_BWD) begin
                            x_pos_next_calc = x_pos_reg + MOVE_SPEED_BWD;
                        end else begin
                            x_pos_next_calc = SCREEN_WIDTH - PLAYER_SPRITE_WIDTH;
                        end
                    end
                end
                if (i_blocked_attack) begin
                    next_player_state_calc = STATE_BLOCKSTUN; 
                    state_timer_next_calc = N_ATTK_DEFENDER_BLOCKSTUN_FRAMES -1;
                end else if (i_hit_by_opponent) begin
                    next_player_state_calc = STATE_HITSTUN; 
                    state_timer_next_calc = N_ATTK_DEFENDER_HITSTUN_FRAMES -1;
                end else if (i_attack) begin
                    next_player_state_calc = STATE_ATTACK_STARTUP; 
                    current_attack_is_directional_type_next_calc = 1'b1;
                    state_timer_next_calc = D_ATTK_STARTUP_FRAMES - 1;
                end else if (!((facing_right_next_calc && i_move_left) || (!facing_right_next_calc && i_move_right))) begin
                    if ((facing_right_next_calc && i_move_right) || (!facing_right_next_calc && i_move_left)) begin
                        next_player_state_calc = STATE_MOVING_FWD;
                    end else begin 
                        next_player_state_calc = STATE_IDLE; 
                    end
                end
            end

            STATE_ATTACK_STARTUP: begin
                if (i_hit_by_opponent) begin
                    next_player_state_calc = STATE_HITSTUN;
                    state_timer_next_calc = N_ATTK_DEFENDER_HITSTUN_FRAMES - 1;
                    hitbox_active_next_calc = 1'b0;
                end else if (state_timer_reg == 0) begin
                    next_player_state_calc = STATE_ATTACK_ACTIVE;
                    state_timer_next_calc = (current_attack_is_directional_type_reg ? D_ATTK_ACTIVE_FRAMES : N_ATTK_ACTIVE_FRAMES) - 1;
                end else begin
                    state_timer_next_calc = state_timer_reg - 1;
                end
            end

            STATE_ATTACK_ACTIVE: begin
                hitbox_active_next_calc = 1'b1;
                hitbox_width_next_calc = (current_attack_is_directional_type_reg ? D_ATTK_HITBOX_WIDTH : N_ATTK_HITBOX_WIDTH);
                if (facing_right_reg) begin 
                    hitbox_x_offset_next_calc = PLAYER_SPRITE_WIDTH / 2;
                end else begin
                    hitbox_x_offset_next_calc = -(PLAYER_SPRITE_WIDTH / 2) - hitbox_width_next_calc; 
                end

                if (i_hit_by_opponent) begin
                    next_player_state_calc = STATE_HITSTUN;
                    state_timer_next_calc = N_ATTK_DEFENDER_HITSTUN_FRAMES - 1;
                    hitbox_active_next_calc = 1'b0;
                end else if (state_timer_reg == 0) begin
                    next_player_state_calc = STATE_ATTACK_RECOVERY;
                    state_timer_next_calc = (current_attack_is_directional_type_reg ? D_ATTK_RECOVERY_FRAMES : N_ATTK_RECOVERY_FRAMES) - 1;
                    hitbox_active_next_calc = 1'b0;
                end else begin
                    state_timer_next_calc = state_timer_reg - 1;
                end
            end

            STATE_ATTACK_RECOVERY: begin
                hitbox_active_next_calc = 1'b0;
                if (i_hit_by_opponent) begin
                    next_player_state_calc = STATE_HITSTUN;
                    state_timer_next_calc = N_ATTK_DEFENDER_HITSTUN_FRAMES - 1;
                end else if (state_timer_reg == 0) begin
                    next_player_state_calc = STATE_IDLE;
                end else begin
                    state_timer_next_calc = state_timer_reg - 1;
                end
            end

            STATE_HITSTUN: begin
                hitbox_active_next_calc = 1'b0;
                if (state_timer_reg == 0) begin
                    next_player_state_calc = STATE_IDLE;
                end else begin
                    state_timer_next_calc = state_timer_reg - 1;
                end
            end

            STATE_BLOCKSTUN: begin
                hitbox_active_next_calc = 1'b0;
                if (state_timer_reg == 0) begin
                    next_player_state_calc = STATE_IDLE;
                end else begin
                    state_timer_next_calc = state_timer_reg - 1;
                end
            end
            default: begin
                next_player_state_calc = STATE_IDLE;
            end
        endcase
    end
endmodule