`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/07/2017 09:38:04 PM
// Design Name: 
// Module Name: snickerbits_tb
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


module snickerbits_tb;

logic clk_axi;
logic rst;
logic led;

initial begin
    clk_axi = 1'b0;
    forever begin
        #5 clk_axi = ~clk_axi;
    end
end

initial begin
    rst = 1'b1;
    repeat(4)begin
        @(posedge clk_axi);
    end
    rst = 1'b0;
end

snickerbits dut(
    .clk_axi,
    .rst,
    .led
);
endmodule
