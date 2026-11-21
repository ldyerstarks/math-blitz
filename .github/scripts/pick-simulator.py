#!/usr/bin/env python3
"""Print the name of an available iPhone simulator on this runner.

Runner images change their preinstalled devices without warning, so the
workflow asks rather than hard-coding "iPhone 16".
"""
import json, subprocess, sys

out = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                     capture_output=True, text=True, check=True).stdout
devices = json.loads(out)["devices"]
names = [d["name"]
         for runtime in sorted(devices)
         if "iOS" in runtime
         for d in devices[runtime]
         if d.get("isAvailable", True) and "iPhone" in d["name"]]
if not names:
    sys.exit("no iPhone simulator available on this runner")
# Prefer a plain numbered iPhone over Plus/Pro Max variants: they boot faster.
names.sort(key=lambda n: (("Pro" in n) + ("Max" in n) + ("Plus" in n), len(n)))
print(names[0])
