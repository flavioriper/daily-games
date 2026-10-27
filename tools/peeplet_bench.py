"""The Peeplet review bench's page and labels (tools/days/peeplet-bench/).

    python3 -I tools/peeplet_bench.py
        writes tools/days/peeplet-bench/index.html: every painting and decoy
        (the phone-size JPEG) in a grid with its name, the reviewer's word at
        paint time where there is one (the day JSON's `vistaTries`) and the
        hand label from labels.json.
    python3 -I tools/peeplet_bench.py --label <file> <pass|fail> [defect] [--subtle]
        writes one label. <file> is a JPEG's name; a .png name is taken for
        its .jpg. A pass has no defect.

labels.json: {"<file.jpg>": {"verdict": "pass"|"fail", "defect": "" |
"third-arm" | "missing-leg" | "fingers" | "human" | "neck" | "fused" |
"long-arm" | "other", "subtle": bool}}

The committed bench keeps the phone-size JPEGs; the full-size PNGs the
painter made stay on disk, uncommitted (README.md there).
"""
import html
import json
import os
import sys

BENCH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "days", "peeplet-bench")
LABELS = os.path.join(BENCH, "labels.json")
DEFECTS = {"", "third-arm", "missing-leg", "fingers", "human", "neck", "fused", "long-arm", "other"}


def load_labels():
    if not os.path.exists(LABELS):
        return {}
    with open(LABELS, encoding="utf8") as f:
        return json.load(f)


def jpg(name):
    return name[:-4] + ".jpg" if name.endswith(".png") else name


def label(argv):
    subtle = "--subtle" in argv
    rest = [a for a in argv if a != "--subtle"]
    if len(rest) < 2 or rest[1] not in ("pass", "fail") or len(rest) > 3:
        sys.exit("usage: --label <file> <pass|fail> [defect] [--subtle]")
    name = jpg(os.path.basename(rest[0]))
    defect = rest[2] if len(rest) == 3 else ""
    if defect not in DEFECTS:
        sys.exit("defect is one of: " + ", ".join(sorted(d for d in DEFECTS if d)))
    if rest[1] == "pass" and defect:
        sys.exit("a pass has no defect")
    if rest[1] == "fail" and not defect:
        sys.exit("a fail names its defect (use other when none fits)")
    if not os.path.exists(os.path.join(BENCH, name)):
        sys.exit(name + " is not in the bench")
    labels = load_labels()
    labels[name] = {"verdict": rest[1], "defect": defect, "subtle": subtle}
    with open(LABELS, "w", encoding="utf8") as f:
        json.dump(dict(sorted(labels.items())), f, indent=1)
        f.write("\n")
    print(name, labels[name])


def verdicts():
    """What the reviewer said at paint time, by JPEG name, from the day JSONs."""
    got = {}
    for f in sorted(os.listdir(BENCH)):
        if f.endswith(".json") and f != "labels.json":
            with open(os.path.join(BENCH, f), encoding="utf8") as h:
                day = json.load(h)
            for t in day.get("vistaTries", []):
                got[t["name"]] = t
    return got


def page():
    labels = load_labels()
    said = verdicts()
    names = sorted(f for f in os.listdir(BENCH) if f.endswith(".jpg"))
    cards = []
    for n in names:
        t = said.get(n)
        if t is not None:
            note = "reviewer: " + ("passed" if t["wrong"] == "" else "turned down: " + t["wrong"])
            note += " (%s Peeplets, %s)" % (t["peeplets"], t["size"])
        elif n.split("_", 1)[-1].startswith("decoy"):
            note = "decoy"
        else:
            note = ""
        lab = labels.get(n)
        if lab is None:
            tag, cls = "unlabelled", "none"
        else:
            tag = lab["verdict"] + (": " + lab["defect"] if lab["defect"] else "") + (" (subtle)" if lab["subtle"] else "")
            cls = lab["verdict"]
        cards.append(
            '<figure class="%s"><img src="%s" loading="lazy"><figcaption><b>%s</b><br>%s<br><span class="tag">%s</span></figcaption></figure>'
            % (cls, html.escape(n), html.escape(n), html.escape(note), html.escape(tag)))
    unl = sum(1 for n in names if n not in labels)
    out = """<!doctype html><meta charset="utf8"><title>Peeplet bench</title>
<style>
body{font:14px system-ui;margin:16px;background:#fafaf5;color:#222}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:12px}
figure{margin:0;border:3px solid #bbb;border-radius:6px;background:#fff}
figure.pass{border-color:#4a4}figure.fail{border-color:#c44}figure.none{border-color:#e90}
img{width:100%%;display:block}figcaption{padding:6px 8px;font-size:12px}.tag{font-weight:bold}
</style>
<h1>Peeplet bench: %d images, %d unlabelled</h1>
<div class="grid">%s</div>
""" % (len(names), unl, "\n".join(cards))
    with open(os.path.join(BENCH, "index.html"), "w", encoding="utf8") as f:
        f.write(out)
    print("index.html: %d images, %d unlabelled" % (len(names), unl))


if len(sys.argv) > 1 and sys.argv[1] == "--label":
    label(sys.argv[2:])
page()
