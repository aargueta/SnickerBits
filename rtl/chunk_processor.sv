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
  output logic [15:0][31:0] chunk_out
);


// State Machine
typedef enum {
  IDLE,
  CTX_LOAD,
  CHUNK_FILL,
  CHUNK_READY,
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
      CTX_LOAD: nstate = ctx_latched? CHUNK_FILL : CTX_LOAD;
      CHUNK_FILL: nstate = chunk_loaded? CHUNK_READY : CHUNK_FILL;
      CHUNK_READY: nstate = chunk_out_rdy? (is_last_chunk? CTX_DONE : CHUNK_FILL) : CHUNK_READY;
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
    CHUNK_FILL: begin
      ctx_rd_offset <= ctx_rd_offset + (mem_data_vld? sha256_pkg::MEM_WORD_BYTES : 32'h0);
      chunk_rd_offset <= chunk_rd_offset + (mem_data_vld? sha256_pkg::MEM_WORD_BYTES : 32'h0);
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

assign chunk_loaded = (chunk_rd_offset + sha256_pkg::MEM_WORD_BYTES >= sha256_pkg::BYTES_IN_CHUNK);
assign chunk_out_vld = (state == CHUNK_READY);
assign is_last_chunk = (ca_state != DATA);
assign mem_addr = ctx.buffer + ctx_rd_offset;

logic [31:0] payload_remainder;
logic [31:0] pad_zero_bytes;
logic [29:0] pad_zero_words;
logic [2:0]  end_word_padding;
logic [31:0] end_word_mask;
logic [31:0] end_word;
logic [31:0] zero_pad_limit;
logic mem_data_full_word;
always_comb begin
  payload_remainder = (ctx.length % sha256_pkg::BYTES_IN_CHUNK);
  mem_data_full_word = ctx_rd_offset < ctx.length;
  if(payload_remainder <= sha256_pkg::BYTES_IN_CHUNK - sha256_pkg::MANDATORY_PADDING_BYTES) begin
    pad_zero_bytes = sha256_pkg::BYTES_IN_CHUNK - payload_remainder - sha256_pkg::MANDATORY_PADDING_BYTES;
  end else begin
    pad_zero_bytes = (sha256_pkg::BYTES_IN_CHUNK * 2) - payload_remainder - sha256_pkg::MANDATORY_PADDING_BYTES;
  end
  pad_zero_words = pad_zero_bytes[31:2];
  zero_pad_limit = ctx.length + end_word_padding + (pad_zero_words * sha256_pkg::MEM_WORD_BYTES);
  case(ctx.length % sha256_pkg::MEM_WORD_BYTES)
    0: begin
      end_word = 32'h8000_0000;
      end_word_mask = 32'h0000_0000;
      end_word_padding = 3'd4;
    end
    1: begin
      end_word = 32'h0080_0000;
      end_word_mask = 32'hFF00_0000;
      end_word_padding = 3'd3;
    end
    2: begin
      end_word = 32'h0000_8000;
      end_word_mask = 32'hFFFF_0000;
      end_word_padding = 3'd2;
    end
    3: begin
      end_word = 32'h0000_0080;
      end_word_mask = 32'hFFFF_FF00;
      end_word_padding = 3'd1;
    end
  endcase
end

// Chunk assembly
typedef enum {
  DATA,
  END_WORD,
  ZERO_PAD,
  LENGTH_1,
  LENGTH_2,
  DONE
} ChunkAssemblyState;
ChunkAssemblyState ca_state;
ChunkAssemblyState nca_state;
always_comb begin
  if(rst) begin
    nca_state = DATA;
  end else if(state == IDLE) begin
    nca_state = DATA;
  end else begin
    case (ca_state)
      DATA:     nca_state = mem_data_full_word? DATA : END_WORD;
      END_WORD: nca_state = pad_zero_words > 0? ZERO_PAD : LENGTH_1;
      ZERO_PAD: nca_state = (ctx_rd_offset + sha256_pkg::MEM_WORD_BYTES < zero_pad_limit)? ZERO_PAD : LENGTH_1;
      LENGTH_1: nca_state = LENGTH_2;
      LENGTH_2: nca_state = DONE;
      DONE:     nca_state = (state == IDLE)? DATA : DONE;
      default : nca_state = DATA;
    endcase
  end
end

always_ff @(posedge clk) begin
  if(rst) begin
    ca_state <= DATA;
  end else if(nstate == CHUNK_FILL) begin
    ca_state <= nca_state;
  end
end


always_ff @(posedge clk) begin
  if(mem_data_vld) begin
    case (ca_state)
      DATA:     chunk_out[chunk_rd_offset[31:2]] <= mem_data;
      END_WORD: chunk_out[chunk_rd_offset[31:2]] <= mem_data & end_word_mask | end_word;
      ZERO_PAD: chunk_out[chunk_rd_offset[31:2]] <= 32'h0000_0000;
      LENGTH_1: chunk_out[chunk_rd_offset[31:2]] <= ctx.length[63:32];
      LENGTH_2: chunk_out[chunk_rd_offset[31:2]] <= ctx.length[31:0];
      default : ;
    endcase
  end else begin
    chunk_out <= chunk_out;
  end
end


endmodule