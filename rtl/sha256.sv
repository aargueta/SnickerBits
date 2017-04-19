//`include "sha256_pkg.sv"
//import sha256_pkg::*;
module sha256 (
  input clk,
  input rst,

  output logic ctx_rdy,
  input logic ctx_vld,
  input sha256_pkg::ShaContext ctx,

  output logic [31:0] mem_addr,
  input logic mem_data_vld,
  input logic [31:0] mem_data
);


logic chunk_out_rdy;
logic chunk_out_vld;
logic [15:0][31:0] chunk_out;
chunk_processor i_chunk_processor (
  .clk          (clk),
  .rst          (rst),

  .mem_addr     (mem_addr),
  .mem_data_vld (mem_data_vld),
  .mem_data     (mem_data),

  .ctx_rdy      (ctx_rdy),
  .ctx_vld      (ctx_vld),
  .ctx          (ctx),

  .chunk_out_rdy(chunk_out_rdy),
  .chunk_out_vld(chunk_out_vld),
  .chunk_out    (chunk_out)
);


// always_ff @(posedge clk) begin
//   if(rst) begin
//     chunk_data_vld <= 0;
//     chunk_data <= 0;
//   end else begin
//     chunk_data_vld <= 1'b1;
//     chunk_data <= {16{32'hDEAD_BEEF}};
//   end
// end


logic ctx_out_rdy;
logic ctx_out_vld;
sha256_pkg::ShaContext ctx_out;
assign ctx_out_rdy = 1'b1;
sha256_transform ctx_transform(
  .clk           (clk),
  .rst           (rst),

  .ctx_in_rdy    (/*ctx_rdy*/),
  .ctx_in_vld    (ctx_vld),
  .ctx_in        (ctx),

  .chunk_data_rdy(chunk_out_rdy),
  .chunk_data_vld(chunk_out_vld),
  .chunk_data    (chunk_out),

  .ctx_out_rdy   (ctx_out_rdy),
  .ctx_out_vld   (ctx_out_vld),
  .ctx_out       (ctx_out)
);



endmodule