`default_nettype none
// Wishbone classic single-transfer adapter to SQuARE register peripheral.
// System interconnect decodes this peripheral's address window.
module square_wishbone_adapter (
 input wire clk, rst,
 input wire cyc_i, stb_i, we_i,
 input wire [31:0] adr_i, dat_i,
 output wire [31:0] dat_o,
 output wire ack_o
);
 reg pending, request_pulse, ack_reg, we_hold;
 reg [7:0] addr_hold;
 reg [31:0] data_hold, read_reg;
 wire peripheral_ack;
 wire [31:0] peripheral_data;
 always @(posedge clk or posedge rst) begin
  if (rst) begin
   pending<=0; request_pulse<=0; ack_reg<=0;
   we_hold<=0; addr_hold<=0; data_hold<=0; read_reg<=0;
  end else begin
   request_pulse<=0;
   ack_reg<=0;
   if (!pending && cyc_i && stb_i) begin
    pending<=1;
    request_pulse<=1;
    addr_hold<=adr_i[7:0];
    data_hold<=dat_i;
    we_hold<=we_i;
   end
   if (pending && peripheral_ack) begin
    pending<=0;
    ack_reg<=1;
    read_reg<=peripheral_data;
   end
  end
 end
 assign ack_o=ack_reg;
 assign dat_o=read_reg;
 square_mac_peripheral u_square (
  .clk(clk), .rst_n(~rst), .req(request_pulse), .we(we_hold),
  .addr(addr_hold), .wdata(data_hold),
  .rdata(peripheral_data), .ack(peripheral_ack)
 );
endmodule
`default_nettype wire
