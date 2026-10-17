`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 15:22:44
// Design Name: 
// Module Name: clockmultiplier
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

