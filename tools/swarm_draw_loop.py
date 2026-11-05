"""Draw, look, fix: the swarm's eye loop against the real swarm on this Mac.

    caffeinate -d -i -u godot --resolution 810x1440 --always-on-top \\
        --script tests/_swarm_eye_link.gd -- /tmp/swarm_eye &
    python3 tools/swarm_draw_loop.py /tmp/swarm_eye duck "a lighthouse" ...

For each subject: terra writes the rows (tools/swarm_eye.py), the swarm
draws them, the phone's snapshot comes back, terra judges it, and a drawing
that does not read is redrawn with the eye's fix, at most TRIES times. The
harness and this script talk through files in the folder: cmd.json down,
seen_<id>.jpg up. Prints one line a step and a summary; writes nothing else.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import swarm_eye  # noqa: E402

TRIES = 3
TONES = ["gold", "cyan", "pink", "mint", "violet", "orange", "blue", "red"]


def send(folder: str, cmd: dict, n: int) -> bytes:
    cmd["id"] = n
    tmp = os.path.join(folder, "cmd.tmp")
    with open(tmp, "w") as f:
        json.dump(cmd, f)
    os.replace(tmp, os.path.join(folder, "cmd.json"))
    want = os.path.join(folder, f"seen_{n}.jpg")
    t = time.time()
    while not os.path.exists(want + ".done"):
        if time.time() - t > 30:
            raise TimeoutError("the swarm did not answer (is tests/_swarm_eye_link.gd running?)")
        time.sleep(0.1)
    with open(want, "rb") as f:
        return f.read()


def main() -> None:
    folder, subjects = sys.argv[1], sys.argv[2:]
    n, spent, rows_in, rows_out = 0, 0.0, 0, 0
    results = []
    for k, subject in enumerate(subjects):
        before, fix, verdict = None, "", {}
        for attempt in range(1, TRIES + 1):
            draw, u1 = swarm_eye.rows_for(subject, before, fix)
            n += 1
            jpg = send(folder, {"draw": draw, "tone": TONES[k % len(TONES)]}, n)
            verdict, u2 = swarm_eye.judge(jpg, subject)
            for u in (u1, u2):
                rows_in += u.get("prompt_tokens", 0)
                rows_out += u.get("completion_tokens", 0)
                spent += u["seconds"]
            print(f"{subject!r} try {attempt}: {len(draw['rows'][0])}x{len(draw['rows'])} reads as {verdict['reads_as']!r} ok={verdict['ok']} "
                  f"(write {u1['seconds']}s, look {u2['seconds']}s) {verdict['fix']}", flush=True)
            if verdict["ok"]:
                break
            before, fix = draw["rows"], verdict["fix"]
        results.append((subject, verdict.get("ok"), attempt))
    n += 1
    with open(os.path.join(folder, "cmd.json"), "w") as f:
        json.dump({"id": n, "quit": True}, f)
    good = sum(1 for _, ok, _ in results if ok)
    print(f"read {good} of {len(results)}; tries {[a for _, _, a in results]}; model time {spent:.1f}s; tokens in {rows_in} out {rows_out}")


if __name__ == "__main__":
    main()
