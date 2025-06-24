// LED_Output_module.v
module LED_Output_module (
    input wire clk_game_logic, // For blink timing
    input wire reset,

    // Inputs from GameLogicFSM_module
    input wire [2:0] i_p1_hp,         // Player 1 health (0-3)
    input wire [2:0] i_p2_hp,         // Player 2 health (0-3)
    input wire [1:0] i_game_phase,    // For game over blink

    // Outputs to specific LEDs
    output reg o_led_p1_hp_0, 
    output reg o_led_p1_hp_1, 
    output reg o_led_p1_hp_2, 
    output reg o_led_p2_hp_0, 
    output reg o_led_p2_hp_1, 
    output reg o_led_p2_hp_2,
    output reg o_all_leds_blinking_state // High when LEDs should be ON in a blink cycle
);

localparam PHASE_MENU      = 2'b00;
localparam PHASE_COUNTDOWN = 2'b01; 
localparam PHASE_GAMEPLAY  = 2'b10;
localparam PHASE_GAMEOVER  = 2'b11;

reg blink_state_reg;
reg [5:0] blink_counter_reg; // For ~0.5s blink rate at 60Hz (counts to 29)

initial begin
    blink_state_reg = 1'b0;
    blink_counter_reg = 0;
end

always @(posedge clk_game_logic or posedge reset) begin
    if (reset) begin
        o_led_p1_hp_0 <= 1'b0;
        o_led_p1_hp_1 <= 1'b0;
        o_led_p1_hp_2 <= 1'b0;
        o_led_p2_hp_0 <= 1'b0;
        o_led_p2_hp_1 <= 1'b0;
        o_led_p2_hp_2 <= 1'b0;
        blink_state_reg <= 1'b0;
        blink_counter_reg <= 0;
        o_all_leds_blinking_state <= 1'b0;
    end else begin
        if (i_game_phase == PHASE_GAMEOVER) begin
            if (blink_counter_reg == 29) begin // Toggle every 30 cycles (0.5s @ 60Hz)
                blink_counter_reg <= 0;
                blink_state_reg <= ~blink_state_reg;
            end else begin
                blink_counter_reg <= blink_counter_reg + 1;
            end
            o_all_leds_blinking_state <= blink_state_reg; // Output current blink state

            // Make health LEDs follow the general blink state during game over
            o_led_p1_hp_0 <= blink_state_reg;
            o_led_p1_hp_1 <= blink_state_reg;
            o_led_p1_hp_2 <= blink_state_reg;
            o_led_p2_hp_0 <= blink_state_reg;
            o_led_p2_hp_1 <= blink_state_reg;
            o_led_p2_hp_2 <= blink_state_reg;

        end else if (i_game_phase == PHASE_MENU) begin
            blink_counter_reg <= 0; 
            blink_state_reg <= 1'b0;
            o_all_leds_blinking_state <= 1'b0;
            // LEDs off in menu
            o_led_p1_hp_0 <= 1'b0; o_led_p1_hp_1 <= 1'b0; o_led_p1_hp_2 <= 1'b0;
            o_led_p2_hp_0 <= 1'b0; o_led_p2_hp_1 <= 1'b0; o_led_p2_hp_2 <= 1'b0;
        end else begin // Gameplay or Countdown
            blink_counter_reg <= 0; 
            blink_state_reg <= 1'b0;
            o_all_leds_blinking_state <= 1'b0;
            // Display health: LED ON if HP >= corresponding point
            o_led_p1_hp_0 <= (i_p1_hp >= 1);
            o_led_p1_hp_1 <= (i_p1_hp >= 2);
            o_led_p1_hp_2 <= (i_p1_hp >= 3);

            o_led_p2_hp_0 <= (i_p2_hp >= 1);
            o_led_p2_hp_1 <= (i_p2_hp >= 2);
            o_led_p2_hp_2 <= (i_p2_hp >= 3);
        end
    end
end
endmodule