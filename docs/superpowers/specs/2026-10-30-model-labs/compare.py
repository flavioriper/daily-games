#!/usr/bin/env python3
"""Side by side: what each lab's day kept, how many asks it took, what it cost."""
import json, re, sys, os
L = os.path.dirname(os.path.abspath(__file__))
DAY = sys.argv[1] if len(sys.argv) > 1 else "20261103"

def load(name):
    p = os.path.join(L, name, f"{DAY}.json")
    return json.load(open(p)) if os.path.exists(p) else None

def row(label, *cells):
    print(f"| {label} | " + " | ".join(str(c) for c in cells) + " |")

def summary(d):
    if d is None:
        return None
    s = {}
    pics = d.get("pictures") or {}
    sizes = pics.get("sizes") or {}
    s["pixel sizes made"] = ", ".join(sorted(sizes.keys(), key=int)) or "none"
    drafts = d.get("drafts") or []
    looks = [t.get("look", {}).get("score") for t in drafts if t.get("look", {}).get("score") is not None]
    s["pixel drafts / eye scores"] = f"{len(drafts)} drafts; scores {looks}" if drafts else "-"
    jl = pics.get("jellies") or {}
    s["jellies kept per band"] = " ".join(f"{b}:{len(v)}" for b, v in sorted(jl.items())) or "none"
    jt = d.get("jellyTries") or []
    s["jelly tries (kept)"] = f"{len(jt)} ({sum(1 for t in jt if t.get('kept'))})"
    jp = d.get("jellyPorts") or []
    asks = [t for p in jp for t in p.get("tries", [])]
    s["jelly asks map/reader/written"] = f"{sum(1 for t in asks if t['route']=='map')}/{sum(1 for t in asks if t['route']=='reader')}/{sum(1 for t in asks if t['route']=='written')}"
    errs = [t.get("error") for t in asks if t.get("error")]
    s["jelly ask errors"] = len(errs)
    hp = pics.get("hoops") or {}
    s["hoops kept (panels)"] = " ".join(f"{b}:{h['id']} {len(h['panels'])}" for b, h in sorted(hp.items())) or "none"
    hports = d.get("hoopPorts") or []
    hasks = [t for p in hports for t in p.get("tries", [])]
    s["hoop asks (errors)"] = f"{len(hasks)} ({sum(1 for t in hasks if t.get('error'))})"
    w = pics.get("words")
    s["words"] = "made" if w else "none"
    s["words tries"] = len(d.get("wordsTries") or [])
    q = d.get("quizzes") or {}
    def themed(bands, pat):
        return "/".join(str(sum(1 for x in b if re.search(pat, x.get("id", "")))) for b in bands)
    a, p = q.get("acorn"), q.get("pearl")
    s["acorn source / themed per band"] = f"{a['source']} {themed(a['bands'], r'b\dt\d+$')}" if a else "-"
    s["pearl source / themed per band"] = f"{p['source']} {themed(p['bands'], r't$')}" if p else "-"
    vt = d.get("vistaTries") or []
    v = d.get("vistas")
    s["vistas"] = (f"{len(v.get('times', {}))} times{' + header' if v.get('header') else ''}" if v else "none") + f" in {len(vt)} paintings"
    s["errors (ports)"] = "; ".join(sorted(set(e[:60] for e in errs)))[:300] or "-"
    s["cost (model asks, US$)"] = round(float(d.get("cost", 0)) + float(q.get("cost", 0)), 3)
    s["seconds (themed step)"] = d.get("seconds")
    return s

g, n = summary(load("lab-gemini")), summary(load("lab-nova"))
print(f"| {DAY} | Gemini (Argon reviews, 3.8 Flash writes) | Nova 2 Lite |")
print("|---|---|---|")
for k in (g or n or {}).keys():
    row(k, g.get(k, "-") if g else "-", n.get(k, "-") if n else "-")
