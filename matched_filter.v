// 250-tap complex matched filter, pipelined via binary adder tree
module matched_filter (
  clk, rst_n,
  in_real, in_imag,
  out_real, out_imag
);
  parameter TAP_NUM    = 250;
  parameter DATA_WIDTH = 16;
  parameter ACC_WIDTH  = 40;
  parameter P          = 256;
  parameter LEVELS     = 8;
  parameter PROD_WIDTH = 2*DATA_WIDTH;

  input                                  clk, rst_n;
  input  signed [DATA_WIDTH-1:0]   in_real, in_imag;
  output signed [DATA_WIDTH-1:0] out_real, out_imag;
  reg    signed [DATA_WIDTH-1:0] out_real, out_imag;

  integer i;

  // 1) coefficient ROMs
  reg signed [DATA_WIDTH-1:0] coeff_real [0:TAP_NUM-1];
  reg signed [DATA_WIDTH-1:0] coeff_imag [0:TAP_NUM-1];
  initial begin
    $readmemb("coeff_real_bin.txt", coeff_real);
    $readmemb("coeff_imag_bin.txt", coeff_imag);
  end

  // 2) shift-register delay line
  reg signed [DATA_WIDTH-1:0] shift_real [0:TAP_NUM-1];
  reg signed [DATA_WIDTH-1:0] shift_imag [0:TAP_NUM-1];
  always @(posedge clk) begin
    if (!rst_n) begin
      for (i=0; i<TAP_NUM; i=i+1) begin
        shift_real[i] <= 0;
        shift_imag[i] <= 0;
      end
    end else begin
      for (i=TAP_NUM-1; i>0; i=i-1) begin
        shift_real[i] <= shift_real[i-1];
        shift_imag[i] <= shift_imag[i-1];
      end
      shift_real[0] <= in_real;
      shift_imag[0] <= in_imag;
    end
  end

  // 3) per-tap complex multiply
  reg signed [PROD_WIDTH-1:0] prod_real [0:TAP_NUM-1];
  reg signed [PROD_WIDTH-1:0] prod_imag [0:TAP_NUM-1];
  always @(posedge clk) begin
    if (!rst_n) begin
      for (i=0; i<TAP_NUM; i=i+1) begin
        prod_real[i] <= 0;
        prod_imag[i] <= 0;
      end
    end else begin
      for (i=0; i<TAP_NUM; i=i+1) begin
        prod_real[i] <= shift_real[i]*coeff_real[i]
                      - shift_imag[i]*coeff_imag[i];
        prod_imag[i] <= shift_real[i]*coeff_imag[i]
                      + shift_imag[i]*coeff_real[i];
      end
    end
  end

  // 4) pipelined binary adder tree stages
  //    stage_real[level][idx] holds partial sums
  reg signed [PROD_WIDTH-1:0] stage_real [0:LEVELS][0:P-1];
  reg signed [PROD_WIDTH-1:0] stage_imag [0:LEVELS][0:P-1];

  // level 0: load prods and zero-pad up to P=256
  always @(posedge clk) begin
    if (!rst_n) begin
      for (i=0; i<P; i=i+1) begin
        stage_real[0][i] <= 0;
        stage_imag[0][i] <= 0;
      end
    end else begin
      for (i=0; i<P; i=i+1) begin
        if (i < TAP_NUM) begin
          stage_real[0][i] <= prod_real[i];
          stage_imag[0][i] <= prod_imag[i];
        end else begin
          stage_real[0][i] <= 0;
          stage_imag[0][i] <= 0;
        end
      end
    end
  end

  // remaining levels: each sums two children
  genvar lvl, idx;
  generate
    for (lvl = 1; lvl <= LEVELS; lvl = lvl+1) begin : tree_levels
      // at level lvl, we have P>>lvl sums
      localparam integer CUR = P >> lvl;
      always @(posedge clk) begin
        if (!rst_n) begin
          for (i=0; i<CUR; i=i+1) begin
            stage_real[lvl][i] <= 0;
            stage_imag[lvl][i] <= 0;
          end
        end else begin
          for (i=0; i<CUR; i=i+1) begin
            stage_real[lvl][i] <= stage_real[lvl-1][2*i]
                                + stage_real[lvl-1][2*i+1];
            stage_imag[lvl][i] <= stage_imag[lvl-1][2*i]
                                + stage_imag[lvl-1][2*i+1];
          end
        end
      end
    end
  endgenerate

  // 5) final accumulator register and downscale to Q15
  reg signed [PROD_WIDTH-1:0] acc_real_pipe, acc_imag_pipe;

  always @(posedge clk) begin
    if (!rst_n) begin
      acc_real_pipe <= 0;
      acc_imag_pipe <= 0;
      out_real      <= 0;
      out_imag      <= 0;
    end else begin
      acc_real_pipe <= stage_real[LEVELS][0];
      acc_imag_pipe <= stage_imag[LEVELS][0];
      // shift off fractional Q15 bits
      out_real      <= acc_real_pipe >>> (DATA_WIDTH-1);
      out_imag      <= acc_imag_pipe >>> (DATA_WIDTH-1);
    end
  end

endmodule
