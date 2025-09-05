`timescale 1ns / 1ps
module fbindct_32bit #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32,
  parameter FRAC_BITS = 12
)(
  input                                        clk,
  input                                        rst,
  input signed [IN_WIDTH-1:0]                  x_in [0:7],
  input                                        valid_in,

  output                                       valid_out,
  output signed [OUT_WIDTH-1:0]                y_out[0:7]
);

// State machine
logic [2:0] state;
typedef enum logic [2:0] {
  STAGE0 = 3'b000,
  STAGE1 = 3'b001, 
  STAGE2 = 3'b010,
  STAGE3 = 3'b011,
  STAGE4 = 3'b100
} state_t;

state_t state, next_state;

always_ff @(posedge clk) begin : state_machine_seq 
  if(rst) begin
    state <= 0;
  end else begin
    state <= next_state;
  end
end

always_comb begin : state_machine_comb
  case (state)
    STAGE0: next_state = (valid_in) ? STAGE1 : STAGE0;
    STAGE1: next_state = STAGE2;
    STAGE2: next_state = STAGE3;
    STAGE3: next_state = STAGE4;
    STAGE4: next_state = STAGE0;
    default: next_state = STAGE0;
  endcase
end


// Stage 0
signed logic [IN_WIDTH-1:0] x_reg [0:7];

always_ff @(posedge clk) begin : stage0
  if (rst) begin
    for (int i = 0; i<8; i++) begin
      x_reg[i] <= 0;
    end
  end else if(valid_in && state == STAGE0) begin
    x_reg <= x_in;
  end
end

// Stage 1
logic signed [OUT_WIDTH-1:0] a_reg [0:7];
logic signed [OUT_WIDTH-1:0] a_wire [0:7];

// Even stage butterfly operations
assign a_wire[0] = x_reg[0] + x_reg[7];
assign a_wire[1] = x_reg[1] + x_reg[6];
assign a_wire[2] = x_reg[2] + x_reg[5];
assign a_wire[3] = x_reg[3] + x_reg[4];
// Odd stage butterfly operations 
assign a_wire[4] = x_reg[3] - x_reg[4];
assign a_wire[5] = x_reg[2] - x_reg[5];
assign a_wire[6] = x_reg[1] - x_reg[6];
assign a_wire[7] = x_reg[0] - x_reg[7];

always_ff @(posedge clk) begin : stage1
  if(rst) begin
    for (int i = 0; i<8; i++) begin
      a_reg[i] <= 0;
    end
  end else if(state == STAGE1) begin
    a_reg <= a_wire;
  end
end

// Stage 2 
logic signed [OUT_WIDTH-1:0] b_reg [0:1];
logic signed [OUT_WIDTH-1:0] b_wire [0:1];

assign b_wire[0] = (a_reg[5]>>>2) + (a_reg[5]>>>3) + a_reg[6];            // 0.375*a5 + a6
assign b_wire[1] = (b_wire[0]>>>1) + (b_wire[0]>>>3) - a_reg[5];          // 0.625*b0 - a5

always_ff @(posedge clk) begin : stage2
  if(rst) begin
    for (int i = 0; i<2; i++) begin
      b_reg[i] <= 0;
    end
  end else if(state == STAGE2) begin
    b_reg <= b_wire;
  end
end

// Stage 3
logic signed [OUT_WIDTH-1:0] c_reg [0:7];
logic signed [OUT_WIDTH-1:0] c_wire [0:7];

// More even and odd butterfly operations
assign c_wire[0] = a_reg[0] + a_reg[3];
assign c_wire[1] = a_reg[2] + a_reg[1];
assign c_wire[2] = a_reg[1] - a_reg[2];
assign c_wire[3] = a_reg[0] - a_reg[3];
assign c_wire[4] = a_reg[4] + b_reg[1];
assign c_wire[5] = a_reg[4] - b_reg[1];
assign c_wire[6] = a_reg[7] - b_reg[0];
assign c_wire[7] = b_reg[0] + a_reg[7];

always_ff @(posedge clk) begin : stage3 
  if(rst) begin
    for (int i = 0; i<8; i++) begin
      c_reg[i] <= 0;
    end
  end else if(state == STAGE3) begin
    c_reg <= c_wire;
  end
end

// Stage 4
logic signed [OUT_WIDTH-1:0] d_reg [0:6];
logic signed [OUT_WIDTH-1:0] d_wire [0:6];

assign d_wire[0] = c_reg[0] + c_reg[1];                                         // c0 + c1
assign d_wire[1] = (d_wire[0]>>>1) - c_reg[1];                                  // 0.5*d0 - c1
assign d_wire[2] = c_reg[2] - ((c_reg[3]>>>2) + (c_reg[3]>>>3));                // c2 - 0.375*c3 
assign d_wire[3] = c_reg[3] + (d_wire[2]>>>2) + (d_wire[2]>>>3);                // c3 + 0.375*d2 
assign d_wire[4] = c_reg[4] - (c_reg[7]>>>3);                                   // c4 - 0.125*c7
assign d_wire[5] = c_reg[5] + (c_reg[6]>>>1) + (c_reg[6]>>>2) + (c_reg[6]>>>3); // c5 + 0.875*c6
assign d_wire[6] = c_reg[6] - (d_wire[5]>>>1);                                  // c6 - 0.5*d5

always_ff @(posedge clk) begin : stage4 
  if(rst) begin
    for (int i = 0; i<7; i++) begin
      d_reg[i] <= 0;
    end
  end else if(state == STAGE4) begin
    d_reg <= d_wire; 
  end
end

// y is purely a combinatorial output for the d registers
assign y_out[0] = d_reg[0];
assign y_out[1] = c_reg[7];
assign y_out[2] = d_reg[3];
assign y_out[3] = d_reg[6];
assign y_out[4] = d_reg[1];
assign y_out[5] = d_reg[5];
assign y_out[6] = d_reg[2];
assign y_out[7] = d_reg[4];

// Delay valid_out by one cycle to arrive at same time as y
logic valid_out_reg;

assign valid_out = valid_out_reg;

always_ff @(posedge clk) begin : delay_valid_out
  if (rst) begin
    valid_out_reg <= 1'b0;
  end else begin
    valid_out_reg <= (state == STAGE4);
  end
end

endmodule
