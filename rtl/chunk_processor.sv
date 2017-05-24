module chunk_processor (
  input clk,
  input rst,

  // Memory interface
  output logic mem_addr_vld,
  output logic [31:0] mem_addr,
  input logic mem_data_vld,
  input logic [31:0] mem_data,

  // Context in
  output logic ctx_in_rdy,
  input logic ctx_in_vld,
  input sha256_pkg::ShaContext ctx_in,

  // Context out
  input logic ctx_out_rdy,
  output logic ctx_out_vld,
  output sha256_pkg::ShaContext ctx_out,

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
    ctx_in_rdy <= 1'b0;
    ctx_latched <= 0;
  end else if(state == CTX_LOAD) begin
    ctx_in_rdy <= ~(ctx_latched | (ctx_in_rdy & ctx_in_vld));
    ctx_latched <= ctx_latched | (ctx_in_rdy & ctx_in_vld);
  end
end

assign ctx_out_vld = ctx_latched;
logic [63:0] total_length;
always @(posedge clk) begin
  case (state)
    CTX_LOAD: begin
      ctx_out.length <= ctx_in.length;
      ctx_out.state <= ctx_in.state;
      ctx_out.curlen <= total_length[34:3];
      ctx_out.buffer <= ctx_in.buffer;
      mem_addr <= ctx_in.buffer;
    end
    CHUNK_FILL: begin
      mem_addr <= mem_addr + (nstate == CHUNK_FILL? sha256_pkg::MEM_WORD_BYTES : 32'h0);
      ctx_out <= ctx_out;
    end
    default : ;
  endcase
end

logic [31:0] ctx_rd_offset;
logic [31:0] ctx_rd_offset_d1;
logic [31:0] chunk_rd_offset;
logic [31:0] chunk_rd_offset_d1;
always @(posedge clk) begin
  ctx_rd_offset_d1 <= ctx_rd_offset;
  chunk_rd_offset_d1 <= chunk_rd_offset;
  case (state)
    CTX_LOAD: begin
      ctx_rd_offset <= 32'h0;
      chunk_rd_offset <= 32'h0;
      total_length <= {ctx_in.length[63:9] +
                       (ctx_in.length[8:0] > (9'd511 - sha256_pkg::MANDATORY_PADDING_BITS))?
                        55'd2 : 55'd1, 9'd0};
    end
    CHUNK_FILL: begin
      ctx_rd_offset <= mem_data_vld? ctx_rd_offset + sha256_pkg::MEM_WORD_BYTES : ctx_rd_offset;
      chunk_rd_offset <= chunk_rd_offset + (mem_data_vld? sha256_pkg::MEM_WORD_BYTES : 32'h0);
      total_length <= total_length;
    end
    CHUNK_READY: begin
      ctx_rd_offset <= ctx_rd_offset;
      chunk_rd_offset <= 32'h0;
      total_length <= total_length;
    end
    default: begin
      ctx_rd_offset <= ctx_rd_offset;
      chunk_rd_offset <= chunk_rd_offset;
      total_length <= total_length;
    end
  endcase
end

assign chunk_loaded = (chunk_rd_offset + sha256_pkg::MEM_WORD_BYTES >= sha256_pkg::BYTES_IN_CHUNK);
assign chunk_out_vld = (state == CHUNK_READY);
assign is_last_chunk = (ca_state != DATA);
// assign mem_addr = ctx_in.buffer + ctx_rd_offset;
assign mem_addr_vld = (state == CHUNK_FILL);

logic [31:0] payload_remainder;
logic [31:0] pad_zero_bytes;
logic [29:0] pad_zero_words;
logic [2:0]  end_word_padding;
logic [31:0] end_word_mask;
logic [31:0] end_word;
logic [31:0] zero_pad_limit;
logic mem_data_full_word;
always_comb begin
  payload_remainder = (ctx_out.length[34:3] % sha256_pkg::BYTES_IN_CHUNK);
  mem_data_full_word = ctx_rd_offset_d1 < ctx_out.length[34:3];
  if(payload_remainder <= sha256_pkg::BYTES_IN_CHUNK - sha256_pkg::MANDATORY_PADDING_BYTES) begin
    pad_zero_bytes = sha256_pkg::BYTES_IN_CHUNK - payload_remainder - sha256_pkg::MANDATORY_PADDING_BYTES;
  end else begin
    pad_zero_bytes = (sha256_pkg::BYTES_IN_CHUNK * 2) - payload_remainder - sha256_pkg::MANDATORY_PADDING_BYTES;
  end
  pad_zero_words = pad_zero_bytes[31:2];
  zero_pad_limit = ctx_out.length[34:3] + end_word_padding + (pad_zero_words * sha256_pkg::MEM_WORD_BYTES);
  case(ctx_out.length[34:3] % sha256_pkg::MEM_WORD_BYTES)
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
  end else if(state == IDLE || state == CTX_LOAD) begin
    nca_state = DATA;
  end else if(state == CHUNK_READY) begin
    nca_state = ca_state;
  end else begin
    case (ca_state)
      DATA:     nca_state = mem_data_full_word? DATA : END_WORD;
      END_WORD: nca_state = pad_zero_words > 0? ZERO_PAD : LENGTH_1;
      ZERO_PAD: nca_state = (ctx_rd_offset + sha256_pkg::MEM_WORD_BYTES < zero_pad_limit)? ZERO_PAD : LENGTH_1;
      LENGTH_1: nca_state = LENGTH_2;
      LENGTH_2: nca_state = DONE;
      DONE:     nca_state = DONE; // Catch here until "reset"
      default : nca_state = DATA;
    endcase
  end
end

always_ff @(posedge clk) begin
  if(rst) begin
    ca_state <= DATA;
  end else begin
    ca_state <= nca_state;
  end
end


always_ff @(posedge clk) begin
  if(mem_data_vld) begin
    case (ca_state)
      DATA:     chunk_out[chunk_rd_offset_d1[31:2]] <= mem_data;
      END_WORD: chunk_out[chunk_rd_offset_d1[31:2]] <= mem_data & end_word_mask | end_word;
      ZERO_PAD: chunk_out[chunk_rd_offset_d1[31:2]] <= 32'h0000_0000;
      LENGTH_1: chunk_out[chunk_rd_offset_d1[31:2]] <= ctx_out.length[63:32];
      LENGTH_2: chunk_out[chunk_rd_offset_d1[31:2]] <= ctx_out.length[31:0];
      default : ;
    endcase
  end else begin
    chunk_out <= chunk_out;
  end
end


endmodule