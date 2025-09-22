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
  input signed [8*IN_WIDTH-1:0]                x_in,        // x_in as single port [x_in_7, x_in_6, ..., x_in_1, x_in_0]
  input                                        ready_in,    // ready_in is asserted by next mdoule once next module can accept new data
  input                                        load,        // load is asserted once 1 partition is wanting to be sent by previous module

  output                                       valid_out,   // valid_out is asserted once 4 stage pipeline is completed 
  output signed [8*OUT_WIDTH-1:0]              y_out        // y_out as single port [y_out_7, y_out_6, ..., y_out_1, y_out_0]
);

// States
parameter [1:0] IDLE = 2'b00;
parameter [1:0] WAIT = 2'b01;
parameter [1:0] SEND = 2'b10;
reg [1:0] state;

// Stages
parameter [1:0] STAGE1 = 2'b00;
parameter [1:0] STAGE2 = 2'b01;
parameter [1:0] STAGE3 = 2'b10;
parameter [1:0] STAGE4 = 2'b11;
reg [1:0] stage;

// FSM logic
reg signed [IN_WIDTH-1:0] x_reg_0, x_reg_1, x_reg_2, x_reg_3, x_reg_4, x_reg_5, x_reg_6, x_reg_7;
reg done;

assign valid_out = done;

always @(posedge clk) begin : state_machine
  if (rst) begin
    state <= IDLE;
    stage <= STAGE1;
    done <= 1'b0;
    x_reg_0 <= 0;
    x_reg_1 <= 0;
    x_reg_2 <= 0;
    x_reg_3 <= 0;
    x_reg_4 <= 0;
    x_reg_5 <= 0;
    x_reg_6 <= 0;
    x_reg_7 <= 0;
  end else begin
    case (state)
      IDLE: begin
        if(load) begin
          x_reg_0 <= x_in[1*IN_WIDTH-1:0*IN_WIDTH];
          x_reg_1 <= x_in[2*IN_WIDTH-1:1*IN_WIDTH];
          x_reg_2 <= x_in[3*IN_WIDTH-1:2*IN_WIDTH];
          x_reg_3 <= x_in[4*IN_WIDTH-1:3*IN_WIDTH];
          x_reg_4 <= x_in[5*IN_WIDTH-1:4*IN_WIDTH];
          x_reg_5 <= x_in[6*IN_WIDTH-1:5*IN_WIDTH];
          x_reg_6 <= x_in[7*IN_WIDTH-1:6*IN_WIDTH];
          x_reg_7 <= x_in[8*IN_WIDTH-1:7*IN_WIDTH];
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
            done <= 1'b1;
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
      default: state <= IDLE;
    endcase
  end
end

// Stage 1
reg signed [INTER_WIDTH-1:0] a_reg_0, a_reg_1, a_reg_2, a_reg_3, a_reg_4, a_reg_5, a_reg_6, a_reg_7;
wire signed [INTER_WIDTH-1:0] a_wire_0, a_wire_1, a_wire_2, a_wire_3, a_wire_4, a_wire_5, a_wire_6, a_wire_7;
 
// Even stage butterfly operations
assign a_wire_0 = (x_reg_0 + x_reg_7) << FRAC_BITS;
assign a_wire_1 = (x_reg_1 + x_reg_6) << FRAC_BITS;
assign a_wire_2 = (x_reg_2 + x_reg_5) << FRAC_BITS;
assign a_wire_3 = (x_reg_3 + x_reg_4) << FRAC_BITS;
// Odd stage butterfly operations 
assign a_wire_4 = (x_reg_3 - x_reg_4) << FRAC_BITS;
assign a_wire_5 = (x_reg_2 - x_reg_5) << FRAC_BITS;
assign a_wire_6 = (x_reg_1 - x_reg_6) << FRAC_BITS;
assign a_wire_7 = (x_reg_0 - x_reg_7) << FRAC_BITS;

always @(posedge clk) begin : stage1
  if(rst) begin
    a_reg_0 <= 0;
    a_reg_1 <= 0;
    a_reg_2 <= 0;
    a_reg_3 <= 0;
    a_reg_4 <= 0;
    a_reg_5 <= 0;
    a_reg_6 <= 0;
    a_reg_7 <= 0;
  end else if(stage == STAGE1) begin
    a_reg_0 <= a_wire_0;
    a_reg_1 <= a_wire_1;
    a_reg_2 <= a_wire_2;
    a_reg_3 <= a_wire_3;
    a_reg_4 <= a_wire_4;
    a_reg_5 <= a_wire_5;
    a_reg_6 <= a_wire_6;
    a_reg_7 <= a_wire_7;
  end
end

// Stage 2 
reg signed [INTER_WIDTH-1:0] b_reg_0, b_reg_1;
wire signed [INTER_WIDTH-1:0] b_wire_0, b_wire_1;

assign b_wire_0 = (a_reg_5>>>2) + (a_reg_5>>>3) + a_reg_6;            // 0.375*a5 + a6
assign b_wire_1 = (b_wire_0>>>1) + (b_wire_0>>>3) - a_reg_5;          // 0.625*b0 - a5

always @(posedge clk) begin : stage2
  if(rst) begin
    b_reg_0 <= 0;
    b_reg_1 <= 0;
  end else if(stage == STAGE2) begin
    b_reg_0 <= b_wire_0;
    b_reg_1 <= b_wire_1;
  end
end

// Stage 3
reg signed [INTER_WIDTH-1:0] c_reg_0, c_reg_1, c_reg_2, c_reg_3, c_reg_4, c_reg_5, c_reg_6, c_reg_7;
wire signed [INTER_WIDTH-1:0] c_wire_0, c_wire_1, c_wire_2, c_wire_3, c_wire_4, c_wire_5, c_wire_6, c_wire_7;

// More even and odd butterfly operations
assign c_wire_0 = a_reg_0 + a_reg_3;
assign c_wire_1 = a_reg_2 + a_reg_1;
assign c_wire_2 = a_reg_1 - a_reg_2;
assign c_wire_3 = a_reg_0 - a_reg_3;
assign c_wire_4 = a_reg_4 + b_reg_1;
assign c_wire_5 = a_reg_4 - b_reg_1;
assign c_wire_6 = a_reg_7 - b_reg_0;
assign c_wire_7 = b_reg_0 + a_reg_7;

always @(posedge clk) begin : stage3 
  if(rst) begin
    c_reg_0 <= 0;
    c_reg_1 <= 0;
    c_reg_2 <= 0;
    c_reg_3 <= 0;
    c_reg_4 <= 0;
    c_reg_5 <= 0;
    c_reg_6 <= 0;
    c_reg_7 <= 0;
  end else if(stage == STAGE3) begin
    c_reg_0 <= c_wire_0;
    c_reg_1 <= c_wire_1;
    c_reg_2 <= c_wire_2;
    c_reg_3 <= c_wire_3;
    c_reg_4 <= c_wire_4;
    c_reg_5 <= c_wire_5;
    c_reg_6 <= c_wire_6;
    c_reg_7 <= c_wire_7;
  end
end

// Stage 4
reg signed [INTER_WIDTH-1:0] d_reg_0, d_reg_1, d_reg_2, d_reg_3, d_reg_4, d_reg_5, d_reg_6;
wire signed [INTER_WIDTH-1:0] d_wire_0, d_wire_1, d_wire_2, d_wire_3, d_wire_4, d_wire_5, d_wire_6;

assign d_wire_0 = c_reg_0 + c_reg_1;                                         // c0 + c1
assign d_wire_1 = (d_wire_0>>>1) - c_reg_1;                                  // 0.5*d0 - c1
assign d_wire_2 = c_reg_2 - ((c_reg_3>>>2) + (c_reg_3>>>3));                // c2 - 0.375*c3 
assign d_wire_3 = c_reg_3 + (d_wire_2>>>2) + (d_wire_2>>>3);                // c3 + 0.375*d2 
assign d_wire_4 = c_reg_4 - (c_reg_7>>>3);                                   // c4 - 0.125*c7
assign d_wire_5 = c_reg_5 + (c_reg_6>>>1) + (c_reg_6>>>2) + (c_reg_6>>>3); // c5 + 0.875*c6
assign d_wire_6 = c_reg_6 - (d_wire_5>>>1);                                  // c6 - 0.5*d5

always @(posedge clk) begin : stage4 
  if(rst) begin
    d_reg_0 <= 0;
    d_reg_1 <= 0;
    d_reg_2 <= 0;
    d_reg_3 <= 0;
    d_reg_4 <= 0;
    d_reg_5 <= 0;
    d_reg_6 <= 0;
  end else if(stage == STAGE4) begin
    d_reg_0 <= d_wire_0;
    d_reg_1 <= d_wire_1;
    d_reg_2 <= d_wire_2;
    d_reg_3 <= d_wire_3;
    d_reg_4 <= d_wire_4;
    d_reg_5 <= d_wire_5;
    d_reg_6 <= d_wire_6;
  end
end

// Delay c_reg_7 by one clock cycle to arrive at same time as d_reg
reg [INTER_WIDTH-1:0] c_reg7_delay;

always @(posedge clk) begin : delay_c_reg
  if (rst) begin
    c_reg7_delay <= 1'b0;
  end else begin
    c_reg7_delay <= c_reg_7;
  end
end

// y is purely a combinational output for the d registers
assign y_out[1*OUT_WIDTH-1:0*OUT_WIDTH] = d_reg_0;
assign y_out[2*OUT_WIDTH-1:1*OUT_WIDTH] = c_reg7_delay;
assign y_out[3*OUT_WIDTH-1:2*OUT_WIDTH] = d_reg_3;
assign y_out[4*OUT_WIDTH-1:3*OUT_WIDTH] = d_reg_6;
assign y_out[5*OUT_WIDTH-1:4*OUT_WIDTH] = d_reg_1;
assign y_out[6*OUT_WIDTH-1:5*OUT_WIDTH] = d_reg_5;
assign y_out[7*OUT_WIDTH-1:6*OUT_WIDTH] = d_reg_2;
assign y_out[8*OUT_WIDTH-1:7*OUT_WIDTH] = d_reg_4;

endmodule