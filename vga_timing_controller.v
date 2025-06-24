// vga_timing_controller.v
// Generates VGA timing signals and pixel coordinates for 640x480 @ 60Hz.
module vga_timing_controller (
    input wire i_clk_pixel,   // Pixel clock (e.g., 25.175 MHz for 640x480 @ 60Hz)
    input wire i_reset,       // Asynchronous or synchronous reset

    output reg o_hsync,        // Horizontal sync pulse (active low)
    output reg o_vsync,        // Vertical sync pulse (active low)
    output reg o_video_active, // High when pixel data is in active display area
    output reg [9:0] o_pixel_x,  // Current X coordinate (0 to H_DISPLAY-1)
    output reg [9:0] o_pixel_y   // Current Y coordinate (0 to V_DISPLAY-1)
);

    // VGA Timings for 640x480 @ 60Hz (Pixel Clock: 25.175 MHz)
    // Horizontal Timings (in pixel clock cycles)
    localparam H_DISPLAY_TIME = 640;  // Visible area
    localparam H_FRONT_PORCH  = 16;
    localparam H_SYNC_PULSE   = 96;
    localparam H_BACK_PORCH   = 48;
    localparam H_TOTAL_TIME   = H_DISPLAY_TIME + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH; // 800

    // Vertical Timings (in line counts)
    localparam V_DISPLAY_TIME = 480;  // Visible area
    localparam V_FRONT_PORCH  = 10;
    localparam V_SYNC_PULSE   = 2;
    localparam V_BACK_PORCH   = 33;
    localparam V_TOTAL_TIME   = V_DISPLAY_TIME + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; // 525

    // Counters for horizontal and vertical position
    reg [9:0] h_count; // Max value H_TOTAL_TIME - 1 = 799
    reg [9:0] v_count; // Max value V_TOTAL_TIME - 1 = 524

    always @(posedge i_clk_pixel or posedge i_reset) begin
        if (i_reset) begin
            h_count <= 0;
            v_count <= 0;
            o_hsync <= 1'b1; // Inactive (high)
            o_vsync <= 1'b1; // Inactive (high)
            o_video_active <= 1'b0;
            o_pixel_x <= 0;
            o_pixel_y <= 0;
        end else begin
            // Horizontal counter
            if (h_count == H_TOTAL_TIME - 1) begin
                h_count <= 0;
                // Vertical counter
                if (v_count == V_TOTAL_TIME - 1) begin
                    v_count <= 0;
                end else begin
                    v_count <= v_count + 1;
                end
            end else begin
                h_count <= h_count + 1;
            end

            // HSYNC Generation (active low)
            // Sync pulse occurs after visible area and front porch
            if ((h_count >= H_DISPLAY_TIME + H_FRONT_PORCH) && 
                (h_count < H_DISPLAY_TIME + H_FRONT_PORCH + H_SYNC_PULSE)) begin
                o_hsync <= 1'b0;
            end else begin
                o_hsync <= 1'b1;
            end

            // VSYNC Generation (active low)
            // Sync pulse occurs after visible area and front porch
            if ((v_count >= V_DISPLAY_TIME + V_FRONT_PORCH) &&
                (v_count < V_DISPLAY_TIME + V_FRONT_PORCH + V_SYNC_PULSE)) begin
                o_vsync <= 1'b0;
            end else begin
                o_vsync <= 1'b1;
            end
            
            // Video Active and Pixel Coordinates
            // Check if current h_count and v_count are within the visible display area
            if ((h_count < H_DISPLAY_TIME) && (v_count < V_DISPLAY_TIME)) begin
                o_video_active <= 1'b1;
                o_pixel_x <= h_count;
                o_pixel_y <= v_count;
            end else begin
                o_video_active <= 1'b0;
                // o_pixel_x and o_pixel_y can be set to 0 or retain last value during blanking
                // Setting to 0 is fine as they are only used when o_video_active is high.
                o_pixel_x <= 0; 
                o_pixel_y <= 0;
            end
        end
    end

endmodule