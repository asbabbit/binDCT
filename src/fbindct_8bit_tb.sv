`timescale 1ns / 1ps

module fbindct_8bit_tb;

  // Parameters
  parameter IN_WIDTH = 8;
  parameter INT_BITS = 6;
  parameter FRAC_BITS = 6;
  parameter OUT_WIDTH = 20;
  parameter CLK_PERIOD = 10; // 10ns = 100MHz

  // Signals
  logic clk;
  logic rst;
  logic signed [IN_WIDTH-1:0] x_in [7:0];
  logic ready_in;
  logic load;
  logic valid_out;
  logic signed [OUT_WIDTH-1:0] y_out [7:0];

  // State and stage tracking for monitoring
  logic [1:0] prev_state, prev_stage;

  // Instantiate DUT
  fbindct_8bit #(
      .IN_WIDTH(IN_WIDTH),
      .INT_BITS(INT_BITS),
      .FRAC_BITS(FRAC_BITS),
      .OUT_WIDTH(OUT_WIDTH)
  ) dut (
      .clk(clk),
      .rst(rst),
      .x_in(x_in),
      .ready_in(ready_in),
      .load(load),
      .valid_out(valid_out),
      .y_out(y_out)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // State/Stage change monitoring
  always @(posedge clk) begin
    if (!rst) begin
      if (prev_state != dut.state || prev_stage != dut.stage) begin
        $display("Time %0t: STATE changed from %s to %s, STAGE changed from %s to %s", 
                 $time,
                 state_name(prev_state), state_name(dut.state),
                 stage_name(prev_stage), stage_name(dut.stage));
        prev_state = dut.state;
        prev_stage = dut.stage;
      end
    end
  end

  // Helper functions for readable state/stage names
  function string state_name(logic [1:0] state);
    case(state)
      2'b00: return "IDLE";
      2'b01: return "WAIT";
      2'b10: return "SEND";
      default: return "UNKNOWN";
    endcase
  endfunction

  function string stage_name(logic [1:0] stage);
    case(stage)
      2'b00: return "STAGE1";
      2'b01: return "STAGE2";
      2'b10: return "STAGE3";
      2'b11: return "STAGE4";
      default: return "UNKNOWN";
    endcase
  endfunction

  // Test stimulus
  initial begin
    // Initialize
    rst = 1;
    ready_in = 0;
    load = 0;
    prev_state = 2'b00;
    prev_stage = 2'b00;
    
    for (int i = 0; i < 8; i++) begin
      x_in[i] = 0;
    end

    $display("=== DCT Testbench Started ===");
    repeat(3) @(posedge clk);
    
    // Release reset
    rst = 0;
    $display("Time %0t: Reset released", $time);
    @(posedge clk);

    //=== TEST 1: Basic Load and Processing ===
    $display("\n=== TEST 1: Load data and wait for processing ===");
    
    // Load test data
    load = 1;
    x_in[0] = 8'h10;  // 16
    x_in[1] = 8'h20;  // 32
    x_in[2] = 8'h30;  // 48
    x_in[3] = 8'h40;  // 64
    x_in[4] = 8'hF0;  // -16
    x_in[5] = 8'hE0;  // -32
    x_in[6] = 8'hD0;  // -48
    x_in[7] = 8'hC0;  // -64

    $display("Loading data at time %0t", $time);
    @(posedge clk);
    load = 0;
    
    // Wait for valid_out
    $display("Waiting for processing to complete...");
    wait(valid_out);
    $display("Time %0t: Processing complete, valid_out asserted", $time);
    
    // Display results
    $display("Output values:");
    for (int i = 0; i < 8; i++) begin
      $display("  y_out[%0d] = %0d", i, $signed(y_out[i]));
    end

    //=== TEST 2: Test Back Pressure (ready_in) ===
    $display("\n=== TEST 2: Testing back pressure with ready_in ===");
    repeat(2) @(posedge clk);
    
    $display("Asserting ready_in at time %0t", $time);
    ready_in = 1;
    @(posedge clk);
    ready_in = 0;
    $display("Deasserted ready_in, should return to IDLE");

    //=== TEST 3: Second Load Test ===
    $display("\n=== TEST 3: Loading second dataset ===");
    @(posedge clk);
    
    load = 1;
    // Different test pattern
    for (int i = 0; i < 8; i++) begin
      x_in[i] = (i % 2) ? -8*(i+1) : 8*(i+1);
    end
    
    $display("Loading second dataset at time %0t", $time);
    @(posedge clk);
    load = 0;
    
    // Wait for completion
    wait(valid_out);
    $display("Time %0t: Second processing complete", $time);
    
    repeat(2) @(posedge clk);
    ready_in = 1;
    @(posedge clk);
    ready_in = 0;

    //=== TEST 4: Test Forward Pressure (load while not ready) ===
    $display("\n=== TEST 4: Testing forward pressure scenarios ===");
    @(posedge clk);
    
    // Load third dataset
    load = 1;
    for (int i = 0; i < 8; i++) begin
      x_in[i] = 8'h55; // Fixed pattern
    end
    
    $display("Loading third dataset at time %0t", $time);
    @(posedge clk);
    load = 0;
    
    // Wait for valid_out but don't assert ready_in immediately
    wait(valid_out);
    $display("Time %0t: Third processing complete, but holding ready_in low", $time);
    
    // Try to load while in SEND state (should be ignored)
    repeat(2) @(posedge clk);
    $display("Attempting to load while in SEND state (should be ignored)");
    load = 1;
    for (int i = 0; i < 8; i++) begin
      x_in[i] = 8'hAA; // Different pattern
    end
    @(posedge clk);
    load = 0;
    
    // Now assert ready_in to clear
    repeat(2) @(posedge clk);
    $display("Finally asserting ready_in to clear SEND state");
    ready_in = 1;
    @(posedge clk);
    ready_in = 0;

    //=== TEST 5: Simultaneous Control Signals ===
    $display("\n=== TEST 5: Testing simultaneous load and ready_in ===");
    
    // Load data first
    @(posedge clk);
    load = 1;
    for (int i = 0; i < 8; i++) begin
      x_in[i] = 8'h33;
    end
    @(posedge clk);
    load = 0;
    
    wait(valid_out);
    $display("Time %0t: Processing complete", $time);
    
    // Test simultaneous signals
    @(posedge clk);
    $display("Testing simultaneous load and ready_in");
    load = 1;
    ready_in = 1;
    for (int i = 0; i < 8; i++) begin
      x_in[i] = 8'h77;
    end
    @(posedge clk);
    load = 0;
    ready_in = 0;

    // Final wait and cleanup
    repeat(5) @(posedge clk);
    
    $display("\n=== Test completed ===");
    $finish;
  end


endmodule
