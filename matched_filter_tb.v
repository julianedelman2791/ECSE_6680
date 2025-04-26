`timescale 1ns/1ps
module matched_filter_tb;
  // Parameters
  parameter integer TAP_NUM     =  250;
  parameter integer DATA_WIDTH  =   16;
  parameter integer MAX_SAMPLES = 1024;

  // Clock & reset
  reg                              clk;
  reg                            rst_n;

  // DUT I/O
  reg  signed [DATA_WIDTH-1:0] in_real, in_imag;
  wire signed [DATA_WIDTH-1:0] out_real, out_imag;

  // Test-vector storage
  reg signed [DATA_WIDTH-1:0] test_real [0:MAX_SAMPLES-1];
  reg signed [DATA_WIDTH-1:0] test_imag [0:MAX_SAMPLES-1];

  // Loop & file variables
  integer num_samples, i, j;
  integer fh, ns;
  reg [8*80-1:0] line;
  integer sim_fh;

  // Instantiate DUT
  matched_filter #(
    .TAP_NUM   (TAP_NUM),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_real  (in_real),
    .in_imag  (in_imag),
    .out_real (out_real),
    .out_imag (out_imag)
  );

  // 100 MHz clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    $display("=== TB START ===");

    // 1) count lines
    fh = $fopen("input_real_bin.txt","r");
    if (fh == 0) begin $display("ERROR: open input_real_bin.txt"); $finish; end
    ns = 0;
    while (!$feof(fh)) begin $fgets(line, fh); ns = ns + 1; end
    $fclose(fh);

    // 2) clamp to TAP_NUM
    num_samples = ns;
    if (num_samples > TAP_NUM) begin
      $display("WARNING: trimming %0d→%0d samples", ns, TAP_NUM);
      num_samples = TAP_NUM;
    end
    $display("TESTBENCH: using %0d samples", num_samples);

    // 3) load test vectors
    $readmemb("input_real_bin.txt", test_real);
    $readmemb("input_imag_bin.txt", test_imag);

    $display("Sample[0]=(%b,%b)", test_real[0], test_imag[0]);
    $display("Sample[%0d]=(%b,%b)",
             num_samples-1,
             test_real[num_samples-1],
             test_imag[num_samples-1]);

    // 4) open sim_io.txt
    sim_fh = $fopen("sim_io.txt","w");
    if (sim_fh == 0) begin $display("ERROR: open sim_io.txt"); $finish; end
    $fwrite(sim_fh, "cycle in_real in_imag out_real out_imag\n");

    // 5) assert reset
    rst_n   = 1'b0;
    in_real = 16'sd0;
    in_imag = 16'sd0;
    repeat (5) @(posedge clk);

    // 6) deassert reset
    rst_n = 1'b1;
    @(posedge clk);
    $display("TB: reset released at time %0t", $time);

    // 7) drive samples & log
    for (i = 0; i < num_samples; i = i+1) begin
      in_real = test_real[i];
      in_imag = test_imag[i];
      @(posedge clk);
      $display("cycle %0d → in=(%0d,%0d) out=(%0d,%0d)",
               i, in_real, in_imag, out_real, out_imag);
      $fwrite(sim_fh, "%0d %0d %0d %0d %0d\n",
              i, in_real, in_imag, out_real, out_imag);
    end

    // 8) flush filter tail with zeros
    for (j = 0; j < TAP_NUM; j = j+1) begin
      in_real = 16'sd0;
      in_imag = 16'sd0;
      @(posedge clk);
      $fwrite(sim_fh, "%0d %0d %0d %0d %0d\n",
              num_samples+j, 0, 0, out_real, out_imag);
    end

    // 9) finish
    $fclose(sim_fh);
    $display("=== TB COMPLETE ===");
    $finish;
  end

endmodule
