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
  sha256_pkg::ShaContext ctx_out
);


typedef enum logic [2:0] {
  IDLE,
  LOAD,
  PROCESSING,
  FEEDBACK,
  OUTPUT
} MsaCompressorState;


MsaCompressorState state;
MsaCompressorState nstate;
logic ctx_in_latched;
logic w_latched;

always @(*) begin
  if(rst) begin
    nstate = IDLE;
  end else begin
    case (nstate)
      IDLE: nstate = LOAD;
      LOAD: nstate = (ctx_in_latched & w_latched)? PROCESSING : LOAD;
      PROCESSING: nstate = (loop_index < 8'd64)? PROCESSING :
                             ((ctx_latch.curlen > 0)? FEEDBACK : OUTPUT);
      FEEDBACK: nstate = LOAD;
      OUTPUT: nstate = ctx_out_rdy? IDLE : OUTPUT;
      default : nstate = IDLE;
    endcase
  end
end

always_ff @(posedge clk) begin
  if(rst) begin
    state <= IDLE;
  end else begin
    state <= nstate;
  end
end

// Working variables
logic [31:0] a, b, c, d, e, f, g, h;
logic [63:0][31:0] w_d1;

// Input latching
sha256_pkg::ShaContext ctx_latch;
always @(posedge clk) begin
  if(state == LOAD) begin
    if(ctx_in_vld & ctx_in_rdy) begin
      ctx_latch.length <= ctx_in.length;
      ctx_latch.state <= ctx_in.state;
      ctx_latch.curlen <= ctx_in.curlen > sha256_pkg::BYTES_IN_CHUNK?
                          ctx_in.curlen - sha256_pkg::BYTES_IN_CHUNK : 0;
      ctx_latch.buffer <= ctx_in.buffer;
    end
    if(w_vld & w_rdy) begin
      w_d1 <= w;
    end
  end if(nstate == FEEDBACK) begin
    ctx_latch.length <= ctx_latch.length;
    ctx_latch.state[0] <= ctx_latch.state[0] + a;
    ctx_latch.state[1] <= ctx_latch.state[1] + b;
    ctx_latch.state[2] <= ctx_latch.state[2] + c;
    ctx_latch.state[3] <= ctx_latch.state[3] + d;
    ctx_latch.state[4] <= ctx_latch.state[4] + e;
    ctx_latch.state[5] <= ctx_latch.state[5] + f;
    ctx_latch.state[6] <= ctx_latch.state[6] + g;
    ctx_latch.state[7] <= ctx_latch.state[7] + h;
    // ctx_latch.state <= ctx_latch.state + {h, g, f, e, d, c, b, a};
    ctx_latch.curlen <= ctx_latch.curlen > sha256_pkg::BYTES_IN_CHUNK?
                          ctx_latch.curlen - sha256_pkg::BYTES_IN_CHUNK : 0;
    ctx_latch.buffer <= ctx_latch.buffer;
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
    FEEDBACK: begin
      ctx_in_rdy <= 1'b0;
      w_rdy <= 1'b0;
      ctx_in_latched <= 1'b1;
      w_latched <= 1'b0;
    end
    OUTPUT: begin
      ctx_in_rdy <= 1'b0;
      w_rdy <= 1'b0;
      ctx_in_latched <= 1'b0;
      w_latched <= 1'b0;
    end
    default : begin
      ctx_in_rdy <= 1'b0;
      w_rdy <= 1'b0;
      ctx_in_latched <= ctx_in_latched;
      w_latched <= w_latched;
    end
  endcase
end

assign ctx_out_vld = (state == OUTPUT) && (nstate == OUTPUT);

logic [31:0] s1;
logic [31:0] ch;
logic [31:0] temp1;
logic [31:0] s0;
logic [31:0] maj;
logic [31:0] temp2;
logic [7:0] loop_index;
logic stall;
always @(*) begin
  case (nstate)
    IDLE: begin
      stall = 1'b1;
    end
    LOAD: begin
      stall = 1'b1;
    end
    PROCESSING: begin
      stall = 1'b0;
    end
    FEEDBACK: begin
      stall = 1'b1;
    end
    OUTPUT: begin
      stall = 1'b1;
    end
    default : begin
      stall = 1'b1;
    end
  endcase
end
// Combinational logic
always_comb begin
  s1 <= sha256_pkg::rightRotate32(e, 6) ^
        sha256_pkg::rightRotate32(e, 11) ^
        sha256_pkg::rightRotate32(e, 25);
  ch <= (g ^ (e & (f ^ g)));
  temp1 <= h + s1 + ch + sha256_pkg::K[loop_index] + w_d1[loop_index];
  s0 <= sha256_pkg::rightRotate32(a, 2) ^
        sha256_pkg::rightRotate32(a, 13) ^
        sha256_pkg::rightRotate32(a, 22);
  maj <= (a & b) ^ (a & c) ^ (b & c);
  temp2 <= s0 + maj;
end
// Accumulate forward to next 'loop'
always @(posedge clk) begin
  if(ctx_in_rdy & ctx_in_vld) begin
    {h, g, f, e, d, c, b, a} <= ctx_in.state;
    loop_index <= 8'd0;
  end else if(nstate == FEEDBACK) begin
    a <= ctx_latch.state[0] + a;
    b <= ctx_latch.state[1] + b;
    c <= ctx_latch.state[2] + c;
    d <= ctx_latch.state[3] + d;
    e <= ctx_latch.state[4] + e;
    f <= ctx_latch.state[5] + f;
    g <= ctx_latch.state[6] + g;
    h <= ctx_latch.state[7] + h;
    // {h, g, f, e, d, c, b, a} <= ctx_latch.state + {h, g, f, e, d, c, b, a};
    loop_index <= 8'd0;
  end else if(stall) begin
    {a, b, c, d, e, f, g, h} <= {a, b, c, d, e, f, g, h};
    loop_index <= loop_index;
  end else begin
    {a, b, c, d, e, f, g, h} <= {temp1 + temp2, a, b, c, d + temp1, e, f, g};
    loop_index <= loop_index + 8'd1;
  end
end

always @(posedge clk) begin
  if((nstate == OUTPUT) && (state == PROCESSING)) begin
    ctx_out.length <= ctx_latch.length;
    ctx_out.state[0] <= ctx_latch.state[0] + a;
    ctx_out.state[1] <= ctx_latch.state[1] + b;
    ctx_out.state[2] <= ctx_latch.state[2] + c;
    ctx_out.state[3] <= ctx_latch.state[3] + d;
    ctx_out.state[4] <= ctx_latch.state[4] + e;
    ctx_out.state[5] <= ctx_latch.state[5] + f;
    ctx_out.state[6] <= ctx_latch.state[6] + g;
    ctx_out.state[7] <= ctx_latch.state[7] + h;
    // ctx_out.state <= ctx_latch.state + {h, g, f, e, d, c, b, a};
    ctx_out.curlen <= ctx_latch.curlen;
    ctx_out.buffer <= ctx_latch.buffer;
  end else begin
    ctx_out <= ctx_out;
  end
end

endmodule