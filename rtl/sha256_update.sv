module sha256_update (
  input clk,
  input rst,

  output logic ctx_rdy,
  input logic ctx_vld,
  input sha256_pkg::ShaContext ctx,

  output logic buf_data_rdy,
  input logic buf_data_vld,
  input logic [31:0] buf_data
);



endmodule