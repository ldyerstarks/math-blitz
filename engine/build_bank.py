#!/usr/bin/env python3
"""Build bank.json, the lesson pack the iPhone app downloads.

The app ships no lessons of its own: it fetches this file from GitHub Pages and
caches it. Everything here comes from engine/lessons/*.json, which the daily run
already writes and verifies, so there is one source of truth for the maths.

    python3 engine/build_bank.py            # write bank.json
    python3 engine/build_bank.py --check    # fail if bank.json is out of date
"""
import argparse, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LESSONS = ROOT / "engine" / "lessons"
CURRICULUM = ROOT / "engine" / "curriculum.md"
OUT = ROOT / "bank.json"
BANK_VERSION = 1


def topic_order():
    """Map a topic name to its position in the curriculum, lowercased."""
    order = {}
    for line in CURRICULUM.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^(\d+)\.\s+(.+?)\s*$", line.strip())
        if m:
            order[m.group(2).lower()] = int(m.group(1))
    return order


def topic_index(topic, order, fallback):
    key = topic.lower().strip()
    if key in order:
        return order[key]
    # Tolerate small wording differences between the lesson and the curriculum.
    for name, idx in order.items():
        if key in name or name in key:
            return idx
    return fallback


def convert(path, order):
    raw = json.loads(path.read_text(encoding="utf-8"))
    day = int(raw["day"])
    stem = f"day{day:03d}"
    video = f"videos/{stem}.mp4"
    poster = f"videos/{stem}.jpg"
    q = raw["question"]
    lesson = {
        "id": stem,
        "title": raw["title"],
        "topic": raw["topic"],
        "topicIndex": topic_index(raw["topic"], order, day),
        "satDomain": raw.get("sat_domain", "Algebra"),
        "level": float(raw.get("level", 3.0)),
        "boss": bool(raw.get("boss", False)),
        "video": video,
        "question": {
            "prompt": q["prompt"],
            "choices": list(q["choices"]),
            "answer": int(q["answer"]),
            "explain": q["explain"],
        },
        "rapid": [
            {
                "prompt": r["prompt"],
                "choices": list(r["choices"]),
                "answer": int(r["answer"]),
                "why": r["why"],
            }
            for r in raw.get("rapid", [])
        ],
        "resources": [
            {
                "name": res["name"],
                "label": res["label"],
                "url": res["url"],
                "quest": bool(res.get("quest", False)),
                **({"button": res["button"]} if res.get("button") else {}),
            }
            for res in raw.get("resources", [])
        ],
    }
    if (ROOT / poster).exists():
        lesson["poster"] = poster
    return lesson


def build():
    order = topic_order()
    files = sorted(LESSONS.glob("day*.json"))
    if not files:
        sys.exit("no lessons found in engine/lessons/")
    lessons = [convert(p, order) for p in files]
    lessons.sort(key=lambda l: (l["topicIndex"], l["level"], l["id"]))
    return {"version": BANK_VERSION, "lessons": lessons}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if bank.json does not match the lessons")
    args = ap.parse_args()
    bank = build()
    text = json.dumps(bank, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            sys.exit("bank.json is out of date — run: python3 engine/build_bank.py")
        print(f"bank.json is up to date ({len(bank['lessons'])} lessons)")
        return
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} with {len(bank['lessons'])} lessons")


if __name__ == "__main__":
    main()
