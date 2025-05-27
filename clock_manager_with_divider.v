module clock_manager_with_divider (
    input wire clk_50mhz,         // System clock (50 MHz)
    input wire reset,             // System reset
    input wire sw1_debug_mode,    // Switch SW[1]
    input wire key_debug_clk_in,  // KEY input for debug

    output wire clk_vga_25mhz,     // 25 MHz clock for VGA
    output wire clk_game_logic     // Clock for game logic
);

    // Internal 60Hz clock signal
    wire clk_60hz_internal;

    // Generate 25 MHz clock from 50 MHz (DIVISOR = 50MHz / 25MHz = 2)
    clock_divider_functional #(
        .DIVISOR(2)
    ) vga_clk_divider (
        .clk(clk_50mhz),
        .reset(reset),
        .clk_out(clk_vga_25mhz)
    );

    // Generate 60 Hz clock from 50 MHz
    // DIVISOR = 50,000,000 / 60 = 833,333.333...
    // We need COUNT_MAX_VAL = (50,000,000 / (2 * 60)) - 1 = 416667 - 1 = 416666
    // So the DIVISOR for clock_divider_functional should be 2 * 416667 = 833334
    // Output frequency = 50,000,000 / 833334 = 59.99995 Hz
    clock_divider_functional #(
        .DIVISOR(833334)
    ) game_logic_clk_divider (
        .clk(clk_50mhz),
        .reset(reset),
        .clk_out(clk_60hz_internal)
    );

    // Select game logic clock
    assign clk_game_logic = sw1_debug_mode ? key_debug_clk_in : clk_60hz_internal;

endmodule