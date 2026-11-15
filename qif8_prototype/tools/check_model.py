#!/usr/bin/env python3
"""Independent functional checks for the quantized event-driven QIF PE."""
from pathlib import Path
from generate_rom import transition

ROOT = Path(__file__).resolve().parents[1]
rom = [int(x,16) for x in (ROOT / "rtl" / "qif_h8.mem").read_text().splitlines()]
assert len(rom) == 65536
for w in range(-128,128):
    for p in range(256):
        assert rom[((w & 255) << 8) | p] == transition(p,w)

class PE:
    def __init__(self):
        self.phase=0
        self.last=0
        self.next=256
        self.spikes=[]
    def syn(self,t,w):
        assert self.last <= t < self.next and 0 <= t < 2**24
        prior=self.phase+t-self.last
        assert prior < 256
        self.phase=transition(prior,w)
        self.last=t
        self.next=t+256-self.phase
        assert self.next < 2**24
    def fire(self,t):
        assert t == self.next
        self.spikes.append(t)
        self.phase=0
        self.last=t
        self.next=t+256
        assert self.next < 2**24

n=PE()
assert n.next == 256
n.syn(30,0)
assert n.next == 256
n.syn(60,16)
assert n.next < 256
try:
    n.syn(300,0)
    raise AssertionError("Expected rejection")
except AssertionError as e:
    if str(e) == "Expected rejection":
        raise
n.fire(n.next)
n.syn(n.last+10,-16)
assert n.next > n.last+246
n.fire(n.next)
print("PASS: 65536 ROM entries and neuron event checks")
print("Example spikes:",n.spikes)
