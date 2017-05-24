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

logic ctx_rdy;
logic ctx_vld;
sha256_pkg::ShaContext ctx;
logic mem_addr_vld;
logic [31:0] mem_addr;
logic mem_data_vld;
logic [31:0] mem_data;
logic hash_rdy;
logic hash_vld;
logic [255:0] hash;

logic [63:0] hash_num;

// Dummy "RAM"
always @(posedge clk_axi) begin
  mem_data <= 32'h4141_4141; //{mem_addr[7:0] + 8'd3, mem_addr[7:0] + 8'd2, mem_addr[7:0] + 8'd1, mem_addr[7:0]};
  mem_data_vld <= mem_addr_vld;
end

always_ff @(posedge clk_axi) begin
  if(rst) begin
    ctx_vld <= 0;
    ctx.length <= 64'h0;
    ctx.state <= sha256_pkg::H;
    ctx.curlen <= 32'h0;
    ctx.buffer <= '0;
  end else begin
    ctx_vld <= 1'b1;
    ctx.length <= 64'd512 + hash_num; // 512 bits, 64 bytes
    ctx.state <= sha256_pkg::H;
    ctx.curlen <= 32'd0;
    ctx.buffer <= '0;
  end
end

always_ff @(posedge clk_axi) begin : proc_hash_num
  if(rst) begin
    hash_num <= 0;
  end else if(ctx_rdy & ctx_vld) begin
    hash_num <= hash_num + 64'h8;
  end
end

snickerbits dut (
  .clk_axi     (clk_axi     ),
  .rst         (rst         ),
  .led         (led         ),

  .ctx_rdy     (ctx_rdy),
  .ctx_vld     (ctx_vld),
  .ctx         (ctx),

  .mem_addr_vld(mem_addr_vld),
  .mem_addr    (mem_addr    ),
  .mem_data_vld(mem_data_vld),
  .mem_data    (mem_data    ),

  .hash_rdy    (1'b1/*hash_rdy*/    ),
  .hash_vld    (hash_vld    ),
  .hash        (hash        )
);


endmodule
