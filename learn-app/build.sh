#!/bin/sh
# Builds index.html (the installable app) from app.html.
cd "$(dirname "$0")"
{
  printf '%s\n' '<!doctype html>' '<html lang="en"><head><meta charset="utf-8">' \
  '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">' \
  '<meta name="theme-color" content="#2f4fd8"><meta name="mobile-web-app-capable" content="yes">' \
  '<meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="Line by Line">' \
  '<meta name="apple-mobile-web-app-status-bar-style" content="default">' \
  '<link rel="manifest" href="manifest.webmanifest"><link rel="icon" href="icon.svg" type="image/svg+xml"><link rel="apple-touch-icon" href="icon-192.png">' \
  '<style>[hidden]{display:none!important}body{margin:0}:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}</style>' \
  '<script>if("serviceWorker" in navigator&&location.protocol.startsWith("http"))addEventListener("load",()=>navigator.serviceWorker.register("sw.js").catch(()=>{}));</script>' \
  '</head><body>'
  cat app.html
  printf '\n</body></html>\n'
} > index.html
