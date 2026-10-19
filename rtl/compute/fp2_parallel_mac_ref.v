// =====================================================================
// fp2_parallel_mac_ref.v
//
`timescale 1ns/1ps

// CLASSIFICATION: independent TWO-LANE FP2 reference MAC. Operands
// (a0,a1,w0,w1) are unrelated -- no packed-pair C-flag relationship
// between lanes. NOT directly comparable to fp2_pair_kfactor_mac.v /
// fp2_pair_kfactor_signed_mac.v (optimized PACKED-PAIR FP2 MACs, valid
// only for that different input encoding) without first proving
// equivalence via a testbench. See docs/DESIGN_NOTES.md Sec. 6.4 for
// why the packed-pair K-factor trick doesn't have an analogous form
// here.
//
// Reference (unoptimized, straightforward) two-lane FP2xFP2 parallel
// MAC:  acc_next = acc_old + a0*w0 + a1*w1
//
// Both lanes are INDEPENDENT FP2 operands -- no C-flag relationship
// between lane 0 and lane 1, no shared block exponent scaling.
//
// ---- Operand encoding: STRICTLY 2 bits per FP2 value ----
// Each of a0,a1,w0,w1 is a strict 2-bit code {sign,bit}. Zero is a
// SEPARATE, explicit 1-bit control per lane (a0_zero, a1_zero,
// w0_zero, w1_zero), not part of the 2-bit value -- see fp2_to_fp3.v
// for why a 2-bit value code has no room left for a zero state of its
// own (both modes' nonzero value sets already use all 4 codes).
//
// ---- Adaptive fixed-point scaling (no hardcoded <<6) ----
// mag2x_x = 2 * |x| (0,1,2,3) is {E,M} from FP3 read as an unsigned
// integer -- no lookup needed. Lanes are summed BEFORE scaling (valid
// since scaling distributes over addition), needing one shifter
// instead of two:
//     pair_sum_native = sign(p0)*mag2x(a0)*mag2x(w0)
//                     + sign(p1)*mag2x(a1)*mag2x(w1)   (native x4 scale)
//     partial_fxp     = pair_sum_native * 2^(frac_bits - 2)
//
// UPDATED for safety across the full frac_bits port range (previously
// flagged: frac_bits<2 underflowed an unsigned subtraction, and large
// frac_bits could overflow a too-narrow intermediate before saturation
// logic ran):
//   - the shift amount is computed as a genuinely SIGNED quantity, so
//     frac_bits < 2 correctly produces a RIGHT shift instead of
//     wrapping into a huge left shift;
//   - the intermediate is widened to 48 bits, comfortably covering
//     every value the frac_bits port can express (up to 2^FRAC_W - 1)
//     without internal overflow ahead of the saturation compare.
//
// ---- Saturating accumulation into adaptive signed fxpN (default N=16) ----
// Saturate, not wrap (per spec preference for NN MAC correctness).
// `overflow` is a per-cycle flag, meaningful exactly when valid_out=1;
// it is explicitly cleared (not left stale) whenever valid_in=0.
//
// ---- Usage contract: frac_bits and fmt_sel must stay constant across
// one dot product (from a clear_acc+valid_in cycle through to the next
// clear_acc+valid_in cycle) ----
// Changing either mid-accumulation mixes different binary-point
// positions (or different value tables) into the same running sum,
// which is not meaningful. This is enforced with a SIMULATION-ONLY
// warning (no synthesized hardware) below, guarded by
// `synthesis translate_off/on` -- it will not affect synthesis results
// but will flag misuse during simulation.
// =====================================================================
// ---- fxp8 output (MSB-8 window over the internal wide accumulator) ----
// Per mentor guidance: FP2's accumulator should present an 8-bit
// ("fxp8") result, but internally compute wider so a full dot product
// doesn't lose precision on every single accumulation step -- unlike a
// naive ACC_W=8 instantiation, which would need to saturate on nearly
// every add given the format's already-tight value range. `acc`
// (unchanged, 16-bit by default, exactly as before) remains the full-
// precision internal result; `acc_fxp8` is a NEW, additional output
// taking just the top 8 bits of that same value (`acc >>> 8`, an
// arithmetic right shift -- equivalent to a plain bit-select of
// acc[ACC_W-1:ACC_W-8] for a two's-complement value, sign-extension
// included for free). No separate saturation logic needed at this
// stage: it's a bit-selection of an already-in-range value, not a new
// computation that could itself overflow. No rounding added, matching
// this package's consistent no-rounding convention elsewhere.
// =====================================================================
module fp2_parallel_mac_ref #(
    parameter ACC_W  = 16,   // accumulator width ("adaptive fxpN")
    parameter FRAC_W = 5     // width of the frac_bits input port (0..31)
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      clear_acc,   // starts a new dot product (see below)
    input  wire                      valid_in,
    input  wire                      fmt_sel,     // 0 = E1M0, 1 = E0M1, must stay constant per dot product
    input  wire [FRAC_W-1:0]         frac_bits,   // adaptive fractional-bit count, must stay constant per dot product
    input  wire [1:0]                a0, a1,      // STRICT 2-bit {sign,bit} FP2 code, lane 0/1
    input  wire [1:0]                w0, w1,
    input  wire                      a0_zero, a1_zero,  // separate per-lane zero control (not part of the 2-bit code)
    input  wire                      w0_zero, w1_zero,
    output reg  signed [ACC_W-1:0]   acc,
    output reg                       valid_out,
    output reg                       overflow,     // this cycle's result saturated; 0 whenever valid_out=0
    output wire signed [7:0]         acc_fxp8      // NEW: MSB-8 window over acc (see header note)
);

    // ---- typecast all four operands to internal FP3 ----
    wire s_a0, e_a0, m_a0;
    wire s_a1, e_a1, m_a1;
    wire s_w0, e_w0, m_w0;
    wire s_w1, e_w1, m_w1;

    fp2_to_fp3 u_a0 (.sign_in(a0[1]), .bit_in(a0[0]), .zero_in(a0_zero), .fmt_sel(fmt_sel),
                      .fp3_sign(s_a0), .fp3_e(e_a0), .fp3_m(m_a0));
    fp2_to_fp3 u_a1 (.sign_in(a1[1]), .bit_in(a1[0]), .zero_in(a1_zero), .fmt_sel(fmt_sel),
                      .fp3_sign(s_a1), .fp3_e(e_a1), .fp3_m(m_a1));
    fp2_to_fp3 u_w0 (.sign_in(w0[1]), .bit_in(w0[0]), .zero_in(w0_zero), .fmt_sel(fmt_sel),
                      .fp3_sign(s_w0), .fp3_e(e_w0), .fp3_m(m_w0));
    fp2_to_fp3 u_w1 (.sign_in(w1[1]), .bit_in(w1[0]), .zero_in(w1_zero), .fmt_sel(fmt_sel),
                      .fp3_sign(s_w1), .fp3_e(e_w1), .fp3_m(m_w1));

    // ---- mag2x is just {E,M} as a 2-bit unsigned integer ----
    wire [1:0] mag2x_a0 = {e_a0, m_a0};
    wire [1:0] mag2x_a1 = {e_a1, m_a1};
    wire [1:0] mag2x_w0 = {e_w0, m_w0};
    wire [1:0] mag2x_w1 = {e_w1, m_w1};

    // ---- two independent products ----
    wire [3:0] prod0_mag = mag2x_a0 * mag2x_w0;   // 0..9
    wire [3:0] prod1_mag = mag2x_a1 * mag2x_w1;
    wire       prod0_sign = s_a0 ^ s_w0;
    wire       prod1_sign = s_a1 ^ s_w1;

    wire signed [5:0] p0_signed = prod0_sign ? -$signed({2'b00, prod0_mag}) : $signed({2'b00, prod0_mag});
    wire signed [5:0] p1_signed = prod1_sign ? -$signed({2'b00, prod1_mag}) : $signed({2'b00, prod1_mag});

    wire signed [6:0] pair_sum_native = p0_signed + p1_signed;   // range -18..18

    // ---- adaptive scaling: genuinely signed shift amount, safe for the
    //      full frac_bits port range in both directions ----
    localparam WIDE_W = 48;   // comfortably covers every frac_bits the port can express
    wire signed [FRAC_W+2:0] shift_signed = $signed({3'b000, frac_bits}) - 3'sd2; // frac_bits - 2, signed
    wire signed [WIDE_W-1:0] pair_sum_ext = {{(WIDE_W-7){pair_sum_native[6]}}, pair_sum_native};
    wire signed [WIDE_W-1:0] partial_fxp  =
        (shift_signed >= 0) ? (pair_sum_ext <<< shift_signed)
                             : (pair_sum_ext >>> (-shift_signed));

    // ---- saturating accumulate ----
    wire signed [WIDE_W-1:0] acc_ext  = {{(WIDE_W-ACC_W){acc[ACC_W-1]}}, acc};
    wire signed [WIDE_W-1:0] sum_wide = clear_acc ? partial_fxp : (acc_ext + partial_fxp);

    localparam signed [WIDE_W-1:0] SAT_MAX = (1 <<< (ACC_W-1)) - 1;
    localparam signed [WIDE_W-1:0] SAT_MIN = -(1 <<< (ACC_W-1));

    wire ovf_pos = (sum_wide > SAT_MAX);
    wire ovf_neg = (sum_wide < SAT_MIN);
    wire signed [ACC_W-1:0] sum_saturated =
        ovf_pos ? SAT_MAX[ACC_W-1:0] :
        ovf_neg ? SAT_MIN[ACC_W-1:0] :
                  sum_wide[ACC_W-1:0];

    // ---- clocked update ----
    // Convention (matches every other MAC in this package): clear_acc
    // takes effect on the SAME cycle valid_in is asserted, marking that
    // cycle's product as the first of a new dot product (old acc
    // discarded). clear_acc without valid_in does nothing (acc holds).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc       <= {ACC_W{1'b0}};
            valid_out <= 1'b0;
            overflow  <= 1'b0;
        end else begin
            if (valid_in) begin
                acc       <= sum_saturated;
                overflow  <= ovf_pos | ovf_neg;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
                overflow  <= 1'b0;   // meaningful only alongside valid_out=1
            end
        end
    end

    // ---- fxp8 MSB-window derived output ----
    // acc[ACC_W-1:ACC_W-8] is the top 8 bits of whatever width ACC_W
    // actually is (defaults to acc[15:8] at the default ACC_W=16) --
    // written generically so this stays correct if ACC_W is ever
    // overridden to something other than 16, as long as it's >= 8.
    assign acc_fxp8 = acc[ACC_W-1:ACC_W-8];

    // ---- SIMULATION-ONLY usage-contract check: frac_bits/fmt_sel must
    // not change mid-accumulation. No synthesized hardware; purely a
    // simulation warning to catch misuse. ----
    // synthesis translate_off
    reg [FRAC_W-1:0] frac_bits_latched;
    reg              fmt_sel_latched;
    reg              in_dot_product;

    initial begin
        in_dot_product = 1'b0;
        frac_bits_latched = {FRAC_W{1'b0}};
        fmt_sel_latched = 1'b0;
    end

    always @(posedge clk) begin
        if (valid_in) begin
            if (clear_acc) begin
                frac_bits_latched <= frac_bits;
                fmt_sel_latched   <= fmt_sel;
                in_dot_product    <= 1'b1;
            end else if (in_dot_product) begin
                if (frac_bits !== frac_bits_latched)
                    $display("WARNING [t=%0t]: frac_bits changed mid-accumulation (was %0d, now %0d) -- results are undefined per this module's usage contract (frac_bits must stay constant across one dot product; change it only together with clear_acc)",
                              $time, frac_bits_latched, frac_bits);
                if (fmt_sel !== fmt_sel_latched)
                    $display("WARNING [t=%0t]: fmt_sel changed mid-accumulation (was %0d, now %0d) -- results are undefined per this module's usage contract (fmt_sel must stay constant across one dot product; change it only together with clear_acc)",
                              $time, fmt_sel_latched, fmt_sel);
            end
        end
    end
    // synthesis translate_on

endmodule
