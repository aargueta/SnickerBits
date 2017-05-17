`timescale 1ns / 1ps

module snickerbits(
  input logic clk_axi,
  input logic rst,
  output logic led,

  output logic hash_rdy,
  output logic hash_vld,
  output logic [255:0] hash
);

logic ctx_rdy;
logic ctx_vld;
sha256_pkg::ShaContext ctx;

logic mem_addr_vld;
logic [31:0] mem_addr;
logic mem_data_vld;
logic [31:0] mem_data;

always_ff @(posedge clk_axi) begin
  if(rst) begin
    ctx_vld <= 0;
    ctx.length <= 64'h0;
    ctx.state <= sha256_pkg::H;
    ctx.curlen <= 32'h0;
    ctx.buffer <= '0;
  end else begin
    ctx_vld <= 1'b1;
    ctx.length <= 64'd512; // 512 bits, 64 bytes
    ctx.state <= sha256_pkg::H;
    ctx.curlen <= 32'd64;
    ctx.buffer <= '0;
  end
end

// Dummy "RAM"
always @(posedge clk_axi) begin
  mem_data <= 32'h4141_4141; //{mem_addr[7:0] + 8'd3, mem_addr[7:0] + 8'd2, mem_addr[7:0] + 8'd1, mem_addr[7:0]};
  mem_data_vld <= mem_addr_vld;
end

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
