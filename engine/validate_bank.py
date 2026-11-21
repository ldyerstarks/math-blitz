#!/usr/bin/env python3
"""Check bank.json before it ever reaches a kid's phone.

Catches the failures that matter: a question with no correct answer or more
than one, duplicate choices, an answer index out of range, a prompt too long
for a phone screen, a missing video, or a lesson the app's picker could never
reach. Run by CI on every push.
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAX_RAPID_PROMPT = 120


def check(bank_path):
    problems = []
    try:
        bank = json.loads(pathlib.Path(bank_path).read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"{bank_path} could not be read: {exc}"]

    if not isinstance(bank.get("version"), int):
        problems.append("missing integer 'version'")
    lessons = bank.get("lessons")
    if not isinstance(lessons, list) or not lessons:
        return problems + ["'lessons' must be a non-empty list"]

    seen_ids = set()
    for lesson in lessons:
        lid = lesson.get("id", "<no id>")
        if lid in seen_ids:
            problems.append(f"{lid}: duplicate id")
        seen_ids.add(lid)

        for field, kind in [("title", str), ("topic", str), ("topicIndex", int),
                            ("satDomain", str), ("level", (int, float)),
                            ("boss", bool), ("video", str)]:
            if not isinstance(lesson.get(field), kind):
                problems.append(f"{lid}: '{field}' missing or wrong type")

        level = lesson.get("level")
        if isinstance(level, (int, float)) and not (1.0 <= level <= 10.0):
            problems.append(f"{lid}: level {level} is outside 1-10")

        video = lesson.get("video")
        if isinstance(video, str) and not (ROOT / video).exists():
            problems.append(f"{lid}: video file {video} is not in the repo")
        poster = lesson.get("poster")
        if isinstance(poster, str) and not (ROOT / poster).exists():
            problems.append(f"{lid}: poster file {poster} is not in the repo")

        problems += check_question(lid, "question", lesson.get("question"), 400)
        rapid = lesson.get("rapid", [])
        if not isinstance(rapid, list):
            problems.append(f"{lid}: 'rapid' must be a list")
        else:
            for i, r in enumerate(rapid):
                problems += check_question(lid, f"rapid[{i}]", r, MAX_RAPID_PROMPT,
                                           explain_key="why")

        resources = lesson.get("resources", [])
        if not isinstance(resources, list):
            problems.append(f"{lid}: 'resources' must be a list")
        else:
            for res in resources:
                if not isinstance(res.get("quest"), bool):
                    problems.append(f"{lid}: resource '{res.get('name')}' needs a boolean 'quest'")
                url = res.get("url", "")
                if not isinstance(url, str) or not url.startswith("https://"):
                    problems.append(f"{lid}: resource '{res.get('name')}' needs an https url")

    # Anything the app can never serve is dead weight and probably a mistake.
    non_boss = [l for l in lessons if not l.get("boss")]
    if not non_boss:
        problems.append("every lesson is a boss battle; the picker would never start")

    return problems


def check_question(lid, where, q, max_prompt, explain_key="explain"):
    out = []
    if not isinstance(q, dict):
        return [f"{lid}: {where} is missing"]
    prompt = q.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        out.append(f"{lid}: {where} has no prompt")
    elif len(prompt) > max_prompt:
        out.append(f"{lid}: {where} prompt is {len(prompt)} characters (max {max_prompt})")
    choices = q.get("choices")
    if not isinstance(choices, list) or len(choices) != 4:
        out.append(f"{lid}: {where} needs exactly 4 choices")
    else:
        if any(not isinstance(c, str) or not c.strip() for c in choices):
            out.append(f"{lid}: {where} has a blank choice")
        if len(set(choices)) != 4:
            out.append(f"{lid}: {where} has duplicate choices, so two answers could be right")
    answer = q.get("answer")
    if not isinstance(answer, int) or isinstance(answer, bool) or not (0 <= answer < 4):
        out.append(f"{lid}: {where} answer index must be 0-3")
    if not isinstance(q.get(explain_key), str) or not q.get(explain_key, "").strip():
        out.append(f"{lid}: {where} has no '{explain_key}'")
    return out


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "bank.json"
    found = check(path)
    if found:
        print(f"{len(found)} problem(s) in {path}:")
        for p in found:
            print("  -", p)
        sys.exit(1)
    data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    print(f"{path} is valid: {len(data['lessons'])} lessons, "
          f"{sum(len(l.get('rapid', [])) for l in data['lessons'])} Rapid Fire questions")
