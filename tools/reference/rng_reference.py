#!/usr/bin/env python3
"""
Reference implementation of Deathworlders' deterministic primitives (M1 Plan WP2).
The GDScript versions in sim/core/ MUST reproduce these outputs exactly (see vectors.json).

All values are 32-bit unsigned; every multiplication keeps intermediates below 2^62
because GDScript ints are signed 64-bit and must never overflow.
Run:  python3 rng_reference.py > vectors.json
"""
import json
M32 = 0xFFFFFFFF

def mul32(a, b):
    """(a*b) mod 2^32 with no intermediate >= 2^48."""
    a &= M32; b &= M32
    lo = a * (b & 0xFFFF)
    hi = (a * (b >> 16)) & 0xFFFF
    return (lo + (hi << 16)) & M32

def rotl32(x, k):
    x &= M32
    return ((x << k) | (x >> (32 - k))) & M32

FNV_OFFSET, FNV_PRIME = 0x811C9DC5, 0x01000193
def fnv1a32_bytes(data, h=FNV_OFFSET):
    for byte in data:
        h ^= byte
        h = (h * FNV_PRIME) & M32
    return h
def fnv1a32_str(s): return fnv1a32_bytes(s.encode("utf-8"))
def fnv1a32_int(v, h=FNV_OFFSET):
    """Signed 64-bit int hashed as 8 little-endian two's-complement bytes."""
    return fnv1a32_bytes((v & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little"), h)

def mix32(z):
    """MurmurHash3 fmix32."""
    z &= M32
    z ^= z >> 16; z = mul32(z, 0x85EBCA6B)
    z ^= z >> 13; z = mul32(z, 0xC2B2AE35)
    z ^= z >> 16
    return z

class SplitMix32:
    def __init__(self, seed): self.s = seed & M32
    def next(self):
        self.s = (self.s + 0x9E3779B9) & M32
        return mix32(self.s)

class Xoshiro128ss:
    def __init__(self, s0, s1, s2, s3):
        self.s = [s0 & M32, s1 & M32, s2 & M32, s3 & M32]
        if not any(self.s): self.s[0] = 1
    @classmethod
    def from_seed(cls, match_seed, stream_name):
        sm = SplitMix32((match_seed & M32) ^ fnv1a32_str(stream_name))
        return cls(sm.next(), sm.next(), sm.next(), sm.next())
    def next_u32(self):
        s = self.s
        result = (rotl32((s[1] * 5) & M32, 7) * 9) & M32
        t = (s[1] << 9) & M32
        s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3]
        s[2] ^= t; s[3] = rotl32(s[3], 11)
        return result
    def range(self, lo, hi):
        """Uniform int in [lo, hi), rejection sampling (no modulo bias)."""
        n = hi - lo
        limit = (1 << 32) - ((1 << 32) % n)
        while True:
            r = self.next_u32()
            if r < limit: return lo + (r % n)
    def get_state(self): return list(self.s)

def match_seed_from_text(t): return fnv1a32_str(t)

if __name__ == "__main__":
    out = {"fnv1a32": {s: fnv1a32_str(s) for s in ["", "a", "galaxy", "combat", "core:hull/human_cruiser_mk1", "Deathworlders"]},
           "fnv1a32_int": {str(v): fnv1a32_int(v) for v in [0, 1, -1, 123456789, -9876543210]},
           "mul32": [{"a": a, "b": b, "result": mul32(a, b)} for a, b in [(0xFFFFFFFF, 0xFFFFFFFF), (0x85EBCA6B, 0x12345678), (123456789, 987654321)]],
           "mix32": {str(z): mix32(z) for z in [0, 1, 0xDEADBEEF, 0xFFFFFFFF]},
           "xoshiro128ss": {}, "range": {},
           "match_seed_from_text": {t: match_seed_from_text(t) for t in ["hello", "HFY", "Sol forever"]}}
    for seed, stream in [(1, "galaxy"), (1, "combat"), (42, "galaxy"), (0xFFFFFFFF, "events")]:
        r = Xoshiro128ss.from_seed(seed, stream)
        out["xoshiro128ss"][f"{seed}:{stream}"] = {"initial_state": r.get_state(), "first_10": [r.next_u32() for _ in range(10)]}
    r = Xoshiro128ss.from_seed(7, "combat")
    out["range"]["7:combat range(0,1000) x10"] = [r.range(0, 1000) for _ in range(10)]
    out["range"]["then range(850,1151) x5"] = [r.range(850, 1151) for _ in range(5)]
    assert all(m["result"] == (m["a"] * m["b"]) & M32 for m in out["mul32"])
    assert out["fnv1a32"][""] == 0x811C9DC5 and out["fnv1a32"]["a"] == 0xE40C292C
    print(json.dumps(out, indent=2))
