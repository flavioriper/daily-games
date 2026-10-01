#!/usr/bin/env python3
"""Mines Rings' Insane bank: Tumble deals (content/insane/rings.json).

A Tumble ring is two-tone -- a top colour and an under colour, packed as
`top | (under + 1) << 3` (a plain ring is just its colour, 0-5, exactly as
on every other band) -- and lifting it turns it over. A deal is six colours of
four rings dealt over seven pegs, six of the rings two-tone (their unders a
derangement of their tops, so every colour still has four tops and four
unders). A deal is kept only once the board's own depth-first search
(puzzles/rings_gen.gd, the same moves in the same order) sorts it within
PROOF nodes, and it opens with no peg already home.

Live dealing would cost ~48 tries a day at up to PROOF nodes each in GDScript,
so the deals are mined here and shipped, as the old move-budget bank was.

    python3 tools/insane/rings_tumble_mine.py [count]
"""
import json, random, sys
from multiprocessing import Pool

sys.setrecursionlimit(100000)
CAP, COLOURS, PEGS, TWO_TONE, PROOF = 4, 6, 7, 6, 20000


def top(c): return c & 7
def flip(c): return c if c < 8 else ((c >> 3) - 1) | ((c & 7) + 1) << 3
def locked(p): return len(p) == CAP and all(top(c) == top(p[0]) for c in p)
def solved(P): return all(not p or locked(p) for p in P)


def moves(P):
    out = []
    for i, s in enumerate(P):
        if not s or locked(s):
            continue
        r = flip(s[-1])
        for j, d in enumerate(P):
            if i == j or len(d) >= CAP:
                continue
            if not d:
                if len(s) == 1 and r == s[-1]:
                    continue
                out.append((2, i, j))
                continue
            if top(d[-1]) != top(r):
                continue
            fin = len(d) + 1 == CAP and all(top(c) == top(r) for c in d)
            out.append((0 if fin else 1, i, j))
    out.sort(key=lambda m: m[0])
    return [(i, j) for _, i, j in out]


def solve(P, budget):
    P = [list(p) for p in P]
    seen, n, path = set(), [0], []

    def dfs():
        if solved(P):
            return True
        n[0] += 1
        if n[0] > budget:
            return False
        k = tuple(sorted(tuple(p) for p in P))
        if k in seen:
            return False
        seen.add(k)
        for i, j in moves(P):
            P[j].append(flip(P[i].pop()))
            path.append((i, j))
            if dfs():
                return True
            path.pop()
            P[i].append(flip(P[j].pop()))
            if n[0] > budget:
                return False
        return False
    return (path if dfs() else None), n[0]


def deal(rng):
    tops = [c for c in range(COLOURS) for _ in range(CAP)]
    rng.shuffle(tops)
    unders = tops[:]
    while True:
        pick = rng.sample(range(len(tops)), TWO_TONE)
        vals = [tops[i] for i in pick]
        rng.shuffle(vals)
        if all(v != tops[i] for i, v in zip(pick, vals)):
            break
    for i, v in zip(pick, vals):
        unders[i] = v
    rings = [t if t == u else t | (u + 1) << 3 for t, u in zip(tops, unders)]
    sizes = [len(rings) // PEGS + (1 if i < len(rings) % PEGS else 0) for i in range(PEGS)]
    rng.shuffle(sizes)
    P, at = [], 0
    for s in sizes:
        P.append(rings[at:at + s])
        at += s
    return P


def mine(seed):
    rng = random.Random(seed)
    while True:
        P = deal(rng)
        if solved(P) or any(locked(p) for p in P):
            continue
        path, n = solve(P, PROOF)
        if path and n >= 200:
            return {"pegs": P, "grade": {"work": n, "line": len(path)}}


if __name__ == "__main__":
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    with Pool() as pool:
        boards = pool.map(mine, range(1000, 1000 + count))
    doc = {"version": 2, "note": "Rings Insane: Tumble deals (top | (under + 1) << 3, plain rings 0-5), six two-tone rings over seven pegs, proved by the board's DFS within %d nodes. tools/insane/rings_tumble_mine.py" % PROOF, "boards": boards}
    with open("content/insane/rings.json", "w") as f:
        json.dump(doc, f, indent=1)
    print("mined", len(boards))
