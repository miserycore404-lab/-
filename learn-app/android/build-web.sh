#!/bin/sh
# Bundles ../app.html and its fonts into the Android app's assets so it runs offline.
set -e
cd "$(dirname "$0")"
OUT=app/src/main/assets/www
mkdir -p "$OUT/fonts"
python3 - "$OUT" <<'PY'
import re, sys, urllib.request, hashlib, os
out = sys.argv[1]
src = open("../app.html", encoding="utf-8").read()
m = re.search(r'<link rel="stylesheet" href="(https://fonts.googleapis.com/[^"]+)">', src)
ua = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36"}
css = urllib.request.urlopen(urllib.request.Request(m.group(1).replace("&amp;","&"), headers=ua)).read().decode()
def grab(mo):
    url = mo.group(1)
    name = hashlib.sha1(url.encode()).hexdigest()[:16] + ".woff2"
    path = os.path.join(out, "fonts", name)
    if not os.path.exists(path):
        open(path, "wb").write(urllib.request.urlopen(urllib.request.Request(url, headers=ua)).read())
    return f"url(fonts/{name})"
css = re.sub(r"url\((https://fonts.gstatic.com/[^)]+)\)", grab, css)
src = re.sub(r'<link rel="preconnect"[^>]*>\n?', "", src)
src = src.replace(m.group(0), "<style>\n" + css + "\n</style>")
head = ('<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
        '<style>[hidden]{display:none!important}body{margin:0}</style></head><body>\n')
open(os.path.join(out, "index.html"), "w", encoding="utf-8").write(head + src + "\n</body></html>\n")
print("fonts:", len(os.listdir(os.path.join(out, "fonts"))), "files")
PY
