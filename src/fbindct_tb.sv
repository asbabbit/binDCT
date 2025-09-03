// Timescale directive for simulation delays
`timescale 1ns / 1ps

// Testbench module
module fbindct_tb;

// 1. Declare signals to connect to the DUT (Device Under Test)
// Regs for inputs
reg clk;
reg srstn;
reg signed [7:0] x_in_tb [0:7];

// Wires for outputs
wire signed [31:0] x_out_tb [0:7];

// 2. Instantiate the module you want to test
fbindct dut (
  .clk      (clk),
  .srstn    (srstn),
  .x_in     (x_in_tb),
  .x_out    (x_out_tb)
);

// 3. Provide the test stimulus
initial begin
  // Initialize inputs
  clk   = 0;  // Not used in combinational logic, but good practice
  srstn = 1;  // De-assert reset

  // Assign the specified input vector
  // Decimal values: {64, 32, 24, 28, 40, 34, 26, 12}
  x_in_tb[0] = 8'd64;
  x_in_tb[1] = 8'd32;
  x_in_tb[2] = 8'd24;
  x_in_tb[3] = 8'd28;
  x_in_tb[4] = 8'd40;
  x_in_tb[5] = 8'd34;
  x_in_tb[6] = 8'd26;
  x_in_tb[7] = 8'd12;
  
  // Wait for combinational logic to propagate
  #10;

  // Display the results
  $display("Simulation Start: Applying input vector.");
  $display("-----------------------------------------");
  $display("Inputs (x_in):");
  $display("x_in_reg\[0]=%b, x_in_reg\[1]=%b, x_in_reg\[2]=%b, x_in_reg\[3]=%b", x_in_tb[0], x_in_tb[1], x_in_tb[2], x_in_tb[3]);
  $display("x_in_reg\[4]=%b, x_in_reg\[5]=%b, x_in_reg\[6]=%b, x_in_reg\[7]=%b", x_in_tb[4], x_in_tb[5], x_in_tb[6], x_in_tb[7]);
  $display("-----------------------------------------");

  $display("Intermediate Signals (from inside the 'fbindct' module):");
  $display("-----------------------------------------");
  $display("Stage 1:");
  $display("a0 = %b, a1 = %b, a2 = %b, a3 = %b", dut.a0, dut.a1, dut.a2, dut.a3);
  $display("a4 = %b, a5 = %b, a6 = %b, a7 = %b", dut.a4, dut.a5, dut.a6, dut.a7);
  $display("-----------------------------------------");
  $display("Stage 2:");
  $display("b0 = %b, b1 = %b", dut.b0, dut.b1);
  $display("-----------------------------------------");
  $display("Stage 3:");
  $display("c0 = %b, c1 = %b, c2 = %b, c3 = %b", dut.c0, dut.c1, dut.c2, dut.c3);
  $display("c4 = %b, c5 = %b, c6 = %b, c7 = %b", dut.c4, dut.c5, dut.c6, dut.c7);
  $display("-----------------------------------------");
  $display("Stage 4:");
  $display("d0 = %b, d1 = %b, d2 = %b, d3 = %b", dut.d0, dut.d1, dut.d2, dut.d3);
  $display("d4 = %b, d5 = %b, d6 = %b", dut.d4, dut.d5, dut.d6);
  $display("-----------------------------------------");

  $display("Outputs (x_out):");
  // Use a loop to print all outputs
  for (int i = 0; i < 8; i=i+1) begin
    $display("x_out[%0d] = %b", i, x_out_tb[i]);
  end
  
  $display("-----------------------------------------");
  $display("Simulation Finished.");

  // End the simulation
  $finish;
end

endmodule
