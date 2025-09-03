`timescale 1ns / 1ps

module fbindct(
  parameter NUM_SIZE = 8;
  parameter FP_SIZE = 32;
)(
  input clk,
  input rst,
  input signed [NUM_SIZE-1:0] x_in [7:0],
  output signed [FP_SIZE-1:0] x_out [7:0]
);

reg [NUM_SIZE-1:0] x_in_reg;
reg [FP_SIZE-1:0] x_out_reg;

//TODO: Fix Readability, Generate block for padding, figure out if pipeling is
//better for resourse utilization, speed, power utilization

// Stage 1
generate
  if(NUM_SIZE == 8) begin
    // Sign extend 8 bits to 20 bits
    wire signed [19:0] a0_0, a1_0, a2_0, a3_0, a4_0, a5_0, a6_0, a7_0;
    assign a0_0 = x_in_reg[0] + x_in_reg[7];
    assign a1_0 = x_in_reg[1] + x_in_reg[6];
    assign a2_0 = x_in_reg[2] + x_in_reg[5];
    assign a3_0 = x_in_reg[3] + x_in_reg[4];
    assign a4_0 = x_in_reg[3] - x_in_reg[4];
    assign a5_0 = x_in_reg[2] - x_in_reg[5];
    assign a6_0 = x_in_reg[1] - x_in_reg[6];
    assign a7_0 = x_in_reg[0] - x_in_reg[7];

    // Append at LSB 12 bits to achieve Q19.12 + 1 sign bit
    wire signed [31:0] a0, a1, a2, a3, a4, a5, a6, a7;
    assign a0 = {a0_0,12'b0};
    assign a1 = {a1_0,12'b0};
    assign a2 = {a2_0,12'b0};
    assign a3 = {a3_0,12'b0};
    assign a4 = {a4_0,12'b0};
    assign a5 = {a5_0,12'b0};
    assign a6 = {a6_0,12'b0};
    assign a7 = {a7_0,12'b0};
  end else if(NUM_SIZE == 32) begin
    wire signed [FP_SIZE-1:0] a0, a1, a2, a3, a4, a5, a6, a7;
    assign a0 = x_in_reg[0] + x_in_reg[7];
    assign a1 = x_in_reg[1] + x_in_reg[6];
    assign a2 = x_in_reg[2] + x_in_reg[5];
    assign a3 = x_in_reg[3] + x_in_reg[4];
    assign a4 = x_in_reg[3] - x_in_reg[4];
    assign a5 = x_in_reg[2] - x_in_reg[5];
    assign a6 = x_in_reg[1] - x_in_reg[6];
    assign a7 = x_in_reg[0] - x_in_reg[7];

  end
endgenerate
 

// Stage 2 
wire signed [31:0] b0, b1;
assign b0 = (a5>>>2) + (a5>>>3) + a6;
assign b1 = (b0>>>1) + (b0>>>3) - a5;

// Stage 3
wire signed [31:0] c0, c1, c2, c3, c4, c5, c6, c7;
assign c0 = a0 + a3;
assign c1 = a2 + a1;
assign c2 = a1 - a2;
assign c3 = a0 - a3;
assign c4 = a4 + b1;
assign c5 = a4 - b1;
assign c6 = a7 - b0;
assign c7 = b0 + a7;

// Stage 4
wire signed [31:0] d0, d1, d2, d3, d4, d5, d6;
assign d0 = c0 + c1;
assign d1 = (d0 >>> 1) - c1;
assign d2 = c2 - ((c3>>>2) + (c3>>>3));
assign d3 = c3 + (d2>>>2) + (d2>>>3);
assign d4 = c4 - (c7>>>3);
assign d5 = c5 + (c6>>>1) + (c6>>>2) + (c6>>>3);
assign d6 = c6 - (d5 >>> 1); 

assign x_out[0] = d0;
assign x_out[1] = c7;
assign x_out[2] = d3;
assign x_out[3] = d6;
assign x_out[4] = d1;
assign x_out[5] = d5;
assign x_out[6] = d2;
assign x_out[7] = d4;

always@(posedge clk)begin
  if(rst) begin
    x_in_reg <= 0;
    x_out_reg <= 0;
  end else begin
    x_in_reg <= x_in;
    x_out_reg <= x_out;
  end
end

endmodule
