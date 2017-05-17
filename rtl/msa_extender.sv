module msa_extender (
  input clk,
  input rst,

  input logic chunk_vld,
  output logic chunk_rdy,
  input logic [15:0][31:0] chunk_data,

  input logic w_rdy,
  output logic w_vld,
  output logic [63:0][31:0] w
);

logic [63:0][31:0] w_shift;
logic [31:0] w_push;
logic [48:0] w_shift_vld;
logic stall;
assign chunk_rdy = ~|w_shift_vld;
assign stall = w_shift_vld[0] & ~w_rdy;
assign w_push = w_shift[64-16] + sha256_pkg::gamma0(w_shift[64-15])
                + w_shift[64-7] + sha256_pkg::gamma1(w_shift[64-2]);
always @(posedge clk) begin
  if(chunk_rdy & chunk_vld) begin
    w_shift[48+:16] <= chunk_data;
  end else if(stall) begin
    w_shift <= w_shift;
  end else begin
    w_shift <= {w_push, w_shift[63:1]};
  end

  if(rst) begin
    w_shift_vld <= 49'd0;
  end else if(stall) begin
    w_shift_vld <= w_shift_vld;
  end else begin
    w_shift_vld <= {chunk_rdy & chunk_vld, w_shift_vld[48:1]};
  end
end

assign w = w_shift;
assign w_vld = w_shift_vld[0];

endmodule