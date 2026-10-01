#!/usr/bin/env python3
"""Mines Knight's Insane bank: Brambles boards (content/insane/knight.json).

Brambles (spec docs/superpowers/specs/2026-10-01-knight-polish-design.md,
section 3): every square your knight hops off grows a bramble, and nothing
lands on a bramble again -- not you, not a rose knight. A rose knight with
no square left to hop to is fenced in and naps for the rest of the day; a
napping knight catches no one and can be taken. These are the rules of
puzzles/knight_gen.gd's `step` with `brambles` on, line for line.

A board: 8x8, the king, three or four rose knights within two Ls of him, you
at least four Ls away and out of reach, the naive line (always hop nearest
the king) failing. Kept when the shortest line (breadth first, exact) is at
least MIN_LINE long, or at least NAP_LINE when it needs a nap (no line
without one), and at most MAX_LINES winning lines of up to two moves more
exist. Ranked by the line's length, a nap counting six moves. Measured
2026-10-01: 400000 tries, 36 s on 8 cores, 3613 found; the 200 kept have
lines of 14-30 and 46 need a nap. The bank is re-proved in GDScript by
tests/_probe_knight_bank.gd.

    python3 tools/insane/knight_bramble_mine.py [count] [tries]
"""
import json, random, sys
from collections import deque
from multiprocessing import Pool

W, FAR, MIN_LINE, MAX_LINES, NAP_LINE = 8, 4, 12, 12, 10
NAP = 1000
DX = [1, 2, 2, 1, -1, -2, -2, -1]
DY = [-2, -1, 1, 2, 2, 1, -1, -2]


def _hops():
    t = []
    for c in range(W * W):
        x, y = c % W, c // W
        t.append([(y + DY[i]) * W + x + DX[i] for i in range(8)
                  if 0 <= x + DX[i] < W and 0 <= y + DY[i] < W])
    return t


HT = _hops()


def _dist():
    out = []
    for s in range(W * W):
        d = [99] * (W * W)
        d[s] = 0
        q = [s]
        for c in q:
            for m in HT[c]:
                if d[m] == 99:
                    d[m] = d[c] + 1
                    q.append(m)
        out.append(d)
    return out


D = _dist()


def sq(f):
    return f - NAP if f >= NAP else f


def step(king, foes, to, mask):
    """mask already holds the square just hopped off."""
    fs = list(foes)
    if to == king:
        return 'won', fs, []
    for i, f in enumerate(fs):
        if f >= 0 and sq(f) == to:
            fs[i] = -1
    napped = []
    for i in range(len(fs)):
        f = fs[i]
        if f < 0 or f >= NAP:
            continue
        if to in HT[f]:
            return 'caught', fs, []
        occ = {sq(x) for x in fs if x >= 0}
        best, bd = -1, 99
        for m in HT[f]:
            if m == king or m in occ or (mask >> m) & 1:
                continue
            if D[m][to] < bd:
                bd, best = D[m][to], m
        if best >= 0:
            fs[i] = best
        else:
            fs[i] = f + NAP
            napped.append(i)
    return 'ok', fs, napped


def legal(you, mask):
    return [m for m in HT[you] if not (mask >> m) & 1]


def solve(king, you, foes, naps=True, cap=64):
    root = (you, tuple(foes), 0)
    par = {root: None}
    q = deque([(root, 0)])
    while q:
        (y, fs, mask), dep = q.popleft()
        if dep >= cap:
            continue
        nm = mask | (1 << y)
        for m in legal(y, mask):
            r, nf, napped = step(king, fs, m, nm)
            if r == 'caught' or (napped and not naps):
                continue
            if r == 'won':
                line, k = [m], (y, fs, mask)
                while par[k] is not None:
                    k, mv = par[k]
                    line.insert(0, mv)
                return line
            nk = (m, tuple(nf), nm)
            if nk not in par:
                par[nk] = ((y, fs, mask), m)
                q.append((nk, dep + 1))
    return []


def count_lines(king, you, foes, cap):
    memo = {}

    def go(y, fs, mask, left):
        if left == 0:
            return 0
        k = (y, fs, mask, left)
        if k in memo:
            return memo[k]
        tot, nm = 0, mask | (1 << y)
        for m in legal(y, mask):
            r, nf, _ = step(king, fs, m, nm)
            if r == 'won':
                tot += 1
            elif r == 'ok':
                tot += go(m, tuple(nf), nm, left - 1)
        memo[k] = tot
        return tot
    return go(you, tuple(foes), 0, cap)


def naive_wins(king, you, foes):
    mask, fs = 0, list(foes)
    for _ in range(W * W):
        lg = legal(you, mask)
        if not lg:
            return False
        best = min(lg, key=lambda m: (D[m][king], HT[you].index(m)))
        mask |= 1 << you
        r, fs, _ = step(king, fs, best, mask)
        if r != 'ok':
            return r == 'won'
        you = best
    return False


def try_one(seed):
    rng = random.Random(seed)
    nf = rng.choice([3, 4])
    cells = list(range(W * W))
    rng.shuffle(cells)
    king = cells[0]
    foes = [c for c in cells if c != king and D[king][c] <= 2][:nf]
    you = next((c for c in cells if c != king and c not in foes and D[c][king] >= FAR), -1)
    if len(foes) < nf or you < 0 or any(you in HT[f] for f in foes):
        return None
    if naive_wins(king, you, foes):
        return None
    line = solve(king, you, foes)
    if len(line) < NAP_LINE:
        return None
    nap = not solve(king, you, foes, naps=False)
    if len(line) < MIN_LINE and not nap:
        return None
    lines = count_lines(king, you, foes, len(line) + 2)
    if lines > MAX_LINES:
        return None
    return {"king": king, "you": you, "foes": foes, "line": line,
            "grade": {"opt": len(line), "lines": lines, "nap": nap}}


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    tries = int(sys.argv[2]) if len(sys.argv) > 2 else 400000
    with Pool() as pool:
        found = [b for b in pool.imap(try_one, range(tries), chunksize=500) if b]
    # the hardest first: a nap needed, then the longest line, then the fewest lines
    found.sort(key=lambda b: (-(b["grade"]["opt"] + (6 if b["grade"]["nap"] else 0)), b["grade"]["lines"]))
    kept = found[:count]
    print("found %d, kept %d" % (len(found), len(kept)))
    out = {"version": 1,
           "note": "Knight Insane: Brambles boards (8x8; king, you, rose knights), the shortest line proved "
                   "breadth first under the bramble and nap rules, few lines within two more moves or a nap "
                   "needed. tools/insane/knight_bramble_mine.py",
           "boards": kept}
    path = __file__.rsplit("/tools/", 1)[0] + "/content/insane/knight.json"
    with open(path, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    from collections import Counter
    print(Counter((b["grade"]["nap"], b["grade"]["opt"]) for b in kept))


if __name__ == "__main__":
    main()
