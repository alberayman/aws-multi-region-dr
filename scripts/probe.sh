#!/usr/bin/env bash
# Logs availability of the app every INTERVAL seconds, for measuring RTO (test T13).
# Usage: ./scripts/probe.sh https://app.example.com/health [interval_seconds] | tee evidence/T13-probe.csv
# Columns: utc_timestamp,http_code,resolved_ip,region_header,total_time_s
# The app should return its Region in an "X-Region" response header.
set -uo pipefail

URL="${1:?usage: probe.sh <url> [interval_seconds]}"
INTERVAL="${2:-5}"
HOST="$(printf '%s' "$URL" | sed -E 's#^[a-z]+://([^/:]+).*#\1#')"

echo "utc_timestamp,http_code,resolved_ip,region_header,total_time_s"
while true; do
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ip="$(dig +short "$HOST" 2>/dev/null | tail -n1)"
  out="$(curl -s -o /dev/null -D - -w 'CODE=%{http_code} TIME=%{time_total}\n' \
        --max-time 5 -H 'Cache-Control: no-cache' "$URL" 2>/dev/null)"
  code="$(printf '%s' "$out" | sed -nE 's/.*CODE=([0-9]{3}).*/\1/p')"
  time="$(printf '%s' "$out" | sed -nE 's/.*TIME=([0-9.]+).*/\1/p')"
  region="$(printf '%s' "$out" | tr -d '\r' | sed -nE 's/^[Xx]-[Rr]egion: *(.*)$/\1/p' | head -n1)"
  echo "${ts},${code:-000},${ip:-none},${region:-none},${time:-5}"
  sleep "$INTERVAL"
done
