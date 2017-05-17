package sha256_pkg;

const logic [63:0][31:0]  K = {
  32'hC671_78F2, 32'hBEF9_A3F7, 32'hA450_6CEB, 32'h90BE_FFFA,
  32'h8CC7_0208, 32'h84C8_7814, 32'h78A5_636F, 32'h748F_82EE,
  32'h682E_6FF3, 32'h5B9C_CA4F, 32'h4ED8_AA4A, 32'h391C_0CB3,
  32'h34B0_BCB5, 32'h2748_774C, 32'h1E37_6C08, 32'h19A4_C116,
  32'h106A_A070, 32'hF40E_3585, 32'hD699_0624, 32'hD192_E819,
  32'hC76C_51A3, 32'hC24B_8B70, 32'hA81A_664B, 32'hA2BF_E8A1,
  32'h9272_2C85, 32'h81C2_C92E, 32'h766A_0ABB, 32'h650A_7354,
  32'h5338_0D13, 32'h4D2C_6DFC, 32'h2E1B_2138, 32'h27B7_0A85,
  32'h1429_2967, 32'h06CA_6351, 32'hD5A7_9147, 32'hC6E0_0BF3,
  32'hBF59_7FC7, 32'hB003_27C8, 32'hA831_C66D, 32'h983E_5152,
  32'h76F9_88DA, 32'h5CB0_A9DC, 32'h4A74_84AA, 32'h2DE9_2C6F,
  32'h240C_A1CC, 32'h0FC1_9DC6, 32'hEFBE_4786, 32'hE49B_69C1,
  32'hC19B_F174, 32'h9BDC_06A7, 32'h80DE_B1FE, 32'h72BE_5D74,
  32'h550C_7DC3, 32'h2431_85BE, 32'h1283_5B01, 32'hD807_AA98,
  32'hAB1C_5ED5, 32'h923F_82A4, 32'h59F1_11F1, 32'h3956_C25B,
  32'hE9B5_DBA5, 32'hB5C0_FBCF, 32'h7137_4491, 32'h428A_2F98
};

typedef logic [7:0][31:0] HashState;

const HashState H = {
  32'h6A09_E667,
  32'hBB67_AE85,
  32'h3C6E_F372,
  32'hA54F_F53A,
  32'h510E_527F,
  32'h9B05_688C,
  32'h1F83_D9AB,
  32'h5BE0_CD19
};


typedef enum logic [3:0] {
  RESET,
  IDLE,
  UPDATE,
  DONE
} ShaState;


typedef struct {
  logic [63:0] length;
  HashState state;
  logic [31:0] curlen;
  logic [31:0] buffer;
} ShaContext;

const logic [31:0] NUM_LENGTH_BYTES = 32'd64 / 32'd8;
const logic [31:0] MANDATORY_PADDING_BYTES = 32'd1 + NUM_LENGTH_BYTES;
const logic [31:0] MANDATORY_PADDING_BITS = 32'h8 + NUM_LENGTH_BYTES;
const logic [31:0] MEM_WORD_BYTES = 32'd4;
const logic [31:0] BYTES_IN_CHUNK = 32'd64;
const logic [31:0] MEM_WORDS_PER_CHUNK = (BYTES_IN_CHUNK / MEM_WORD_BYTES);
typedef logic [15:0][31:0] Chunk;

function logic[31:0] rightRotate32(logic [31:0] val, int bits);
  rightRotate32 = (val >> bits) | (val << (32 - bits));
endfunction : rightRotate32

function logic[31:0] rightShift(logic [31:0] val, int bits);
  rightShift = (val >> bits);
endfunction : rightShift

function logic[31:0] gamma0(logic [31:0] val);
  gamma0 = rightRotate32(val, 7) ^ rightRotate32(val, 18) ^ rightShift(val, 3);
endfunction : gamma0

function logic[31:0] gamma1(logic [31:0] val);
  gamma1 = rightRotate32(val, 17) ^ rightRotate32(val, 19) ^ rightShift(val, 10);
endfunction : gamma1

// function HashStateToDigest(HashState state);
//   return HashStateToDigest = {state[0], state[1], state[2], state[3],
//     state[4], state[5], state[6], state[7]};
// endfunction : HashStateToDigest
endpackage