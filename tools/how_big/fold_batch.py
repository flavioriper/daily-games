#!/usr/bin/env python3
"""Folds a batch of How Big? things into the bundled table.

The batch is made by tools/how_big/batch_things.sh with the night's own
pipeline (server/functions/src/things.ts) into build/how_big_batch/pool.json.
Every thing in it that the night did not already hold (night_ids.json) becomes:

  tools/how_big/items.json      a row, its shape {"traced": true, ...}
  tools/how_big/src/<id>.json   the shape as the pipeline traced it
  locale/boards.csv             HB_ITEM_<ID> and HB_FACT_<ID> in en, pt, es

Then run the build, which writes content/how_big*.json and SOURCES.md, and
copy the table to the functions so the night never offers these again:

  python3 tools/how_big/fold_batch.py [--skip id,id]
  tools/how_big/.venv/bin/python -I tools/build_how_big.py
  cp content/how_big.json server/functions/src/how_big_bank.json
  godot --headless --path . --import

--skip leaves out things turned down on review. Ids lose the night's `d_`.
Running it again replaces what an earlier run folded (same ids).
"""
import csv
import io
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HB = os.path.join(ROOT, "tools", "how_big")
BATCH = os.path.join(ROOT, "build", "how_big_batch")
CSV = os.path.join(ROOT, "locale", "boards.csv")


def credit_parts(credit):
    """`https://www.phylopic.org/images/<uuid> <by...> <licence>` or the model's line."""
    bits = credit.split()
    if bits and bits[0].startswith("https://www.phylopic.org/"):
        return {"credit": credit, "url": bits[0], "by": " ".join(bits[1:-1]) or None, "licence": bits[-1] if len(bits) > 1 else None}
    return {"credit": credit}


def main(argv):
    skip = set(argv[argv.index("--skip") + 1].split(",")) if "--skip" in argv else set()
    with open(os.path.join(BATCH, "pool.json")) as f:
        pool = json.load(f)
    with open(os.path.join(BATCH, "night_ids.json")) as f:
        night = set(json.load(f))
    with open(os.path.join(HB, "items.json")) as f:
        table = json.load(f)
    items = table["items"]
    have = {it["id"] for it in items if "traced" not in it["shape"]}
    names = {it["name_en"].lower().split(" ", 1)[-1] for it in items if "traced" not in it["shape"]}

    new = []
    for t in pool:
        if t["id"] in night:
            continue
        iid = t["id"][2:] if t["id"].startswith("d_") else t["id"]
        if iid in skip or t["id"] in skip:
            continue
        assert iid.replace("_", "").isalnum() and iid not in have, "%s: id taken" % iid
        if t["name"]["en"].lower() in names:
            print("skipped %s: the table has a %s" % (iid, t["name"]["en"]))
            continue
        new.append((iid, t))

    # Replace what an earlier fold put in, then add.
    items = [it for it in items if "traced" not in it["shape"]]
    rows = {}
    for iid, t in new:
        with open(os.path.join(HB, "src", iid + ".json"), "w") as f:
            json.dump({"w": t["shape"]["w"], "h": t["shape"]["h"], "loops": t["shape"]["loops"], "tris": t["shape"]["tris"]}, f, separators=(",", ":"))
        name = t["name"]["en"]
        article = "an" if name[0].lower() in "aeiou" else "a"
        items.append({
            "id": iid,
            "name_en": "%s %s" % (article, name[0].lower() + name[1:]),
            "kind": t["kind"] if t["kind"] in ("animal", "object") else "animal",
            "size_m": t["size_m"],
            "measure": t["measure"],
            "what_en": "",
            "from": t.get("from", 0),
            "to": t.get("to", 1),
            "fact_en": t["fact"]["en"],
            "source": t["source"],
            "shape": dict({"traced": True, "born": t.get("born")}, **credit_parts(t.get("credit", ""))),
        })
        up = iid.upper()
        rows["HB_ITEM_" + up] = [t["name"]["en"], t["name"]["pt"], t["name"]["es"]]
        rows["HB_FACT_" + up] = [t["fact"]["en"], t["fact"]["pt"], t["fact"]["es"]]

    table["items"] = items
    with open(os.path.join(HB, "items.json"), "w") as f:
        f.write('{"items": [\n' + ",\n".join("  " + json.dumps(it, ensure_ascii=False) for it in items) + "\n]}\n")

    # The locale: drop rows an earlier fold wrote for traced ids, then put each
    # family's new rows after its last row.
    traced = {"HB_ITEM_" + i.upper() for i, _ in new} | {"HB_FACT_" + i.upper() for i, _ in new}
    # Line by line, so the rest of the file keeps its own quoting: the HB rows
    # are one line each.
    with open(CSV, encoding="utf-8") as f:
        text = f.read().split("\n")
    drop = traced | set(rows)
    text = [ln for ln in text if ln.split(",", 1)[0] not in drop]

    def line(key, cells):
        out = io.StringIO()
        csv.writer(out, lineterminator="").writerow([key] + [c.replace("\n", " ") for c in cells])
        return out.getvalue()

    for family in ("HB_ITEM_", "HB_FACT_"):
        at = max(i for i, ln in enumerate(text) if ln.startswith(family)) + 1
        text[at:at] = [line(k, v) for k, v in rows.items() if k.startswith(family)]
    with open(CSV, "w", encoding="utf-8") as f:
        f.write("\n".join(text))

    print("folded %d things: %s" % (len(new), ", ".join(i for i, _ in new)))
    print("the table now holds %d" % len(items))


if __name__ == "__main__":
    main(sys.argv[1:])
