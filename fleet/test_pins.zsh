#!/usr/bin/env zsh
# Headless pins for the fleet oh-my-zsh overlay.
HERE="${0:A:h}"
SRC="$HERE"
FIX=/tmp/lane-omz-fixture
PLUGIN="$HERE/plugins/fleet/fleet.plugin.zsh"
PASS=0; FAILN=0
ok()  { if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); print "PASS $TESTNAME"; else FAILN=$((FAILN+1)); print "FAIL $TESTNAME"; fi; }

rm -rf "$FIX"; mkdir -p "$FIX/tools" "$FIX/receipts"
echo "# LEDGER" > "$FIX/LEDGER.md"
printf 'print("GREEN: fixture ok")\n' > "$FIX/tools/pin_ok.py"
printf 'import sys\nprint("RED: fixture broken")\nsys.exit(1)\n' > "$FIX/tools/pin_bad.py"
printf '%s\n' '{"run":1,"wal_ref":"fixturewal0001abcd"}' > "$FIX/receipts/run.jsonl"

TESTNAME="F1 plugin loads in plain zsh"
ok zsh -f -c "source '$PLUGIN'; print -r -- loaded" --grep-not-needed 2>/dev/null
# direct check (simpler than ok wrapper for output compare):
L=$(zsh -f -c "source '$PLUGIN'; print -r -- loaded" 2>&1)
[[ "$L" == loaded ]] && { PASS=$((PASS+1)); print "PASS F1 plugin loads"; } || { FAILN=$((FAILN+1)); print "FAIL F1 ($L)"; }

TESTNAME="F2 lane discovery up-tree"
F=$( (cd "$FIX/tools" && zsh -f -c "source '$PLUGIN'; fleet_lane_root") 2>/dev/null )
[[ "$F" == "$FIX" ]] && { PASS=$((PASS+1)); print "PASS F2 up-tree discovery"; } || { FAILN=$((FAILN+1)); print "FAIL F2 ($F)"; }

O=$( zsh -f -c "source '$PLUGIN'; fleet_lane_root" 2>/dev/null; print "rc=$?" )
[[ "$O" == rc=1 ]] && { PASS=$((PASS+1)); print "PASS F2b outside returns nonzero"; } || { FAILN=$((FAILN+1)); print "FAIL F2b ($O)"; }

(cd "$FIX" && zsh -f -c "source '$PLUGIN'; pinrun" >/dev/null 2>&1)
RC=$?
[[ $RC != 0 ]] && { PASS=$((PASS+1)); print "PASS F3 pinrun nonzero on RED"; } || { FAILN=$((FAILN+1)); print "FAIL F3"; }
LAST=$(<"$FIX/.pin-last")
[[ "$LAST" == "FAIL 1/2" ]] && { PASS=$((PASS+1)); print "PASS F3b .pin-last FAIL mix"; } || { FAILN=$((FAILN+1)); print "FAIL F3b ($LAST)"; }

rm "$FIX/tools/pin_bad.py"
(cd "$FIX" && zsh -f -c "source '$PLUGIN'; pinrun" >/dev/null 2>&1)
RC=$?
[[ $RC == 0 ]] && { PASS=$((PASS+1)); print "PASS F3c all-green exit 0"; } || { FAILN=$((FAILN+1)); print "FAIL F3c"; }
[[ "$(<"$FIX/.pin-last")" == "PASS 1/1" ]] && { PASS=$((PASS+1)); print "PASS F3d .pin-last PASS"; } || { FAILN=$((FAILN+1)); print "FAIL F3d"; }

W=$( (cd "$FIX" && zsh -f -c "source '$PLUGIN'; walref") 2>/dev/null )
[[ "$W" == fixturewal0001abcd* ]] && { PASS=$((PASS+1)); print "PASS F4 walref"; } || { FAILN=$((FAILN+1)); print "FAIL F4 ($W)"; }

P=$( (cd "$FIX" && zsh -f -c "source '$PLUGIN'; source '$SRC/themes/receipts.zsh-theme'; print -P -r -- \"\$PROMPT\"") 2>/dev/null )
[[ "$P" == *"[lane-omz-fixture]"* ]] && { PASS=$((PASS+1)); print "PASS F5 prompt names lane"; } || { FAILN=$((FAILN+1)); print "FAIL F5 ($P)"; }
[[ "$P" == *$'\e[32m'* || "$P" == *$'%F{green}'* ]] && { PASS=$((PASS+1)); print "PASS F5b pin dot present"; } || { FAILN=$((FAILN+1)); print "FAIL F5b ($P)"; }

STUB=/tmp/lane-omz-stub; rm -rf "$STUB" "$STUB-x"; mkdir -p "$STUB"
zsh -c "ZSH='$STUB-x' zsh '$SRC/install.sh'" >/dev/null 2>&1
[[ $? != 0 ]] && { PASS=$((PASS+1)); print "PASS F6 refuses without omz"; } || { FAILN=$((FAILN+1)); print "FAIL F6"; }
zsh -c "ZSH='$STUB' zsh '$SRC/install.sh'" >/dev/null 2>&1; RC1=$?
zsh -c "ZSH='$STUB' zsh '$SRC/install.sh'" >/dev/null 2>&1; RC2=$?
[[ $RC1 == 0 && $RC2 == 0 && -L "$STUB/custom/themes/receipts.zsh-theme" && -L "$STUB/custom/plugins/fleet/fleet.plugin.zsh" ]] \
  && { PASS=$((PASS+1)); print "PASS F6b install idempotent + links"; } || { FAILN=$((FAILN+1)); print "FAIL F6b"; }

if (( FAILN == 0 )); then print "GREEN: $PASS/$((PASS+FAILN)) pins"; else print "RED: $FAILN failed"; fi
exit $(( FAILN > 0 ))
