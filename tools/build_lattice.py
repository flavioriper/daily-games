#!/usr/bin/env python3
"""Lattice's bank: content/lattice.json, a pool of deals a band.

    python3 tools/build_lattice.py [count a band] [seed]

A deal is a lattice of number tiles (every other row and column is whole, the
cells where two short lines would cross are holes), the tiles scrambled, and a
knot in some of the holes that sums the tiles it points at. It is kept when

  * every whole row and column of the answer holds 1..n once,
  * the fewest swaps that put every tile home (`par`) is the band's, and
  * the answer is the only one the opening position allows: the tiles on the
    board, the ones already home, the ones known not to be, and the knots.

The phone only reads the file (puzzles/lattice_gen.gd). Re-run this when a
band changes; the output is deterministic for a seed.

A line of the file, per deal: "<answer>|<opening>|<knots>|<par>", the two
grids read row by row with the holes left out, a knot as hole index (row by
row over the holes), then its arrows out of L U R D.
"""
import json
import random
import sys
from functools import lru_cache
from pathlib import Path

# size, knots kept, par, and how the deal is scrambled: pairs traded, rings of three
BANDS = [
    {"n": 5, "knots": 4, "par": 8, "pairs": 4, "threes": 2},
    {"n": 7, "knots": 9, "par": 12, "pairs": 8, "threes": 2},
    {"n": 7, "knots": 9, "par": 15, "pairs": 11, "threes": 2},
    {"n": 7, "knots": 6, "par": 15, "pairs": 11, "threes": 2},
]
DIRS = {"L": (0, -1), "U": (-1, 0), "R": (0, 1), "D": (1, 0)}


def cells(n):
    return [(r, c) for r in range(n) for c in range(n) if not (r % 2 and c % 2)]


def holes(n):
    return [(r, c) for r in range(n) for c in range(n) if r % 2 and c % 2]


def lines(n):
    out = []
    for r in range(0, n, 2):
        out.append([(r, c) for c in range(n)])
    for c in range(0, n, 2):
        out.append([(r, c) for r in range(n)])
    return out


def answer(n, rng):
    """A filled lattice: the crossings first, then each line's own cells."""
    k = (n + 1) // 2
    while True:
        grid = {}
        ok = True
        for i in range(k):
            for j in range(k):
                used = {grid[(2 * i, 2 * jj)] for jj in range(j)} | {grid[(2 * ii, 2 * j)] for ii in range(i)}
                free = [d for d in range(1, n + 1) if d not in used]
                if not free:
                    ok = False
                    break
                grid[(2 * i, 2 * j)] = rng.choice(free)
            if not ok:
                break
        if not ok:
            continue
        for line in lines(n):
            have = {grid[p] for p in line if p in grid}
            rest = [d for d in range(1, n + 1) if d not in have]
            rng.shuffle(rest)
            for p in line:
                if p not in grid:
                    grid[p] = rest.pop()
        return grid


def par_of(cur, sol, n):
    """The fewest swaps that sort `cur` into `sol`: the tiles out of place,
    less the most cycles their holds->wants graph splits into."""
    cnt = [[0] * n for _ in range(n)]
    m = 0
    for p in cur:
        if cur[p] != sol[p]:
            cnt[cur[p] - 1][sol[p] - 1] += 1
            m += 1
    two = 0
    for a in range(n):
        for b in range(a + 1, n):
            t = min(cnt[a][b], cnt[b][a])
            cnt[a][b] -= t
            cnt[b][a] -= t
            two += t

    @lru_cache(maxsize=None)
    def best(state):
        g = [list(row) for row in state]
        start = next((a for a in range(n) if any(g[a])), -1)
        if start < 0:
            return 0
        top = 0
        # every cycle through the first edge out of `start`
        b0 = next(b for b in range(n) if g[start][b])
        stack = [(b0, (start, b0))]
        while stack:
            at, path = stack.pop()
            if at == start:
                h = [row[:] for row in g]
                for i in range(len(path) - 1):
                    h[path[i]][path[i + 1]] -= 1
                top = max(top, 1 + best(tuple(tuple(r) for r in h)))
                continue
            for nx in range(n):
                if g[at][nx] and (nx == start or nx not in path):
                    stack.append((nx, path + (nx,)))
        return top

    return m - two - best(tuple(tuple(r) for r in cnt))


def scramble(sol, n, band, rng):
    """Tiles dealt out of place as pairs that traded cells and a few rings of
    three, so that most swaps of a clean solve send two tiles home at once.
    No moved tile shows its cell's own number."""
    cs = cells(n)
    moved = rng.sample(cs, 2 * band["pairs"] + 3 * band["threes"])
    cur = dict(sol)
    at = 0
    for size, times in ((3, band["threes"]), (2, band["pairs"])):
        for _ in range(times):
            ring = moved[at:at + size]
            at += size
            for i, p in enumerate(ring):
                cur[p] = sol[ring[(i + 1) % size]]
    if any(cur[p] == sol[p] for p in moved):
        return None
    return cur


def knots(sol, n, band, rng):
    """Each knot points two of its four ways: a corner or straight across."""
    hs = holes(n)
    keep = sorted(rng.sample(range(len(hs)), band["knots"]))
    out = []
    for i in keep:
        r, c = hs[i]
        two = rng.sample("LURD", 2)
        d = "".join(x for x in "LURD" if x in two)
        out.append((i, d, sum(sol[(r + DIRS[x][0], c + DIRS[x][1])] for x in d)))
    return out


def count_answers(cur, sol, n, kn, cap=2):
    """How many fillings the opening allows, up to `cap`."""
    cs = cells(n)
    hs = holes(n)
    fixed = {p: cur[p] for p in cs if cur[p] == sol[p]}
    free = [p for p in cs if p not in fixed]
    pool = [0] * (n + 1)
    for p in free:
        pool[cur[p]] += 1
    of = {p: [] for p in cs}
    ls = lines(n)
    for i, line in enumerate(ls):
        for p in line:
            of[p].append(i)
    used = [set() for _ in ls]
    for p, v in fixed.items():
        for i in of[p]:
            used[i].add(v)
    sums = {p: [] for p in cs}
    ks = []
    for (i, d, total) in kn:
        r, c = hs[i]
        pts = [(r + DIRS[x][0], c + DIRS[x][1]) for x in d]
        ks.append((pts, total))
        for p in pts:
            sums[p].append(len(ks) - 1)
    val = dict(fixed)
    found = 0

    def options(p):
        out = []
        for v in range(1, n + 1):
            if pool[v] == 0 or v == cur[p]:
                continue
            if any(v in used[i] for i in of[p]):
                continue
            good = True
            for k in sums[p]:
                pts, total = ks[k]
                rest = total - v
                others = [q for q in pts if q != p]
                known = [val[q] for q in others if q in val]
                rest -= sum(known)
                open_n = len(others) - len(known)
                if open_n == 0:
                    if rest != 0:
                        good = False
                elif rest < open_n or rest > open_n * n:
                    good = False
                if not good:
                    break
            if good:
                out.append(v)
        return out

    def go(left):
        nonlocal found
        if not left:
            found += 1
            return
        bestp, besto = None, None
        for p in left:
            o = options(p)
            if not o:
                return
            if besto is None or len(o) < len(besto):
                bestp, besto = p, o
                if len(o) == 1:
                    break
        rest = [q for q in left if q != bestp]
        for v in besto:
            val[bestp] = v
            pool[v] -= 1
            for i in of[bestp]:
                used[i].add(v)
            go(rest)
            for i in of[bestp]:
                used[i].discard(v)
            pool[v] += 1
            del val[bestp]
            if found >= cap:
                return

    go(free)
    return found


def deal(band, rng):
    n = band["n"]
    while True:
        sol = answer(n, rng)
        kn = knots(sol, n, band, rng)
        for _ in range(400):
            cur = scramble(sol, n, band, rng)
            if cur is None or par_of(cur, sol, n) != band["par"]:
                continue
            if count_answers(cur, sol, n, kn) != 1:
                continue
            cs = cells(n)
            return "%s|%s|%s|%d" % (
                "".join(str(sol[p]) for p in cs),
                "".join(str(cur[p]) for p in cs),
                ",".join("%d%s" % (i, d) for (i, d, _t) in kn),
                band["par"],
            )


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 20261009
    out = {"bands": []}
    for b, band in enumerate(BANDS):
        rng = random.Random(seed * 10 + b)
        pool = []
        seen = set()
        while len(pool) < count:
            line = deal(band, rng)
            if line not in seen:
                seen.add(line)
                pool.append(line)
        out["bands"].append(pool)
        print("band %d: %d deals" % (b, len(pool)), file=sys.stderr)
    path = Path(__file__).resolve().parent.parent / "content" / "lattice.json"
    path.write_text(json.dumps(out, separators=(",", ":")) + "\n")
    print(path, file=sys.stderr)


if __name__ == "__main__":
    main()
