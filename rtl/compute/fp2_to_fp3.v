// =====================================================================
// fp2_to_fp3.v
//
// Typecasts an external FP2 operand into the internal, format-unified
// FP3 representation {sign, E, M}:
//
//   E=0, M=0 -> 0
//   E=0, M=1 -> 0.5
//   E=1, M=0 -> 1.0
//   E=1, M=1 -> 1.5
//
// ---- External FP2 operand encoding: precise statement ----
// Each FP2 operand at this module's boundary consists of TWO separate
// things, and it is important not to blur them together:
//   (a) a STRICT 2-bit FP2 VALUE code, {sign, bit}          (sign_in, bit_in)
//   (b) a SEPARATE 1-bit zero-mask/control signal            (zero_in)
// The complete operand as presented to fp2_parallel_mac_ref.v is these
// 3 bits together. Do NOT describe the external operand as "2 bits
// total" -- that is only true of the VALUE code in isolation; zero_in
// is real control information the caller must supply, not free. If a
// use case requires strict 2-bit TOTAL operand storage (value+zero
// folded into 2 bits with no separate control line), this interface
// must change, or the zero-mask must be accounted for as external
// sparsity/mask overhead elsewhere in the system (e.g. a shared
// per-tile "which lanes are pruned" bitmap upstream of this module,
// rather than a dedicated wire per operand) -- it cannot simply be
// omitted from the bit-cost accounting.
//
// Why the value code alone is strictly 2 bits, no more, and why zero
// genuinely cannot be folded in without either a separate mask or a
// packed-pair encoding: count the values each mode actually needs,
// INCLUDING zero:
//   E1M0 needs {0, +0.5, -0.5, +1, -1}  -- 5 distinct values
//   E0M1 needs {0, +1, -1, +1.5, -1.5}  -- 5 distinct values
// A strict 2-bit code has exactly 4 states -- one short of the 5
// needed either way. The 4 nonzero values already consume all 4 codes
// (2 magnitudes x 2 signs), leaving no 5th code for zero. This is not
// a design choice that could be tightened; it is a counting fact about
// 2 bits vs. 5 values. The only ways to represent all 5 values per
// mode are: (a) add a bit of information from somewhere -- here, a
// separate zero-mask signal per lane (adds 1 bit/lane, giving 3 bits/
// lane total, exactly what this module's port list reflects), or
// (b) the original paper's packed-pair encoding, which gets zero "for
// free" by spending a 2-bit flag across a PAIR of values rather than
// 1 bit per value (Sec. 1.4 of docs/DESIGN_NOTES.md) -- a different
// bit-cost trade entirely, not directly comparable to this module's
// per-lane cost without accounting for both approaches' actual total
// bits per represented value.
//
// If you are ever comparing storage/bandwidth against another format
// or against the packed-pair encoding, COUNT THE ZERO-MASK BIT
// SEPARATELY from the 2-bit value code -- e.g. state costs as
// "2 bits/lane value + 1 bit/lane zero-mask = 3 bits/lane," not
// "2 bits/lane." Folding the mask into an unstated "2 bits total"
// figure would understate this interface's real bit cost.
//
// ---- Decode table: FP2-E1M0 (fmt_sel=0) ----
//   zero=1          -> 0
//   zero=0, bit=0   -> +-1.0   (sign decides +/-)
//   zero=0, bit=1   -> +-0.5   (sign decides +/-)
//
// ---- Decode table: FP2-E0M1 (fmt_sel=1) ----
//   zero=1          -> 0
//   zero=0, bit=0   -> +-1.0   (sign decides +/-)
//   zero=0, bit=1   -> +-1.5   (sign decides +/-)
//
// Useful consequence unchanged from before: mag2x (= 2 x the real
// magnitude) is simply {E,M} read as a 2-bit unsigned integer.
// =====================================================================
module fp2_to_fp3 (
    input  wire sign_in,     // bit 1 of the strict 2-bit FP2 VALUE code
    input  wire bit_in,      // bit 0 of the strict 2-bit FP2 VALUE code
    input  wire zero_in,     // SEPARATE zero-mask/control bit, not part of the value code
    input  wire fmt_sel,     // 0 = E1M0, 1 = E0M1 (shared across the MAC op)
    output wire fp3_sign,
    output wire fp3_e,
    output wire fp3_m
);
    assign fp3_sign = zero_in ? 1'b0 : sign_in;
    assign fp3_e     = zero_in ? 1'b0 : (fmt_sel ? 1'b1 : ~bit_in);
    assign fp3_m     = zero_in ? 1'b0 : bit_in;  // M=bit_in in both modes (see tables above)
endmodule

