// vga_graphics_connector.v
// Hitbox yüksekliği azaltıldı.
module vga_graphics_connector (
    input wire clk_pixel,
    input wire reset,

    // Oyun durumu girişleri
    input wire [1:0] i_game_phase,
    input wire       i_p1_is_attacking,
    input wire       i_p2_is_attacking,

    // Mutlak Hitbox ve Hurtbox koordinatları
    input wire [9:0] i_p1_hitbox_x1, i_p1_hitbox_x2,
    input wire [9:0] i_p1_hurtbox_x1, i_p1_hurtbox_x2,
    input wire [9:0] i_p2_hitbox_x1, i_p2_hitbox_x2,
    input wire [9:0] i_p2_hurtbox_x1, i_p2_hurtbox_x2,

    input wire       i_show_hitboxes_continuously,

    // Player FSM durumları
    input wire [2:0] i_p1_fsm_state,
    input wire [2:0] i_p2_fsm_state,

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
    localparam C_P1_MAIN_GREEN = 8'b000_111_00;
    localparam C_P2_MAIN_BLUE  = 8'b000_000_11;
    localparam C_UI_BAR_GREEN   = 8'b000_111_00;
    localparam C_UI_BAR_RED     = 8'b111_000_00;
    localparam C_UI_BAR_BLUE    = 8'b000_000_11;
    localparam C_ATTACK_HITBOX_YELLOW = 8'b111_111_00; // Sarı Hitbox
    localparam C_HIT_STUN_ORANGE    = 8'b111_100_00; // Vurulan karakter için Turuncu
    localparam C_OVERLAP_RED        = 8'b111_000_00;
    localparam C_BG                 = 8'b001_001_01;

    localparam P_STATE_HITSTUN_REF = 3'b110; 

    // Oyuncuların Y eksenindeki sınırları
    localparam P_TOP_Y    = V_DISPLAY - PLAYER_SPRITE_H - GROUND_OFFSET_Y;
    localparam P_BOTTOM_Y = V_DISPLAY - GROUND_OFFSET_Y;

    // Hitbox'ların Y eksenindeki sınırları (YÜKSEKLİK AZALTILDI)
    localparam HITBOX_Y_OFFSET_FROM_P_EDGES = 35; // Offset artırıldı (20'den 35'e)
                                                  // Bu, hitbox'ı dikey olarak daha dar yapar.
                                                  // Yükseklik = PLAYER_SPRITE_H - 2 * HITBOX_Y_OFFSET_FROM_P_EDGES
                                                  // Yükseklik = 100 - 2 * 35 = 100 - 70 = 30 piksel
    localparam HITBOX_VISUAL_TOP_Y    = P_TOP_Y + HITBOX_Y_OFFSET_FROM_P_EDGES; 
    localparam HITBOX_VISUAL_BOTTOM_Y = P_BOTTOM_Y - HITBOX_Y_OFFSET_FROM_P_EDGES;


    reg [7:0] calculated_color;

    always @(*) begin
        automatic reg [9:0] x = i_vga_next_x;
        automatic reg [9:0] y = i_vga_next_y;
        
        automatic reg pixel_in_p1_body;
        automatic reg pixel_in_p2_body;
        automatic reg pixel_in_p1_visual_hitbox;
        automatic reg pixel_in_p2_visual_hitbox;
        automatic reg p1_attack_collides_with_p2_body_at_pixel;
        automatic reg p2_attack_collides_with_p1_body_at_pixel;

        pixel_in_p1_body = (x >= i_p1_hurtbox_x1 && x <= i_p1_hurtbox_x2 && y >= P_TOP_Y && y < P_BOTTOM_Y);
        pixel_in_p2_body = (x >= i_p2_hurtbox_x1 && x <= i_p2_hurtbox_x2 && y >= P_TOP_Y && y < P_BOTTOM_Y);

        pixel_in_p1_visual_hitbox = (i_show_hitboxes_continuously || i_p1_is_attacking) &&
                                    (x >= i_p1_hitbox_x1 && x <= i_p1_hitbox_x2 && 
                                     y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y); // Güncellenmiş Y sınırları kullanılır
        pixel_in_p2_visual_hitbox = (i_show_hitboxes_continuously || i_p2_is_attacking) &&
                                    (x >= i_p2_hitbox_x1 && x <= i_p2_hitbox_x2 && 
                                     y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y); // Güncellenmiş Y sınırları kullanılır

        p1_attack_collides_with_p2_body_at_pixel = i_p1_is_attacking && 
                                                   (x >= i_p1_hitbox_x1 && x <= i_p1_hitbox_x2 && 
                                                    y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y) &&
                                                   pixel_in_p2_body;

        p2_attack_collides_with_p1_body_at_pixel = i_p2_is_attacking && 
                                                   (x >= i_p2_hitbox_x1 && x <= i_p2_hitbox_x2 && 
                                                    y >= HITBOX_VISUAL_TOP_Y && y < HITBOX_VISUAL_BOTTOM_Y) &&
                                                   pixel_in_p1_body;

        calculated_color = C_WHITE;

        if (pixel_in_p1_body) begin
            if (i_p1_fsm_state == P_STATE_HITSTUN_REF) begin
                calculated_color = C_HIT_STUN_ORANGE;
            end else begin
                calculated_color = C_P1_MAIN_GREEN;
            end
        end
        if (pixel_in_p2_body) begin
            if (i_p2_fsm_state == P_STATE_HITSTUN_REF) begin
                calculated_color = C_HIT_STUN_ORANGE;
            end else begin
                calculated_color = C_P2_MAIN_BLUE;
            end
        end

        if (pixel_in_p1_visual_hitbox) begin
            calculated_color = C_ATTACK_HITBOX_YELLOW;
        end
        if (pixel_in_p2_visual_hitbox) begin
            calculated_color = C_ATTACK_HITBOX_YELLOW;
        end

        if (p1_attack_collides_with_p2_body_at_pixel) begin
            calculated_color = C_OVERLAP_RED;
        end
        if (p2_attack_collides_with_p1_body_at_pixel) begin
            calculated_color = C_OVERLAP_RED;
        end
        
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
