// Sequential 2-Instance 2D DCT Implementation
module 2d_fbindct (
    input clk,
    input rst,
    input signed [7:0] block_in [7:0][7:0],    // 8x8 input block
    input load_block,                          // Start processing new block
    input ready_in,                            // Downstream ready for output
    
    output logic valid_out,                    // Output valid
    output signed [19:0] block_out [7:0][7:0]  // 8x8 DCT output block
);

    // ========================================================================
    // ROW DCT (Instance 1) - Process rows sequentially
    // ========================================================================
    
    // Row DCT signals
    logic signed [7:0]  row_x_in [7:0];
    logic               row_load;
    logic               row_ready_in;
    logic               row_valid_out;
    logic signed [19:0] row_y_out [7:0];
    
    // Row DCT instance
    fbindct_8bit u_row_dct (
        .clk        (clk),
        .rst        (rst),
        .x_in       (row_x_in),
        .ready_in   (row_ready_in),
        .load       (row_load),
        .valid_out  (row_valid_out),
        .y_out      (row_y_out)
    );

    // ========================================================================
    // COLUMN DCT (Instance 2) - Process columns sequentially  
    // ========================================================================
    
    // Column DCT signals
    logic signed [19:0] col_x_in [7:0];       // Note: 20-bit input from row DCT
    logic               col_load;
    logic               col_ready_in;
    logic               col_valid_out;
    logic signed [19:0] col_y_out [7:0];

    // Column DCT instance (custom parameters for 20-bit input)
    fbindct_8bit #(
        .IN_WIDTH    (20),                     // 20-bit input from row DCT
        .INT_BITS    (4),                      // Same overflow protection
        .FRAC_BITS   (6),                      // Same fractional bits
        .INTER_WIDTH (30),                     // 20+4+6 = 30 bits
        .OUT_WIDTH   (20)                      // Keep 20-bit output
    ) u_col_dct (
        .clk        (clk),
        .rst        (rst),
        .x_in       (col_x_in),
        .ready_in   (col_ready_in),
        .load       (col_load),
        .valid_out  (col_valid_out),
        .y_out      (col_y_out)
    );

    // ========================================================================
    // CONTROL STATE MACHINE
    // ========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        PROCESS_ROWS,
        TRANSPOSE,
        PROCESS_COLS,
        OUTPUT_READY
    } state_t;
    
    state_t state;
    logic [2:0] row_counter, col_counter;
    
    // ========================================================================
    // TRANSPOSE BUFFER - Store intermediate results
    // ========================================================================
    
    logic signed [19:0] transpose_buffer [7:0][7:0];
    
    // ========================================================================
    // MAIN CONTROL LOGIC
    // ========================================================================
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            row_counter <= 0;
            col_counter <= 0;
            row_load <= 1'b0;
            col_load <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (load_block) begin
                        state <= PROCESS_ROWS;
                        row_counter <= 0;
                        // Load first row
                        for (int i = 0; i < 8; i++) begin
                            row_x_in[i] <= block_in[0][i];
                        end
                        row_load <= 1'b1;
                    end
                end
                
                PROCESS_ROWS: begin
                    row_load <= 1'b0;
                    
                    if (row_valid_out && row_ready_in) begin
                        // Store completed row in transpose buffer
                        for (int i = 0; i < 8; i++) begin
                            transpose_buffer[row_counter][i] <= row_y_out[i];
                        end
                        
                        if (row_counter == 7) begin
                            // All rows done, start column processing
                            state <= PROCESS_COLS;
                            col_counter <= 0;
                            // Load first column (transposed)
                            for (int i = 0; i < 8; i++) begin
                                col_x_in[i] <= transpose_buffer[i][0];
                            end
                            col_load <= 1'b1;
                        end else begin
                            // Load next row
                            row_counter <= row_counter + 1;
                            for (int i = 0; i < 8; i++) begin
                                row_x_in[i] <= block_in[row_counter + 1][i];
                            end
                            row_load <= 1'b1;
                        end
                    end
                end
                
                PROCESS_COLS: begin
                    col_load <= 1'b0;
                    
                    if (col_valid_out && col_ready_in) begin
                        // Store completed column in output buffer
                        for (int i = 0; i < 8; i++) begin
                            block_out[i][col_counter] <= col_y_out[i];
                        end
                        
                        if (col_counter == 7) begin
                            // All columns done
                            state <= OUTPUT_READY;
                            valid_out <= 1'b1;
                        end else begin
                            // Load next column
                            col_counter <= col_counter + 1;
                            for (int i = 0; i < 8; i++) begin
                                col_x_in[i] <= transpose_buffer[i][col_counter + 1];
                            end
                            col_load <= 1'b1;
                        end
                    end
                end
                
                OUTPUT_READY: begin
                    if (ready_in) begin
                        valid_out <= 1'b0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Connect ready signals - always ready to accept data from DCT modules
    assign row_ready_in = 1'b1;
    assign col_ready_in = 1'b1;

endmodule
