#!/usr/bin/env python3
"""Rebuild site/lessons.json from lessons/*.json and copy rendered videos into site/videos/.

Usage: python3 build_site.py [ALERT_URL]
Only days whose video exists in out/ are published.
"""
import base64, glob, json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
site = ROOT
os.makedirs(os.path.join(site, "videos"), exist_ok=True)
days = []
for p in sorted(glob.glob(os.path.join(HERE, "lessons", "day*.json"))):
    L = json.load(open(p))
    name = os.path.basename(p).replace(".json", ".mp4")
    vid = os.path.join(ROOT, "videos", name)
    if not os.path.exists(vid):
        continue
    q = L["question"]
    assert 0 <= q["answer"] < len(q["choices"]), p
    enc = base64.b64encode(json.dumps({"prompt": q["prompt"], "choices": q["choices"],
                                       "a": q["answer"], "explain": q["explain"]}).encode()).decode()
    days.append({"day": L["day"], "title": L["title"], "video": f"videos/{name}", "poster": f"videos/{name[:-4]}.jpg" if os.path.exists(vid[:-4] + ".jpg") else "", "q": enc,
                 "boss": bool(L.get("boss")), "resources": L.get("resources", [])})
cfg_p = os.path.join(HERE, "config.json")
cfg = json.load(open(cfg_p)) if os.path.exists(cfg_p) else {}
json.dump({"days": days, "prizes": cfg.get("prizes", {})}, open(os.path.join(site, "lessons.json"), "w"), indent=1)
if len(sys.argv) > 1:
    idx = os.path.join(site, "index.html")
    html = open(idx).read()
    html = html.replace('const ALERT_URL = "__ALERT_URL__";', f'const ALERT_URL = "{sys.argv[1]}";')
    open(idx, "w").write(html)
print(f"published days: {[d['day'] for d in days]}")
