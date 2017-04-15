//`include "sha256_pkg.sv"
import sha256_pkg::*;
module sha256 (
  input clk,
  input rst,

  output logic context_rdy,
  input logic context_vld,
  input sha256_pkg::ShaContext Context,

  output logic buf_data_rdy,
  input logic buf_data_vld,
  input logic [31:0] buf_data
);

logic [3:0] state;

always_ff @(posedge clk) begin : proc_state
  if(rst) begin
    state <= sha256_pkg::RESET;
  end else begin
    case (state)
      sha256_pkg::IDLE:
        state <= context_vld? sha256_pkg::UPDATE : sha256_pkg::IDLE;
      sha256_pkg::UPDATE:
        state <= sha256_pkg::DONE;
      sha256_pkg::DONE:
        state <= sha256_pkg::RESET;
      default:
        state <= sha256_pkg::RESET;
    endcase
  end
end

logic [31:0][7:0] hash_vals;
logic [31:0][63:0] round_consts;

always_ff @(posedge clk) begin : proc_hash_vals
  if(rst) begin
    hash_vals <= {32'h6A09_E667, 32'hBB67_AE85, 32'h3C6E_F372, 32'hA54F_F53A,
                  32'h510E_527F, 32'h9B05_688C, 32'h1F83_D9AB, 32'h5BE0_CD19};
    round_consts <= {32'h428A_2F98, 32'h7137_4491, 32'hB5C0_FBCF, 32'hE9B5_DBA5,
                     32'h3956_C25B, 32'h59F1_11F1, 32'h923F_82A4, 32'hAB1C_5ED5,
                     32'hD807_AA98, 32'h1283_5B01, 32'h2431_85BE, 32'h550C_7DC3,
                     32'h72BE_5D74, 32'h80DE_B1FE, 32'h9BDC_06A7, 32'hC19B_F174,
                     32'hE49B_69C1, 32'hEFBE_4786, 32'h0FC1_9DC6, 32'h240C_A1CC,
                     32'h2DE9_2C6F, 32'h4A74_84AA, 32'h5CB0_A9DC, 32'h76F9_88DA,
                     32'h983E_5152, 32'hA831_C66D, 32'hB003_27C8, 32'hBF59_7FC7,
                     32'hC6E0_0BF3, 32'hD5A7_9147, 32'h06CA_6351, 32'h1429_2967,
                     32'h27B7_0A85, 32'h2E1B_2138, 32'h4D2C_6DFC, 32'h5338_0D13,
                     32'h650A_7354, 32'h766A_0ABB, 32'h81C2_C92E, 32'h9272_2C85,
                     32'hA2BF_E8A1, 32'hA81A_664B, 32'hC24B_8B70, 32'hC76C_51A3,
                     32'hD192_E819, 32'hD699_0624, 32'hF40E_3585, 32'h106A_A070,
                     32'h19A4_C116, 32'h1E37_6C08, 32'h2748_774C, 32'h34B0_BCB5,
                     32'h391C_0CB3, 32'h4ED8_AA4A, 32'h5B9C_CA4F, 32'h682E_6FF3,
                     32'h748F_82EE, 32'h78A5_636F, 32'h84C8_7814, 32'h8CC7_0208,
                     32'h90BE_FFFA, 32'hA450_6CEB, 32'hBEF9_A3F7, 32'hC671_78F2};
end else begin
    hash_vals <= 1;
  end
end

endmodule