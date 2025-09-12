// Testbench with unpacked arrays
`timescale 1ns / 1ps
module fbindct_tb;

  // Parameters to match DUT
  parameter IN_WIDTH = 8;
  parameter INT_BITS = 4;
  parameter FRAC_BITS = 6;
  parameter INTER_WIDTH = IN_WIDTH + INT_BITS + FRAC_BITS;
  
  // Clock period
  parameter CLK_PERIOD = 10; // 10ns = 100MHz
  
  // Declare signals to connect to the DUT
  logic clk;
  logic rst;
  logic signed [IN_WIDTH-1:0] x_in_tb [7:0];
  logic valid_in_tb;
  
  logic valid_out_tb;
  logic signed [INTER_WIDTH-1:0] y_out_tb [7:0];
  
  // Instantiate the module
  fbindct_8bit #(
      .IN_WIDTH(IN_WIDTH),
      .INT_BITS(INT_BITS),
      .FRAC_BITS(FRAC_BITS)
  ) dut (
      .clk(clk),
      .rst(rst),
      .x_in(x_in_tb),
      .valid_in(valid_in_tb),
      .valid_out(valid_out_tb),
      .y_out(y_out_tb)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  // Test stimulus
  initial begin
    // Initialize signals
    rst = 1;
    valid_in_tb = 0;
    
    // Initialize input array
    for (int i = 0; i < 8; i++) begin
      x_in_tb[i] = 0;
    end
    
    // Wait for a few clock cycles
    repeat(3) @(posedge clk);
    
    // Release reset
    rst = 0;
    @(posedge clk);
    
    // Test case 1: Load some test data
    $display("Starting test...");
    
    valid_in_tb = 1;
    x_in_tb[0] = 8'sh10;  // 16 in decimal
    x_in_tb[1] = 8'sh20;  // 32 in decimal  
    x_in_tb[2] = 8'sh30;  // 48 in decimal
    x_in_tb[3] = 8'sh40;  // 64 in decimal
    x_in_tb[4] = 8'shF0;  // -16 in decimal (signed)
    x_in_tb[5] = 8'shE0;  // -32 in decimal (signed)
    x_in_tb[6] = 8'shD0;  // -48 in decimal (signed)
    x_in_tb[7] = 8'shC0;  // -64 in decimal (signed)
    
    @(posedge clk);
    valid_in_tb = 0;
    
    // Wait for valid output
    @(posedge valid_out_tb);
    
    // Display results
    $display("Input values:");
    for (int i = 0; i < 8; i++) begin
      $display("  x_in[%0d] = %d (0x%h)", i, $signed(x_in_tb[i]), x_in_tb[i]);
    end
    
    $display("Output values:");
    for (int i = 0; i < 8; i++) begin
      $display("  y_out[%0d] = %d (0x%h)", i, $signed(y_out_tb[i]), y_out_tb[i]);
    end
    
    // Wait a few more cycles
    repeat(5) @(posedge clk);
    
    $display("Test completed successfully!");
    $finish;
  end
  
  // Optional: Monitor for debugging
  initial begin
    $monitor("Time=%t, rst=%b, valid_in=%b, valid_out=%b", 
             $time, rst, valid_in_tb, valid_out_tb);
  end

endmodule
