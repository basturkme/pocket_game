// led_driver.v
module led_driver (
    input wire       clk_game_logic, // Game logic clock (e.g., 60Hz) for blink timing
    input wire       reset,

    input wire [1:0] i_game_phase,      // Input to indicate current game phase
                                        // Example: 2'b00: MENU, 2'b01: GAMEPLAY/COUNTDOWN, 2'b10: GAMEOVER

    input wire [1:0] i_p1_health,       // Player 1 health (0-3, where 3 is full health)
    input wire [1:0] i_p2_health,       // Player 2 health (0-3)

    output reg [9:0] o_ledr             // Output to drive the 10 LEDs (LEDR[9:0])
);

    // Game Phase Parameters (matching example in thought process)
    localparam PHASE_MENU     = 2'b00;
    localparam PHASE_GAMEPLAY = 2'b01; // Includes countdown for health display
    localparam PHASE_GAMEOVER = 2'b10;

    // Blinking logic for Game Over mode
    // For a ~2Hz blink rate (toggle every ~0.25s) with a 60Hz clock:
    // 0.25s * 60 cycles/s = 15 cycles. Counter goes 0 to 14.
    localparam BLINK_COUNTER_MAX = 14;
    reg [$clog2(BLINK_COUNTER_MAX+1)-1:0] blink_counter_reg;
    reg blink_toggle_reg;

    initial begin
        blink_counter_reg = 0;
        blink_toggle_reg = 1'b0;
        o_ledr = 10'b0;
    end

    // Blink clock generator
    always @(posedge clk_game_logic or posedge reset) begin
        if (reset) begin
            blink_counter_reg <= 0;
            blink_toggle_reg <= 1'b0;
        end else begin
            if (i_game_phase == PHASE_GAMEOVER) begin
                if (blink_counter_reg == BLINK_COUNTER_MAX) begin
                    blink_counter_reg <= 0;
                    blink_toggle_reg <= ~blink_toggle_reg;
                end else begin
                    blink_counter_reg <= blink_counter_reg + 1;
                end
            end else begin
                // Reset blinker when not in game over to ensure consistent start
                blink_counter_reg <= 0;
                blink_toggle_reg <= 1'b0;
            end
        end
    end

    // Main logic to drive LEDs
    always @(*) begin // Combinational based on game phase and health
        case (i_game_phase)
            PHASE_MENU: begin
                o_ledr = 10'b0000_000_000; // All LEDs off [cite: 108]
            end

            PHASE_GAMEPLAY: begin
                // Player 1 Health: Leftmost 3 LEDs (LEDR[9:7]) [cite: 109]
                // LEDs turn off progressively [cite: 110]
                // LEDR[7] for health >= 1
                // LEDR[8] for health >= 2
                // LEDR[9] for health >= 3
                reg [9:0] gameplay_leds; // Temporary variable for clarity

                gameplay_leds = 10'b0; // Start with all off

                // P1 Health
                if (i_p1_health >= 1) gameplay_leds[7] = 1'b1;
                if (i_p1_health >= 2) gameplay_leds[8] = 1'b1;
                if (i_p1_health >= 3) gameplay_leds[9] = 1'b1;

                // Player 2 Health: Rightmost 3 LEDs (LEDR[2:0]) [cite: 109]
                // LEDR[0] for health >= 1
                // LEDR[1] for health >= 2
                // LEDR[2] for health >= 3
                if (i_p2_health >= 1) gameplay_leds[0] = 1'b1;
                if (i_p2_health >= 2) gameplay_leds[1] = 1'b1;
                if (i_p2_health >= 3) gameplay_leds[2] = 1'b1;
                
                // LEDs LEDR[6:3] are unused for health display
                o_ledr = gameplay_leds;
            end

            PHASE_GAMEOVER: begin
                if (blink_toggle_reg) begin
                    o_ledr = 10'b1111_111_111; // All LEDs on [cite: 109] (during one phase of blink)
                end else begin
                    o_ledr = 10'b0000_000_000; // All LEDs off (during other phase of blink)
                end
            end

            default: begin
                o_ledr = 10'b0000_000_000; // Default to all off
            end
        endcase
    end

endmodule