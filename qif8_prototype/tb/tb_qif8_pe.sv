\`timescale 1ns/1ps
module tb_qif8_pe;
    logic clk=0; always #5 clk=~clk;
    logic rst_n=0,syn_valid=0,fire_valid=0;
    logic [23:0] syn_time=0,fire_time=0;
    logic signed [7:0] syn_weight=0;
    wire accepted,rejected,spike_valid;
    wire [23:0] spike_time,next_spike_time,last_time;
    wire [7:0] phase_state;
    integer test_count=0;
    qif8_pe dut (.*);
    task automatic syn(input integer t,input integer w,input bit expect_accept);
        @(negedge clk); syn_time=24'(t); syn_weight=8'(w); syn_valid=1;
        @(posedge clk); #1;
        if (accepted!==expect_accept || rejected===expect_accept)
            $fatal(1,"Unexpected syn acceptance t=%0d w=%0d",t,w);
        test_count=test_count+1;
        @(negedge clk); syn_valid=0;
    endtask
    task automatic fire(input integer t,input bit expect_accept);
        @(negedge clk); fire_time=24'(t); fire_valid=1;
        @(posedge clk); #1;
        if (accepted!==expect_accept || spike_valid!==expect_accept)
            $fatal(1,"Unexpected fire t=%0d",t);
        if(expect_accept && spike_time!==24'(t)) $fatal(1,"Wrong spike time");
        test_count=test_count+1;
        @(negedge clk); fire_valid=0;
    endtask
    initial begin
        repeat (3) @(negedge clk); rst_n=1;
        if(next_spike_time!==24'd256) $fatal(1,"Incorrect reset");
        syn(30,0,1);
        if(next_spike_time!==24'd256) $fatal(1,"Identity failed");
        syn(60,16,1);
        if(next_spike_time>=24'd256) $fatal(1,"Excitation failed");
        syn(300,0,0);
        fire(next_spike_time,1);
        syn(last_time+10,-16,1);
        if(next_spike_time<=last_time+24'd246) $fatal(1,"Inhibition failed");
        fire(next_spike_time,1);
        $display("PASS: %0d transactions", test_count);
        $finish;
    end
endmodule
