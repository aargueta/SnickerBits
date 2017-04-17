//`include "sha256_pkg.sv"
//import sha256_pkg::*;
module sha256 (
  input clk,
  input rst,

  output logic ctx_rdy,
  input logic ctx_vld,
  input sha256_pkg::ShaContext ctx,

  output logic buf_data_rdy,
  input logic buf_data_vld,
  input logic [31:0] buf_data
);
logic chunk_data_rdy;
logic chunk_data_vld;
logic [511:0] chunk_data;

always_ff @(posedge clk) begin
  if(rst) begin
    chunk_data_vld <= 0;
    chunk_data <= 0;
  end else begin
    chunk_data_vld <= 1'b1;
    chunk_data <= {16{32'hDEAD_BEEF}};
  end
end


logic ctx_out_rdy;
logic ctx_out_vld;
sha256_pkg::ShaContext ctx_out;

sha256_transform ctx_transform(
  .clk(clk),
  .rst(rst),

  .ctx_in_rdy  (ctx_rdy),
  .ctx_in_vld  (ctx_vld),
  .ctx_in      (ctx),

  .chunk_data_rdy(chunk_data_rdy),
  .chunk_data_vld(chunk_data_vld),
  .chunk_data(chunk_data),

  .ctx_out_rdy (ctx_out_rdy),
  .ctx_out_vld (ctx_out_vld),
  .ctx_out     (ctx_out)
);



endmodule