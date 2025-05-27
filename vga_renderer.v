// vga_renderer.v
// VGA sürücüsünden gelen koordinatlara ve oyun durumuna göre pikselleri çizer.
module vga_renderer (
    input wire clk_pixel, // VGA piksel saati (vga_color_out'u kaydetmek için kullanılabilir)
    input wire reset,
    input wire [9:0] vga_x_in, // Mevcut X koordinatı
    input wire [9:0] vga_y_in, // Mevcut Y koordinatı
    input wire vga_video_enable_in, // Aktif çizim alanı ise 1

    // Oyun Durumu Girişleri
    input wire [1:0] game_phase_in,
    input wire [2:0] countdown_value_in,
    input wire [1:0] winner_info_in,
    input wire [6:0] game_seconds_in,
    input wire selected_mode_in, // Menüde 1P/2P göstermek için

    // Oyuncu 1 Bilgileri
    input wire [9:0] p1_x_in,
    input wire [2:0] p1_hp_in,
    input wire [2:0] p1_bp_in,
    input wire [2:0] p1_state_in,
    input wire p1_facing_right_in,

    // Oyuncu 2 Bilgileri
    input wire [9:0] p2_x_in,
    input wire [2:0] p2_hp_in,
    input wire [2:0] p2_bp_in,
    input wire [2:0] p2_state_in,
    input wire p2_facing_right_in,

    output reg [7:0] vga_rgb_out // RRRGGGBB renk çıkışı
);

    // Renk Sabitleri
    localparam C_BLACK       = 8'b000_000_00;
    localparam C_RED         = 8'b111_000_00;
    localparam C_GREEN       = 8'b000_111_00;
    localparam C_BLUE        = 8'b000_000_11;
    localparam C_YELLOW      = 8'b111_111_00;
    localparam C_WHITE       = 8'b111_111_11;
    localparam C_GRAY_DARK   = 8'b010_010_01;
    localparam C_GRAY_LIGHT  = 8'b101_101_10;
    localparam C_CYAN        = 8'b000_111_11;
    localparam C_P1_COLOR    = C_RED;
    localparam C_P2_COLOR    = C_BLUE;
    localparam C_HEALTH_COLOR= C_GREEN;
    localparam C_BLOCK_COLOR = C_YELLOW;
    localparam C_TEXT_COLOR  = C_WHITE;
    localparam C_BG_COLOR    = C_GRAY_DARK;

    // Oyun Aşamaları
    localparam PHASE_MENU      = 2'b00;
    localparam PHASE_COUNTDOWN = 2'b01;
    localparam PHASE_GAMEPLAY  = 2'b10;
    localparam PHASE_GAMEOVER  = 2'b11;

    // Oyuncu Durumları
    localparam P_STATE_HITSTUN   = 3'b110;
    localparam P_STATE_BLOCKSTUN = 3'b111;

    // Sprite ve Ekran Boyutları
    localparam PLAYER_SPRITE_W = 64;
    localparam PLAYER_SPRITE_H = 240;
    localparam V_DISPLAY_AREA = 480;
    localparam H_DISPLAY_AREA = 640;
    localparam PLAYER_Y_GROUND = V_DISPLAY_AREA - 30 - PLAYER_SPRITE_H;

    // UI Elemanları
    localparam BAR_H = 10;
    localparam BAR_W_PER_POINT = 20;
    localparam P1_BAR_X = 10;
    localparam P1_HEALTH_Y = 10;
    localparam P1_BLOCK_Y  = P1_HEALTH_Y + BAR_H + 5;
    localparam MAX_HEALTH_PARAM = 3; // game_logic_fsm'den MAX_HEALTH
    localparam MAX_BLOCK_PARAM  = 3; // game_logic_fsm'den MAX_BLOCK
    localparam P2_BAR_X_START_OFFSET = 10 + MAX_HEALTH_PARAM * BAR_W_PER_POINT;


    // 'automatic' olmadan x ve y için bildirimler
    // Bu değişkenler kombinasyonel blok içinde atandığı için 'reg' olmalı
    // veya doğrudan girişler (vga_x_in, vga_y_in) kullanılmalı.
    // Doğrudan girişleri kullanmak daha temizdir.
    // reg [9:0] x; // Bu satırlara gerek yok, doğrudan vga_x_in ve vga_y_in kullanılacak
    // reg [9:0] y;

    // Oyuncu sprite renkleri için geçici değişkenler (always bloğu içinde tanımlanacak)
    // reg p1_sprite_color; // Bu da always bloğu içine alınacak
    // reg p2_sprite_color; // Bu da always bloğu içine alınacak


    always @(*) begin
        reg [7:0] current_pixel_color; // Bu, always bloğu içinde kalabilir, her seferinde yeniden hesaplanır.
        reg p1_sprite_color; // Oyuncu 1 sprite rengi için geçici değişken
        reg p2_sprite_color; // Oyuncu 2 sprite rengi için geçici değişken

        // x ve y'yi doğrudan girişlerden alalım, modül seviyesinde reg'e gerek yok.
        // x = vga_x_in; // Bu atamalara gerek yok, doğrudan vga_x_in kullanılacak
        // y = vga_y_in;

        current_pixel_color = C_BG_COLOR; // Varsayılan arka plan

        if (vga_video_enable_in) begin // Sadece aktif çizim alanında çiz
            // --- Oyun Aşamasına Özel Çizim ---
            case (game_phase_in)
                PHASE_MENU: begin
                    if (vga_y_in >= V_DISPLAY_AREA/2 - 25 && vga_y_in < V_DISPLAY_AREA/2 -5 &&
                        vga_x_in >= H_DISPLAY_AREA/2 - 40 && vga_x_in < H_DISPLAY_AREA/2 + 40) begin // <-- Koşul için begin
                        current_pixel_color = C_TEXT_COLOR; // "MENU"
                    end // <-- Koşul için end
                    else if (vga_y_in >= V_DISPLAY_AREA/2 + 5 && vga_y_in < V_DISPLAY_AREA/2 + 25) begin // <-- 'else if' ve begin
                        if (selected_mode_in == 1'b1) begin // 1P
                            if (vga_x_in >= H_DISPLAY_AREA/2 - 20 && vga_x_in < H_DISPLAY_AREA/2 + 0) current_pixel_color = C_YELLOW; // "1"
                            else if (vga_x_in >= H_DISPLAY_AREA/2 + 5 && vga_x_in < H_DISPLAY_AREA/2 + 25) current_pixel_color = C_YELLOW; // "P"
                            // else current_pixel_color = C_BG_COLOR; // Opsiyonel: Eğer bu koşullar dışındaysa arka plan
                        end else begin // 2P
                            if (vga_x_in >= H_DISPLAY_AREA/2 - 20 && vga_x_in < H_DISPLAY_AREA/2 + 0) current_pixel_color = C_CYAN; // "2"
                            else if (vga_x_in >= H_DISPLAY_AREA/2 + 5 && vga_x_in < H_DISPLAY_AREA/2 + 25) current_pixel_color = C_CYAN; // "P"
                            // else current_pixel_color = C_BG_COLOR; // Opsiyonel
                        end
                    end // <-- 'else if' için end
                    // else begin // Opsiyonel: Hiçbiri değilse varsayılan renk (zaten en başta C_BG_COLOR atanmıştı)
                    //    current_pixel_color = C_BG_COLOR;
                    // end
                end
                PHASE_COUNTDOWN: begin
                    if (vga_y_in >= V_DISPLAY_AREA/2 - 20 && vga_y_in < V_DISPLAY_AREA/2 + 20 &&
                        vga_x_in >= H_DISPLAY_AREA/2 - 20 && vga_x_in < H_DISPLAY_AREA/2 + 20) begin
                        case(countdown_value_in)
                            3'd3: current_pixel_color = C_RED;
                            3'd2: current_pixel_color = C_YELLOW;
                            3'd1: current_pixel_color = C_GREEN;
                            3'd0: current_pixel_color = C_WHITE;
                            default: current_pixel_color = C_BLACK;
                        endcase
                    end
                end

                PHASE_GAMEPLAY, PHASE_GAMEOVER: begin
                    // Oyuncu 1 Sprite
                    p1_sprite_color = C_P1_COLOR;
                    if (p1_state_in == P_STATE_HITSTUN && (vga_x_in % 8 < 4)) p1_sprite_color = C_WHITE;
                    else if (p1_state_in == P_STATE_BLOCKSTUN) p1_sprite_color = C_GRAY_LIGHT;

                    if (vga_x_in >= p1_x_in && vga_x_in < p1_x_in + PLAYER_SPRITE_W &&
                        vga_y_in >= PLAYER_Y_GROUND && vga_y_in < PLAYER_Y_GROUND + PLAYER_SPRITE_H) begin
                        current_pixel_color = p1_sprite_color;
                    end

                    // Oyuncu 2 Sprite
                    p2_sprite_color = C_P2_COLOR;
                    if (p2_state_in == P_STATE_HITSTUN && (vga_x_in % 8 < 4)) p2_sprite_color = C_WHITE;
                    else if (p2_state_in == P_STATE_BLOCKSTUN) p2_sprite_color = C_GRAY_LIGHT;

                    if (vga_x_in >= p2_x_in && vga_x_in < p2_x_in + PLAYER_SPRITE_W &&
                        vga_y_in >= PLAYER_Y_GROUND && vga_y_in < PLAYER_Y_GROUND + PLAYER_SPRITE_H) begin
                        current_pixel_color = p2_sprite_color;
                    end

                    // P1 Sağlık Çubuğu
                    if (vga_y_in >= P1_HEALTH_Y && vga_y_in < P1_HEALTH_Y + BAR_H &&
                        vga_x_in >= P1_BAR_X && vga_x_in < P1_BAR_X + p1_hp_in * BAR_W_PER_POINT) begin
                        current_pixel_color = C_HEALTH_COLOR;
                    end
                    // P1 Blok Çubuğu
                    if (vga_y_in >= P1_BLOCK_Y && vga_y_in < P1_BLOCK_Y + BAR_H &&
                        vga_x_in >= P1_BAR_X && vga_x_in < P1_BAR_X + p1_bp_in * BAR_W_PER_POINT) begin
                        current_pixel_color = C_BLOCK_COLOR;
                    end

                    // P2 Sağlık Çubuğu
                    if (vga_y_in >= P1_HEALTH_Y && vga_y_in < P1_HEALTH_Y + BAR_H &&
                        vga_x_in >= H_DISPLAY_AREA - P2_BAR_X_START_OFFSET + (MAX_HEALTH_PARAM - p2_hp_in) * BAR_W_PER_POINT &&
                        vga_x_in < H_DISPLAY_AREA - P2_BAR_X_START_OFFSET + MAX_HEALTH_PARAM * BAR_W_PER_POINT) begin
                        current_pixel_color = C_HEALTH_COLOR;
                    end
                    // P2 Blok Çubuğu
                    if (vga_y_in >= P1_BLOCK_Y && vga_y_in < P1_BLOCK_Y + BAR_H &&
                        vga_x_in >= H_DISPLAY_AREA - P2_BAR_X_START_OFFSET + (MAX_BLOCK_PARAM - p2_bp_in) * BAR_W_PER_POINT &&
                        vga_x_in < H_DISPLAY_AREA - P2_BAR_X_START_OFFSET + MAX_BLOCK_PARAM * BAR_W_PER_POINT ) begin
                        current_pixel_color = C_BLOCK_COLOR;
                    end

                    // Oyun Zamanlayıcısı
                    if (vga_y_in >= 10 && vga_y_in < 30 && vga_x_in >= H_DISPLAY_AREA/2 - 30 && vga_x_in < H_DISPLAY_AREA/2 + 30) begin
                        current_pixel_color = C_TEXT_COLOR;
                    end

                    if (game_phase_in == PHASE_GAMEOVER) begin
                        // Kazanan Metni
                        if (vga_y_in >= V_DISPLAY_AREA/2 - 40 && vga_y_in < V_DISPLAY_AREA/2 - 20 &&
                            vga_x_in >= H_DISPLAY_AREA/2 - 60 && vga_x_in < H_DISPLAY_AREA/2 + 60) begin
                            case(winner_info_in)
                                2'b01: current_pixel_color = C_P1_COLOR;
                                2'b10: current_pixel_color = C_P2_COLOR;
                                2'b11: current_pixel_color = C_YELLOW;
                                default: ;
                            endcase
                        end
                        // "OYUN BITTI"
                        if (vga_y_in >= V_DISPLAY_AREA/2 - 15 && vga_y_in < V_DISPLAY_AREA/2 + 5 &&
                            vga_x_in >= H_DISPLAY_AREA/2 - 70 && vga_x_in < H_DISPLAY_AREA/2 + 70) current_pixel_color = C_WHITE;
                    end
                end
                default: ;
            endcase
        end else begin
            current_pixel_color = C_BLACK; // Blanking alanı
        end
        vga_rgb_out = current_pixel_color;
    end

endmodule