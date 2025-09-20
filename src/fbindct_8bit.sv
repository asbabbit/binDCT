`timescale 1ns / 1ps
module fbindct_8bit #(
  parameter IN_WIDTH = 8,                                 // Data input size for Y,Cb,Cr values
  parameter INT_BITS = 6,                                 // Bits needed to prevent overflow
  parameter FRAC_BITS = 6,                                // Bits needed for shifting
  parameter INTER_WIDTH = IN_WIDTH + INT_BITS + FRAC_BITS,// Intermediate width of wires
  parameter OUT_WIDTH = 20                                // Output width may need shortening due to hardware constraints
)(
  input                                        clk,
  input                                        rst,
  input signed [IN_WIDTH-1:0]                  x_in [7:0],      // x_in is 1/8th partition of 8x8 block
  input                                        ready_in,        // ready_in is asserted by next mdoule once next module can accept new data
  input                                        load,            // load is asserted once 1 partition is wanting to be sent by previous module

  output                                       valid_out,       // valid_out is asserted once 4 stage pipeline is completed 
  output signed [OUT_WIDTH-1:0]                y_out [7:0]      // y_out is the 1DCT output on 1/8th of 8x8 block
);

// States
typedef enum logic [1:0] {
  IDLE,
  WAIT,
  SEND
} state_t;
state_t state;

// Stages
typedef enum logic [1:0] {
  STAGE1 = 2'b00,
  STAGE2 = 2'b01, 
  STAGE3 = 2'b10,
  STAGE4 = 2'b11
} stage_t;
stage_t stage;

// FSM logic
logic signed [IN_WIDTH-1:0] x_reg [0:7];
logic done;

assign valid_out = done;

always_ff @(posedge clk) begin : state_machine
  if (rst) begin
    state <= IDLE;
    stage <= STAGE1;
    done <= 1'b0;
    for (int i = 0; i<8; i++) begin
      x_reg[i] <= 0;
    end
  end else begin
    case (state)
      IDLE: begin
        if(load) begin
          x_reg <= x_in;
          state <= WAIT;
        end
      end
      WAIT: begin
        case (stage)
          STAGE1: begin 
            stage <= STAGE2;
            done <= 1'b0;
          end
          STAGE2: stage <= STAGE3;
          STAGE3: stage <= STAGE4;
          STAGE4: begin 
            state <= SEND;
            stage <= STAGE1;
            done <=1'b1;
          end
          default : begin 
            stage <= STAGE1;
          end
        endcase
      end
      SEND: begin
        if(ready_in) begin
          state <= IDLE;
          done <= 1'b0;
        end
      end
      default :  state <= IDLE;
    endcase
  end
end

// Stage 1
logic signed [INTER_WIDTH-1:0] a_reg [0:7];
logic signed [INTER_WIDTH-1:0] a_wire [0:7];
 
// Even stage butterfly operations
assign a_wire[0] = (x_reg[0] + x_reg[7]) << FRAC_BITS;
assign a_wire[1] = (x_reg[1] + x_reg[6]) << FRAC_BITS;
assign a_wire[2] = (x_reg[2] + x_reg[5]) << FRAC_BITS;
assign a_wire[3] = (x_reg[3] + x_reg[4]) << FRAC_BITS;
// Odd stage butterfly operations 
assign a_wire[4] = (x_reg[3] - x_reg[4]) << FRAC_BITS;
assign a_wire[5] = (x_reg[2] - x_reg[5]) << FRAC_BITS;
assign a_wire[6] = (x_reg[1] - x_reg[6]) << FRAC_BITS;
assign a_wire[7] = (x_reg[0] - x_reg[7]) << FRAC_BITS;

always_ff @(posedge clk) begin : stage1
  if(rst) begin
    for (int i = 0; i<8; i++) begin
      a_reg[i] <= 0;
    end
  end else if(stage == STAGE1) begin
    a_reg <= a_wire;
  end
end

// Stage 2 
logic signed [INTER_WIDTH-1:0] b_reg [0:1];
logic signed [INTER_WIDTH-1:0] b_wire [0:1];

assign b_wire[0] = (a_reg[5]>>>2) + (a_reg[5]>>>3) + a_reg[6];            // 0.375*a5 + a6
assign b_wire[1] = (b_wire[0]>>>1) + (b_wire[0]>>>3) - a_reg[5];          // 0.625*b0 - a5

always_ff @(posedge clk) begin : stage2
  if(rst) begin
    for (int i = 0; i<2; i++) begin
      b_reg[i] <= 0;
    end
  end else if(stage == STAGE2) begin
    b_reg <= b_wire;
  end
end

// Stage 3
logic signed [INTER_WIDTH-1:0] c_reg [0:7];
logic signed [INTER_WIDTH-1:0] c_wire [0:7];

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
  end else if(stage == STAGE3) begin
    c_reg <= c_wire;
  end
end

// Stage 4
logic signed [INTER_WIDTH-1:0] d_reg [0:6];
logic signed [INTER_WIDTH-1:0] d_wire [0:6];

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
  end else if(stage == STAGE4) begin
    d_reg <= d_wire; 
  end
end

// Delay c_reg[7] by one clock cycle to arrive at same time as d_reg
logic [INTER_WIDTH-1:0] c_reg7_delay;

always_ff @(posedge clk) begin : delay_c_reg
  if (rst) begin
    c_reg7_delay <= 1'b0;
  end else begin
    c_reg7_delay <= c_reg[7];
  end
end

// y is purely a combinational output for the d registers
assign y_out[0] = d_reg[0];
assign y_out[1] = c_reg7_delay;
assign y_out[2] = d_reg[3];
assign y_out[3] = d_reg[6];
assign y_out[4] = d_reg[1];
assign y_out[5] = d_reg[5];
assign y_out[6] = d_reg[2];
assign y_out[7] = d_reg[4];

endmodule
