module player_fsm (
	 input wire reset, // KEY[0] input reset
    input wire clk_game_logic, // Clock wire from clock manager 60Hz rate 
    

    // Inputs
	 input wire attack,
    input wire move_left,
    input wire move_right,
    

    // Logic Inputs 
	 input wire main_player, // Seperating the main player of the game
    input wire [9:0] opponent_x, // We will use this for the look mechanism of the players
    input wire hit_by_opponent, // Got hit by enemy
    input wire blocked_attack, // Moving opposite the enemy

    // Outputs
    output reg [9:0] x_pos_player,  // Position wire 
	 
    output reg [2:0] player_state,      // State of each player 
    output reg [9:0] hitbox_vertical_offset,
	 
    output reg [9:0] hitbow_width,// Hitbox / Hurtboxoffsets 
    output reg [9:0] hurtbox_width,
	 output reg hitbox_active,
	 
    output reg looking_right // Looking mechanism wire 
 
);

    // Local Parameters for easy check
    localparam POSITION_INITIAL_P1 = 10'd100;
    localparam POSITION_INITIAL_P2 = 10'd500;   // Initial positions 
	 
    localparam SCREEN_MIN = 10'd0;// 
    localparam SCREEN_MAX = 10'd639;// 640 pixels resolution
	 
    localparam PLAYER_WIDTH = 64; // Player width
	 
    localparam ATTACK_HITBOX_OFFSET = 10'd0;
    localparam ATTACK_HITBOX_WIDTH  = 10'd50; // Attack Length
	 
    localparam S_IDLE            = 4'd0;
    localparam S_MOVE_RIGHT      = 4'd1;
    localparam S_MOVE_LEFT       = 4'd2;
    localparam S_N_ATK_START   = 4'd3;
    localparam S_N_ATK_ACTIVE    = 4'd4; // STATES 
    localparam S_N_ATK_RECOVERY  = 4'd5;
    localparam S_D_ATK_STARTUP   = 4'd6;
    localparam S_D_ATK_ACTIVE    = 4'd7;
    localparam S_D_ATK_RECOVERY  = 4'd8;
    localparam S_HITSTUN         = 4'd9;
    localparam S_BLOCKSTUN       = 4'd10;
	 
    localparam P_STATE_OUT_IDLE        = 3'b000;
    localparam P_STATE_OUT_MOVE_LEFT   = 3'b010;
    localparam P_STATE_OUT_MOVE_RIGHT  = 3'b001; // Output for game logic
    localparam P_STATE_OUT_ATTACKING   = 3'b100;
    localparam P_STATE_OUT_HITSTUN     = 3'b110;
    localparam P_STATE_OUT_BLOCKSTUN   = 3'b111;
	 
	 localparam N_ATK_START_FRAMES   = 5;
    localparam N_ATK_ACTIVE_FRAMES    = 2;  
    localparam N_ATK_RECOVERY_FRAMES  = 16;
    localparam D_ATK_START_FRAMES   = 4;   // Frame Rates for given in the mamnual
    localparam D_ATK_ACTIVE_FRAMES    = 3;
    localparam D_ATK_RECOVERY_FRAMES  = 15;
	 
	 localparam MOVE_SPEED_FORWARD  = 10'd3; // Forward 3
    localparam MOVE_SPEED_BACKWARD = 10'd2;// Back 2

    
	 reg [4:0] attack_frame_counter; // For 16 cycles , we need 4 bits by ceiling no matter 5 or 6
	 
    reg [3:0] next_state;
	 reg [3:0] current_state; // State Registers 
    


    // Comb Logic - State Register
    always @(*) begin
        next_state = current_state;
		  
        hitbox_active = 1'b0; // Attack Hitbox Enable
		  
		  hitbox_vertical_offset = ATTACK_HITBOX_OFFSET;
        hitbow_width  = ATTACK_HITBOX_WIDTH;  // Attack Hitbox values 
		  
        hurtbox_width  = PLAYER_WIDTH; // DMG area
        
        
        case (current_state)
            S_IDLE: begin
                player_state = P_STATE_OUT_IDLE; // IDLE
                if (hit_by_opponent) next_state = S_HITSTUN; // Got hit
					 
                else if (attack) next_state = (move_left || move_right) ? S_D_ATK_STARTUP : S_N_ATK_START; // Directional Attack
					 
					 else if (move_right && !move_left) next_state = S_MOVE_RIGHT;// Just Right
					 
                else if (move_left && !move_right) next_state = S_MOVE_LEFT; // Just Left
           
            end
				
            S_MOVE_LEFT: begin
                player_state = P_STATE_OUT_MOVE_LEFT; // Going Left
                if (hit_by_opponent) next_state = S_HITSTUN; 
					 
                else if (attack) next_state = S_D_ATK_STARTUP;
					 
                else if (!move_left) next_state = S_IDLE;
            end
            S_MOVE_RIGHT: begin
                player_state = P_STATE_OUT_MOVE_RIGHT; // Going right
                if (hit_by_opponent) next_state = S_HITSTUN; // Got Hit
					 
                else if (attack) next_state = S_D_ATK_STARTUP; // Starting Moving Attack
					 
                else if (!move_right) next_state = S_IDLE; // Releasing input will go idle
            end
            S_N_ATK_START: begin // Normal Attack Starting
                player_state = P_STATE_OUT_ATTACKING;
                if (hit_by_opponent) next_state = S_HITSTUN; // If got hit before attack, get stunned
					 
                else if (attack_frame_counter == N_ATK_START_FRAMES - 1) next_state = S_N_ATK_ACTIVE; // Go into attack active after the frame counter
            end
            S_N_ATK_ACTIVE: begin// Normal Attack active 
                player_state = P_STATE_OUT_ATTACKING; // Attacking state
                hitbox_active = 1'b1; // Attack hitbox is active now we will draw it in VGA_controller
                if (hit_by_opponent) next_state = S_HITSTUN; // If attack hits simultaneously, both are stunned
					 
                else if (attack_frame_counter == N_ATK_ACTIVE_FRAMES - 1) next_state = S_N_ATK_RECOVERY; // Count frames and move on
            end
            S_N_ATK_RECOVERY: begin
                player_state = P_STATE_OUT_ATTACKING; // Recovery still attacking
                if (hit_by_opponent) next_state = S_HITSTUN; // If you miss the shot and got hit, get stunned
					 
                else if (attack_frame_counter == N_ATK_RECOVERY_FRAMES - 1) next_state= S_IDLE; // Count the recovery and go idle 
            end
            S_D_ATK_STARTUP: begin
                player_state = P_STATE_OUT_ATTACKING; // Movement attack starts 
                if (hit_by_opponent) next_state = S_HITSTUN; // Hit stunned 
					 
                else if (attack_frame_counter == D_ATK_START_FRAMES - 1) next_state = S_D_ATK_ACTIVE;// Count frames
            end
            S_D_ATK_ACTIVE: begin
                player_state = P_STATE_OUT_ATTACKING; // Movement attack active 
                hitbox_active = 1'b1;// Attack Hitbox Active
                if (hit_by_opponent) next_state = S_HITSTUN; // Stunned 
					 
                else if (attack_frame_counter == D_ATK_ACTIVE_FRAMES - 1) next_state = S_D_ATK_RECOVERY; // Count and mvoe on
            end
            S_D_ATK_RECOVERY: begin  
                player_state = P_STATE_OUT_ATTACKING; 
                if (hit_by_opponent) next_state = S_HITSTUN;
					 
                else if (attack_frame_counter == D_ATK_RECOVERY_FRAMES - 1) next_state = S_IDLE; // Same 
            end
            S_HITSTUN: begin
                player_state = P_STATE_OUT_HITSTUN; // Stunned for 1 clock no need to count 
                next_state = S_IDLE; 
            end
            S_BLOCKSTUN: begin
                player_state = P_STATE_OUT_BLOCKSTUN; 
                next_state = S_IDLE;
            end
            default: begin
                player_state = P_STATE_OUT_IDLE;
                next_state = S_IDLE;
            end
        endcase
    end

    // Sequential logic
	 
    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            current_state <= S_IDLE;
            x_pos_player <= main_player ? POSITION_INITIAL_P1 : POSITION_INITIAL_P2; // Set the position of the player whether main or player 2
            looking_right <= main_player ? 1'b1 : 1'b0; // Main player looks right
            attack_frame_counter <= 0; 
        end else begin
            if (current_state != next_state) begin
                attack_frame_counter <= 0;
            end else begin
                case (current_state)
                    S_N_ATK_START, S_N_ATK_ACTIVE, S_N_ATK_RECOVERY,S_D_ATK_STARTUP, S_D_ATK_ACTIVE, S_D_ATK_RECOVERY: begin // Any attack case 
                        attack_frame_counter <= attack_frame_counter + 1; // Count attack frame 
                    end
                    default: begin
                        attack_frame_counter <= 0; // default 0
                    end
                endcase
            end
				
            current_state <= next_state; // main logic
 
            if (next_state == S_IDLE || next_state == S_MOVE_LEFT || next_state == S_MOVE_RIGHT) begin // No attacking
				
                if (move_left && !move_right) looking_right <= 1'b0; // Looking left if moving left
					 
                else if (move_right && !move_left) looking_right <= 1'b1; // Looking right if moving right
					 
                else begin
                    if ((x_pos_player + (PLAYER_WIDTH / 2)) < (opponent_x + (PLAYER_WIDTH / 2))) looking_right <= 1'b1; // If half of the player passes the other one , rotate the direction 
						  
                    else if ((x_pos_player + (PLAYER_WIDTH / 2)) > (opponent_x + (PLAYER_WIDTH / 2))) looking_right <= 1'b0; // Middle position comparison
                    else if ((x_pos_player + (PLAYER_WIDTH / 2)) > (opponent_x + (PLAYER_WIDTH / 2))) looking_right <= 1'b0; // Middle position comparison
                end
            end
            if (next_state == S_MOVE_LEFT) begin
                automatic reg is_moving_forward_calc_seq;
					 automatic reg [9:0] current_move_speed_calc_seq;
					 
                is_moving_forward_calc_seq = !looking_right; // Not looking right while moving left
                current_move_speed_calc_seq = is_moving_forward_calc_seq ? MOVE_SPEED_FORWARD : MOVE_SPEED_BACKWARD; // Speed 
					 
                if (x_pos_player >= SCREEN_MIN + current_move_speed_calc_seq) x_pos_player <= x_pos_player - current_move_speed_calc_seq; // Substracting instant position change since going left
					 
                else x_pos_player <= SCREEN_MIN;
            end else if (next_state == S_MOVE_RIGHT) begin // Same logic 
                automatic reg is_moving_forward_calc_seq;
					 automatic reg [9:0] current_move_speed_calc_seq;
					 
                is_moving_forward_calc_seq = looking_right;
                current_move_speed_calc_seq = is_moving_forward_calc_seq ? MOVE_SPEED_FORWARD : MOVE_SPEED_BACKWARD;
					 
                if (x_pos_player <= SCREEN_MAX - PLAYER_WIDTH + 1 - current_move_speed_calc_seq) x_pos_player <= x_pos_player + current_move_speed_calc_seq;// Substracting instant position change since going right
					 
                else x_pos_player <= SCREEN_MAX - PLAYER_WIDTH + 1;
            end
        end
    end
endmodule
