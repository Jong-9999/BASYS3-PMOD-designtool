`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 17:06:48
// Design Name: 
// Module Name: circle
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
sample code in topmodule
*/

module circle (
    input  wire [12:0] pixel_index,
    input  wire [6:0]  centrex,
    input  wire [5:0]  centrey,
    input  wire [6:0]  radius,
    input  wire [15:0] colour,
    input  wire [15:0] background_colour,
    output wire [15:0] oled_data
);

    // Convert pixel index into OLED coordinates.
    wire [6:0] x = pixel_index % 13'd96;
    wire [5:0] y = pixel_index / 13'd96;

    // Absolute distances from the circle's centre.
    wire [6:0] dx = (x >= centrex) ? x - centrex : centrex - x;
    wire [5:0] dy = (y >= centrey) ? y - centrey : centrey - y;

    // Wide enough to hold the squared values and their sum.
    wire [15:0] dx_squared = dx * dx;
    wire [15:0] dy_squared = dy * dy;
    wire [15:0] radius_squared = radius * radius;
    wire [15:0] distance_squared = dx_squared + dy_squared;

    // A pixel is inside when dx² + dy² <= radius².
    wire inside_circle = (distance_squared <= radius_squared);

    assign oled_data = inside_circle ? colour : background_colour;

endmodule