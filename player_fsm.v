// player_fsm.v
// Bir oyuncunun durumlarını, hareketlerini ve temel eylemlerini yönetir.
module player_fsm (
    input wire clk_game_logic,
    input wire reset,

    // Oyuncu Girişleri
    input wire move_left_in,
    input wire move_right_in,
    input wire attack_in,

    // Başlangıç Parametreleri
    input wire [9:0] initial_x,
    input wire initial_facing_right,

    // Rakip Bilgileri (Vuruş Tespiti için game_logic_fsm'e gönderilecek)
    input wire [9:0] opponent_x_pos,
    // input wire opponent_is_attacking, // Gerekirse
    // input wire [9:0] opponent_hitbox_x1, // Gerekirse
    // input wire [9:0] opponent_hitbox_x2, // Gerekirse

    // Game Logic FSM'den Gelen Tetiklemeler
    input wire got_hit_trigger,    // Vurulduğunda
    input wire got_blocked_trigger,// Blokladığında

    // Game Logic FSM'den Gelen Güncel HP/BP
    input wire [2:0] current_hp_in,
    input wire [2:0] current_bp_in,

    // Çıkışlar
    output reg [9:0] player_x_pos_out,
    output reg [2:0] player_current_state_out, // P_STATE_IDLE, P_STATE_MOVE_F, vb.
    output reg player_is_attacking_active_out, // Saldırının vuruş kutusunun aktif olduğu an
    output reg player_facing_right_out,
    // Vuruş Kutusu (Hitbox) Bilgileri (Saldırı aktifken)
    output reg [9:0] player_hitbox_x1_out,
    output reg [9:0] player_hitbox_x2_out,
    // Hasar Kutusu (Hurtbox) Bilgileri (Her zaman oyuncu ile birlikte)
    output reg [9:0] player_hurtbox_x1_out,
    output reg [9:0] player_hurtbox_x2_out
);

    // Oyuncu Durumları (game_logic_module'den kopyalandı)
    localparam P_STATE_IDLE      = 3'b000;
    localparam P_STATE_MOVE_F    = 3'b001; // İleri
    localparam P_STATE_MOVE_B    = 3'b010; // Geri (aynı zamanda bloklama)
    localparam P_STATE_ATK_START = 3'b011; // Saldırı Başlangıç
    localparam P_STATE_ATK_ACTIVE= 3'b100; // Saldırı Aktif
    localparam P_STATE_ATK_RECOV = 3'b101; // Saldırı Toparlanma
    localparam P_STATE_HITSTUN   = 3'b110; // Vuruş Sersemlemesi
    localparam P_STATE_BLOCKSTUN = 3'b111; // Blok Sersemlemesi

    // Ekran ve Sprite Boyutları
    localparam H_DISPLAY_AREA = 640;
    localparam PLAYER_SPRITE_W = 64;
    localparam MOVE_F_SPEED = 3; // İleri hareket hızı (piksel/kare)
    localparam MOVE_B_SPEED = 2; // Geri hareket hızı (piksel/kare)

    // Saldırı Çerçeve Verileri (Nötr Saldırı için Örnek)
    localparam NEUTRAL_ATK_STARTUP_FRAMES  = 5;
    localparam NEUTRAL_ATK_ACTIVE_FRAMES   = 2;
    localparam NEUTRAL_ATK_RECOVERY_FRAMES = 16;
    // Yönlü saldırı için ayrı parametreler eklenebilir.
    localparam HITSTUN_DURATION   = 10; // Vuruş sersemlemesi süresi
    localparam BLOCKSTUN_DURATION = 7;  // Blok sersemlemesi süresi

    // Vuruş Kutusu Uzantısı (Sprite'ın önüne/arkasına ne kadar uzanacağı)
    localparam HITBOX_REACH_FORWARD = 20; // Saldırı sırasında sprite'ın önünden ne kadar ileri
    localparam HITBOX_WIDTH = 40; // Vuruş kutusunun genişliği

    // Dahili Kaydediciler
    reg [7:0] action_timer_reg; // Saldırı aşamaları, sersemleme vb. için zamanlayıcı

    // Başlangıç durumu
    initial begin
        player_x_pos_out = initial_x;
        player_facing_right_out = initial_facing_right;
        player_current_state_out = P_STATE_IDLE;
        action_timer_reg = 0;
        player_is_attacking_active_out = 1'b0;
    end

    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            player_x_pos_out <= initial_x;
            player_facing_right_out <= initial_facing_right;
            player_current_state_out <= P_STATE_IDLE;
            action_timer_reg <= 0;
            player_is_attacking_active_out <= 1'b0;
        end else begin
            // Önce eylem zamanlayıcısını işle
            if (action_timer_reg > 0) begin
                action_timer_reg <= action_timer_reg - 1;

                case (player_current_state_out)
                    P_STATE_ATK_START: begin
                        player_is_attacking_active_out <= 1'b0;
                        if (action_timer_reg == 1) begin // Başlangıç bitti, aktife geç
                            player_current_state_out <= P_STATE_ATK_ACTIVE;
                            action_timer_reg <= NEUTRAL_ATK_ACTIVE_FRAMES;
                        end
                    end
                    P_STATE_ATK_ACTIVE: begin
                        player_is_attacking_active_out <= 1'b1; // Vuruş kutusu bu durumda aktif
                        if (action_timer_reg == 1) begin // Aktif bitti, toparlanmaya geç
                            player_current_state_out <= P_STATE_ATK_RECOV;
                            action_timer_reg <= NEUTRAL_ATK_RECOVERY_FRAMES;
                        end
                    end
                    P_STATE_ATK_RECOV: begin
                        player_is_attacking_active_out <= 1'b0;
                        if (action_timer_reg == 1) begin // Toparlanma bitti, boşa geç
                            player_current_state_out <= P_STATE_IDLE;
                        end
                    end
                    P_STATE_HITSTUN: begin
                        player_is_attacking_active_out <= 1'b0;
                        if (action_timer_reg == 1) begin // Sersemleme bitti
                            player_current_state_out <= P_STATE_IDLE;
                        end
                    end
                    P_STATE_BLOCKSTUN: begin
                        player_is_attacking_active_out <= 1'b0;
                        if (action_timer_reg == 1) begin // Blok sersemlemesi bitti
                            player_current_state_out <= P_STATE_IDLE;
                        end
                    end
                    default: player_is_attacking_active_out <= 1'b0;
                endcase
            end else begin // Eylem zamanlayıcısı aktif değil, yeni eylemlere izin ver
                player_is_attacking_active_out <= 1'b0; // Zamanlayıcı sıfırsa saldırı aktif değil

                // game_logic_fsm'den gelen tetiklemeleri kontrol et
                if (got_hit_trigger) begin
                    player_current_state_out <= P_STATE_HITSTUN;
                    action_timer_reg <= HITSTUN_DURATION;
                end else if (got_blocked_trigger) begin
                    player_current_state_out <= P_STATE_BLOCKSTUN;
                    action_timer_reg <= BLOCKSTUN_DURATION;
                end else begin // Tetikleme yoksa, oyuncu girişlerini işle
                    if (attack_in) begin
                        player_current_state_out <= P_STATE_ATK_START;
                        action_timer_reg <= NEUTRAL_ATK_STARTUP_FRAMES;
                        // Yönlü saldırı mantığı burada eklenebilir (move_left/right ile birlikte attack_in)
                    end else if (move_right_in) begin
                        player_current_state_out <= player_facing_right_out ? P_STATE_MOVE_F : P_STATE_MOVE_B;
                        if (player_x_pos_out + PLAYER_SPRITE_W + (player_facing_right_out ? MOVE_F_SPEED : MOVE_B_SPEED) < H_DISPLAY_AREA &&  // Ekran sınırı
                            player_x_pos_out + PLAYER_SPRITE_W + (player_facing_right_out ? MOVE_F_SPEED : MOVE_B_SPEED) < opponent_x_pos) begin // Rakip sınırı
                            player_x_pos_out <= player_x_pos_out + (player_facing_right_out ? MOVE_F_SPEED : MOVE_B_SPEED);
                        end
                        // Eğer sağa hareket ederken sola bakıyorsa (veya tersi), yönünü değiştirmez.
                        // Yön değiştirme mantığı ayrı olabilir veya burada basitleştirilebilir.
                        // Proje tanımına göre: "Oyuncular birbirlerinin içinden geçemez."
                        // "Oyuncular ekran sınırlarının dışına çıkamaz."
                        // Yön her zaman rakibe doğrudur varsayımı (dövüş oyunlarında yaygın)
                        if (player_x_pos_out < opponent_x_pos) player_facing_right_out <= 1'b1;
                        else player_facing_right_out <= 1'b0;

                    end else if (move_left_in) begin
                        player_current_state_out <= player_facing_right_out ? P_STATE_MOVE_B : P_STATE_MOVE_F;
                         if (player_x_pos_out - (!player_facing_right_out ? MOVE_F_SPEED : MOVE_B_SPEED) > 0 && // Ekran sınırı
                            player_x_pos_out - (!player_facing_right_out ? MOVE_F_SPEED : MOVE_B_SPEED) > opponent_x_pos + PLAYER_SPRITE_W ) begin // Rakip sınırı
                             player_x_pos_out <= player_x_pos_out - (!player_facing_right_out ? MOVE_F_SPEED : MOVE_B_SPEED);
                         end
                        if (player_x_pos_out < opponent_x_pos) player_facing_right_out <= 1'b1;
                        else player_facing_right_out <= 1'b0;

                    end else begin
                        player_current_state_out <= P_STATE_IDLE;
                    end
                end
            end

            // Ekran sınırları ve oyuncu çarpışma kontrolleri (basit)
            if (player_x_pos_out < 0) player_x_pos_out <= 0;
            if (player_x_pos_out > H_DISPLAY_AREA - PLAYER_SPRITE_W) player_x_pos_out <= H_DISPLAY_AREA - PLAYER_SPRITE_W;

            // Rakiple çarpışmayı önleme (birbirlerinin içinden geçmeme)
            // Bu mantık, hareket sırasında zaten kontrol ediliyor, ancak ek bir güvence olabilir.
            // if (player_facing_right_out) begin // Oyuncu solda, rakip sağda
            //     if (player_x_pos_out + PLAYER_SPRITE_W > opponent_x_pos) begin
            //         player_x_pos_out <= opponent_x_pos - PLAYER_SPRITE_W;
            //     end
            // end else begin // Oyuncu sağda, rakip solda
            //     if (player_x_pos_out < opponent_x_pos + PLAYER_SPRITE_W) begin
            //         player_x_pos_out <= opponent_x_pos + PLAYER_SPRITE_W;
            //     end
            // end

        end
    end

    // Hasar Kutusu (Hurtbox) Çıkışları (Her zaman oyuncu sprite'ı ile aynı)
    always @(*) begin
        player_hurtbox_x1_out = player_x_pos_out;
        player_hurtbox_x2_out = player_x_pos_out + PLAYER_SPRITE_W;
    end

    // Vuruş Kutusu (Hitbox) Çıkışları (Sadece saldırı aktifken anlamlı)
    always @(*) begin
        if (player_is_attacking_active_out) begin
            if (player_facing_right_out) begin
                player_hitbox_x1_out = player_x_pos_out + PLAYER_SPRITE_W - (HITBOX_WIDTH - HITBOX_REACH_FORWARD); // Sprite'ın ön kısmı
                player_hitbox_x2_out = player_x_pos_out + PLAYER_SPRITE_W + HITBOX_REACH_FORWARD;
            end else begin
                player_hitbox_x1_out = player_x_pos_out - HITBOX_REACH_FORWARD;
                player_hitbox_x2_out = player_x_pos_out + (HITBOX_WIDTH - HITBOX_REACH_FORWARD); // Sprite'ın ön kısmı
            end
        end else begin
            player_hitbox_x1_out = 0; // Aktif değilken geçersiz değerler
            player_hitbox_x2_out = 0;
        end
    end

endmodule
