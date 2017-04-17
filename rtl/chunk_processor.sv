module chunk_processor (
  input clk,
  input rst,

  // Memory interface
  output logic [31:0] mem_addr,
  input logic mem_data_vld,
  input logic [31:0] mem_data,

  // Context in
  output logic ctx_rdy,
  input logic ctx_vld,
  input sha256_pkg::ShaContext ctx,

  // Chunk out
  input logic chunk_out_rdy,
  output logic chunk_out_vld,
  output logic [511:0] chunk_out
);


// State Machine
typedef enum {
  IDLE,
  MEM_READ,
  CHUNK_READY,
  LAST_CHUNK,
  LAST_CHUNK_READY,
  CTX_DONE
} ChunkProcessorState;

ChunkProcessorState state;
ChunkProcessorState nstate;
logic ctx_latched;
logic chunk_loaded;
logic is_last_chunk;
always_comb begin
  if(rst) begin
    nstate = IDLE;
  end else begin
    case (state)
      IDLE: nstate = CTX_LOAD;
      CTX_LOAD: nstate = ctx_latched? MEM_READ : CTX_LOAD
      MEM_READ: nstate = chunk_loaded? (is_last_chunk? LAST_CHUNK : CHUNK_READY) : MEM_READ;
      CHUNK_READY: nstate = chunk_out_rdy? MEM_READ : CHUNK_READY;
      LAST_CHUNK: nstate = LAST_CHUNK_READY;
      LAST_CHUNK_READY: nstate = chunk_out_rdy? CTX_DONE : LAST_CHUNK_READY;
      CTX_DONE: nstate = IDLE;
      default: nstate = IDLE;
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

always_ff @(posedge clk) begin
  if(state == IDLE) begin
    ctx_rdy <= 1'b0;
    ctx_latched <= 0;
  end else if(state == CTX_LOAD) begin
    ctx_rdy <= ~ctx_latched;
    ctx_latched <= ctx_latched | (ctx_rdy & ctx_vld);
  end
end

logic [31:0] ctx_rd_offset;
logic [31:0] chunk_rd_offset;
always @(posedge clk) begin
  case (state)
    CTX_LOAD: begin
      ctx_rd_offset <= 32'h0;
      chunk_rd_offset <= 32'h0;
    end
    MEM_READ: begin
      ctx_rd_offset <= ctx_rd_offset + mem_data_vld;
      chunk_rd_offset <= chunk_rd_offset + mem_data_vld;
    end
    CHUNK_READY: begin
      chunk_rd_offset <= 32'h0;
    end
    default: begin
      ctx_rd_offset <= ctx_rd_offset;
      chunk_rd_offset <= chunk_rd_offset;
    end
  endcase
end

assign is_last_chunk = ctx_rd_offset + BYTES_IN_CHUNK;
// assign mem_addr = ctx.buffer


endmodule