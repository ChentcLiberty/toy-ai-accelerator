module mac_pipeline (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        in_valid,
    input  logic signed [7:0] a,
    input  logic signed [7:0] b,
    input  logic signed [31:0] acc,

    output logic        out_valid,
    output logic signed [31:0] y
);

    // Stage 0 registers
    logic signed [7:0]  a_r0, b_r0;
    logic signed [31:0] acc_r0;
    logic               v_r0;

    // Stage 1 registers
    logic signed [15:0] mul_r1;
    logic signed [31:0] acc_r1;
    logic               v_r1;

    // Stage 2 registers
    logic signed [31:0] sum_r2;
    logic               v_r2;

    // Stage 0: latch inputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_r0 <= 1'b0;
        end else begin
            v_r0 <= in_valid;
            a_r0 <= a;
            b_r0 <= b;
            acc_r0 <= acc;
        end
    end

    // Stage 1: multiply
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_r1 <= 1'b0;
        end else begin
            v_r1 <= v_r0;
            mul_r1 <= a_r0 * b_r0;
            acc_r1 <= acc_r0;
        end
    end

    // Stage 2: accumulate
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_r2 <= 1'b0;
        end else begin
            v_r2 <= v_r1;
            sum_r2 <= acc_r1 + mul_r1;
        end
    end

    assign out_valid = v_r2;
    assign y = sum_r2;

endmodule

