`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// oled_modules.v
//
// The modules used by My_Top_Module, combined into one source file:
//   rectangle      fills a rectangle over a background colour   (was rectangle.v)
//   circle         fills a circle over a background colour      (was circle.v)
//   triangle       fills a triangle given its 3 corners
//   character      one 5x7 font character (petabyt/font), scalable 1x, 2x, 3x ...
//   clock_divider  100 MHz -> 6.25 MHz clock for the OLED       (was clockmultiplier.v)
//   Oled_Display   Pmod OLEDrgb driver, unmodified              (was Oled_Display.v)
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
// rectangle  (from rectangle.v)
//================================================================================
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

//================================================================================
// circle  (from circle.v)
//================================================================================
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

//================================================================================
// triangle
//================================================================================
/*
sample code in topmodule:

triangle triangle1 (
    .pixel_index       (pixel_index),
    .x1                (7'd48),
    .y1                (6'd10),
    .x2                (7'd20),
    .y2                (6'd50),
    .x3                (7'd76),
    .y3                (6'd50),
    .colour            (16'hFFE0),
    .background_colour (background_colour),
    .oled_data         (after_triangle1)
);
*/

module triangle (
    input  wire [12:0] pixel_index,
    input  wire [6:0]  x1,
    input  wire [5:0]  y1,
    input  wire [6:0]  x2,
    input  wire [5:0]  y2,
    input  wire [6:0]  x3,
    input  wire [5:0]  y3,
    input  wire [15:0] colour,
    input  wire [15:0] background_colour,
    output wire [15:0] oled_data
);

    // Convert pixel index into OLED coordinates.
    wire [6:0] x = pixel_index % 13'd96;
    wire [5:0] y = pixel_index / 13'd96;

    // Signed copies of every point so differences can go negative.
    wire signed [8:0] px = {2'b00, x};
    wire signed [8:0] py = {3'b000, y};
    wire signed [8:0] ax = {2'b00, x1};
    wire signed [8:0] ay = {3'b000, y1};
    wire signed [8:0] bx = {2'b00, x2};
    wire signed [8:0] by = {3'b000, y2};
    wire signed [8:0] cx = {2'b00, x3};
    wire signed [8:0] cy = {3'b000, y3};

    // Edge functions (2D cross products): the sign says which side of each
    // edge the pixel is on, and 0 means the pixel lies exactly on that edge.
    wire signed [17:0] e1 = (bx - ax) * (py - ay) - (by - ay) * (px - ax);
    wire signed [17:0] e2 = (cx - bx) * (py - by) - (cy - by) * (px - bx);
    wire signed [17:0] e3 = (ax - cx) * (py - cy) - (ay - cy) * (px - cx);

    wire any_negative = e1[17] | e2[17] | e3[17];
    wire any_positive = (~e1[17] & (|e1)) | (~e2[17] & (|e2)) | (~e3[17] & (|e3));

    // Bounding box of the corners, so a flat triangle (all corners in a line)
    // draws just the line segment between them.
    wire [6:0] min_x = (x1 < x2) ? ((x1 < x3) ? x1 : x3) : ((x2 < x3) ? x2 : x3);
    wire [6:0] max_x = (x1 > x2) ? ((x1 > x3) ? x1 : x3) : ((x2 > x3) ? x2 : x3);
    wire [5:0] min_y = (y1 < y2) ? ((y1 < y3) ? y1 : y3) : ((y2 < y3) ? y2 : y3);
    wire [5:0] max_y = (y1 > y2) ? ((y1 > y3) ? y1 : y3) : ((y2 > y3) ? y2 : y3);
    wire inside_box = (x >= min_x) && (x <= max_x) && (y >= min_y) && (y <= max_y);

    // Inside, or on an edge, when the edges never disagree in sign.
    // This works whichever order (clockwise or not) the corners are given in.
    wire inside_triangle = inside_box && !(any_negative && any_positive);

    assign oled_data = inside_triangle ? colour : background_colour;

endmodule

//================================================================================
// character  (5x7 font from https://github.com/petabyt/font)
//================================================================================
/*
Font data is taken unchanged from font.h in https://github.com/petabyt/font :

MIT License

Copyright (c) 2020 Petabyte

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Draws one character whose top-left pixel is (leftx, upy). Every font pixel
becomes a scale x scale block, so the character box is 5*scale wide and
7*scale tall: scale 1 = 5x7, 2 = 10x14, 3 = 15x21 ... (scale 0 draws nothing).
Supported: a-z, A-Z, 0-9, comma and period. Any other code draws nothing.

sample code in topmodule:

character text1_1 (
    .pixel_index       (pixel_index),
    .ascii             ("A"),
    .leftx             (7'd10),
    .upy               (6'd20),
    .scale             (4'd2),
    .colour            (16'hFFFF),
    .background_colour (background_colour),
    .oled_data         (after_text1_1)
);
*/

module character (
    input  wire [12:0] pixel_index,
    input  wire [7:0]  ascii,
    input  wire [6:0]  leftx,
    input  wire [5:0]  upy,
    input  wire [3:0]  scale,
    input  wire [15:0] colour,
    input  wire [15:0] background_colour,
    output wire [15:0] oled_data
);

    // Convert pixel index into OLED coordinates.
    wire [6:0] x = pixel_index % 13'd96;
    wire [5:0] y = pixel_index / 13'd96;

    // Offset of this pixel from the character's top-left pixel.
    wire [7:0] dx = x - leftx;
    wire [7:0] dy = y - upy;

    // Multiples of scale, so the font row and column can be found
    // with comparisons instead of a divider.
    wire [7:0] s1 = scale;
    wire [7:0] s2 = s1 << 1;
    wire [7:0] s3 = s2 + s1;
    wire [7:0] s4 = s1 << 2;
    wire [7:0] s5 = s4 + s1;
    wire [7:0] s6 = s4 + s2;
    wire [7:0] s7 = s6 + s1;

    // Font column (0-4) = dx / scale and font row (0-6) = dy / scale.
    wire [2:0] col = (dx < s1) ? 3'd0 : (dx < s2) ? 3'd1 : (dx < s3) ? 3'd2 :
                     (dx < s4) ? 3'd3 : 3'd4;
    wire [2:0] row = (dy < s1) ? 3'd0 : (dy < s2) ? 3'd1 : (dy < s3) ? 3'd2 :
                     (dy < s4) ? 3'd3 : (dy < s5) ? 3'd4 : (dy < s6) ? 3'd5 : 3'd6;

    // Inside the 5*scale x 7*scale character box?
    wire inside_box = (x >= leftx) && (y >= upy) && (dx < s5) && (dy < s7);

    // 35 font bits, top row first. Bit 34 is the top-left font pixel.
    wire [34:0] glyph = font_5x7(ascii);
    wire [5:0]  bit_index = 6'd34 - (row * 6'd5 + col);
    wire inside_character = inside_box && glyph[bit_index];

    assign oled_data = inside_character ? colour : background_colour;

    // One row of 5 bits per font row, '1' = pixel on (a '#' in font.h).
    function [34:0] font_5x7;
        input [7:0] c;
        case (c)
            //                  row0  row1  row2  row3  row4  row5  row6
            "a": font_5x7 = 35'b00000_00000_01110_00001_01111_10001_01111;
            "b": font_5x7 = 35'b10000_10000_11110_10001_10001_10001_11110;
            "c": font_5x7 = 35'b00000_00000_01110_10001_10000_10001_01110;
            "d": font_5x7 = 35'b00001_00001_01111_10001_10001_10001_01111;
            "e": font_5x7 = 35'b00000_00000_01110_10001_11111_10000_01111;
            "f": font_5x7 = 35'b00110_01001_01000_11100_01000_01000_01000;
            "g": font_5x7 = 35'b00000_01111_10001_10001_01111_00001_11110;
            "h": font_5x7 = 35'b10000_10000_11110_10001_10001_10001_10001;
            "i": font_5x7 = 35'b10000_00000_10000_10000_10000_10000_10000;
            "j": font_5x7 = 35'b00001_00000_00011_00001_00001_10001_01110;
            "k": font_5x7 = 35'b10000_10000_10001_10010_11100_10010_10001;
            "l": font_5x7 = 35'b10000_10000_10000_10000_10000_10000_11000;
            "m": font_5x7 = 35'b00000_00000_11110_10101_10101_10101_10101;
            "n": font_5x7 = 35'b00000_00000_11110_10001_10001_10001_10001;
            "o": font_5x7 = 35'b00000_00000_01110_10001_10001_10001_01110;
            "p": font_5x7 = 35'b00000_01110_01001_01001_01110_01000_01000;
            "q": font_5x7 = 35'b00000_00000_00111_01001_00111_00001_00001;
            "r": font_5x7 = 35'b00000_00000_10111_11000_10000_10000_10000;
            "s": font_5x7 = 35'b00000_00000_01111_10000_01110_00001_11110;
            "t": font_5x7 = 35'b01000_01000_11100_01000_01000_01000_00110;
            "u": font_5x7 = 35'b00000_00000_10001_10001_10001_10001_01110;
            "v": font_5x7 = 35'b00000_00000_10001_10001_10001_01010_00100;
            "w": font_5x7 = 35'b00000_00000_10001_10001_10101_10101_01010;
            "x": font_5x7 = 35'b00000_00000_10001_01010_00100_01010_10001;
            "y": font_5x7 = 35'b00000_00000_10001_10001_01111_00001_11110;
            "z": font_5x7 = 35'b00000_00000_11111_00010_00100_01000_11111;
            "A": font_5x7 = 35'b01110_10001_10001_10001_11111_10001_10001;
            "B": font_5x7 = 35'b11110_10001_10001_11110_10001_10001_11110;
            "C": font_5x7 = 35'b01111_10000_10000_10000_10000_10000_01111;
            "D": font_5x7 = 35'b11110_10001_10001_10001_10001_10001_11110;
            "E": font_5x7 = 35'b11111_10000_10000_11111_10000_10000_11111;
            "F": font_5x7 = 35'b11111_10000_10000_11111_10000_10000_10000;
            "G": font_5x7 = 35'b01111_10000_10000_10011_10001_10001_01111;
            "H": font_5x7 = 35'b10001_10001_10001_11111_10001_10001_10001;
            "I": font_5x7 = 35'b10000_10000_10000_10000_10000_10000_10000;
            "J": font_5x7 = 35'b00001_00001_00001_00001_00001_00001_11110;
            "K": font_5x7 = 35'b10001_10010_10100_11000_10100_10010_10001;
            "L": font_5x7 = 35'b10000_10000_10000_10000_10000_10000_11111;
            "M": font_5x7 = 35'b10001_11011_10101_10001_10001_10001_10001;
            "N": font_5x7 = 35'b10001_11001_10101_10011_10001_10001_10001;
            "O": font_5x7 = 35'b01110_10001_10001_10001_10001_10001_01110;
            "P": font_5x7 = 35'b11110_10001_10001_11110_10000_10000_10000;
            "Q": font_5x7 = 35'b01110_10001_10001_10001_10001_10011_01111;
            "R": font_5x7 = 35'b11110_10001_10001_10001_11110_10001_10001;
            "S": font_5x7 = 35'b01111_10000_10000_01110_00001_00001_11110;
            "T": font_5x7 = 35'b11111_00100_00100_00100_00100_00100_00100;
            "U": font_5x7 = 35'b10001_10001_10001_10001_10001_10001_01110;
            "V": font_5x7 = 35'b10001_10001_10001_10001_10001_01010_00100;
            "W": font_5x7 = 35'b10001_10001_10001_10001_10101_11011_10001;
            "X": font_5x7 = 35'b10001_10001_01010_00100_01010_10001_10001;
            "Y": font_5x7 = 35'b10001_10001_10001_01110_00100_00100_00100;
            "Z": font_5x7 = 35'b11111_00001_00010_00100_01000_10000_11111;
            "0": font_5x7 = 35'b01110_10001_10011_10101_11001_10001_01110;
            "1": font_5x7 = 35'b11000_01000_01000_01000_01000_01000_01000;
            "2": font_5x7 = 35'b01110_10001_00001_00110_01000_10000_11111;
            "3": font_5x7 = 35'b11110_00001_00001_01110_00001_00001_11110;
            "4": font_5x7 = 35'b10001_10001_10001_11111_00001_00001_00001;
            "5": font_5x7 = 35'b11111_10000_10000_11110_00001_00001_11110;
            "6": font_5x7 = 35'b01111_10000_10000_01110_10001_10001_01110;
            "7": font_5x7 = 35'b11111_00001_00001_00110_01000_01000_01000;
            "8": font_5x7 = 35'b01110_10001_10001_01110_10001_10001_01110;
            "9": font_5x7 = 35'b01110_10001_10001_01111_00001_00001_01110;
            ",": font_5x7 = 35'b00000_00000_00000_00000_00000_00100_01000;
            ".": font_5x7 = 35'b00000_00000_00000_00000_00000_00000_10000;
            default: font_5x7 = 35'b0;
        endcase
    endfunction

endmodule

//================================================================================
// clock_divider  (from clockmultiplier.v)
//================================================================================
module clock_divider #(
    parameter DIVISOR = 16 
)(
    input  wire clk,  // Fast input clock
    output reg  clk_out = 1'b0 // Initialized to 0 for FPGA power-up
);

    // Initialized to 0 for FPGA power-up
    reg [$clog2(DIVISOR)-1:0] counter = 0; 

    always @(posedge clk) begin
        if (counter >= (DIVISOR / 2) - 1) begin
            counter <= 0;
            clk_out <= ~clk_out;
        end else begin
            counter <= counter + 1;
        end
    end

endmodule

//================================================================================
// Oled_Display  (from Oled_Display.v) - third-party code, keep the licence below with it
//================================================================================
// DO NOT MODIFY THIS MODULE

// The codes here are adapted from https://github.com/jhol/otl-icoboard-pmodoledrgb-demo/tree/master/fw/sim

/*
 * Copyright (c) 2017 Joel Holdsworth <joel@airwebreathe.org.uk>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

module Oled_Display(clk, reset, frame_begin, sending_pixels,
  sample_pixel, pixel_index, pixel_data, cs, sdin, sclk, d_cn, resn, vccen,
  pmoden);
localparam Width = 96;
localparam Height = 64;
localparam PixelCount = Width * Height;
localparam PixelCountWidth = $clog2(PixelCount);

parameter ClkFreq = 6250000; // Hz
input clk, reset;
output frame_begin, sending_pixels, sample_pixel;
output [PixelCountWidth-1:0] pixel_index;
input [15:0] pixel_data;
output cs, sdin, sclk, d_cn, resn, vccen, pmoden;

// Frame begin event
localparam FrameFreq = 60;
localparam FrameDiv = ClkFreq / FrameFreq;
localparam FrameDivWidth = $clog2(FrameDiv);

reg [FrameDivWidth-1:0] frame_counter;
assign frame_begin = frame_counter == 0;

// State Machine
localparam PowerDelay = 20; // ms
localparam ResetDelay = 3; // us
localparam VccEnDelay = 20; // ms
localparam StartupCompleteDelay = 100; // ms

localparam MaxDelay = StartupCompleteDelay;
localparam MaxDelayCount = (ClkFreq * MaxDelay) / 1000;
reg [$clog2(MaxDelayCount)-1:0] delay;

localparam StateCount = 32;
localparam StateWidth = $clog2(StateCount);

localparam PowerUp = 5'b00000;
localparam Reset = 5'b00001;
localparam ReleaseReset = 5'b00011;
localparam EnableDriver = 5'b00010;
localparam DisplayOff = 5'b00110;
localparam SetRemapDisplayFormat = 5'b00111;
localparam SetStartLine = 5'b00101;
localparam SetOffset = 5'b00100;
localparam SetNormalDisplay = 5'b01100;
localparam SetMultiplexRatio = 5'b01101;
localparam SetMasterConfiguration = 5'b01111;
localparam DisablePowerSave = 5'b01110;
localparam SetPhaseAdjust = 5'b01010;
localparam SetDisplayClock = 5'b01011;
localparam SetSecondPrechargeA = 5'b01001;
localparam SetSecondPrechargeB = 5'b01000;
localparam SetSecondPrechargeC = 5'b11000;
localparam SetPrechargeLevel = 5'b11001;
localparam SetVCOMH = 5'b11011;
localparam SetMasterCurrent = 5'b11010;
localparam SetContrastA = 5'b11110;
localparam SetContrastB = 5'b11111;
localparam SetContrastC = 5'b11101;
localparam DisableScrolling = 5'b11100;
localparam ClearScreen = 5'b10100;
localparam VccEn = 5'b10101;
localparam DisplayOn = 5'b10111;
localparam PrepareNextFrame = 5'b10110;
localparam SetColAddress = 5'b10010;
localparam SetRowAddress = 5'b10011;
localparam WaitNextFrame = 5'b10001;
localparam SendPixel = 5'b10000;

reg [15:0] color;
reg [StateWidth-1:0] state;
wire [StateWidth-1:0] next_state = fsm_next_state(state, frame_begin, pixel_index);

assign sending_pixels = state == SendPixel;

assign resn = state != Reset;
assign d_cn = sending_pixels;
assign vccen = state == VccEn || state == DisplayOn ||
  state == PrepareNextFrame || state == SetColAddress ||
  state == SetRowAddress || state == WaitNextFrame || state == SendPixel;
assign pmoden = !reset;

function [StateWidth-1:0] fsm_next_state;
  input [StateWidth-1:0] state;
  input frame_begin;
  input [PixelCountWidth-1:0] pixels_remain;
  case (state)
    PowerUp: fsm_next_state = Reset;
    Reset: fsm_next_state = ReleaseReset;
    ReleaseReset: fsm_next_state = EnableDriver;
    EnableDriver: fsm_next_state = DisplayOff;
    DisplayOff: fsm_next_state = SetRemapDisplayFormat;
    SetRemapDisplayFormat: fsm_next_state = SetStartLine;
    SetStartLine: fsm_next_state = SetOffset;
    SetOffset: fsm_next_state = SetNormalDisplay;
    SetNormalDisplay: fsm_next_state = SetMultiplexRatio;
    SetMultiplexRatio: fsm_next_state = SetMasterConfiguration;
    SetMasterConfiguration: fsm_next_state = DisablePowerSave;
    DisablePowerSave: fsm_next_state = SetPhaseAdjust;
    SetPhaseAdjust: fsm_next_state = SetDisplayClock;
    SetDisplayClock: fsm_next_state = SetSecondPrechargeA;
    SetSecondPrechargeA: fsm_next_state = SetSecondPrechargeB;
    SetSecondPrechargeB: fsm_next_state = SetSecondPrechargeC;
    SetSecondPrechargeC: fsm_next_state = SetPrechargeLevel;
    SetPrechargeLevel: fsm_next_state = SetVCOMH;
    SetVCOMH: fsm_next_state = SetMasterCurrent;
    SetMasterCurrent: fsm_next_state = SetContrastA;
    SetContrastA: fsm_next_state = SetContrastB;
    SetContrastB: fsm_next_state = SetContrastC;
    SetContrastC: fsm_next_state = DisableScrolling;
    DisableScrolling: fsm_next_state = ClearScreen;
    ClearScreen: fsm_next_state = VccEn;
    VccEn: fsm_next_state = DisplayOn;
    DisplayOn: fsm_next_state = PrepareNextFrame;
    PrepareNextFrame: fsm_next_state = SetColAddress;
    SetColAddress: fsm_next_state = SetRowAddress;
    SetRowAddress: fsm_next_state = WaitNextFrame;
    WaitNextFrame: fsm_next_state = frame_begin ? SendPixel : WaitNextFrame;
    SendPixel: fsm_next_state = (pixel_index == PixelCount-1) ?
      PrepareNextFrame : SendPixel;
    default: fsm_next_state = PowerUp;
  endcase
endfunction

// SPI Master
localparam SpiCommandMaxWidth = 40;
localparam SpiCommandBitCountWidth = $clog2(SpiCommandMaxWidth);

reg [SpiCommandBitCountWidth-1:0] spi_word_bit_count;
reg [SpiCommandMaxWidth-1:0] spi_word;

wire spi_busy = spi_word_bit_count != 0;
assign cs = !spi_busy;
assign sclk = clk | !spi_busy;
assign sdin = spi_word[SpiCommandMaxWidth-1] & spi_busy;

// Video
assign sample_pixel = (state == WaitNextFrame && frame_begin) ||
  (sending_pixels && frame_counter[3:0] == 0);
assign pixel_index = sending_pixels ?
  frame_counter[FrameDivWidth-1:$clog2(16)] : 0;

always @(negedge clk) begin
  if (reset) begin
    frame_counter <= 0;
    delay <= 0;
    state <= 0;
    spi_word <= 0;
    spi_word_bit_count <= 0;
  end else begin
    frame_counter <= (frame_counter == FrameDiv-1) ? 0 : frame_counter + 1;

    if (spi_word_bit_count > 1) begin
      spi_word_bit_count <= spi_word_bit_count - 1;
      spi_word <= {spi_word[SpiCommandMaxWidth-2:0], 1'b0};
    end else if (delay != 0) begin
      spi_word <= 0;
      spi_word_bit_count <= 0;
      delay <= delay - 1;
    end else begin
      state <= next_state;
      case (next_state)
        PowerUp: begin
          spi_word <= 0;
          spi_word_bit_count <= 0;
          delay <= (ClkFreq * PowerDelay) / 1000;
        end
        Reset: begin
          spi_word <= 0;
          spi_word_bit_count <= 0;
          delay <= (ClkFreq * ResetDelay) / 1000;
        end
        ReleaseReset: begin
          spi_word <= 0;
          spi_word_bit_count <= 0;
          delay <= (ClkFreq * ResetDelay) / 1000;
        end
        EnableDriver: begin
          // Enable the driver
          spi_word <= {16'hFD12, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        DisplayOff: begin
          // Turn the display off
          spi_word <= {8'hAE, {SpiCommandMaxWidth-8{1'b0}}};
          spi_word_bit_count <= 8;
          delay <= 1;
        end
        SetRemapDisplayFormat: begin
          // Set the remap and display formats
          spi_word <= {16'hA072, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetStartLine: begin
          // Set the display start line to the top line
          spi_word <= {16'hA100, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetOffset: begin
          // Set the display offset to no vertical offset
          spi_word <= {16'hA200, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetNormalDisplay: begin
          // Make it a normal display with no color inversion or forcing
          // pixels on/off
          spi_word <= {8'hA4, {SpiCommandMaxWidth-8{1'b0}}};
          spi_word_bit_count <= 8;
          delay <= 1;
        end
        SetMultiplexRatio: begin
          // Set the multiplex ratio to enable all of the common pins
          // calculated by thr 1+register value
          spi_word <= {16'hA83F, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetMasterConfiguration: begin
          // Set the master configuration to use a required a required
          // external Vcc supply.
          spi_word <= {16'hAD8E, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        DisablePowerSave: begin
          // Disable power saving mode.
          spi_word <= {16'hB00B, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetPhaseAdjust: begin
          // Set the phase length of the charge and dischare rates of
          // an OLED pixel.
          spi_word <= {16'hB131, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetDisplayClock: begin
          // Set the display clock divide ration and oscillator frequency
          spi_word <= {16'hB3F0, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetSecondPrechargeA: begin
          // Set the second pre-charge speed of color A
          spi_word <= {16'h8A64, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetSecondPrechargeB: begin
          // Set the second pre-charge speed of color B
          spi_word <= {16'h8B78, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetSecondPrechargeC: begin
          // Set the second pre-charge speed of color C
          spi_word <= {16'h8C64, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetPrechargeLevel: begin
          // Set the pre-charge voltage to approximately 45% of Vcc
          spi_word <= {16'hBB3A, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetVCOMH: begin
          // Set the VCOMH deselect level
          spi_word <= {16'hBE3E, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetMasterCurrent: begin
          // Set the master current attenuation
          spi_word <= {16'h8706, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetContrastA: begin
          // Set the contrast for color A
          spi_word <= {16'h8191, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetContrastB: begin
          // Set the contrast for color B
          spi_word <= {16'h8250, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        SetContrastC: begin
          // Set the contrast for color C
          spi_word <= {16'h837D, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 1;
        end
        DisableScrolling: begin
          // Disable scrolling
          spi_word <= {8'h25, {SpiCommandMaxWidth-8{1'b0}}};
          spi_word_bit_count <= 8;
          delay <= 1;
        end
        ClearScreen: begin
          // Clear the screen
          spi_word <= {40'h2500005F3F, {SpiCommandMaxWidth-40{1'b0}}};
          spi_word_bit_count <= 40;
          delay <= 1;
        end
        VccEn: begin
          spi_word <= 0;
          spi_word_bit_count <= 0;
          delay <= (ClkFreq * VccEnDelay) / 1000;
        end
        DisplayOn: begin
          // Turn the display on
          spi_word <= {8'hAF, {SpiCommandMaxWidth-8{1'b0}}};
          spi_word_bit_count <= 8;
          delay <= (ClkFreq * StartupCompleteDelay) / 1000;
        end
        PrepareNextFrame: begin
          // Deassert CS before beginning next frame
          spi_word <= 0;
          spi_word_bit_count <= 0;
          delay <= 1;
        end
        SetColAddress: begin
          // Set the column address
          spi_word <= {24'h15005F, {SpiCommandMaxWidth-24{1'b0}}};
          spi_word_bit_count <= 24;
          delay <= 1;
        end
        SetRowAddress: begin
          // Set the row address
          spi_word <= {24'h75003F, {SpiCommandMaxWidth-24{1'b0}}};
          spi_word_bit_count <= 24;
          delay <= 1;
        end
        WaitNextFrame: begin
          spi_word <= 0;
          spi_word_bit_count <= 0;
          delay <= 0;
        end
        SendPixel: begin
          spi_word <= {pixel_data, {SpiCommandMaxWidth-16{1'b0}}};
          spi_word_bit_count <= 16;
          delay <= 0;
        end
        default: begin
          spi_word <= 0;
          spi_word_bit_count <= 0;
          delay <= 0;
        end
      endcase
    end
  end
end

endmodule
