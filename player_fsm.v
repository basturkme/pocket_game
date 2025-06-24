// player_fsm.v
// YENİ DÜZENLEME:
// - Saldırı yönü sabitlendi: P1 sadece sağa, P2 sadece sola saldırır.
// - looking_right kaydedicisinin dinamik olarak güncellenmesi kaldırıldı.
//   Değeri artık reset anında oyuncuya göre sabitleniyor.
module player_fsm (
    input wire reset,
    input wire clk_game_logic,
    input wire attack,
    input wire move_left,
    input wire move_right,
    input wire main_player,
    input wire [9:0] opponent_x_pos,
    input wire [9:0] opponent_actual_hurtbox_width,
    input wire hit_by_opponent,
    input wire confirmed_my_block,

    output reg [9:0] x_pos_player,
    output reg [2:0] player_state,
    output reg [9:0] hitbox_x_offset,
    output reg [9:0] hitbox_width,
    output reg [9:0] hurtbox_width,
    output reg          hitbox_active,
    output reg          looking_right,
    output reg          is_in_recovery,
    output reg          is_holding_backward,
    output reg          is_actively_blocking
);


    // Parametreler ve Durum Tanımları
    localparam POSITION_INITIAL_P1 = 10'd100, POSITION_INITIAL_P2 = 10'd500;
    localparam MOVE_SPEED_FORWARD  = 10'd3, MOVE_SPEED_BACKWARD = 10'd2;
    localparam SCREEN_MIN_X = 10'd0, SCREEN_MAX_X = 10'd639;
    localparam PLAYER_WIDTH_CONST  = 64;
    localparam ATTACK_HITBOX_OFFSET_PARAM = 10'd0, ATTACK_HITBOX_WIDTH_PARAM  = 10'd50;
    localparam PRE_ATTACK_CHARGE_FRAMES = 8, N_ATK_STARTUP_FRAMES   = 5, N_ATK_ACTIVE_FRAMES    = 2, N_ATK_RECOVERY_FRAMES  = 16;
    localparam M_ATK_STARTUP_FRAMES   = 4, M_ATK_ACTIVE_FRAMES    = 3, M_ATK_RECOVERY_FRAMES  = 15;
    localparam HITSTUN_DURATION_FRAMES = 10, BLOCKSTUN_DURATION_FRAMES = 8;
    
    localparam S_IDLE = 4'h0, S_MOVE_RIGHT = 4'h1, S_MOVE_LEFT = 4'h2, S_N_ATK_STARTUP = 4'h3, S_N_ATK_ACTIVE = 4'h4, S_N_ATK_RECOVERY = 4'h5;
    localparam S_M_ATK_STARTUP = 4'h6, S_M_ATK_ACTIVE = 4'h7, S_M_ATK_RECOVERY = 4'h8, S_HITSTUN = 4'h9, S_BLOCKSTUN = 4'hA, S_PRE_ATTACK_CHARGE = 4'hB, S_BLOCKING_IDLE = 4'hC;
    
    // <<< DEĞİŞTİ: Saldırı durumları ayrıldı, stun durumları birleştirildi.
    localparam P_STATE_OUT_IDLE = 3'b000, P_STATE_OUT_MOVE_RIGHT = 3'b001, P_STATE_OUT_MOVE_LEFT = 3'b010, P_STATE_OUT_BLOCKING = 3'b011;
    localparam P_STATE_OUT_ATTACKING = 3'b100; // Bu artık sadece N_ATK için
    localparam P_STATE_OUT_CHARGING = 3'b101;
    localparam P_STATE_OUT_STUNNED = 3'b110;   // HITSTUN ve BLOCKSTUN için ortak
    localparam P_STATE_OUT_MOVING_ATTACK = 3'b111; // <<< YENİ: M_ATK için yeni durum kodu
    localparam P_STATE_OUT_HITSTUN = 3'b110, P_STATE_OUT_BLOCKSTUN = 3'b111; // <<< ESKİLER

    // Dahili Kaydediciler
    reg [3:0] current_state_reg, next_state_reg;
    reg [4:0] attack_frame_counter_reg, stun_timer_reg;
    reg [9:0] next_x_pos_player;
	 
    // Kombinasyonel Mantık Bloğu (Değişiklik yok)
    always @(*) begin
        reg should_initiate_block_local;
        reg [9:0] move_speed;
        reg [9:0] tentative_x;

        next_state_reg = current_state_reg; 
        player_state = P_STATE_OUT_IDLE; 
        hitbox_active = 1'b0; 
        is_in_recovery = 1'b0;
        is_actively_blocking = 1'b0; 
        hurtbox_width = PLAYER_WIDTH_CONST; 
        hitbox_x_offset = ATTACK_HITBOX_OFFSET_PARAM; 
        hitbox_width = ATTACK_HITBOX_WIDTH_PARAM;
        
        // Bu mantık looking_right sabit olsa bile doğru çalışır.
        if (looking_right) is_holding_backward = move_left && !move_right;
        else is_holding_backward = move_right && !move_left;
        
        if (opponent_x_pos > x_pos_player) should_initiate_block_local = move_left && !move_right && !attack;
        else if (opponent_x_pos < x_pos_player) should_initiate_block_local = move_right && !move_left && !attack;
        else should_initiate_block_local = is_holding_backward && !attack;

        case (current_state_reg)
            // Bu case bloğunun tamamı öncekiyle aynı, değişiklik yok.
            S_IDLE: begin
                if (hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (confirmed_my_block) next_state_reg = S_BLOCKSTUN;
                else if (should_initiate_block_local) next_state_reg = S_BLOCKING_IDLE;
                else if (attack) next_state_reg = S_PRE_ATTACK_CHARGE;
                else if (move_right && !move_left) next_state_reg = S_MOVE_RIGHT;
                else if (move_left && !move_right) next_state_reg = S_MOVE_LEFT;
            end
            S_MOVE_LEFT: begin
                player_state = P_STATE_OUT_MOVE_LEFT; // Çizim için state ataması
                if (hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (confirmed_my_block) next_state_reg = S_BLOCKSTUN;
                else if (should_initiate_block_local) next_state_reg = S_BLOCKING_IDLE;
                else if (attack) next_state_reg = S_PRE_ATTACK_CHARGE;
                else if (!move_left) next_state_reg = S_IDLE;
            end
            S_MOVE_RIGHT: begin
                player_state = P_STATE_OUT_MOVE_RIGHT; // Çizim için state ataması
                if (hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (confirmed_my_block) next_state_reg = S_BLOCKSTUN;
                else if (should_initiate_block_local) next_state_reg = S_BLOCKING_IDLE;
                else if (attack) next_state_reg = S_PRE_ATTACK_CHARGE;
                else if (!move_right) next_state_reg = S_IDLE;
            end
            S_BLOCKING_IDLE: begin
                player_state = P_STATE_OUT_BLOCKING;
                is_actively_blocking = 1'b1;
                if (confirmed_my_block) next_state_reg = S_BLOCKSTUN;
                else if (hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (!should_initiate_block_local || attack) begin
                    next_state_reg = S_IDLE;
                    if (attack) next_state_reg = S_PRE_ATTACK_CHARGE;
                end
            end
            S_PRE_ATTACK_CHARGE: begin
                player_state = P_STATE_OUT_CHARGING;
                if (hit_by_opponent) next_state_reg = S_HITSTUN;
                // should_initiate_block_local kontrolü, saldırı sırasında blok yapmayı engellemek için eklendi.
                // Normalde saldırı taahhüt edicidir (committal), ama bu bir tasarım tercihi.
                else if (should_initiate_block_local && confirmed_my_block) next_state_reg = S_BLOCKSTUN; 
                else if (attack_frame_counter_reg == PRE_ATTACK_CHARGE_FRAMES - 1) begin
                    // move_left || move_right hala yönlü saldırıyı tetikleyebilir.
                    if (move_left || move_right) next_state_reg = S_M_ATK_STARTUP;
                    else next_state_reg = S_N_ATK_STARTUP;
                end
            end
            // <<< DEĞİŞTİ: N_ATK ve M_ATK durumları artık farklı 'player_state' değerleri üretiyor
            S_N_ATK_STARTUP, S_N_ATK_ACTIVE, S_N_ATK_RECOVERY: begin
                 player_state = P_STATE_OUT_ATTACKING; // N_ATK (Duran Saldırı) kodu
                 hitbox_active = (current_state_reg == S_N_ATK_ACTIVE);
                 is_in_recovery = (current_state_reg == S_N_ATK_RECOVERY);

                 if (hit_by_opponent) next_state_reg = S_HITSTUN;
                 else if (attack_frame_counter_reg == (current_state_reg == S_N_ATK_STARTUP ? N_ATK_STARTUP_FRAMES : (current_state_reg == S_N_ATK_ACTIVE ? N_ATK_ACTIVE_FRAMES : N_ATK_RECOVERY_FRAMES)) - 1)
                     next_state_reg = (current_state_reg == S_N_ATK_RECOVERY) ? S_IDLE : (current_state_reg == S_N_ATK_STARTUP ? S_N_ATK_ACTIVE : S_N_ATK_RECOVERY);
            end
            S_M_ATK_STARTUP, S_M_ATK_ACTIVE, S_M_ATK_RECOVERY: begin
                 player_state = P_STATE_OUT_MOVING_ATTACK; // <<< YENİ: M_ATK (Hareketli Saldırı) kodu
                 hitbox_active = (current_state_reg == S_M_ATK_ACTIVE);
                 is_in_recovery = (current_state_reg == S_M_ATK_RECOVERY);

                 if (hit_by_opponent) next_state_reg = S_HITSTUN;
                 else if (attack_frame_counter_reg == (current_state_reg == S_M_ATK_STARTUP ? M_ATK_STARTUP_FRAMES : (current_state_reg == S_M_ATK_ACTIVE ? M_ATK_ACTIVE_FRAMES : M_ATK_RECOVERY_FRAMES)) - 1)
                     next_state_reg = (current_state_reg == S_M_ATK_RECOVERY) ? S_IDLE : (current_state_reg == S_M_ATK_STARTUP ? S_M_ATK_ACTIVE : S_M_ATK_RECOVERY);
            end

            // <<< DEĞİŞTİ: HITSTUN ve BLOCKSTUN birleştirildi.
            S_HITSTUN: begin
                player_state = P_STATE_OUT_HITSTUN;
                if (stun_timer_reg == HITSTUN_DURATION_FRAMES - 1) next_state_reg = S_IDLE;
            end
            S_BLOCKSTUN: begin
                player_state = P_STATE_OUT_BLOCKSTUN;
                if (stun_timer_reg == BLOCKSTUN_DURATION_FRAMES - 1) next_state_reg = S_IDLE;
            end
            default: next_state_reg = S_IDLE;
        endcase
        
        // Hareket hesaplama mantığı (Değişiklik yok)
        next_x_pos_player = x_pos_player;
        if ((current_state_reg == S_MOVE_LEFT || current_state_reg == S_MOVE_RIGHT) ||
            (current_state_reg == S_BLOCKING_IDLE && is_holding_backward)) begin
            
            if (current_state_reg == S_BLOCKING_IDLE) move_speed = MOVE_SPEED_BACKWARD;
            else if ((looking_right && move_right) || (!looking_right && move_left)) move_speed = MOVE_SPEED_FORWARD;
            else move_speed = MOVE_SPEED_BACKWARD;
            
            if (move_left) begin
                if (x_pos_player >= move_speed) tentative_x = x_pos_player - move_speed;
                else tentative_x = SCREEN_MIN_X;
            end else if (move_right) begin
                if (x_pos_player < (SCREEN_MAX_X - PLAYER_WIDTH_CONST)) tentative_x = x_pos_player + move_speed;
                else tentative_x = SCREEN_MAX_X - PLAYER_WIDTH_CONST;
            end else begin
                tentative_x = x_pos_player;
            end

            // Çarpışma mantığı (Değişiklik yok)
            if ((tentative_x + PLAYER_WIDTH_CONST > opponent_x_pos) && (tentative_x < opponent_x_pos + opponent_actual_hurtbox_width)) begin
                if (x_pos_player < opponent_x_pos) tentative_x = opponent_x_pos - PLAYER_WIDTH_CONST;
                else tentative_x = opponent_x_pos + opponent_actual_hurtbox_width;
            end
            
            next_x_pos_player = tentative_x;
        end
    end

    // Sıralı Mantık Bloğu (Sadece looking_right güncellemeleri kaldırıldı)
    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            current_state_reg <= S_IDLE;
            x_pos_player <= main_player ? POSITION_INITIAL_P1 : POSITION_INITIAL_P2;
            attack_frame_counter_reg <= 0;
            stun_timer_reg <= 0;
            
            // ==================== YENİ DÜZENLEME ====================
            // looking_right değeri reset anında oyuncuya göre sabitlenir ve bir daha DEĞİŞTİRİLMEZ.
            looking_right <= main_player ? 1'b1 : 1'b0; // P1 sağa, P2 sola bakar.
            // =========================================================

        end else begin
            current_state_reg <= next_state_reg;
            x_pos_player <= next_x_pos_player;
            
            if (current_state_reg != next_state_reg) begin
                attack_frame_counter_reg <= 0;
                stun_timer_reg <= 0;
            end else begin
                case (current_state_reg)
                    S_PRE_ATTACK_CHARGE, S_N_ATK_STARTUP, S_N_ATK_ACTIVE, S_N_ATK_RECOVERY,
                    S_M_ATK_STARTUP, S_M_ATK_ACTIVE, S_M_ATK_RECOVERY:
                        attack_frame_counter_reg <= attack_frame_counter_reg + 1;
                    S_HITSTUN, S_BLOCKSTUN:
                        stun_timer_reg <= stun_timer_reg + 1;
                    default: ;
                endcase
            end

        end
end
endmodule