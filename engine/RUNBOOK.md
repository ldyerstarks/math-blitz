# Math Blitz — daily 7:00 am ET run

You are making today's Math Blitz video for Len's 13-year-old son and texting it to him. Personal project (never mix with Len's work). Keep it fun, accurate and short.

## 0. Setup (fresh cloud session)
1. Attach and clone this repo (`ldyerstarks/math-blitz`, push access) to /home/claude/math-blitz.
2. `pip install --break-system-packages kokoro-onnx soundfile` and download the voice model into `engine/`:
   - https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx → `engine/kokoro.onnx`
   - https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin → `engine/voices.bin`
3. Read `engine/curriculum.md` (topic order, adaptive rules, free resources) and `engine/progress.json`.

## 1. Check yesterday and Dad's settings (cheap: one Drive read)
Read the "Math Blitz Log" Google Sheet with the Google Drive connector (`read_file_content`, sheet ID in the task prompt). It has two tabs:
- **Sheet1 (log):** one row per event: `watched` (with % watched), `answered` (Picked, Correct? yes/no), `bonus`, `feedback` (a note from Jack — read it and adjust). No `answered` row for the last day → he skipped it (treat like a miss for pacing).
- **Settings:** `Level adjustment` (B2), `Pause texts` (B3), `Note to the video maker` (B4), `Level before adjustment (auto)` (B5).
  - If Pause texts = yes → do nothing today (no video, no text) and stop.
  - His Math Level = B5 + B2, clamped to 1–10. Write today's question at that level.
  - Follow B4 if Dad wrote anything there.
Only fall back to Gmail (`subject:"Math Blitz" newer_than:2d`) if the Drive read fails.

## 2. Plan today
- **First check `progress.json`: if the newest day has `"sent": false`, it was never texted. Skip making a new video and just text that day's link (step 5), then set `sent: true` and push.**
- Today's day number = `progress.json.last_day + 1`. If that's a multiple of 7 → **Boss Battle** (`"boss": true`): no new topic, a harder mixed question over the last 6 days' topics.
- Otherwise pick the topic per curriculum.md: next topic if he got the last one right; **Instant Replay** (same topic, new angle, one notch easier) if he missed or skipped it.
- Write the question at his Math Level (see the level table in curriculum.md). 4 choices; the 3 wrong ones are the classic mistakes. Double-check the math by actually computing it (run Python). Exactly one choice may be correct.

## 3. Write the lesson file `engine/lessons/dayNNN.json`
Copy the shape of `engine/lessons/day001.json`:
- `day`, `title` (punchy, ≤ 22 chars), `topic`, `sat_domain`, `level`, `boss`, `voice: "am_puck"`, `speed: 1.08`
- `scenes`: title → 2–3 board scenes (each ≤ 4 short lines, ≤ 25 words of narration) → question scene with `hold: 3.0`. Total narration ≈ 110–150 words (45–75 s). Hype sports-announcer voice, kid-friendly, never mean. Say math the way it reads aloud ("four x minus five"). Use − × ÷ characters on screen; avoid emoji and ✔ on screen (the font lacks them).
- `question`: prompt, choices, `answer` (index), `explain` (one or two sentences, shows after he answers), `trap_notes`.
- `resources`: ⭐ quest first (`"quest": true`) = Khan Academy search link for the exact topic; then Desmos and/or the right Khan course; Bluebook "Mega Boss" about every 4 weeks once level ≥ 6; AoPS Alcumus at level ≥ 8. Links only.

## 4. Render, check, publish
1. `cd engine && python3 render.py lessons/dayNNN.json ../videos/dayNNN.mp4` (about 1–2 min).
2. Pull 3 frames (`ffmpeg -ss T -i … -frames:v 1`) at the busiest moments and LOOK at them: text fits, nothing overlaps, math is right.
3. `python3 build_site.py` (from engine/) → rebuilds `lessons.json` at the repo root.
4. Update `progress.json`: last_day, topic index, level, history entry (day, topic, result of yesterday, `sent`).
5. Commit "Day NNN: <title>" and push to main. GitHub Pages republishes in about 1 minute. Confirm https://ldyerstarks.github.io/math-blitz/?d=NNN loads (or wait 60 s and retry once).

## 5. Text him (Inkbox iMessage, identity @jackiesmath)
Send to his number (given in the scheduled-task prompt, never written in this repo) with `inkbox_imessage_send`. One short hype line naming today's topic and the XP on the line, then the link `https://ldyerstarks.github.io/math-blitz/?d=NNN`. Boss days: add send_style "fireworks". Never send more than one text per day; never reply to his messages beyond a short friendly acknowledgment, and nothing personal.
After a successful send set `sent: true` in progress.json and push. If the send fails because he isn't connected, leave `sent: false` and email Len (the Gmail connector account, subject "Math Blitz — couldn't text him today") with the link so he can forward it.

## Guardrails
- Original questions only; never copy Khan/College Board content. Linking is fine.
- Text at 7:00 am ET: if everything is ready earlier, wait until 7:00 before sending.
- Stop and email Len instead of publishing if the render fails twice or the math can't be verified.
- Don't change the alert script, the scoreboard rules, or the prizes; those are Len's calls.
