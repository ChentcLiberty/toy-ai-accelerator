`timescale 1ns/1ps

module tb_mac_pipeline;

 `include "include/fsdb_dump.svh"
  
  // ===== 硬编码 FSDB dump 测试 =====
//  initial begin
 //   $display("[DEBUG] FSDB dump starting...");
 //   $fsdbDumpfile("build/waves.fsdb");
 //   $fsdbDumpvars(0, tb_mac_pipeline);
 //   $display("[DEBUG] FSDB dump enabled!");
 // end
  // ===== 结束 =====

  logic clk, rst_n;
  logic        in_valid;
  logic signed [7:0]  a, b;
  logic signed [31:0] acc;
  logic        out_valid;
  logic signed [31:0] y;


  mac_pipeline dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid(in_valid), .a(a), .b(b), .acc(acc),
    .out_valid(out_valid), .y(y)
  );

  // 10ns clk
  always #5 clk = ~clk;

  int expected[$];
  int idx;

  initial begin
    clk = 0; rst_n = 0;
    in_valid = 0; a = 0; b = 0; acc = 0;
    idx = 0;

    // reset
    #20 rst_n = 1;

    // 3 transactions back-to-back
    // (acc + a*b): 10+3*4=22, 5+(-2)*7=-9, 0+8*8=64
    expected.push_back(22);
    expected.push_back(-9);
    expected.push_back(64);

    @(negedge clk);
    in_valid = 1; a = 3;  b = 4;  acc = 10;
    @(negedge clk);
    in_valid = 1; a = -2; b = 7;  acc = 5;
    @(negedge clk);
    in_valid = 1; a = 8;  b = 8;  acc = 0;

    @(negedge clk);
    in_valid = 0; a = 0; b = 0; acc = 0;

    // wait enough cycles
    repeat (20) @(negedge clk);

    if (idx == expected.size()) $display("SELF-CHECK PASS: %0d items OK", idx);
    else $fatal(1, "SELF-CHECK FAIL: expected %0d outputs, got %0d", expected.size(), idx);

    $finish;
  end


  always @(posedge clk) begin
    if (out_valid) begin
      $display("t=%0t y=%0d (exp=%0d)", $time, y, expected[idx]);
      if (y !== expected[idx]) $fatal(1, "Mismatch at %0d: got %0d exp %0d", idx, y, expected[idx]);
      idx++;
    end
  end

endmodule

