`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 16:50:27
// Design Name: 
// Module Name: rectangle
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


/*
rectangle rectangle1 (
    .pixel_index       (pixel_index),
    .leftx             (7'd10),
    .rightx            (7'd35),
    .upy               (6'd10),
    .downy             (6'd25),
    .colour            (16'hF800),
    .background_colour (background_colour),
    .oled_data         (after_rectangle1)
);



sample code in topmodule



*/


module rectangle (
    input  wire [12:0] pixel_index,
    input  wire [6:0]  leftx,
    input  wire [6:0]  rightx,
    input  wire [5:0]  upy,
    input  wire [5:0]  downy,
    input  wire [15:0] colour,
    input  wire [15:0] background_colour,
    output wire [15:0] oled_data
);

    // Convert pixel index into coordinates on the 96 x 64 OLED.
    wire [6:0] x;
    wire [5:0] y;

    assign x = pixel_index % 13'd96;
    assign y = pixel_index / 13'd96;

    // Include all four edges of the rectangle.
    wire inside_rectangle;

    assign inside_rectangle = (x >= leftx) && (x <= rightx) &&
                              (y >= upy)  && (y <= downy);

    // RGB565: red [15:11], green [10:5], blue [4:0].
    // Outside the rectangle, pass through the supplied background colour.
    assign oled_data = inside_rectangle ? colour : background_colour;

endmodule
