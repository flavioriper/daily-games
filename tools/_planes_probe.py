"""Throwaway probe: reverse-insertion generation + greedy solve for Paper Planes.

Not shipped. Validates that a board carved backwards out of an empty grid is
always solvable, how full it comes out and how many planes are free at once.
"""
import random, statistics, time

DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]


def gen(rows, cols, rng, target, maxlen=6, minlen=2, tries=400, weights=None):
    occ = {}          # (r,c) -> arrow index
    arrows = []       # insertion order; play order is the reverse
    fails = 0
    while len(occ) < target * rows * cols and fails < tries:
        r = rng.randrange(rows)
        c = rng.randrange(cols)
        if (r, c) in occ:
            fails += 1
            continue
        dirs = DIRS[:]
        rng.shuffle(dirs)
        placed = False
        for d in dirs:
            rr, cc = r + d[0], c + d[1]
            clear = True
            lane = []
            while 0 <= rr < rows and 0 <= cc < cols:
                if (rr, cc) in occ:
                    clear = False
                    break
                lane.append((rr, cc))
                rr += d[0]
                cc += d[1]
            if not clear:
                continue
            lane_set = set(lane)
            body = [(r, c)]
            used = {(r, c)}
            w = weights or [6, 5, 4, 3, 2]
            span = list(range(minlen, maxlen + 1))
            want = rng.choices(span, weights=(w + [w[-1]] * len(span))[:len(span)])[0]
            prev = (r - d[0], c - d[1])
            if not (0 <= prev[0] < rows and 0 <= prev[1] < cols
                    and prev not in occ and prev not in lane_set):
                continue
            body.append(prev)
            used.add(prev)
            while len(body) < want:
                last = body[-1]
                cand = []
                for e in DIRS:
                    q = (last[0] + e[0], last[1] + e[1])
                    if not (0 <= q[0] < rows and 0 <= q[1] < cols):
                        continue
                    if q in occ or q in used or q in lane_set:
                        continue
                    cand.append(q)
                if not cand:
                    break
                body.append(rng.choice(cand))
                used.add(body[-1])
            if len(body) < minlen:
                continue
            body.reverse()
            idx = len(arrows)
            for cell in body:
                occ[cell] = idx
            arrows.append({"cells": body, "dir": d})
            placed = True
            break
        if not placed:
            fails += 1
        else:
            fails = 0
    return arrows, occ


def lane_clear(a, occ, gone, rows, cols):
    d = a["dir"]
    r, c = a["cells"][-1]
    rr, cc = r + d[0], c + d[1]
    while 0 <= rr < rows and 0 <= cc < cols:
        o = occ.get((rr, cc))
        if o is not None and o not in gone:
            return False
        rr += d[0]
        cc += d[1]
    return True


def solve(arrows, occ, rows, cols, rng=None):
    gone = set()
    profile = []
    while len(gone) < len(arrows):
        free = [i for i, a in enumerate(arrows)
                if i not in gone and lane_clear(a, occ, gone, rows, cols)]
        if not free:
            return None, profile
        profile.append(len(free))
        gone.add(free[0] if rng is None else rng.choice(free))
    return True, profile


BANDS = [
    (14, 10, "easy   10x14", 2, 8, [2, 3, 4, 5, 5, 4, 3]),
    (18, 13, "medium 13x18", 2, 9, [2, 3, 4, 5, 5, 5, 4, 3]),
    (22, 16, "hard   16x22", 2, 10, [2, 3, 4, 5, 5, 5, 4, 3, 2]),
]
for rows, cols, label, mn_len, mx_len, w in BANDS:
    for name in ["as designed"]:
        stats = []
        t0 = time.time()
        for seed in range(20):
            rng = random.Random(seed)
            arrows, occ = gen(rows, cols, rng, 0.95, maxlen=mx_len, minlen=mn_len, weights=w)
            ok, prof = solve(arrows, occ, rows, cols, random.Random(seed + 99))
            tight = sum(1 for p in prof if p <= 3) / max(len(prof), 1)
            stats.append((len(arrows), len(occ) / (rows * cols), min(prof),
                          statistics.mean(prof), ok is True, tight))
        n = [s[0] for s in stats]
        cov = [s[1] for s in stats]
        me = [s[3] for s in stats]
        tg = [s[5] for s in stats]
        print(f"{label} {name}: planes {min(n)}-{max(n)} (mean {statistics.mean(n):.1f}), "
              f"coverage {min(cov):.2f}-{max(cov):.2f}, mean free {statistics.mean(me):.1f}, "
              f"tight steps {statistics.mean(tg):.0%}, solved {all(s[4] for s in stats)}, "
              f"{(time.time() - t0) / 20 * 1000:.1f} ms")
    print()
