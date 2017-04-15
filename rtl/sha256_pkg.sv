package sha256_pkg;
typedef struct {
  logic [63:0] length;
  logic [31:0] state [7:0];
  logic [31:0] curlen;
  logic [7:0]  buffer [63:0];
} ShaContext;

typedef enum logic [3:0] {
  RESET,
  IDLE,
  UPDATE,
  DONE
} ShaState;
endpackage