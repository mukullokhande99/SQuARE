// Two element-level FP2 x FP2 products accumulated into a 2-tap partial sum.
module fp2_pair_mac_fp2xfp2 #(parameter ACC_W=32)(
 input wire clk,rst_n,clear_acc,valid_in,is_e0m1_w,is_e0m1_a,
 input wire [3:0] wp,ap,
 output reg signed [ACC_W-1:0] acc,
 output reg valid_out
);
 wire [3:0] w1,w2,a1,a2;
 fp2_pair_unpack u_unpack_w(.wp(wp),.is_e0m1(is_e0m1_w),.elem1(w1),.elem2(w2));
 fp2_pair_unpack u_unpack_a(.wp(ap),.is_e0m1(is_e0m1_a),.elem1(a1),.elem2(a2));
 wire sign_p1,sign_p2;
 wire [ACC_W-1:0] pp1,pp2;
 fp2_pp #(.ACC_W(ACC_W)) u_pp1(.a(a1),.b_in(w1),.sign_prod(sign_p1),.partial(pp1));
 fp2_pp #(.ACC_W(ACC_W)) u_pp2(.a(a2),.b_in(w2),.sign_prod(sign_p2),.partial(pp2));
 wire signed [ACC_W-1:0] term1=sign_p1 ? -$signed(pp1):$signed(pp1);
 wire signed [ACC_W-1:0] term2=sign_p2 ? -$signed(pp2):$signed(pp2);
 wire signed [ACC_W-1:0] psum=term1+term2;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin acc<={ACC_W{1'b0}}; valid_out<=0; end
  else begin
   if(clear_acc) acc<={ACC_W{1'b0}};
   if(valid_in) begin acc<=(clear_acc?{ACC_W{1'b0}}:acc)+psum;valid_out<=1;end
   else valid_out<=0;
  end
 end
endmodule
