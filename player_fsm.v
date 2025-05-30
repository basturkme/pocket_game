// player_fsm.v
// Frame verilerine göre saldırı animasyon süreleri eklendi.
module player_fsm (
    input wire clk_game_logic, // 60Hz frame clock
    input wire reset,

    // Kontrol Girişleri
    input wire i_move_left,
    input wire i_move_right,
    input wire i_attack,

    // Oyun Ortamı Girişleri
    input wire [9:0] i_opponent_x_pos,
    input wire i_am_player1,
    input wire i_hit_by_opponent,
    input wire i_blocked_attack, // Saldırının bloklandığı bilgisi

    // Çıkışlar
    output reg [9:0] o_x_pos,
    output reg [2:0] o_player_state,      // game_logic_fsm için durum
    output reg       o_hitbox_active,
    output reg [9:0] o_hitbox_x_offset,
    output reg [9:0] o_hitbox_width,
    output reg [9:0] o_hurtbox_width,
    output reg       o_facing_right
);

    // Parametreler
    localparam X_INITIAL_P1 = 10'd100;
    localparam X_INITIAL_P2 = 10'd500;
    localparam MOVE_SPEED_FORWARD  = 10'd3;
    localparam MOVE_SPEED_BACKWARD = 10'd2;
    localparam SCREEN_MIN_X = 10'd0;
    localparam SCREEN_MAX_X = 10'd639;
    localparam PLAYER_WIDTH = 64;

    localparam ATTACK_HITBOX_OFFSET_VAL = 10'd0;
    localparam ATTACK_HITBOX_WIDTH_VAL  = 10'd50;

    // Saldırı Frame Verileri (Tablodan)
    localparam N_ATK_STARTUP_FRAMES   = 5;
    localparam N_ATK_ACTIVE_FRAMES    = 2;
    localparam N_ATK_RECOVERY_FRAMES  = 16;

    localparam M_ATK_STARTUP_FRAMES   = 4; // Moving Attack
    localparam M_ATK_ACTIVE_FRAMES    = 3;
    localparam M_ATK_RECOVERY_FRAMES  = 15;

    // Durumlar (4-bit)
    localparam S_IDLE            = 4'd0;
    localparam S_MOVE_RIGHT      = 4'd1;
    localparam S_MOVE_LEFT       = 4'd2;
    // Nötr Saldırı Durumları
    localparam S_N_ATK_STARTUP   = 4'd3;
    localparam S_N_ATK_ACTIVE    = 4'd4;
    localparam S_N_ATK_RECOVERY  = 4'd5;
    // Hareketli Saldırı Durumları
    localparam S_M_ATK_STARTUP   = 4'd6;
    localparam S_M_ATK_ACTIVE    = 4'd7;
    localparam S_M_ATK_RECOVERY  = 4'd8;
    // Diğer Durumlar
    localparam S_HITSTUN         = 4'd9;
    localparam S_BLOCKSTUN       = 4'd10; // Eğer blok sonrası özel bir stun durumu olacaksa

    // o_player_state için çıkış durum kodları (3-bit)
    localparam P_STATE_OUT_IDLE        = 3'b000;
    localparam P_STATE_OUT_MOVE_LEFT   = 3'b010; // game_logic_fsm'deki P_STATE_MOVE_B
    localparam P_STATE_OUT_MOVE_RIGHT  = 3'b001; // game_logic_fsm için yeni bir durum olabilir veya IDLE
    localparam P_STATE_OUT_ATTACKING   = 3'b100; // Tüm saldırı fazları için genel
    localparam P_STATE_OUT_HITSTUN     = 3'b110;
    localparam P_STATE_OUT_BLOCKSTUN   = 3'b111;


    reg [3:0] current_state_reg;
    reg [3:0] next_state_reg;

    reg [4:0] attack_frame_counter; // Max 16 frame için 0-15 (4 bit) veya 0-16 (5 bit) yeterli. 5 bit daha güvenli.
    reg       is_moving_on_attack_init; // Saldırı başlarken hareketli miydi?

    // --- Kombinasyonel Mantık: Sonraki Durum ve Çıkışlar ---
    always @(*) begin
        next_state_reg        = current_state_reg;
        o_hitbox_active       = 1'b0;
        o_hurtbox_width       = PLAYER_WIDTH;
        o_hitbox_x_offset     = ATTACK_HITBOX_OFFSET_VAL;
        o_hitbox_width        = ATTACK_HITBOX_WIDTH_VAL;
        // o_player_state varsayılanı aşağıda case içinde ayarlanacak

        case (current_state_reg)
            S_IDLE: begin
                o_player_state = P_STATE_OUT_IDLE;
                if (i_hit_by_opponent) begin
                    next_state_reg = S_HITSTUN;
                end else if (i_attack) begin
                    if (i_move_left || i_move_right) begin // Hareket ederken saldırı
                        next_state_reg = S_M_ATK_STARTUP;
                        is_moving_on_attack_init = 1'b1; // Bu bilgi bir sonraki state'e taşınabilir (gerekirse)
                    end else begin // Nötr saldırı
                        next_state_reg = S_N_ATK_STARTUP;
                        is_moving_on_attack_init = 1'b0;
                    end
                end else if (i_move_left && !i_move_right) begin
                    next_state_reg = S_MOVE_LEFT;
                end else if (i_move_right && !i_move_left) begin
                    next_state_reg = S_MOVE_RIGHT;
                end
            end
            S_MOVE_LEFT: begin
                o_player_state = P_STATE_OUT_MOVE_LEFT;
                if (i_hit_by_opponent) begin
                    next_state_reg = S_HITSTUN;
                end else if (i_attack) begin
                    next_state_reg = S_M_ATK_STARTUP; // Hareketli saldırı
                    is_moving_on_attack_init = 1'b1;
                end else if (!i_move_left) begin
                    next_state_reg = S_IDLE;
                end
            end
            S_MOVE_RIGHT: begin
                o_player_state = P_STATE_OUT_MOVE_RIGHT; // Veya P_STATE_OUT_IDLE
                if (i_hit_by_opponent) begin
                    next_state_reg = S_HITSTUN;
                end else if (i_attack) begin
                    next_state_reg = S_M_ATK_STARTUP; // Hareketli saldırı
                    is_moving_on_attack_init = 1'b1;
                end else if (!i_move_right) begin
                    next_state_reg = S_IDLE;
                end
            end

            S_N_ATK_STARTUP: begin
                o_player_state = P_STATE_OUT_ATTACKING;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (attack_frame_counter == N_ATK_STARTUP_FRAMES - 1) begin
                    next_state_reg = S_N_ATK_ACTIVE;
                end
            end
            S_N_ATK_ACTIVE: begin
                o_player_state = P_STATE_OUT_ATTACKING;
                o_hitbox_active = 1'b1;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN; // Aktifken de vurulabilir (trade)
                else if (attack_frame_counter == N_ATK_ACTIVE_FRAMES - 1) begin
                    next_state_reg = S_N_ATK_RECOVERY;
                end
            end
            S_N_ATK_RECOVERY: begin
                o_player_state = P_STATE_OUT_ATTACKING;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (attack_frame_counter == N_ATK_RECOVERY_FRAMES - 1) begin
                    next_state_reg = S_IDLE;
                end
            end

            S_M_ATK_STARTUP: begin
                o_player_state = P_STATE_OUT_ATTACKING;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (attack_frame_counter == M_ATK_STARTUP_FRAMES - 1) begin
                    next_state_reg = S_M_ATK_ACTIVE;
                end
            end
            S_M_ATK_ACTIVE: begin
                o_player_state = P_STATE_OUT_ATTACKING;
                o_hitbox_active = 1'b1;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (attack_frame_counter == M_ATK_ACTIVE_FRAMES - 1) begin
                    next_state_reg = S_M_ATK_RECOVERY;
                end
            end
            S_M_ATK_RECOVERY: begin
                o_player_state = P_STATE_OUT_ATTACKING;
                if (i_hit_by_opponent) next_state_reg = S_HITSTUN;
                else if (attack_frame_counter == M_ATK_RECOVERY_FRAMES - 1) begin
                    next_state_reg = S_IDLE;
                end
            end

            S_HITSTUN: begin
                o_player_state = P_STATE_OUT_HITSTUN;
                // Hitstun süresi için de bir sayaç gerekebilir, şimdilik 1 frame varsayılıyor
                // veya i_hit_by_opponent kalkana kadar kalabilir (ama i_hit_by_opponent darbe olmalı)
                // Frame datasına göre hitstun/blockstun süreleri de tanımlanabilir (On Hit / On Block değerleri)
                // Şimdilik basitçe IDLE'a dönüyor.
                next_state_reg = S_IDLE;
            end
            S_BLOCKSTUN: begin
                o_player_state = P_STATE_OUT_BLOCKSTUN;
                next_state_reg = S_IDLE; // Benzer şekilde, süre için sayaç gerekebilir.
            end
            default: begin
                o_player_state = P_STATE_OUT_IDLE;
                next_state_reg = S_IDLE;
            end
        endcase
    end

    // --- Sekansiyel Mantık: Durum Güncelleme, Sayaçlar ve Kayıtlı Çıkışlar ---
    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            current_state_reg <= S_IDLE;
            o_x_pos           <= i_am_player1 ? X_INITIAL_P1 : X_INITIAL_P2;
            o_facing_right    <= i_am_player1 ? 1'b1 : 1'b0;
            attack_frame_counter <= 0;
            is_moving_on_attack_init <= 1'b0;
        end else begin
            // Önceki durumdan yeni duruma geçişte sayaçları sıfırla/ayarla
            if (current_state_reg != next_state_reg) begin
                attack_frame_counter <= 0; // Yeni bir duruma (özellikle saldırı fazına) girerken sayacı sıfırla
                // Saldırıya başlarken hareketli olup olmadığını kaydet
                if (next_state_reg == S_N_ATK_STARTUP || next_state_reg == S_M_ATK_STARTUP) begin
                    if (current_state_reg == S_MOVE_LEFT || current_state_reg == S_MOVE_RIGHT || i_move_left || i_move_right) begin
                        is_moving_on_attack_init <= 1'b1;
                    end else begin
                        is_moving_on_attack_init <= 1'b0;
                    end
                end
            end else begin // Aynı durum içinde kalıyorsak (saldırı fazları gibi)
                case (current_state_reg)
                    S_N_ATK_STARTUP, S_N_ATK_ACTIVE, S_N_ATK_RECOVERY,
                    S_M_ATK_STARTUP, S_M_ATK_ACTIVE, S_M_ATK_RECOVERY: begin
                        attack_frame_counter <= attack_frame_counter + 1;
                    end
                    default: begin
                        attack_frame_counter <= 0; // Diğer durumlarda sayacı sıfır tut
                    end
                endcase
            end

            current_state_reg <= next_state_reg;

            // Yön güncelleme mantığı (önceki gibi)
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
            // Saldırı sırasında yön kilitli kalır (yukarıdaki if'e girmezse)

            // Pozisyon güncelleme (önceki gibi, doğru hızlarla)
            if (next_state_reg == S_MOVE_LEFT) begin
                automatic reg is_moving_forward_calc_seq; // Sekansiyel blok içinde 'automatic' kullanımı
                automatic reg [9:0] current_move_speed_calc_seq; // İsim çakışmasını önlemek için _seq eklendi
                is_moving_forward_calc_seq = !o_facing_right;
                current_move_speed_calc_seq = is_moving_forward_calc_seq ? MOVE_SPEED_FORWARD : MOVE_SPEED_BACKWARD;
                if (o_x_pos >= SCREEN_MIN_X + current_move_speed_calc_seq) begin
                    o_x_pos <= o_x_pos - current_move_speed_calc_seq;
                end else begin
                    o_x_pos <= SCREEN_MIN_X;
                end
            end else if (next_state_reg == S_MOVE_RIGHT) begin
                automatic reg is_moving_forward_calc_seq;
                automatic reg [9:0] current_move_speed_calc_seq;
                is_moving_forward_calc_seq = o_facing_right;
                current_move_speed_calc_seq = is_moving_forward_calc_seq ? MOVE_SPEED_FORWARD : MOVE_SPEED_BACKWARD;
                if (o_x_pos <= SCREEN_MAX_X - PLAYER_WIDTH + 1 - current_move_speed_calc_seq) begin
                    o_x_pos <= o_x_pos + current_move_speed_calc_seq;
                end else begin
                    o_x_pos <= SCREEN_MAX_X - PLAYER_WIDTH + 1;
                end
            end
            // Saldırı sırasında pozisyon sabit kalır (bu örnekte) veya özel hareketler eklenebilir
        end
    end
endmodule
