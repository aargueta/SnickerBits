module msa_extender (
  input clk,
  input rst,

  input logic ctx_vld,
  output logic ctx_rdy,
  input sha256_pkg::ShaContext ctx,

  input logic chunk_vld,
  output logic chunk_rdy,
  input logic [15:0][31:0] chunk_data,

  input logic w_rdy,
  output logic w_vld,
  output logic [63:0][31:0] w
);

typedef enum logic [2:0] {
  IDLE,
  LOAD,
  PROCESSING,
  OUTPUT
} MsaExtensionState;

MsaExtensionState state;
MsaExtensionState nstate;
logic ctx_latched;
logic chunk_latched;
logic [5:0] w_rdy_count;
always @(*) begin
  if(rst) begin
    nstate = IDLE;
  end else begin
    case (nstate)
      IDLE: nstate = LOAD;
      LOAD: nstate = (ctx_latched & chunk_latched)? PROCESSING : LOAD;
      PROCESSING: nstate = (w_rdy_count >= 6'd21)? OUTPUT : PROCESSING;
      OUTPUT: nstate = w_rdy? IDLE : OUTPUT;
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

// Context/Chunk loading logic
always @(posedge clk) begin
  if(state == IDLE) begin
    chunk_rdy <= 1'b0;
    ctx_rdy <= 1'b0;
    ctx_latched <= 1'b0;
    chunk_latched <= 1'b0;
  end else if (state == LOAD) begin
    chunk_rdy <= ~chunk_latched;
    ctx_rdy <= ~ctx_latched;
    ctx_latched <= ctx_latched | ctx_vld;
    chunk_latched <= chunk_latched | chunk_vld;
  end else begin
    chunk_rdy <= 1'b0;
    ctx_rdy <= 1'b0;
    ctx_latched <= ctx_latched;
    chunk_latched <= chunk_latched;
  end
end

// Load chunk data
genvar i;
generate
  for (i = 0; i < 16; i++) begin
    always @(posedge clk) begin
      if(chunk_vld) begin
        w[i] <= chunk_data[i];
      end
    end
  end
endgenerate

// W readiness timer
always @(posedge clk) begin
  if(state == PROCESSING) begin
    w_rdy_count <= w_rdy_count + 6'd1;
  end else begin
    w_rdy_count <= 6'd0;
  end
end

assign w_vld = state == OUTPUT;


generate
  for (i = 16; i < 64; i++) begin : extend_msa
    logic [31:0] s0;
    logic [31:0] s1;
    always_comb begin
      s0 <= sha256_pkg::rightRotate32(w[i-15], 7) ^
            sha256_pkg::rightRotate32(w[i-15], 18) ^
            sha256_pkg::rightRotate32(w[i-15], 3);
      s1 <= sha256_pkg::rightRotate32(w[i-2], 17) ^
            sha256_pkg::rightRotate32(w[i-2], 19) ^
            sha256_pkg::rightRotate32(w[i-2], 10);
    end
    always @(posedge clk) begin
      w[i] <= w[i-16] + s0 + w[i-7] + s1;
    end
  end
endgenerate
endmodule