// vga_graphics_connector.v
// İSTEK ÜZERİNE GÜNCELLENDİ:
// - Hitbox rengi SARI oldu.
// - Aktif bir saldırı hitbox'ı rakibin hurtbox'ı ile kesiştiği anda rakip oyuncu TURUNCU olur.
// - Kesişim pikselleri KIRMIZI olarak en üste çizilir.
module vga_graphics_connector (
    input wire clk_pixel,
    input wire reset,

    // Oyun durumu girişleri
    input wire [1:0] i_game_phase,
    input wire       i_p1_is_attacking, // P1'in saldırı mekaniği aktif mi? (player_fsm.o_hitbox_active)
    input wire       i_p2_is_attacking, // P2'nin saldırı mekaniği aktif mi?

    // Mutlak Hitbox ve Hurtbox koordinatları
    input wire [9:0] i_p1_hitbox_x1, i_p1_hitbox_x2,
    input wire [9:0] i_p1_hurtbox_x1, i_p1_hurtbox_x2,
    input wire [9:0] i_p2_hitbox_x1, i_p2_hitbox_x2,
    input wire [9:0] i_p2_hurtbox_x1, i_p2_hurtbox_x2,

    input wire       i_show_hitboxes_continuously, // Hitbox'ları sürekli göster/gizle toggle'ı

    // Oyuncu FSM durumları (hitstun kontrolü için)
    input wire [2:0] i_p1_fsm_state,
    input wire [2:0] i_p2_fsm_state,

    input wire [9:0] i_vga_next_x,
    input wire [9:0] i_vga_next_y,
    output [7:0] o_pixel_color_data // RRRGGGBB
);

    localparam H_DISPLAY = 640;
    localparam V_DISPLAY = 480;
    localparam PLAYER_SPRITE_H = 100;
    localparam GROUND_OFFSET_Y = 20;

    // Renkler (RRRGGGBB)
    localparam C_BLACK  = 8'b000_000_00;
    localparam C_WHITE  = 8'b111_111_11;
    localparam C_P1_MAIN_GREEN = 8'b000_111_00; // P1 için Yeşil
    localparam C_P2_MAIN_BLUE  = 8'b000_000_11; // P2 için Mavi
    
    localparam C_UI_BAR_GREEN   = 8'b000_111_00;
    localparam C_UI_BAR_RED     = 8'b111_000_00;
    localparam C_UI_BAR_BLUE    = 8'b000_000_11;

    localparam C_ATTACK_HITBOX_YELLOW = 8'b111_111_00; // YENİ: Sarı Hitbox
    localparam C_BEING_HIT_ORANGE   = 8'b111_100_00; // YENİ: Vurulan/Kesişen karakter için Turuncu
    localparam C_OVERLAP_RED        = 8'b111_000_00; // Kırmızı Kesişim Alanı (En üstte)
    localparam C_BG                 = 8'b001_001_01; // Arka plan

    // Player FSM durum sabitleriyle eşleşen localparam (P_STATE_HITSTUN)
    localparam P_STATE_HITSTUN_REF = 3'b110; 

    reg [7:0] calculated_color;

    localparam P_TOP_Y    = V_DISPLAY - PLAYER_SPRITE_H - GROUND_OFFSET_Y;
    localparam P_BOTTOM_Y = V_DISPLAY - GROUND_OFFSET_Y;
    localparam HITBOX_VISUAL_TOP_Y    = P_TOP_Y + 35; // Yüksekliği azaltılmış hitbox için offsetler
    localparam HITBOX_VISUAL_BOTTOM_Y = P_BOTTOM_Y - 35;

    always @(*) begin
         automatic reg [9:0] x = i_vga_next_x;
        automatic reg [9:0] y = i_vga_next_y;
        
        automatic reg pixel_in_p1_body;
        automatic reg pixel_in_p2_body;
        automatic reg pixel_in_p1_visual_hitbox_area; // veya önceki adıyla pixel_in_p1_visual_hitbox
        automatic reg pixel_in_p2_visual_hitbox_area; // veya önceki adıyla pixel_in_p2_visual_hitbox
        
        // EKSİK OLABİLECEK VEYA KONTROL ETMENİZ GEREKEN TANIMLAMALAR:
        automatic reg p1_attack_collides_with_p2_body_at_pixel;
        automatic reg p2_attack_collides_with_p1_body_at_pixel;

        // Global kesişim bayrakları (eğer en son versiyonu kullanıyorsanız)
        automatic reg p1_is_globally_hit_by_p2;
        automatic reg p2_is_globally_hit_by_p1;

        // Alan kontrolleri
        pixel_in_p1_body = (x >= i_p1_hurtbox_x1 && x <= i_p1_hurtbox_x2 && y >= P_TOP_Y && y < P_BOTTOM_Y);
        pixel_in_p2_body = (x >= i_p2_hurtbox_x1 && x <= i_p2_hurtbox_x2 && y >= P_TOP_Y && y < P_BOTTOM_Y);

        pixel_in_p1_visual_hitbox_area = (i_show_hitboxes_continuously || i_p1_is_attacking) &&
                                         (x >= i_p1_hitbox_x1 && x <= i_p1_hitbox_x2 && 
                                          y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y);
        pixel_in_p2_visual_hitbox_area = (i_show_hitboxes_continuously || i_p2_is_attacking) &&
                                         (x >= i_p2_hitbox_x1 && x <= i_p2_hitbox_x2 && 
                                          y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y);

        // --- Global Kesişim Tespiti (Tüm sprite'ın rengini değiştirmek için) ---
        // P1'in aktif saldırısı P2'nin hurtbox'ı ile genel olarak kesişiyor mu?
        p2_is_globally_hit_by_p1 = i_p1_is_attacking &&
                                   (i_p1_hitbox_x1 <= i_p2_hurtbox_x2 && i_p1_hitbox_x2 >= i_p2_hurtbox_x1) && // X ekseninde kesişim
                                   (HITBOX_VISUAL_TOP_Y < P_BOTTOM_Y && HITBOX_VISUAL_BOTTOM_Y > P_TOP_Y);     // Y ekseninde kesişim (hitbox ve hurtbox Y'leri)
                                                                                                           // Bu Y koşulu, hitbox'ın genel olarak vücut hizasında olduğunu varsayar.

        // P2'nin aktif saldırısı P1'in hurtbox'ı ile genel olarak kesişiyor mu?
        p1_is_globally_hit_by_p2 = i_p2_is_attacking &&
                                   (i_p2_hitbox_x1 <= i_p1_hurtbox_x2 && i_p2_hitbox_x2 >= i_p1_hurtbox_x1) && // X ekseninde kesişim
                                   (HITBOX_VISUAL_TOP_Y < P_BOTTOM_Y && HITBOX_VISUAL_BOTTOM_Y > P_TOP_Y);     // Y ekseninde kesişim


        // --- Piksel Bazlı Kesişim Tespiti (Kırmızı alan için) ---
        p1_attack_collides_with_p2_body_at_pixel = i_p1_is_attacking && // P1 gerçekten saldırıyor olmalı
                                                   (x >= i_p1_hitbox_x1 && x <= i_p1_hitbox_x2 && 
                                                    y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y) && // P1 hitbox alanı
                                                   pixel_in_p2_body; // P2'nin gövdesi

        p2_attack_collides_with_p1_body_at_pixel = i_p2_is_attacking && // P2 gerçekten saldırıyor olmalı
                                                   (x >= i_p2_hitbox_x1 && x <= i_p2_hitbox_x2 && 
                                                    y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y) && // P2 hitbox alanı
                                                   pixel_in_p1_body; // P1'in gövdesi

        // --- Çizim Mantığı (Katmanlama sırasına göre) ---
        calculated_color = C_WHITE; // 1. Arka Plan

        // 2. Oyuncu Gövdelerini Çiz
        // P1 Çizimi
        if (pixel_in_p1_body) begin
            if (i_p1_fsm_state == P_STATE_HITSTUN_REF) begin // Hitstun'da ise turuncu
                calculated_color = C_BEING_HIT_ORANGE;
            end else if (p1_is_globally_hit_by_p2) begin // VEYA o an aktif bir saldırıyla kesişiyorsa turuncu
                calculated_color = C_BEING_HIT_ORANGE;
            end else begin
                calculated_color = C_P1_MAIN_GREEN; // Normal rengi yeşil
            end
        end

        // P2 Çizimi (P1 üzerine yazabilir)
        if (pixel_in_p2_body) begin
            if (i_p2_fsm_state == P_STATE_HITSTUN_REF) begin // Hitstun'da ise turuncu
                calculated_color = C_BEING_HIT_ORANGE;
            end else if (p2_is_globally_hit_by_p1) begin // VEYA o an aktif bir saldırıyla kesişiyorsa turuncu
                calculated_color = C_BEING_HIT_ORANGE;
            end else begin
                calculated_color = C_P2_MAIN_BLUE; // Normal rengi mavi
            end
        end

        // 3. Hitbox'ları Çiz (Sarı)
        if (pixel_in_p1_visual_hitbox_area) begin
            calculated_color = C_ATTACK_HITBOX_YELLOW;
        end
        if (pixel_in_p2_visual_hitbox_area) begin
            calculated_color = C_ATTACK_HITBOX_YELLOW;
        end

        // 4. Kesişim Alanlarını Çiz (Kırmızı) - En üstte
        if (p1_attack_collides_with_p2_body_at_pixel) begin
            calculated_color = C_OVERLAP_RED;
        end
        if (p2_attack_collides_with_p1_body_at_pixel) begin
            calculated_color = C_OVERLAP_RED;
        end
        
        // 5. Oyun Aşaması Barı (Diğer her şeyin üzerinde)
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
