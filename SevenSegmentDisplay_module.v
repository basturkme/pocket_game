// SevenSegmentDisplay_module.v
module SevenSegmentDisplay_module (
    // input wire clk_display, // Clock might not be needed if purely combinational
    input wire reset, // Can be used to initialize display characters if needed

    // Inputs from GameLogicFSM_module
    input wire [1:0] i_game_phase,
    input wire i_sw0_current_mode_selection, // Live from SW[0] for MENU display
    // input wire i_selected_player_mode,    // Confirmed mode (not directly used for display by project spec)
    input wire [1:0] i_winner_info,
    input wire [6:0] i_elapsed_time_seconds, // 0-99

    // Outputs to connect to HEX0-HEX5 in the top module
    output wire [6:0] o_hex5_pattern, // Digit 5 (Leftmost)
    output wire [6:0] o_hex4_pattern, // Digit 4
    output wire [6:0] o_hex3_pattern, // Digit 3
    output wire [6:0] o_hex2_pattern, // Digit 2
    output wire [6:0] o_hex1_pattern, // Digit 1
    output wire [6:0] o_hex0_pattern  // Digit 0 (Rightmost)
);

    // Game Phases
    localparam PHASE_MENU      = 2'b00;
    localparam PHASE_COUNTDOWN = 2'b01; // Gameplay display for countdown phase
    localparam PHASE_GAMEPLAY  = 2'b10;
    localparam PHASE_GAMEOVER  = 2'b11;

    // Winner Info
    localparam WINNER_NONE = 2'b00; // Should not occur in GAMEOVER
    localparam WINNER_P1   = 2'b01;
    localparam WINNER_P2   = 2'b10;
    localparam WINNER_DRAW = 2'b11;

    // Character hex codes for hexto7seg input
    // These map to the 'hex' input of your hexto7seg module
    localparam HEX_0 = 4'd0; localparam HEX_1 = 4'd1; localparam HEX_2 = 4'd2;
    localparam HEX_3 = 4'd3; localparam HEX_4 = 4'd4; localparam HEX_5 = 4'd5;
    localparam HEX_6 = 4'd6; localparam HEX_7 = 4'd7; localparam HEX_8 = 4'd8;
    localparam HEX_9 = 4'd9;
    // Letters based on the hexto7seg module provided/corrected above:
    localparam HEX_P = 4'hA; // 'P' (using 'A' pattern)
    localparam HEX_F = 4'hF; // 'F'
    localparam HEX_I = 4'd1; // 'I' (using '1' pattern)
    localparam HEX_G = 4'd6; // 'G' (using '6' pattern which looks like G)
    localparam HEX_H = 4'd4; // 'H' (using '4' pattern which can be H)
    localparam HEX_T = 4'd7; // 'T' (using '7' pattern which can be t)
    localparam HEX_E = 4'hE; // 'E'
    localparam HEX_Q = 4'd9; // 'q' (using '9' pattern)
    localparam HEX_DASH = 4'hB; // '-' (using 'b' pattern as a stand-in for dash, or update hexto7seg)
    localparam HEX_BLANK = 4'hF; // Assuming default in hexto7seg gives blank (or 7'b0000000)
                                 // Corrected hexto7seg default: 7'b0000000 (blank for active high)

    reg [3:0] digit_hex_value[5:0]; // Hex values for 6 digits [Leftmost ... Rightmost]

    // Logic to determine what characters (as hex codes) to display
    always @(*) begin
        // Default to blanks
        digit_hex_value[5] = HEX_BLANK; digit_hex_value[4] = HEX_BLANK;
        digit_hex_value[3] = HEX_BLANK; digit_hex_value[2] = HEX_BLANK;
        digit_hex_value[1] = HEX_BLANK; digit_hex_value[0] = HEX_BLANK;

        case (i_game_phase)
            PHASE_MENU: begin
                // Display "1P    " or "2P    " (left-aligned)
                // SW[0] directly determines "1P" or "2P" displayed
                if (i_sw0_current_mode_selection == 1'b1) begin // 1P
                    digit_hex_value[5] = HEX_BLANK; // Or align to center
                    digit_hex_value[4] = HEX_1;
                    digit_hex_value[3] = HEX_P;
                    digit_hex_value[2] = HEX_BLANK;
                    digit_hex_value[1] = HEX_BLANK;
                    digit_hex_value[0] = HEX_BLANK;
                end else begin // 2P
                    digit_hex_value[5] = HEX_BLANK;
                    digit_hex_value[4] = HEX_2;
                    digit_hex_value[3] = HEX_P;
                    digit_hex_value[2] = HEX_BLANK;
                    digit_hex_value[1] = HEX_BLANK;
                    digit_hex_value[0] = HEX_BLANK;
                end
            end
            PHASE_COUNTDOWN, PHASE_GAMEPLAY: begin // Display "FIGHt "
                digit_hex_value[5] = HEX_F;
                digit_hex_value[4] = HEX_I;
                digit_hex_value[3] = HEX_G;
                digit_hex_value[2] = HEX_H;
                digit_hex_value[1] = HEX_T;
                digit_hex_value[0] = HEX_BLANK;
            end
            PHASE_GAMEOVER: begin
                automatic integer time_val = i_elapsed_time_seconds;
                if (time_val > 99) time_val = 99; // Cap at 99 for 2 digits

                digit_hex_value[2] = HEX_DASH;
                digit_hex_value[1] = time_val / 10; // Tens digit
                digit_hex_value[0] = time_val % 10; // Ones digit

                case (i_winner_info)
                    WINNER_P1: begin // "P1-XX"
                        digit_hex_value[5] = HEX_P;
                        digit_hex_value[4] = HEX_1;
                        digit_hex_value[3] = HEX_DASH;
                    end
                    WINNER_P2: begin // "P2-XX"
                        digit_hex_value[5] = HEX_P;
                        digit_hex_value[4] = HEX_2;
                        digit_hex_value[3] = HEX_DASH;
                    end
                    WINNER_DRAW: begin // "Eq-XX"
                        digit_hex_value[5] = HEX_E; 
                        digit_hex_value[4] = HEX_Q; 
                        digit_hex_value[3] = HEX_DASH;
                    end
                    default: begin // Should not happen
                        digit_hex_value[5] = HEX_BLANK;
                        digit_hex_value[4] = HEX_BLANK;
                        digit_hex_value[3] = HEX_BLANK;
                    end
                endcase
            end
            default: ; // All blanks
        endcase
    end

    // Instantiate hexto7seg for each of the 6 digits
    hexto7seg inst_hex5 (.hex(digit_hex_value[5]), .hexn(o_hex5_pattern));
    hexto7seg inst_hex4 (.hex(digit_hex_value[4]), .hexn(o_hex4_pattern));
    hexto7seg inst_hex3 (.hex(digit_hex_value[3]), .hexn(o_hex3_pattern));
    hexto7seg inst_hex2 (.hex(digit_hex_value[2]), .hexn(o_hex2_pattern));
    hexto7seg inst_hex1 (.hex(digit_hex_value[1]), .hexn(o_hex1_pattern));
    hexto7seg inst_hex0 (.hex(digit_hex_value[0]), .hexn(o_hex0_pattern));

endmodule