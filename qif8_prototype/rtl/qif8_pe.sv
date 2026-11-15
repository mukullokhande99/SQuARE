// Single logical event-driven QIF neuron, 8-bit phase, 24-bit timestamps.
// External scheduler must issue every predicted autonomous firing before any
// later synaptic event. One transaction per clock; no network scheduler here.
module qif8_pe #(
    parameter integer TIME_W = 24,
    parameter ROM_FILE = "rtl/qif_h8.mem"
) (
    input logic clk, rst_n,
    input logic syn_valid,
    input logic [TIME_W-1:0] syn_time,
    input logic signed [7:0] syn_weight,
    input logic fire_valid,
    input logic [TIME_W-1:0] fire_time,
    output logic accepted, rejected, spike_valid,
    output logic [TIME_W-1:0] spike_time, next_spike_time, last_time,
    output logic [7:0] phase_state
);
    logic [TIME_W-1:0] delta;
    logic [7:0] phase_before, phase_after;
    logic [TIME_W:0] next_syn_full, next_fire_full;
    logic syn_ok, fire_ok;

    assign delta = syn_time - last_time;
    assign syn_ok = syn_valid && !fire_valid &&
        (syn_time >= last_time) && (syn_time < next_spike_time) &&
        (delta < TIME_W'(256));
    assign fire_ok = fire_valid && !syn_valid &&
        (fire_time == next_spike_time);
    assign phase_before = phase_state + delta[7:0];
    qif_h8_rom #(.ROM_FILE(ROM_FILE)) table_unit (
        .phase_in(phase_before), .weight_in(syn_weight), .phase_out(phase_after)
    );
    assign next_syn_full = {1'b0,syn_time} +
        ((TIME_W+1)'(256) - (TIME_W+1)'(phase_after));
    assign next_fire_full = {1'b0,fire_time} + (TIME_W+1)'(256);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_state <= 8'd0;
            last_time <= '0;
            next_spike_time <= TIME_W'(256);
            spike_time <= '0;
            spike_valid <= 1'b0;
            accepted <= 1'b0;
            rejected <= 1'b0;
        end else begin
            spike_valid <= 1'b0;
            accepted <= 1'b0;
            rejected <= 1'b0;
            if (syn_valid || fire_valid) begin
                if (syn_ok && !next_syn_full[TIME_W]) begin
                    phase_state <= phase_after;
                    last_time <= syn_time;
                    next_spike_time <= next_syn_full[TIME_W-1:0];
                    accepted <= 1'b1;
                end else if (fire_ok && !next_fire_full[TIME_W]) begin
                    phase_state <= 8'd0;
                    last_time <= fire_time;
                    next_spike_time <= next_fire_full[TIME_W-1:0];
                    spike_time <= fire_time;
                    spike_valid <= 1'b1;
                    accepted <= 1'b1;
                end else begin
                    rejected <= 1'b1;
                end
            end
        end
    end
endmodule
