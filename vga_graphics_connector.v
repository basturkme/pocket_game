// vga_graphics_connector.v
// Hitbox kesişimlerini kırmızı gösterecek şekilde güncellendi.
module vga_graphics_connector (
    input wire clk_pixel,
    input wire reset,

    // Oyun durumu girişleri
    input wire [1:0] i_game_phase,
    input wire       i_p1_is_attacking, // Player 1'in saldırı mekaniği aktif mi? (player_fsm.o_hitbox_active)
    input wire       i_p2_is_attacking, // Player 2'nin saldırı mekaniği aktif mi?

    // Mutlak Hitbox ve Hurtbox koordinatları (Game_PokeD'den hesaplanıp gelecek)
    input wire [9:0] i_p1_hitbox_x1, i_p1_hitbox_x2,
    input wire [9:0] i_p1_hurtbox_x1, i_p1_hurtbox_x2, // P1'in gövde/hasar alma alanı
    input wire [9:0] i_p2_hitbox_x1, i_p2_hitbox_x2,
    input wire [9:0] i_p2_hurtbox_x1, i_p2_hurtbox_x2, // P2'nin gövde/hasar alma alanı

    input wire       i_show_hitboxes_continuously, // Hitbox'ları sürekli göster/gizle toggle'ı

    input wire [9:0] i_vga_next_x,
    input wire [9:0] i_vga_next_y,
    output [7:0] o_pixel_color_data // RRRGGGBB
);

    localparam H_DISPLAY = 640;
    localparam V_DISPLAY = 480;
    localparam PLAYER_SPRITE_H = 100; // Oyuncu sprite/hurtbox yüksekliği
    localparam GROUND_OFFSET_Y = 20;

    // Renkler (RRRGGGBB)
    localparam C_BLACK  = 8'b000_000_00;
    localparam C_WHITE  = 8'b111_111_11;
    localparam C_P1_MAIN_GREEN = 8'b000_111_00; // P1 için Yeşil
    localparam C_P2_MAIN_BLUE  = 8'b000_000_11; // P2 için Mavi
    
    localparam C_UI_BAR_GREEN   = 8'b000_111_00; // Menü için (P1 ile aynı olabilir)
    localparam C_UI_BAR_RED     = 8'b111_000_00; // Gameplay bar için Kırmızı
    localparam C_UI_BAR_BLUE    = 8'b000_000_11; // Gameover bar için Mavi (P2 ile aynı olabilir)

    localparam C_ATTACK_HITBOX_ORANGE = 8'b111_100_00; // Turuncu Hitbox (R:7, G:4, B:0)
    localparam C_OVERLAP_RED        = 8'b111_000_00; // Kırmızı Kesişim Alanı

    localparam C_BG     = 8'b001_001_01; // Arka plan

    reg [7:0] calculated_color;

    // Oyuncuların ve hitbox/hurtbox'ların Y eksenindeki sınırları
    localparam P_TOP_Y    = V_DISPLAY - PLAYER_SPRITE_H - GROUND_OFFSET_Y;
    localparam P_BOTTOM_Y = V_DISPLAY - GROUND_OFFSET_Y; // Bu exclusive üst sınır (y < P_BOTTOM_Y)

    // Hitbox'ların Y eksenindeki sınırları (oyuncunun ortasında daha dar bir alan)
    localparam HITBOX_VISUAL_TOP_Y    = P_TOP_Y + 20; 
    localparam HITBOX_VISUAL_BOTTOM_Y = P_BOTTOM_Y - 20;


    always @(*) begin
        automatic reg [9:0] x = i_vga_next_x;
        automatic reg [9:0] y = i_vga_next_y;
        
        automatic reg pixel_in_p1_body; // Oyuncu 1'in gövdesi (hurtbox alanı)
        automatic reg pixel_in_p2_body; // Oyuncu 2'nin gövdesi
        automatic reg pixel_in_p1_visual_hitbox; // P1'in çizilecek hitbox alanı
        automatic reg pixel_in_p2_visual_hitbox; // P2'nin çizilecek hitbox alanı
        automatic reg p1_attack_collides_with_p2_body_at_pixel;
        automatic reg p2_attack_collides_with_p1_body_at_pixel;

        // Alan kontrolleri
        // Oyuncu gövdeleri (hurtbox'lar)
        pixel_in_p1_body = (x >= i_p1_hurtbox_x1 && x <= i_p1_hurtbox_x2 && 
                            y >= P_TOP_Y && y < P_BOTTOM_Y);
        pixel_in_p2_body = (x >= i_p2_hurtbox_x1 && x <= i_p2_hurtbox_x2 && 
                            y >= P_TOP_Y && y < P_BOTTOM_Y);

        // Çizilecek hitbox alanları (sürekli göster veya saldırı anında)
        pixel_in_p1_visual_hitbox = (i_show_hitboxes_continuously || i_p1_is_attacking) &&
                                    (x >= i_p1_hitbox_x1 && x <= i_p1_hitbox_x2 && 
                                     y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y);
        pixel_in_p2_visual_hitbox = (i_show_hitboxes_continuously || i_p2_is_attacking) &&
                                    (x >= i_p2_hitbox_x1 && x <= i_p2_hitbox_x2 && 
                                     y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y);

        // Kesişim kontrolleri (SADECE oyun mekaniği için saldırı aktifken)
        // Bir pikselin hem P1'in AKTİF saldırı hitbox'ında hem de P2'nin gövdesinde olması durumu
        p1_attack_collides_with_p2_body_at_pixel = i_p1_is_attacking && // P1 gerçekten saldırıyor olmalı
                                                   (x >= i_p1_hitbox_x1 && x <= i_p1_hitbox_x2 && // P1 hitbox X
                                                    y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y) && // P1 hitbox Y
                                                   pixel_in_p2_body; // P2'nin gövdesi

        p2_attack_collides_with_p1_body_at_pixel = i_p2_is_attacking && // P2 gerçekten saldırıyor olmalı
                                                   (x >= i_p2_hitbox_x1 && x <= i_p2_hitbox_x2 && // P2 hitbox X
                                                    y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y) && // P2 hitbox Y
                                                   pixel_in_p1_body; // P1'in gövdesi


        // Çizim Mantığı (Katmanlama sırasına göre)
        // 1. Arka Plan
        calculated_color = C_WHITE;

        // 2. Oyuncu 1'in Gövdesi (Yeşil)
        if (pixel_in_p1_body) begin
            calculated_color = C_P1_MAIN_GREEN;
        end

        // 3. Oyuncu 2'nin Gövdesi (Mavi)
        // Eğer P2, P1'in üzerindeyse, P2 çizilir. Aksi halde P1 görünür.
        if (pixel_in_p2_body) begin
            calculated_color = C_P2_MAIN_BLUE;
        end

        // 4. Hitbox'ları Çiz (Turuncu)
        // Bu, oyuncu gövdelerinin üzerine çizilir.
        if (pixel_in_p1_visual_hitbox) begin
            calculated_color = C_ATTACK_HITBOX_ORANGE;
        end
        if (pixel_in_p2_visual_hitbox) begin // Eğer P2 hitbox, P1 hitbox üzerindeyse, P2 hitbox görünür.
            calculated_color = C_ATTACK_HITBOX_ORANGE;
        end

        // 5. Kesişim Alanlarını Çiz (Kırmızı)
        // Bu, hitbox'ların ve oyuncu gövdelerinin üzerine çizilir.
        if (p1_attack_collides_with_p2_body_at_pixel) begin
            calculated_color = C_OVERLAP_RED;
        end
        if (p2_attack_collides_with_p1_body_at_pixel) begin // Eğer her iki saldırı da aynı pikselde kesişiyorsa, bu sonuncusu baskın olur.
            calculated_color = C_OVERLAP_RED;             // Zaten ikisi de kırmızı olacağı için sorun teşkil etmez.
        end
        
        // 6. Oyun Aşaması Barı (En Üstte Her Şeyi Ezer)
        if (y < 10) begin
            case(i_game_phase)
                2'b00: calculated_color = C_UI_BAR_GREEN;
                2'b01: calculated_color = C_WHITE;
                2'b10: calculated_color = C_UI_BAR_RED;
                2'b11: calculated_color = C_UI_BAR_BLUE;
                default: calculated_color = C_BLACK;
            endcase
        end
    end

    assign o_pixel_color_data = calculated_color;
endmodule
