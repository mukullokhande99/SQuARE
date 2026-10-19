// Packed FP2 pair unpack: {sign, exponent/mantissa, code[1:0]}.
// code 11: both same-sign; 10: second zero; 01: first zero;
// code 00 with nonzero word: opposite-sign pair; 0000: both zero.
module fp2_pair_unpack (
 input wire [3:0] wp,
 input wire is_e0m1,
 output wire [3:0] elem1,elem2
);
 wire s=wp[3];
 wire em_bit=wp[2];
 wire [1:0] c=wp[1:0];
 wire is_true_zero=(wp==4'b0000);
 wire is_opposite_pair=(c==2'b00)&&!is_true_zero;
 wire zero1=is_true_zero||(c==2'b01);
 wire zero2=is_true_zero||(c==2'b10);
 wire sign2=is_opposite_pair?~s:s;
 assign elem1={s,is_e0m1,zero1,em_bit};
 assign elem2={sign2,is_e0m1,zero2,em_bit};
endmodule
