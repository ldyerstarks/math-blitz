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
- `rapid`: **5 Rapid Fire questions** on today's topic (or the last few days' topics), each `{prompt, choices[4], answer, why}`. Ramp the difficulty: Q1 at his level −0.5, Q2–Q3 at his level, Q4 a word problem at level +0.5, Q5 a stretch at level +1 (SAT-style twist, e.g. "what is 6x − 1" instead of "what is x"). Prompts ≤ 120 characters so they fit a phone; `why` is one short sentence. Verify every answer by computing it in Python. Wrong choices are the classic mistakes.
- `resources`: ⭐ quest first (`"quest": true`) = Khan Academy search link for the exact topic; then Desmos and/or the right Khan course; Bluebook "Mega Boss" about every 4 weeks once level ≥ 6; AoPS Alcumus at level ≥ 8. Links only.

## 4. Render, check, publish
1. `cd engine && python3 render.py lessons/dayNNN.json ../videos/dayNNN.mp4` (about 1–2 min).
2. Pull 3 frames (`ffmpeg -ss T -i … -frames:v 1`) at the busiest moments and LOOK at them: text fits, nothing overlaps, math is right.
3. `python3 build_site.py` (from engine/) → rebuilds `lessons.json` at the repo root.
4. Update `progress.json`: last_day, topic index, level, history entry (day, topic, result of yesterday, `sent`).
5. Commit "Day NNN: <title>" and push to main. GitHub Pages republishes in about 1 minute. Confirm https://ldyerstarks.github.io/math-blitz/?d=NNN loads (or wait 60 s and retry once).

## 4a. Make the page easier to use (Dad's request: "iterate as he uses it")
The page is a 4-step flow: Watch → Answer → Rapid Fire → Bonus, with a stepper at the top and one big Next button at the bottom. It logs his taps as **`started` rows with `ux` in the "% watched" column** (no email, no XP effect). The tap trail is in Picked + Answer, e.g. `vp@3.vd@50.xA@51.AD-@64.nR@70.r0+@75.r1-@82.rg@95|120s` (`@` = seconds since he opened the page; `|120s` = time on page).
Codes: `vp` play · `vs` tried to skip ahead · `vd` video done · `x`/`n`/`s` + W/A/R/B = went to Watch/Answer/Rapid/Bonus automatically / with the Next button / with the stepper · `L`+letter = tapped a locked step · `A`+letter+`±` = daily answer · `r`N`±` = Rapid Fire answer · `rg` "Got it" after a miss · `qo` opened the quest · `qx` tapped "I did it" before opening · `qd` quest claimed · `me` stats · `p`N past day · `OLD` old-day banner → today · `fb`/`fbs` opened/sent a note to Dad.
Each run, read yesterday's ux rows and look for friction: locked-step taps, tries to skip, steps he never reached (e.g. answered but no `R`), long gaps, bouncing between steps, old-day visits, notes from Jack. Make **at most one small, safe change** to `index.html` that fixes the clearest problem (wording, button text, which step he lands on, what's shown where). Test it at iPhone size with Playwright using `?test=1` (that turns off all logging so tests never touch his scoreboard), walk the whole flow, look at the screenshots, then commit "Page: <what changed>". Keep the scoreboard rules, XP, prizes, quest lock and the alert script as they are. If there are no ux rows or nothing looks wrong, change nothing. Add one line per change to the "Page changes" list at the end of this file.

## 4b. Nudge rule ("bug him" — Dad's request)
From the log sheet, count the released days *before today* in a row (most recent first) with **no `answered` row** — the days he skipped.
- **0–1 skipped:** normal hype text.
- **2 skipped:** today's text leads with a playful, teasing nudge (never mean or guilt-trippy), e.g. "2 days, no Blitz?! Your streak is on life support 🚑 — 60 seconds to save it" or "Rapid Fire misses you 😤 Dad's prize isn't gonna win itself". Name what's at stake (streak, XP to the next rank, the next prize from engine/config.json). Use send_style "loud". Still only one text per day.
- **4+ skipped:** same nudge, and also email Len (subject "Math Blitz — Jack has skipped N days") with the dates, so Dad can step in. Don't escalate further on your own.
- If Pause texts = yes, skip all of this.

## 5. Text him (Inkbox iMessage, identity @jackiesmath)
Send to his number (given in the scheduled-task prompt, never written in this repo) with `inkbox_imessage_send`. One short hype line naming today's topic and the XP on the line, then the link `https://ldyerstarks.github.io/math-blitz/?d=NNN`. Boss days: add send_style "fireworks". Never send more than one text per day; never reply to his messages beyond a short friendly acknowledgment, and nothing personal.
After a successful send set `sent: true` in progress.json and push. If the send fails because he isn't connected, leave `sent: false` and email Len (the Gmail connector account, subject "Math Blitz — couldn't text him today") with the link so he can forward it.

## Guardrails
- Original questions only; never copy Khan/College Board content. Linking is fine.
- Text at 7:00 am ET on weekdays and 10:00 am ET on Saturdays and Sundays (Dad's rule): if everything is ready earlier, wait until that time before sending.
- Stop and email Len instead of publishing if the render fails twice or the math can't be verified.
- Don't change the alert script, the scoreboard rules, or the prizes; those are Len's calls.

## Page changes
- 2026-11-21: Redesigned as a 4-step flow with a Next button. Why: on Day 2 he answered, then never found Rapid Fire; 30 min later he opened Day 1 from an old link and did its Rapid Fire there. Now: old-day banner points to today, stepper shows what's done/locked, wrong Rapid Fire answers wait for "Got it" instead of a 3-second timer, stats and past days moved into a sheet behind the XP chip.
- 2026-11-23: Added a big "⚡ Rapid Fire · 5 quick taps · +XP" button right under the answer explanation (hidden once Rapid Fire is done). Why: on Day 3 he answered right at 68 s, then left at 90 s without ever reaching Rapid Fire — the only way on was the bottom Next bar.
- 2026-11-24: Added a "⭐ Last step: Bonus Quest · +30 XP" button right under the Rapid Fire score (hidden once the quest is claimed). Why: on Day 4 he finished Rapid Fire 4/5 at 215 s, then left at 230 s without ever opening the Bonus step — the only way on was the bottom Next bar.
- 2026-11-26: After a fresh daily answer, the "⚡ Rapid Fire" button now counts down ("starts in 5…") and rolls into Rapid Fire on its own after ~6 s (stops if he taps anywhere else first). Why: on Day 6 he answered right at 111 s and left at 122 s without ever reaching Rapid Fire, even with the button right under the explanation.
