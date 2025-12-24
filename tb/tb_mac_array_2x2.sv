`timescale 1ns/1ps
module tb_mac_array_2x2;

  logic clk, rst_n;
  logic in_valid, out_valid;
  logic signed [7:0] a0, a1, b0, b1;
  logic signed [31:0] acc00, acc01, acc10, acc11;
  logic signed [31:0] y00, y01, y10, y11;

  mac_array_2x2 dut(
    .clk, .rst_n, .in_valid,
    .a0, .a1, .b0, .b1,
    .acc00, .acc01, .acc10, .acc11,
    .out_valid, .y00, .y01, .y10, .y11
  );

  always #5 clk = ~clk;

  // partial sums storage between steps
  logic signed [31:0] p00, p01, p10, p11;
  int phase; // 0: first step sent, wait; 1: second step sent, wait; 2: done

  initial begin
    clk=0; rst_n=0; in_valid=0;
    a0=0; a1=0; b0=0; b1=0;
    acc00=0; acc01=0; acc10=0; acc11=0;
    phase = -1;

    // reset
    #20 rst_n=1;

    // Step 1: send first K-slice
    @(negedge clk);
    in_valid=1;
    a0 = 1; a1 = 3; // A00, A10
    b0 = 5; b1 = 6; // B00, B01
    acc00=0; acc01=0; acc10=0; acc11=0;
    phase = 0;

    @(negedge clk);
    in_valid=0; a0=0; a1=0; b0=0; b1=0;

    // wait for first out_valid, capture partials
    wait(out_valid==1);
    p00 = y00; p01 = y01; p10 = y10; p11 = y11;
    $display("Partial: p00=%0d p01=%0d p10=%0d p11=%0d", p00,p01,p10,p11);

    // Step 2: send second K-slice with partials as acc
    @(negedge clk);
    in_valid=1;
    a0 = 2; a1 = 4; // A01, A11
    b0 = 7; b1 = 8; // B10, B11
    acc00 = p00; acc01 = p01; acc10 = p10; acc11 = p11;
    phase = 1;

    @(negedge clk);
    in_valid=0;
  end

  // Check final results when out_valid after step 2
  always @(posedge clk) begin
    if (out_valid && phase==1) begin
      $display("Final: y00=%0d y01=%0d y10=%0d y11=%0d", y00,y01,y10,y11);
      if (y00!==19 || y01!==22 || y10!==43 || y11!==50) begin
        $fatal(1, "Mismatch! got {%0d,%0d;%0d,%0d}, exp {19,22;43,50}",
               y00,y01,y10,y11);
      end else begin
        $display("2x2 GEMM PASS");
      end
      // small delay then finish
      #20 $finish;
    end
  end

endmodule
