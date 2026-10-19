// FP2 element-level partial-product generator (E1M0/E0M1).
// Inputs encode {sign, mode, zero, magnitude_bit}.
`default_nettype none
module fp2_pp #(parameter ACC_W=32)(
 input wire [3:0] a,b_in,
 output wire sign_prod,
 output wire [ACC_W-1:0] partial
);
 function [1:0] mag2;
 input mode,z,bitv;
 begin
  if(z) mag2=0;
  else if(!mode) mag2=bitv?2'd1:2'd2;
  else mag2=bitv?2'd3:2'd2;
 end
 endfunction
 wire [1:0] ma=mag2(a[2],a[1],a[0]);
 wire [1:0] mb=mag2(b_in[2],b_in[1],b_in[0]);
 wire [3:0] product=ma*mb;
 assign sign_prod=a[3]^b_in[3];
 assign partial={{(ACC_W-4){1'b0}},product}<<6;
endmodule
module fp2_block_exp_adder(
 input wire [7:0] x_a,x_b,
 output wire [8:0] x_sum
);
 assign x_sum={1'b0,x_a}+{1'b0,x_b};
endmodule
`default_nettype wire
