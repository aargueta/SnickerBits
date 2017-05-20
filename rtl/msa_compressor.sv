module msa_compressor (
  input clk,
  input rst,

  output logic w_rdy,
  input logic w_vld,
  input logic [63:0][31:0] w,

  output logic ctx_in_rdy,
  input logic ctx_in_vld,
  input sha256_pkg::ShaContext ctx_in,

  input logic ctx_out_rdy,
  output logic ctx_out_vld,
  output sha256_pkg::ShaContext ctx_out,
  output sha256_pkg::ShaContext ctx_out1
);


typedef enum logic [2:0] {
  IDLE,
  LOAD,
  PROCESSING,
  OUTPUT
} MsaCompressorState;


MsaCompressorState state_d1;
MsaCompressorState state;
MsaCompressorState nstate;
logic ctx_in_latched;
logic w_latched;
logic [7:0] ctx_out_rdy_count;

always @(*) begin
  if(rst) begin
    nstate = IDLE;
  end else begin
    case (nstate)
      IDLE: nstate = LOAD;
      LOAD: nstate = (ctx_in_latched & w_latched)? PROCESSING : LOAD;
      PROCESSING: nstate = (ctx_out_rdy_count >= 8'd64)? OUTPUT : PROCESSING;
      OUTPUT: nstate = ctx_out_rdy? LOAD : OUTPUT;
      default : nstate = IDLE;
    endcase
  end
end

always_ff @(posedge clk) begin
  if(rst) begin
    state <= IDLE;
    state_d1 <= IDLE;
  end else begin
    state <= nstate;
    state_d1 <= state;
  end
end

// Working variables
logic [64:0][31:0] a, b, c, d, e, f, g, h;
logic [31:0] a1, b1, c1, d1, e1, f1, g1, h1;
logic [63:0][31:0] w_d1;

// Input latching
sha256_pkg::ShaContext ctx_latch;
always @(posedge clk) begin
  if(ctx_in_vld & ctx_in_rdy) begin
    ctx_latch.length <= ctx_in.length;
    ctx_latch.state <= ctx_in.state;
    // {a[0], b[0], c[0], d[0], e[0], f[0], g[0], h[0]} <= ctx_in.state;
    {h[0], g[0], f[0], e[0], d[0], c[0], b[0], a[0]} <= ctx_in.state;
    ctx_latch.curlen <= ctx_in.curlen > sha256_pkg::BYTES_IN_CHUNK?
                        ctx_in.curlen - sha256_pkg::BYTES_IN_CHUNK : 0;
    ctx_latch.buffer <= ctx_in.buffer;
  end
  if(w_vld & w_rdy) begin
    w_d1 <= w;
  end
end

always @(posedge clk) begin
  case (state)
    IDLE: begin
      ctx_in_rdy <= 1'b0;
      w_rdy <= 1'b0;
      ctx_in_latched <= 1'b0;
      w_latched <= 1'b0;
    end
    LOAD: begin
      ctx_in_rdy <= ~ctx_in_latched;
      w_rdy <= ~w_latched;
      ctx_in_latched <= ctx_in_latched | (ctx_in_rdy & ctx_in_vld);
      w_latched <= w_latched | (w_rdy & w_vld);
    end
    PROCESSING: begin
      ctx_in_rdy <= 1'b0;
      w_rdy <= 1'b0;
      ctx_in_latched <= 1'b0;
      w_latched <= 1'b0;
    end
    OUTPUT: begin
      ctx_in_rdy <= ~ctx_in_latched;
      w_rdy <= ~w_latched;
      ctx_in_latched <= ctx_in_latched | (ctx_in_rdy & ctx_in_vld);
      w_latched <= w_latched | (w_rdy & w_vld);
    end
    default : begin
      ctx_in_rdy <= 1'b0;
      w_rdy <= 1'b0;
      ctx_in_latched <= ctx_in_latched;
      w_latched <= w_latched;
    end
  endcase
end

// Ctx out readiness timer
always @(posedge clk) begin
  if(state == PROCESSING) begin
    ctx_out_rdy_count <= ctx_out_rdy_count + 6'd1;
  end else begin
    ctx_out_rdy_count <= 6'd0;
  end
end

assign ctx_out_vld = (state == OUTPUT) && (state_d1 == OUTPUT);

MsaCompressorState state1;
MsaCompressorState nstate1;
always @(*) begin
  if(rst) begin
    nstate1 = IDLE;
  end else begin
    case (nstate1)
      IDLE: nstate1 = LOAD;
      LOAD: nstate1 = (ctx_in_latched & w_latched)? PROCESSING : LOAD;
      PROCESSING: nstate1 = (loop_index < 8'd64)? PROCESSING : OUTPUT;
      OUTPUT: nstate1 = ctx_out_rdy? LOAD : OUTPUT;
      default : nstate1 = IDLE;
    endcase
  end
end

always_ff @(posedge clk) begin
  if(rst) begin
    state1 <= IDLE;
  end else begin
    state1 <= nstate1;
  end
end


logic [31:0] s1;
logic [31:0] ch;
logic [31:0] temp1;
logic [31:0] s0;
logic [31:0] maj;
logic [31:0] temp2;
logic [7:0] loop_index;
logic stall;
always @(*) begin
  case (nstate1)
    IDLE: begin
      stall = 1'b1;
    end
    LOAD: begin
      stall = 1'b1;
    end
    PROCESSING: begin
      stall = 1'b0;
    end
    OUTPUT: begin
      stall = 1'b1;
    end
    default : begin
    end
  endcase
end
// Combinational logic
always_comb begin
  s1 <= sha256_pkg::rightRotate32(e1, 6) ^
        sha256_pkg::rightRotate32(e1, 11) ^
        sha256_pkg::rightRotate32(e1, 25);
  ch <= (g1 ^ (e1 & (f1 ^ g1)));
  temp1 <= h1 + s1 + ch + sha256_pkg::K[loop_index] + w_d1[loop_index];
  s0 <= sha256_pkg::rightRotate32(a1, 2) ^
        sha256_pkg::rightRotate32(a1, 13) ^
        sha256_pkg::rightRotate32(a1, 22);
  maj <= (a1 & b1) ^ (a1 & c1) ^ (b1 & c1);
  temp2 <= s0 + maj;
end
// Accumulate forward to next 'loop'
always @(posedge clk) begin
  if(ctx_in_rdy & ctx_in_vld) begin
    {h1, g1, f1, e1, d1, c1, b1, a1} <= ctx_in.state;
    // {a1, b1, c1, d1, e1, f1, g1, h1} <= ctx_in.state;
    loop_index <= 8'd0;
  end else if(stall) begin
    {a1, b1, c1, d1, e1, f1, g1, h1} <= {a1, b1, c1, d1, e1, f1, g1, h1};
    loop_index <= loop_index;
  end else begin
    {a1, b1, c1, d1, e1, f1, g1, h1} <= {temp1 + temp2, a1, b1, c1, d1 + temp1, e1, f1, g1};
    loop_index <= loop_index + 8'd1;
  end
end

genvar i;
generate
  for ( i = 0; i < 64; i++) begin : main_compression
    logic [31:0] s1;
    logic [31:0] ch;
    logic [31:0] temp1;
    logic [31:0] s0;
    logic [31:0] maj;
    logic [31:0] temp2;
    // Combinational logic
    always_comb begin
      s1 <= sha256_pkg::rightRotate32(e[i], 6) ^
            sha256_pkg::rightRotate32(e[i], 11) ^
            sha256_pkg::rightRotate32(e[i], 25);
      ch <= (g[i] ^ (e[i] & (f[i] ^ g[i])));
      temp1 <= h[i] + s1 + ch + sha256_pkg::K[i] + w_d1[i];
      s0 <= sha256_pkg::rightRotate32(a[i], 2) ^
            sha256_pkg::rightRotate32(a[i], 13) ^
            sha256_pkg::rightRotate32(a[i], 22);
      maj <= (a[i] & b[i]) ^ (a[i] & c[i]) ^ (b[i] & c[i]);
      temp2 <= s0 + maj;
    end
    // Accumulate forward to next 'loop'
    always @(posedge clk) begin
      h[i+1] <= g[i];
      g[i+1] <= f[i];
      f[i+1] <= e[i];
      e[i+1] <= d[i] + temp1;
      d[i+1] <= c[i];
      c[i+1] <= b[i];
      b[i+1] <= a[i];
      a[i+1] <= temp1 + temp2;
    end
  end
endgenerate


always @(posedge clk) begin
  if((nstate1 == OUTPUT) && (state1 == PROCESSING)) begin
    ctx_out.length <= ctx_latch.length;
    ctx_out1.state[0] <= ctx_latch.state[0] + a1;
    ctx_out1.state[1] <= ctx_latch.state[1] + b1;
    ctx_out1.state[2] <= ctx_latch.state[2] + c1;
    ctx_out1.state[3] <= ctx_latch.state[3] + d1;
    ctx_out1.state[4] <= ctx_latch.state[4] + e1;
    ctx_out1.state[5] <= ctx_latch.state[5] + f1;
    ctx_out1.state[6] <= ctx_latch.state[6] + g1;
    ctx_out1.state[7] <= ctx_latch.state[7] + h1;
    // ctx_out1.state[7] <= ctx_latch.state[7] + a1;
    // ctx_out1.state[6] <= ctx_latch.state[6] + b1;
    // ctx_out1.state[5] <= ctx_latch.state[5] + c1;
    // ctx_out1.state[4] <= ctx_latch.state[4] + d1;
    // ctx_out1.state[3] <= ctx_latch.state[3] + e1;
    // ctx_out1.state[2] <= ctx_latch.state[2] + f1;
    // ctx_out1.state[1] <= ctx_latch.state[1] + g1;
    // ctx_out1.state[0] <= ctx_latch.state[0] + h1;
  end else begin
    ctx_out1 <= ctx_out1;
  end
end


always @(posedge clk) begin
  if((state == OUTPUT) && (state_d1 == PROCESSING)) begin
    ctx_out.length <= ctx_latch.length;
    ctx_out.state[0] <= a[0] + a[64];
    ctx_out.state[1] <= b[0] + b[64];
    ctx_out.state[2] <= c[0] + c[64];
    ctx_out.state[3] <= d[0] + d[64];
    ctx_out.state[4] <= e[0] + e[64];
    ctx_out.state[5] <= f[0] + f[64];
    ctx_out.state[6] <= g[0] + g[64];
    ctx_out.state[7] <= h[0] + h[64];
    // ctx_out.state[7] <= a[0] + a[64];
    // ctx_out.state[6] <= b[0] + b[64];
    // ctx_out.state[5] <= c[0] + c[64];
    // ctx_out.state[4] <= d[0] + d[64];
    // ctx_out.state[3] <= e[0] + e[64];
    // ctx_out.state[2] <= f[0] + f[64];
    // ctx_out.state[1] <= g[0] + g[64];
    // ctx_out.state[0] <= h[0] + h[64];
    ctx_out.curlen <= ctx_latch.curlen - sha256_pkg::BYTES_IN_CHUNK;
    ctx_out.buffer <= ctx_latch.buffer;
  end else begin
    ctx_out <= ctx_out;
  end
end

endmodule