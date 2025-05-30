// player_fsm.v (İlgili kısımlar güncellendi)
module player_fsm (
    // ... (Port listesi aynı kalır) ...
    input wire clk_game_logic,
    input wire reset,
    input wire i_move_left,
    input wire i_move_right,
    input wire i_attack,
    input wire [9:0] i_opponent_x_pos,
    input wire i_am_player1,
    input wire i_hit_by_opponent,
    input wire i_blocked_attack,
    output reg [9:0] o_x_pos,
    output reg [2:0] o_player_state,
    output reg       o_hitbox_active, // Oyun mekaniği için aktif hitbox
    output reg [9:0] o_hitbox_x_offset, // Her zaman potansiyel hitbox offset'i
    output reg [9:0] o_hitbox_width,  // Her zaman potansiyel hitbox genişliği
    output reg [9:0] o_hurtbox_width,
    output reg       o_facing_right
);

    // ... (Parametreler ve Durumlar önceki gibi) ...
    localparam X_INITIAL_P1 = 10'd100;
    localparam X_INITIAL_P2 = 10'd500;
    localparam MOVE_SPEED_FORWARD  = 10'd3;
    localparam MOVE_SPEED_BACKWARD = 10'd2;
    localparam SCREEN_MIN_X = 10'd0;
    localparam SCREEN_MAX_X = 10'd639;
    localparam PLAYER_WIDTH = 64;
    localparam ATTACK_HITBOX_OFFSET_VAL = 10'd5; // Potansiyel saldırının varsayılan offset'i
    localparam ATTACK_HITBOX_WIDTH_VAL  = 10'd30; // Potansiyel saldırının varsayılan genişliği

    localparam S_IDLE           = 3'b000;
    // ... (Diğer durum tanımları aynı) ...
    localparam S_MOVE_RIGHT     = 3'b001;
    localparam S_MOVE_LEFT      = 3'b010;
    localparam S_ATTACK_START   = 3'b011;
    localparam S_ATTACK_ACTIVE  = 3'b100;
    localparam S_ATTACK_COOLDOWN= 3'b101;
    localparam S_HITSTUN        = 3'b110;
    localparam S_BLOCKSTUN      = 3'b111;


    reg [2:0] current_state_reg;
    reg [2:0] next_state_reg;

    // --- Kombinasyonel Mantık ---
    always @(*) begin
        next_state_reg        = current_state_reg;
        o_player_state        = current_state_reg;
        o_hitbox_active       = 1'b0; // Varsayılan olarak oyun mekaniği hitbox'ı pasif
        o_hurtbox_width       = PLAYER_WIDTH;

        // Potansiyel hitbox parametrelerini her zaman ayarla (mevcut duruşa göre)
        // Bu değerler farklı durumlara veya saldırı tiplerine göre değişebilir.
        // Şimdilik tek bir varsayılan saldırı tipi için sabit değerler kullanıyoruz.
        o_hitbox_x_offset     = ATTACK_HITBOX_OFFSET_VAL;
        o_hitbox_width        = ATTACK_HITBOX_WIDTH_VAL;

        case (current_state_reg)
            S_IDLE: begin
                // ... (önceki IDLE mantığı) ...
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (i_attack) next_state_reg = S_ATTACK_START;
                else if (i_move_left && !i_move_right) next_state_reg = S_MOVE_LEFT;
                else if (i_move_right && !i_move_left) next_state_reg = S_MOVE_RIGHT;
            end
            // ... (S_MOVE_LEFT, S_MOVE_RIGHT mantığı önceki gibi) ...
             S_MOVE_LEFT: begin
                o_player_state = S_MOVE_LEFT;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (i_attack) next_state_reg = S_ATTACK_START;
                else if (!i_move_left) next_state_reg = S_IDLE;
            end
            S_MOVE_RIGHT: begin
                o_player_state = S_MOVE_RIGHT;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (i_attack) next_state_reg = S_ATTACK_START;
                else if (!i_move_right) next_state_reg = S_IDLE;
            end
            S_ATTACK_START: begin
                o_player_state = S_ATTACK_START;
                next_state_reg = S_ATTACK_ACTIVE;
            end
            S_ATTACK_ACTIVE: begin
                o_player_state = S_ATTACK_ACTIVE;
                o_hitbox_active   = 1'b1; // Oyun mekaniği için hitbox BU DURUMDA aktif
                // o_hitbox_x_offset ve o_hitbox_width zaten yukarıda ayarlandı.
                next_state_reg = S_ATTACK_COOLDOWN;
            end
            S_ATTACK_COOLDOWN: begin
                o_player_state = S_ATTACK_COOLDOWN;
                next_state_reg = S_IDLE;
            end
            S_HITSTUN: begin
                o_player_state = S_HITSTUN;
                next_state_reg = S_IDLE;
            end
            S_BLOCKSTUN: begin
                o_player_state = S_BLOCKSTUN;
                next_state_reg = S_IDLE;
            end
            default: begin
                next_state_reg = S_IDLE;
            end
        endcase
    end

    // --- Sekansiyel Mantık ---
    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            current_state_reg <= S_IDLE;
            o_x_pos           <= i_am_player1 ? X_INITIAL_P1 : X_INITIAL_P2;
            o_facing_right    <= i_am_player1 ? 1'b1 : 1'b0;
        end else begin
            current_state_reg <= next_state_reg;
            // ... (Pozisyon güncelleme ve Yön güncelleme mantığı bir önceki yanıttaki gibi kalacak) ...
            // Yön güncelleme mantığı
            if (next_state_reg == S_IDLE || next_state_reg == S_MOVE_LEFT || next_state_reg == S_MOVE_RIGHT) begin
                if (i_move_left && !i_move_right) begin
                    o_facing_right <= 1'b0;
                end else if (i_move_right && !i_move_left) begin
                    o_facing_right <= 1'b1;
                end else begin
                    if ((o_x_pos + (PLAYER_WIDTH / 2)) < (i_opponent_x_pos + (PLAYER_WIDTH / 2))) begin
                        o_facing_right <= 1'b1;
                    end else if ((o_x_pos + (PLAYER_WIDTH / 2)) > (i_opponent_x_pos + (PLAYER_WIDTH / 2))) begin
                        o_facing_right <= 1'b0;
                    end
                end
            end

            // Pozisyon güncelleme
            if (next_state_reg == S_MOVE_LEFT) begin
                automatic reg is_moving_forward_calc;
                automatic reg [9:0] current_move_speed_calc;
                is_moving_forward_calc = !o_facing_right;
                current_move_speed_calc = is_moving_forward_calc ? MOVE_SPEED_FORWARD : MOVE_SPEED_BACKWARD;
                if (o_x_pos >= SCREEN_MIN_X + current_move_speed_calc) begin
                    o_x_pos <= o_x_pos - current_move_speed_calc;
                end else begin
                    o_x_pos <= SCREEN_MIN_X;
                end
            end else if (next_state_reg == S_MOVE_RIGHT) begin
                automatic reg is_moving_forward_calc;
                automatic reg [9:0] current_move_speed_calc;
                is_moving_forward_calc = o_facing_right;
                current_move_speed_calc = is_moving_forward_calc ? MOVE_SPEED_FORWARD : MOVE_SPEED_BACKWARD;
                if (o_x_pos <= SCREEN_MAX_X - PLAYER_WIDTH + 1 - current_move_speed_calc) begin
                    o_x_pos <= o_x_pos + current_move_speed_calc;
                end else begin
                    o_x_pos <= SCREEN_MAX_X - PLAYER_WIDTH + 1;
                end
            end
        end
    end
endmodule
