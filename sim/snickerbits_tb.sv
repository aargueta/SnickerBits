`timescale 1ns / 1ps
//import sha256_pkg::*;
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

logic [7:0] a = 8'h1;
logic [7:0] b = 8'h2;
logic [7:0] sum;
always @(posedge clk_axi) begin
  if(rst) begin
    sum <= '0;
  end else begin
    sum <= sum + a;
  end
end


endmodule
