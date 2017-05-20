`timescale 1ns / 1ps

module snickerbits(
  input logic clk_axi,
  input logic rst,
  output logic led,

  output logic ctx_rdy,
  input logic ctx_vld,
  input sha256_pkg::ShaContext ctx,

  output logic        mem_addr_vld,
  output logic [31:0] mem_addr,
  input logic         mem_data_vld,
  input logic [31:0]  mem_data,

  input logic hash_rdy,
  output logic hash_vld,
  output logic [255:0] hash
);



sha256 i_sha256 (
  .clk         (clk_axi),
  .rst         (rst),

  .ctx_rdy     (ctx_rdy),
  .ctx_vld     (ctx_vld),
  .ctx         (ctx),

  .mem_addr_vld(mem_addr_vld),
  .mem_addr    (mem_addr),
  .mem_data_vld(mem_data_vld),
  .mem_data    (mem_data),

  .hash_rdy   (hash_rdy),
  .hash_vld   (hash_vld),
  .hash       (hash)
);


always @(posedge clk_axi) begin
  if(rst) begin
    led <= 1'b0;
  end else begin
    led <= ~led;
  end
end
endmodule
