`timescale 1ns / 1ps

module snickerbits(
  input logic clk_axi,
  input logic rst,
  output logic led
);

logic ctx_rdy;
logic ctx_vld;
sha256_pkg::ShaContext ctx;

logic  buf_data_rdy;
logic  buf_data_vld;
logic [31:0]  buf_data;

always_ff @(posedge clk_axi) begin
  if(rst) begin
    ctx_vld <= 0;
    ctx.length <= 64'h0;
    ctx.state <= '0;
    ctx.curlen <= 64'h0;
    ctx.buffer <= '0;
  end else begin
    ctx_vld <= 1'b1;
    ctx.length <= 64'h1;
    ctx.state <= '0;
    ctx.curlen <= 64'h1;
    ctx.buffer <= '0;
  end
end

sha256 sha(
  .clk         (clk_axi),
  .rst         (rst),

  .ctx_rdy     (ctx_rdy),
  .ctx_vld     (ctx_vld),
  .ctx         (ctx),

  .buf_data_rdy(buf_data_rdy),
  .buf_data_vld(buf_data_vld),
  .buf_data    (buf_data)
);

always @(posedge clk_axi) begin
  if(rst) begin
    led <= 1'b0;
  end else begin
    led <= ~led;
  end
end
endmodule
