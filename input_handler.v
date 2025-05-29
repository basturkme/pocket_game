// input_handler.v
module input_handler (
    input wire clk, // System clock (e.g., 50MHz for debouncer)
    input wire reset,

    // Player 1 Raw Inputs (e.g., from FPGA KEYs)
    input wire p1_raw_move_left_key,
    input wire p1_raw_move_right_key,
    input wire p1_raw_attack_key,

    // Player 2 Raw Inputs (e.g., from external keypad via GPIO)
    input wire p2_raw_move_left_key,
    input wire p2_raw_move_right_key,
    input wire p2_raw_attack_key,

    // Player 1 Debounced Outputs
    output reg p1_move_left,
    output reg p1_move_right,
    output reg p1_attack,

    // Player 2 Debounced Outputs
    output reg p2_move_left,
    output reg p2_move_right,
    output reg p2_attack
);

    parameter DEBOUNCE_THRESHOLD = 50000; // For ~1ms debounce at 50MHz (50MHz * 1ms = 50000)
                                          // Adjust as needed

    // Generic debouncer sub-module
    // Instantiated for each button
    generate
        genvar i;
        for (i = 0; i < 6; i = i + 1) begin : debounce_loop
            reg [$clog2(DEBOUNCE_THRESHOLD)-1:0] debounce_counter_reg;
            reg raw_prev_state_reg;
            reg debounced_out_reg;
            wire current_raw_key;

            // Assign current raw key based on index 'i'
            assign current_raw_key = (i == 0) ? p1_raw_move_left_key :
                                     (i == 1) ? p1_raw_move_right_key :
                                     (i == 2) ? p1_raw_attack_key :
                                     (i == 3) ? p2_raw_move_left_key :
                                     (i == 4) ? p2_raw_move_right_key :
                                                p2_raw_attack_key;

            initial begin
                debounce_counter_reg = 0;
                raw_prev_state_reg = 1'b1; // Assume buttons are active low, released initially
                debounced_out_reg = 1'b0;  // Output pressed state as 1, released as 0
            end

            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    debounce_counter_reg <= 0;
                    // Assuming KEYs are active low on DE1-SoC (pressed = 0, released = 1)
                    // And game logic expects pressed = 1, released = 0
                    raw_prev_state_reg <= 1'b1; // Initial raw state (released)
                    debounced_out_reg  <= 1'b0; // Initial debounced state (not pressed)
                end else begin
                    if (current_raw_key != raw_prev_state_reg) begin
                        // Input changed, reset counter
                        debounce_counter_reg <= 0;
                        raw_prev_state_reg <= current_raw_key;
                    end else if (debounce_counter_reg < DEBOUNCE_THRESHOLD -1 ) begin
                        debounce_counter_reg <= debounce_counter_reg + 1;
                    end else begin
                        // Counter reached threshold, input is stable
                        // Update debounced output (invert active-low raw input)
                        debounced_out_reg <= ~current_raw_key;
                    end
                end
            end

            // Assign to module outputs
            always @(*) begin
                case(i)
                    0: p1_move_left = debounced_out_reg;
                    1: p1_move_right = debounced_out_reg;
                    2: p1_attack = debounced_out_reg;
                    3: p2_move_left = debounced_out_reg;
                    4: p2_move_right = debounced_out_reg;
                    5: p2_attack = debounced_out_reg;
                endcase
            end
        end
    endgenerate

endmodule