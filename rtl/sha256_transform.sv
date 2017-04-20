module sha256_transform (
  input clk,
  input rst,

  output logic ctx_in_rdy,
  input logic ctx_in_vld,
  input sha256_pkg::ShaContext ctx_in,

  output logic chunk_data_rdy,
  input logic chunk_data_vld,
  input logic [15:0][31:0] chunk_data,

  input logic ctx_out_rdy,
  output logic ctx_out_vld,
  output sha256_pkg::ShaContext ctx_out
);



//===========================
// MSA extender
//===========================
logic [63:0][31:0] w; // 64-entry message schedule array (MSA)
logic w_rdy = 1'b1;
logic w_vld;
msa_extender msa_extender(
  .clk       (clk),
  .rst       (rst),

  .ctx_vld   (ctx_in_vld),
  .ctx_rdy   (ctx_in_rdy),
  .ctx       (ctx_in),
  .chunk_vld (chunk_data_vld),
  .chunk_rdy (chunk_data_rdy),
  .chunk_data(chunk_data),

  .w_rdy     (w_rdy),
  .w_vld     (w_vld),
  .w         (w)
);


//===========================
// Compression function
//===========================
logic ctx_out_rdy = 1'b1;
logic ctx_out_vld;
sha256_pkg::ShaContext ctx_out;
msa_compressor msa_compressor (
  .clk        (clk),
  .rst        (rst),

  .w_rdy      (w_rdy),
  .w_vld      (w_vld),
  .w          (w),

  .ctx_in_rdy (/*ctx_in_rdy*/), // CTX isn't pipelined in previous state?
  .ctx_in_vld (ctx_in_vld),
  .ctx_in     (ctx_in),

  .ctx_out_rdy(ctx_out_rdy),
  .ctx_out_vld(ctx_out_vld),
  .ctx_out    (ctx_out)
);


endmodule