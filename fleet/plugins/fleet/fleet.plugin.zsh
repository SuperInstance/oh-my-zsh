# fleet.plugin.zsh — builder verbs for the Cocapn fleet.
# Design law: every verb is a thin wrapper over fleet doctrine
# (receipts cite wal_ref, pins fail-first, PRs are Casey-gated).
# This file must stay dependency-light: plain zsh + git + python3.

# ---- discovery ----------------------------------------------------------
# Lane = a git worktree/repo whose LEDGER.md, receipts/, or tools/pin_*.py
# says "fleet lives here". We detect, we never invent.
fleet_lane_root() {
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    if [[ -e "$d/LEDGER.md" || -d "$d/receipts" || -d "$d/tools" ]]; then
      print -r -- "$d"; return 0
    fi
    d="${d:h}"
  done
  return 1
}

# ---- pinrun: run every FAIL-first pin suite in the tree -----------------
# Contract: tools/pin_*.py each exit 0 on GREEN, nonzero on RED.
# Writes .pin-last (PASS n / FAIL reason) for the prompt segment.
pinrun() {
  local root="${1:-$(fleet_lane_root 2>/dev/null)}"; [[ -n "$root" ]] || {
    print -u2 "pinrun: not inside a fleet lane (no LEDGER.md/receipts/tools up-tree)"; return 2; }
  local found=0 green=0 red=0
  local suite
  for suite in "$root"/tools/pin_*.py(N); do
    found=$((found+1))
    if (cd "$root" && python3 "$suite" >/tmp/.pinrun.$$ 2>&1); then
      green=$((green+1))
    else
      red=$((red+1)); print -u2 "RED ${suite#$root/}:"; tail -3 /tmp/.pinrun.$$
    fi
  done
  rm -f /tmp/.pinrun.$$
  if (( found == 0 )); then
    print -u2 "pinrun: no tools/pin_*.py under $root"; return 2
  fi
  local verdict="PASS $green/$found"
  (( red > 0 )) && verdict="FAIL $red/$found"
  print -r -- "$verdict" > "$root/.pin-last"
  print -r -- "$verdict  ($root)"
  (( red == 0 ))
}

# ---- walref: the chain hash that makes a claim a fact --------------------
walref() {
  local root="${1:-$(fleet_lane_root 2>/dev/null)}"; [[ -n "$root" ]] || {
    print -u2 "walref: not inside a fleet lane"; return 2; }
  python3 - "$root" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
refs = []
for f in sorted((root / "receipts").glob("*.jsonl")) if (root / "receipts").is_dir() else []:
    try:
        rows = [json.loads(l) for l in f.read_text().splitlines() if l.strip()]
    except Exception:
        continue
    for r in rows:
        for k in ("wal_ref",):
            if isinstance(r, dict) and r.get(k):
                refs.append((f.name, r[k]))
if refs:
    name, ref = refs[-1]
    print(f"{ref}  ({name})")
else:
    print("walref: no wal_ref in receipts/*.jsonl — any claim about this tree is a rumor",
          file=sys.stderr); sys.exit(1)
PY
}

# ---- ship: receipt-disciplined commit+push -------------------------------
ship() {
  local msg="$1"; [[ -n "$msg" ]] || { print -u2 "usage: ship <receipt-citing message>"; return 2; }
  git add -A && git commit -q -m "$msg" && git push -q
  local rc=$?
  (( rc == 0 )) && print -r -- "shipped: $(git rev-parse --short HEAD)"
  return $rc
}

# ---- prqueue: what is waiting on the gate --------------------------------
prqueue() {
  gh pr list --limit "${1:-20}" --json number,title,headRefName,repository \
    --template '{{range .}}#{{.number}}  {{.headRefName}}  — {{.title}}  ({{.repository.nameWithOwner}}){{"\n"}}{{end}}' 2>/dev/null \
    || print -u2 "prqueue: gh not available"
}

# ---- recent: the fleet's heartbeat ---------------------------------------
recent() {
  local n="${1:-8}"
  for d in "${FLEET_LANES[@]:-$HOME/lanes/*}"(N); do
    [[ -d "$d/.git" ]] || continue
    print -r -- "${d:t}: $(git -C "$d" log --oneline -1 --format='%h %s' 2>/dev/null)"
  done | head -n "$n"
}

alias lanes='cd "${FLEET_ROOT:-$HOME/lanes}" && ls'
