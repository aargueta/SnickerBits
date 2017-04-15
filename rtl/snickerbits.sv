`timescale 1ns / 1ps

module snickerbits(
    input logic clk_axi,
    input logic rst,
    output logic led

);

always @(posedge clk_axi) begin
    if(rst) begin
        led <= 1'b0;
    end else begin
        led <= ~led;
    end
end
endmodule
