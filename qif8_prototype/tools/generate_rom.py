#!/usr/bin/env python3
"""Generate 8-bit QIF phase-transition ROM from Wan et al. Eq. (6)-(10)."""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[1]
I0 = 1.25
A = math.sqrt(I0 - 0.25)
SCALE = 16.0

def transition(phase, signed_weight):
    if signed_weight == 0:
        return phase
    u = (phase + 0.5) / 256.0
    voltage = 0.5 + A * math.tan(math.pi * (u - 0.5))
    after = voltage + signed_weight / SCALE
    fraction = (math.atan((after - 0.5) / A) + math.pi / 2) / math.pi
    return max(0, min(255, int(math.floor(fraction * 256))))

def main():
    rom = ROOT / "rtl" / "qif_h8.mem"
    with rom.open("w") as f:
        for w_raw in range(256):
            w = w_raw if w_raw < 128 else w_raw - 256
            for phase in range(256):
                f.write(f"{transition(phase, w):02x}\n")
    print(f"Wrote {rom}: {rom.stat().st_size} bytes, 65536 entries")
    assert all(transition(p, 0) == p for p in range(256))
    assert all(transition(p, w) <= transition(p+1, w)
               for w in range(-128,128) for p in range(255))
    assert all(transition(p, w) <= transition(p, w+1)
               for w in range(-128,127) for p in range(256))
    print("PASS: identity and monotonicity")

if __name__ == "__main__":
    main()
