module mac_array_2x2 (
  input  logic clk,
  input  logic rst_n,
  input  logic in_valid,
  input  logic signed [7:0] a0,  // row 0 element
  input  logic signed [7:0] a1,  // row 1 element
  input  logic signed [7:0] b0,  // col 0 element
  input  logic signed [7:0] b1,  // col 1 element
  input  logic signed [31:0] acc00,
  input  logic signed [31:0] acc01,
  input  logic signed [31:0] acc10,
  input  logic signed [31:0] acc11,
  output logic out_valid,
  output logic signed [31:0] y00,
  output logic signed [31:0] y01,
  output logic signed [31:0] y10,
  output logic signed [31:0] y11
);

  logic v00, v01, v10, v11;

  mac_pipeline u00(.clk, .rst_n, .in_valid, .a(a0), .b(b0), .acc(acc00), .out_valid(v00), .y(y00));
  mac_pipeline u01(.clk, .rst_n, .in_valid, .a(a0), .b(b1), .acc(acc01), .out_valid(v01), .y(y01));
  mac_pipeline u10(.clk, .rst_n, .in_valid, .a(a1), .b(b0), .acc(acc10), .out_valid(v10), .y(y10));
  mac_pipeline u11(.clk, .rst_n, .in_valid, .a(a1), .b(b1), .acc(acc11), .out_valid(v11), .y(y11));

  // all four share the same pipeline; any v* is fine; keep AND to be safe
  assign out_valid = v00 & v01 & v10 & v11;

endmodule

