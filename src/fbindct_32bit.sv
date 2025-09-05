`timescale 1ns / 1ps
//TODO: Seperate combinational from sequential, add specific always_ff block
//for the state machine
module fbindct_32bit #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32,
  parameter INT_BITS = 20,
  parameter FRAC_BITS = 12
)(
  input                                        clk,
  input                                        rst,
  input signed [IN_WIDTH-1:0]                  x_in [0:7],
  input                                        valid_in,

  output                                       valid_out,
  output signed [OUT_WIDTH-1:0]                y_out[0:7]
);

logic [2:0] state;
parameter [2:0] STAGE0 = 3'b000
                STAGE1 = 3'b001, 
                STAGE2 = 3'b010,
                STAGE3 = 3'b011,
                STAGE4 = 3'b100;

// Stage 0
signed logic [IN_WIDTH-1:0] x_reg [0:7];
always_ff @(posedge clk) begin : stage0
  if (rst) begin
    state <= STAGE0;
    for (int i = 0; i<8; i++) begin
      x_reg[i] <= 0;
    end
  end else if(valid_in && state == STAGE0) begin
    x_reg <= x_in;
    state <=STAGE1;
  end
end

// Stage 1
logic signed [OUT_WIDTH-1:0] a_reg [0:7];
always_ff @(posedge clk) begin : stage1
  if(rst) begin
    for (int i = 0; i<8; i++) begin
      a_reg[i] <= 0;
    end
  end else if(state == STAGE1) begin
    a_reg[0] <= x_reg[0] + x_reg[7];
    a_reg[1] <= x_reg[1] + x_reg[6];
    a_reg[2] <= x_reg[2] + x_reg[5];
    a_reg[3] <= x_reg[3] + x_reg[4];
    a_reg[4] <= x_reg[3] - x_reg[4];
    a_reg[5] <= x_reg[2] - x_reg[5];
    a_reg[6] <= x_reg[1] - x_reg[6];
    a_reg[7] <= x_reg[0] - x_reg[7];
    state <= STAGE2;
  end
end

// Stage 2 
logic signed [OUT_WIDTH-1:0] b_reg [0:1];
always_ff @(posedge clk) begin : stage2
  if(rst) begin
    for (int i = 0; i<2; i++) begin
      b_reg[i] <= 0;
    end
  end else if(state == STAGE2) begin
    b_reg[0] <= (a_reg[5]>>>2) + (a_reg[5]>>>3) + a_reg[6];
    b_reg[1] <= (b_reg[0]>>>1) + (b_reg[0]>>>3) - a_reg[5];
    state <= STAGE3;
  end
end

// Stage 3
logic signed [OUT_WIDTH-1:0] c_reg [0:7];
always_ff @(posedge clk) begin : stage3 
  if(rst) begin
    for (int i = 0; i<8; i++) begin
      c_reg[i] <= 0;
    end
  end else if(state == STAGE3) begin
    c_reg[0] <= a_reg[0] + a_reg[3];
    c_reg[1] <= a_reg[2] + a_reg[1];
    c_reg[2] <= a_reg[1] - a_reg[2];
    c_reg[3] <= a_reg[0] - a_reg[3];
    c_reg[4] <= a_reg[4] + b_reg[1];
    c_reg[5] <= a_reg[4] - b_reg[1];
    c_reg[6] <= a_reg[7] - b_reg[0];
    c_reg[7] <= b_reg[0] + a_reg[7];
    state <= STAGE4;
  end
end

// Stage 4
logic done;
logic signed [OUT_WIDTH-1:0] d_reg [0:6];
always_ff @(posedge clk) begin : stage4 
  if(rst) begin
    for (int i = 0; i<7; i++) begin
      d_reg[i] <= 0;
    end
  end else if(state == STAGE4) begin
    d_reg[0] <= c_reg[0] + c_reg[1];
    d_reg[1] <= (d_reg[0]>>>1) - c_reg[1];
    d_reg[2] <= c_reg[2] - ((c_reg[3]>>>2) + (c_reg[3]>>>3));
    d_reg[3] <= c_reg[3] + (d_reg[2]>>>2) + (d_reg[2]>>>3);
    d_reg[4] <= c_reg[4] - (c_reg[7]>>>3);
    d_reg[5] <= c_reg[5] + (c_reg[6]>>>1) + (c_reg[6]>>>2) + (c_reg[6]>>>3);
    d_reg[6] <= c_reg[6] - (d_reg[5]>>>1);
    state <= STAGE0;
    done <= 1'b1;
  end
end

assign y_out[0] = d_reg[0];
assign y_out[1] = c_reg[7];
assign y_out[2] = d_reg[3];
assign y_out[3] = d_reg[6];
assign y_out[4] = d_reg[1];
assign y_out[5] = d_reg[5];
assign y_out[6] = d_reg[2];
assign y_out[7] = d_reg[4];

endmodule
