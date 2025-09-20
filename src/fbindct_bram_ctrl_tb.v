`timescale 1ns / 1ps

module tb_fbindct_simple_waveform();

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 13;
    parameter DATA_DEPTH = 512;
    parameter BRAM_DEPTH = 8192;
    parameter ROW_DIM = 8;
    parameter IN_WIDTH = 8;
    parameter WORDS_PER_ROW = 2; // 8*8/32 = 2
    
    // Clock and reset
    reg clk;
    reg rst;
    
    // PS control signals
    reg [1:0] ps_gpio;
    wire [0:0] ps_irq;
    
    // BRAM interface signals
    wire [ADDR_WIDTH-1:0] bram_addr;
    wire [DATA_WIDTH-1:0] bram_wrdata;
    reg [DATA_WIDTH-1:0] bram_rddata;
    wire bram_en;
    wire bram_we;
    
    // DCT interface signals
    wire dct_load;
    reg dct_valid;
    wire [ROW_DIM*IN_WIDTH-1:0] dct_row;
    
    // Test memory
    reg [DATA_WIDTH-1:0] test_memory [0:1023];
    
    // State decode for waveform viewing
    wire [1:0] state_raw = dut.state;
    reg [47:0] state_name; // 6 characters * 8 bits
    always @(*) begin
        case (state_raw)
            2'b00: state_name = "IDLE  ";
            2'b01: state_name = "READ  ";
            2'b10: state_name = "PROC  ";
            default: state_name = "UNDEF ";
        endcase
    end
    
    // Partition decode for waveform viewing
    wire partition_raw = dut.current_partition;
    reg [15:0] partition_name; // 2 characters * 8 bits
    always @(*) begin
        case (partition_raw)
            1'b0: partition_name = "A ";
            1'b1: partition_name = "B ";
            default: partition_name = "? ";
        endcase
    end
    
    // Control signals for easier waveform viewing
    wire buffer_A_ready = ps_gpio[0];
    wire buffer_B_ready = ps_gpio[1];
    wire [3:0] row_count = dut.row_counter;
    wire [3:0] word_count = dut.word_counter;
    
    // DCT delay counter for visualization
    reg [3:0] dct_delay_count;
    
    // Instantiate the DUT
    fbindct_bram_ctrl #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_DEPTH(DATA_DEPTH),
        .BRAM_DEPTH(BRAM_DEPTH),
        .ROW_DIM(ROW_DIM),
        .IN_WIDTH(IN_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ps_gpio(ps_gpio),
        .ps_irq(ps_irq),
        .bram_addr(bram_addr),
        .bram_wrdata(bram_wrdata),
        .bram_rddata(bram_rddata),
        .bram_en(bram_en),
        .bram_we(bram_we),
        .dct_load(dct_load),
        .dct_valid(dct_valid),
        .dct_row(dct_row)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz
    
    // Simple memory model
    always @(posedge clk) begin
        if (rst) begin
            bram_rddata <= 32'h00000000;
        end else if (bram_en && !bram_we && bram_addr < 1024) begin
            bram_rddata <= test_memory[bram_addr];
        end else begin
            bram_rddata <= 32'h00000000;
        end
    end
    
    // DCT response model with fixed 3-cycle delay
    always @(posedge clk) begin
        if (rst) begin
            dct_valid <= 1'b0;
            dct_delay_count <= 4'b0;
        end else if (dct_load) begin
            dct_delay_count <= 4'd3; // 3-cycle delay
            dct_valid <= 1'b0;
        end else if (dct_delay_count > 0) begin
            dct_delay_count <= dct_delay_count - 1;
            dct_valid <= (dct_delay_count == 1);
        end else begin
            dct_valid <= 1'b0;
        end
    end
    
    // Initialize test memory
    integer i;
    initial begin
        // Buffer A: Pattern 0xA000xxxx
        for (i = 0; i < 512; i = i + 1) begin
            test_memory[i] = 32'hA0000000 + i;
        end
        
        // Buffer B: Pattern 0xB000xxxx
        for (i = 512; i < 1024; i = i + 1) begin
            test_memory[i] = 32'hB0000000 + (i - 512);
        end
    end
    
    // Simple test sequence
    initial begin
        $display("=== Simplified FBINDCT Waveform Test ===");
        $dumpfile("simple_waveform.vcd");
        $dumpvars(0, tb_fbindct_simple_waveform);
        
        // Initialize
        rst = 1;
        ps_gpio = 2'b00;
        dct_valid = 0;
        
        $display("Time %0t: Starting test with reset active", $time);
        
        // Release reset after 100ns
        #100;
        rst = 0;
        $display("Time %0t: Reset released", $time);
        
        // Wait a bit, then test Buffer A
        #50;
        $display("Time %0t: Setting Buffer A ready", $time);
        ps_gpio = 2'b01; // Buffer A ready
        
        // Let Buffer A process completely (should take ~200 cycles)
        #2000;
        
        // Clear Buffer A, set Buffer B ready
        $display("Time %0t: Switching to Buffer B", $time);
        ps_gpio = 2'b10; // Buffer B ready
        
        // Let Buffer B process
        #2000;
        
        // Test both buffers ready (should pick opposite of current)
        $display("Time %0t: Both buffers ready", $time);
        ps_gpio = 2'b11; // Both ready
        
        #2000;
        
        // Clear all
        $display("Time %0t: Clearing all buffers", $time);
        ps_gpio = 2'b00;
        
        #100;
        
        $display("Time %0t: Test complete", $time);
        $finish;
    end
    
    // Console monitoring (minimal for cleaner output)
    always @(posedge clk) begin
        if (!rst) begin
            // Only display state changes and important events
            if (dut.state != 2'b00) begin // Not IDLE
                $display("[%0t] %s | Partition:%s | Row Count:%0d | Word Count:%0d | BRAM Addr:0x%03X | Word Data: 0x%016x | Row Data:0x%08X | Load:%b | Valid:%b", 
                        $time, state_name, partition_name, row_count+1, word_count+1, 
                        bram_addr, dct_row, bram_rddata, dct_load, dct_valid);
            end
            
            // Display IRQ toggles
            if (ps_irq !== ps_irq) begin
                $display("[%0t] *** IRQ TOGGLE: %b ***", $time, ps_irq);
            end
        end
    end
    
    // Timeout safety
    initial begin
        #10000;
        $display("TIMEOUT: Test completed");
        $finish;
    end
    
endmodule