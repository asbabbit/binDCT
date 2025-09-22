`timescale 1ns / 1ps

/* Ping-Pong Buffer Coordination:
 * 
 * PS (Write) Side:
 * 1. PS writes to Partition A, then sets buffer_A_ready = 1
 * 2. PS switches to writing Partition B
 * 3. When PS receives IRQ with partition_id = 0 (A finished):
 *    - PS clears buffer_A_ready = 0
 *    - PS can start writing to A again
 * 4. When PS finishes B, sets buffer_B_ready = 1
 * 5. When PS receives IRQ with partition_id = 1 (B finished):
 *    - PS clears buffer_B_ready = 0
 *    - PS can start writing to B again
 *
 * PL (Read) Side:
 * 1. PL monitors buffer_X_ready flags
 * 2. When buffer becomes ready, PL switches to reading it
 * 3. After processing all rows, PL sends IRQ with partition_id
 * 4. PL returns to IDLE to check for next ready buffer
 */
 
module fbindct_bram_ctrl #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 13,
    parameter DATA_DEPTH = 512,
    parameter BRAM_DEPTH = 8192,
    
    parameter ROW_DIM = 8,
    parameter IN_WIDTH = 8
)(
    input                                   clk,
    input                                   rst,
    // PS control
    input  wire     [1:0]                   ps_gpio,  // Flags to say which buffer is ready to ready
    output reg      [0:0]                   ps_irq,   // PS dual edge detection irq: swap buffer base addr
    // BRAM control
    output reg      [ADDR_WIDTH-1:0]        bram_addr,    // Addr to be read/write
    output wire     [DATA_WIDTH-1:0]        bram_wrdata,  // Data write to addr
    input  wire     [DATA_WIDTH-1:0]        bram_rddata,  // Data read from addr
    output reg                              bram_en,      // Enable read
    output wire                             bram_we,      // Enable write
    // fbindct control
    output reg                                  dct_load,   // Signals DCT to load new data
    input  wire                                 dct_valid,  // Siganls when DCT done processing
    output wire [ROW_DIM*IN_WIDTH-1:0]          dct_row     // Row of data to be processed
);

function integer clogb2 (input integer bit_depth);
  begin
    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
      bit_depth = bit_depth >> 1;
  end
endfunction

localparam integer ROW_COUNT_BITS = clogb2(ROW_DIM);
localparam integer WORDS_PER_ROW  = ROW_DIM*IN_WIDTH/DATA_WIDTH;
localparam integer WORD_COUNT_BITS = clogb2(WORDS_PER_ROW);

localparam A_BASE_ADDR = {ADDR_WIDTH{1'b0}};
localparam A_HIGH_ADDR = A_BASE_ADDR + DATA_DEPTH - 1;
localparam B_BASE_ADDR = A_HIGH_ADDR + 1;
localparam B_HIGH_ADDR = B_BASE_ADDR + DATA_DEPTH - 1;

localparam IDLE = 2'b000;
localparam START = 2'b001;
localparam WRITE_ROW = 2'b010;
localparam PROCESSING = 2'b011;

localparam IN_A = 1'b0;
localparam IN_B = 1'b1;

// PS signals
wire A_ready = ps_gpio[0];
wire B_ready = ps_gpio[1];

// BRAM interface
assign bram_wrdata = {DATA_WIDTH{1'b0}}; // Dummny values
assign bram_we = 1'b0;                   // Only reading BRAM

// fbindct interface - pack row data into output
generate
  genvar i;
  for(i=0; i<WORDS_PER_ROW; i=i+1) begin : gen_dct_row
    assign dct_row[i*DATA_WIDTH +: DATA_WIDTH] = words[i];
  end
endgenerate

// Control registers
reg [2:0]                   state;
reg                         buffer;                             // 0=A, 1=B
reg [ROW_COUNT_BITS-1:0]    row_counter;                        // Count rows processed in block

// Row RAM interface
reg [DATA_WIDTH-1:0]        words [WORDS_PER_ROW-1:0];          // Store words for row
reg [WORD_COUNT_BITS-1:0]   word_addr;                          // Addr of row RAM

always @(posedge clk) begin
  if (rst) begin
    bram_en <= 0;
    bram_addr <= A_BASE_ADDR;
    dct_load <=0;
    ps_irq  <= 0;

    state <= IDLE;
    buffer <= IN_B;
    row_counter <= 0;

    word_addr <= 0;

  end else begin
    case (state)
      IDLE: begin
        // Ping-pong buffer logic
        if (A_ready && (buffer == IN_B)) begin   // If buffer A is ready and current buffer pointed to is B
          state <= START;
          buffer <= IN_A;
          bram_addr <= A_BASE_ADDR;
          bram_en <= 1'b1;
        end else if (B_ready && (buffer == IN_A)) begin
          state <= START;
          buffer <= IN_B;
          bram_addr <= B_BASE_ADDR;
          bram_en <= 1'b1;
        end else begin
          state <= IDLE;
        end
      end

      START: begin
        state <= WRITE_ROW;
        bram_addr <= bram_addr + 1;
      end

      WRITE_ROW: begin
        words[word_addr] <= bram_rddata;
        if (word_addr == WORDS_PER_ROW-1) begin
          state <= PROCESSING;
          dct_load <= 1'b1;
          bram_en <= 1'b0;
          word_addr <= 0;
        end else begin
          word_addr <= word_addr + 1;
          bram_addr <= bram_addr + 1;
        end
      end

      PROCESSING: begin
        dct_load <= 1'b0;   // Current row being processed, deassert load
        if(dct_valid) begin // DCT finished processing this row
          if(row_counter == ROW_DIM-1) begin // Finished processing all rows in block
            state <= IDLE;
            row_counter <=0;
            ps_irq <= ~ps_irq;   // Interrupt PS to ping-pong the buffer
          end else begin      // Still processing current block row by row
            state <= START;
            bram_en <= 1'b1;
            row_counter <= row_counter + 1;
          end
        end
      end
      default: begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule
