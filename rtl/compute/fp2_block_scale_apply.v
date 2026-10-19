// Shared exponent scaling for an accumulated FP2 block.
module fp2_block_scale_apply #(
    parameter ACC_W = 32,
    parameter OUT_W = 48
)(
    input  wire signed [ACC_W-1:0] block_acc,
    input  wire        [7:0]       x_shared,
    output wire signed [OUT_W-1:0] block_result
);
    localparam MAX_SHIFT = OUT_W - ACC_W;
    wire [7:0] shift_amt =
        (x_shared > MAX_SHIFT[7:0]) ? MAX_SHIFT[7:0] : x_shared;
    wire signed [OUT_W-1:0] sign_extended =
        {{(OUT_W-ACC_W){block_acc[ACC_W-1]}}, block_acc};
    assign block_result = sign_extended <<< shift_amt;
endmodule
