module 2d_fbindct(
    input clk,
    input rst,
    input [7:0] blk_in [7:0][7:0],
    output [OUT_WIDTH-1:0] coef_out [7:0][7:0]
  );

  wire done;
  wire start;
  reg [2:0] cnt;
  reg [7:0] blk_reg [7:0][7:0];
  reg [OUT_WIDTH-1:0] coef_reg [7:0][7:0];
  reg [7:0] blk_vec_reg [7:0];
  reg [OUT_WIDTH-1:0] coef_vec_reg [7:0];

  //TODO: Find the sweet spot between sequential and parralelism of DCTs per
  //image or 
  fbindct dct(.clk(clk), .rst(rst), .x_in(blk_vec_reg), .x_out(coef_vec_reg));

  assign done = &cnt;

  always_ff @(clk) begin : DCT1
    if(rst) begin
      cnt <=0;
      blk_reg <=0;
      coef_reg <=0;
      blk_vec_reg <=0;
      coef_vec_reg <=0;
    end else if(start) begin
      blk_reg <= blk_in;     
    end else if(!done) begin
      for (int i = 0; i<cnt; i=i+1) begin
        blk_vec_reg <= blk_reg[i];
      end
    end
  end

  always_ff @(clk) begin : DCT2
    if(rst) begin
      
    end else if(done) begin
      // Use the same DCT to calculate the 2D DCT
    end
  end
