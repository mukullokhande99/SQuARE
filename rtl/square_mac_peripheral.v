`default_nettype none
// SQuARE streaming-MAC register peripheral.
// Register interface: 32-bit data, 8-bit byte offsets, single-clock req/ack.
module square_mac_peripheral(
 input wire clk, rst_n, req, we,
 input wire [7:0] addr,
 input wire [31:0] wdata,
 output reg [31:0] rdata,
 output reg ack
);
 reg [1:0] mode;
 reg [4:0] frac;
 reg [3:0] op_a, op_b;
 reg [7:0] pair_ops;
 reg [3:0] zeros;
 reg pair_format, issue, clear;
 wire signed [31:0] shared_acc, acc_out;
 wire signed [15:0] pair_acc;
 wire signed [7:0] pair_q8;
 wire shared_valid, pair_valid, result_valid, pair_overflow, nar;
 wire accept = req && !ack;

 always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
   ack<=0; mode<=0; frac<=8; op_a<=0; op_b<=0;
   pair_ops<=0; zeros<=0; pair_format<=0; issue<=0; clear<=0;
  end else begin
   ack<=accept;
   issue<=0;
   clear<=0;
   if (accept && we) begin
    case (addr)
     8'h00: begin mode<=wdata[1:0]; frac<=wdata[6:2]; pair_format<=wdata[7]; end
     8'h04: begin op_a<=wdata[3:0]; op_b<=wdata[7:4]; end
     8'h08: pair_ops<=wdata[7:0];
     8'h0c: zeros<=wdata[3:0];
     8'h10: begin issue<=wdata[0]; clear<=wdata[1]; end
     default: begin end
    endcase
   end
  end
 end
 always @* begin
  case (addr)
   8'h00: rdata={24'd0,pair_format,frac,mode};
   8'h04: rdata={24'd0,op_b,op_a};
   8'h08: rdata={24'd0,pair_ops};
   8'h0c: rdata={28'd0,zeros};
   8'h14: rdata=acc_out;
   8'h18: rdata={27'd0,nar,pair_overflow,pair_valid,shared_valid,result_valid};
   8'h1c: rdata={{24{pair_q8[7]}},pair_q8};
   default: rdata=0;
  endcase
 end
 sparx_mac_unified_v2 #(.ACC_W(32),.FP2P_ACC_W(16)) u_mac (
  .clk(clk),.rst_n(rst_n),.clear_acc(clear),.valid_in(issue),
  .mode_sel(mode),.frac_bits(frac),.a(op_a),.b(op_b),
  .fp2p_fmt_sel(pair_format),.fp2p_frac_bits(frac),
  .fp2p_a0(pair_ops[1:0]),.fp2p_a1(pair_ops[3:2]),
  .fp2p_w0(pair_ops[5:4]),.fp2p_w1(pair_ops[7:6]),
  .fp2p_a0_zero(zeros[0]),.fp2p_a1_zero(zeros[1]),
  .fp2p_w0_zero(zeros[2]),.fp2p_w1_zero(zeros[3]),
  .acc(shared_acc),.valid_out(shared_valid),.nar_flag(nar),
  .fp2p_acc(pair_acc),.fp2p_valid_out(pair_valid),
  .fp2p_overflow(pair_overflow),.fp2p_acc_fxp8(pair_q8),
  .acc_out(acc_out),.valid_out_final(result_valid)
 );
endmodule
`default_nettype wire
