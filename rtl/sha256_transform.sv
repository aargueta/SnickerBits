module sha256_transform (
  input clk,
  input rst,

  output logic ctx_rdy,
  input logic ctx_vld,
  input sha256_pkg::ShaContext ctx,

  output logic chunk_data_rdy,
  input logic chunk_data_vld,
  input logic [15:0][31:0] chunk_data,

  input logic hash_rdy,
  output logic hash_vld,
  output logic [255:0] hash
);



//===========================
// MSA extender
//===========================
logic [63:0][31:0] w; // 64-entry message schedule array (MSA)
logic w_rdy = 1'b1;
logic w_vld;
msa_extender msa_extender(
  .clk          (clk),
  .rst          (rst),

  .chunk_vld    (chunk_data_vld),
  .chunk_rdy    (chunk_data_rdy),
  .chunk_data   (chunk_data),

  .w_rdy        (w_rdy),
  .w_vld        (w_vld),
  .w            (w)
);


//===========================
// Compression function
//===========================
logic ctx_in_rdy;
logic ctx_in_vld;
sha256_pkg::ShaContext ctx_in;

logic ctx_out_rdy;
logic ctx_out_vld;
sha256_pkg::ShaContext ctx_out;

typedef enum {
  LOADING,
  COMPRESSING,
  DONE
} CompressionLoopState;

CompressionLoopState state;
CompressionLoopState nstate;
assign hash_vld = (state == DONE);
assign hash = {ctx_out.state[0], ctx_out.state[1], ctx_out.state[2], ctx_out.state[3],
               ctx_out.state[4], ctx_out.state[5], ctx_out.state[6], ctx_out.state[7]};
always_comb begin
  if(rst) begin
    nstate = LOADING;
  end else begin
    case (state)
      LOADING: nstate = (ctx_rdy & ctx_vld)? COMPRESSING : LOADING;
      COMPRESSING: begin
        if(ctx_out_vld) begin
          nstate = (ctx_out.curlen > 32'h0)? COMPRESSING : DONE;
        end else begin
          nstate = state;
        end
      end
      DONE: nstate = (hash_rdy & hash_vld)? LOADING : DONE;
      default : nstate = LOADING;
    endcase
  end
end

always @(posedge clk) begin
  if(rst) begin
    state <= LOADING;
  end else begin
    state <= nstate;
  end
end

assign ctx_rdy = ctx_in_rdy;
assign ctx_in_vld = ctx_vld;
assign ctx_in = ctx;
assign ctx_out_rdy = (state == DONE) & hash_rdy;


msa_compressor msa_compressor (
  .clk        (clk),
  .rst        (rst),

  .w_rdy      (w_rdy),
  .w_vld      (w_vld),
  .w          (w),

  .ctx_in_rdy (ctx_in_rdy),
  .ctx_in_vld (ctx_in_vld),
  .ctx_in     (ctx_in),

  .ctx_out_rdy(ctx_out_rdy),
  .ctx_out_vld(ctx_out_vld),
  .ctx_out    (ctx_out)
);


endmodule