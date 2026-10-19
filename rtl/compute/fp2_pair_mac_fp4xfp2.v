// FP4 activation x packed FP2 weight pair, two-lane dot-product MAC.
// Psum=Fa*W1+Fb*W2; signed fixed-point accumulator (LSB 2^-8).
module fp2_pair_mac_fp4xfp2 #(parameter ACC_W=32)(
 input wire clk,rst_n,clear_acc,valid_in,is_e0m1,
 input wire [3:0] wp,fa,fb,
 output reg signed [ACC_W-1:0] acc,
 output reg valid_out
);
 wire [3:0] w1_elem,w2_elem;
 fp2_pair_unpack u_unpack(.wp(wp),.is_e0m1(is_e0m1),.elem1(w1_elem),.elem2(w2_elem));
 wire sign_p1,sign_p2;
 wire [ACC_W-1:0] pp1,pp2;
 fp4_x_fp2_pp #(.ACC_W(ACC_W)) u_pp1(
 .f(fa),.w(w1_elem),.sign_prod(sign_p1),.partial(pp1));
 fp4_x_fp2_pp #(.ACC_W(ACC_W)) u_pp2(
 .f(fb),.w(w2_elem),.sign_prod(sign_p2),.partial(pp2));
 wire signed [ACC_W-1:0] term1=sign_p1 ? -$signed(pp1):$signed(pp1);
 wire signed [ACC_W-1:0] term2=sign_p2 ? -$signed(pp2):$signed(pp2);
 wire signed [ACC_W-1:0] psum=term1+term2;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin acc<={ACC_W{1'b0}};valid_out<=1'b0;end
  else begin
   if(clear_acc) acc<={ACC_W{1'b0}};
   if(valid_in) begin acc<=(clear_acc?{ACC_W{1'b0}}:acc)+psum;valid_out<=1'b1;end
   else valid_out<=1'b0;
  end
 end
endmodule
