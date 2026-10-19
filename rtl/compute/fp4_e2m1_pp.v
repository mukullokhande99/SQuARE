// FP4 E2M1 bias-1 exact partial-product generator, Q8.8 output.
module fp4_e2m1_pp #(parameter ACC_W=32)(
 input wire [3:0] a,b,
 output wire sign_prod,
 output wire [ACC_W-1:0] partial
);
 localparam GLOBAL_EXTRA_SHIFT=6;
 wire [1:0] ea=a[2:1],eb=b[2:1];
 function [2:0] sig;
 input [1:0] e;input m;
 begin sig=(e==0)?{2'b0,m}:(3'd2+m);end
 endfunction
 function [1:0] pw;
 input [1:0] e;
 begin pw=(e==0)?2'd0:(e-2'd1);end
 endfunction
 wire [2:0] sa=sig(ea,a[0]),sb=sig(eb,b[0]);
 wire [5:0] prod=sa*sb;
 wire signed [3:0] exponent=$signed({2'b00,pw(ea)})+$signed({2'b00,pw(eb)})-4'sd2;
 wire [2:0] sh=exponent+4'sd2;
 wire [6:0] shift_total=sh+GLOBAL_EXTRA_SHIFT;
 assign sign_prod=a[3]^b[3];
 assign partial={{(ACC_W-6){1'b0}},prod}<<shift_total;
endmodule
