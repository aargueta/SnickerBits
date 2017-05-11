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
  output sha256_pkg::ShaContext ctx_out
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
logic [63:0][31:0] w_d1;

// Input latching
sha256_pkg::ShaContext ctx_latch;
always @(posedge clk) begin
  if(ctx_in_vld & ctx_in_rdy) begin
    ctx_latch.length <= ctx_in.length;
    {a[0], b[0], c[0], d[0], e[0], f[0], g[0], h[0]} <= ctx_in.state;
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
  if((state == OUTPUT) && (state_d1 == PROCESSING)) begin
    ctx_out.length <= ctx_latch.length;
    ctx_out.state[7] <= a[0] + a[64];
    ctx_out.state[6] <= b[0] + b[64];
    ctx_out.state[5] <= c[0] + c[64];
    ctx_out.state[4] <= d[0] + d[64];
    ctx_out.state[3] <= e[0] + e[64];
    ctx_out.state[2] <= f[0] + f[64];
    ctx_out.state[1] <= g[0] + g[64];
    ctx_out.state[0] <= h[0] + h[64];
    ctx_out.curlen <= ctx_latch.curlen;
    ctx_out.buffer <= ctx_latch.buffer;
  end else begin
    ctx_out <= ctx_out;
  end
end

endmodule