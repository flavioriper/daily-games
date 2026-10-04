#!/usr/bin/env bash
# Drives server/database.rules.json against the Realtime Database emulator
# with curl and prints PASS or FAIL for each case. Not a test: a probe, for
# reading with your eyes. Every user is a fresh anonymous sign-up on the
# auth emulator and every match id is new, so it can be run again and again
# on one emulator.
#
#   cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" \
#     firebase emulators:start --only auth,database --project demo-peeplet
#   tests/_probe_live_rules.sh          # about 65 s: it waits out the clocks
#   QUICK=1 tests/_probe_live_rules.sh  # 12 s: the 20 s and 60 s cases SKIP
#
# The waits are real. Five matches are made at the start so the four clocks
# (void 10 s, left 20 s, timeout 60 s, stale ticket 60 s) run side by side.
# Friends' rules (codes, friendships, presence, invites, the private claim)
# are in the middle, with every way to cheat them that was thought of.
# Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 2,
# and 2026-10-04-friends-design.md, section 1.
set -uo pipefail

EMU="${FIREBASE_EMULATOR:-127.0.0.1}"
NS="${FIREBASE_PROJECT:-demo-peeplet}-default-rtdb"
DB="http://$EMU:9000"
AUTH="http://$EMU:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=probe"
RUN="r$(date +%s)$RANDOM"
NOW='{".sv":"timestamp"}'
pass=0; fail=0; skip=0

# Signs one anonymous user up; sets UID_<name> and TOK_<name>.
user() {
	local out
	out=$(curl -s -X POST "$AUTH" -H 'Content-Type: application/json' -d '{"returnSecureToken":true}')
	eval "UID_$1=$(printf '%s' "$out" | sed -n 's/.*"localId":"\([^"]*\)".*/\1/p')"
	eval "TOK_$1=$(printf '%s' "$out" | sed -n 's/.*"idToken":"\([^"]*\)".*/\1/p')"
}
uid() { eval "printf '%s' \"\$UID_$1\""; }
tok() { eval "printf '%s' \"\$TOK_$1\""; }

# code <who> <method> <path> [body] -> the HTTP status
code() {
	local args=(-s -o /dev/null -w '%{http_code}' -X "$2" "$DB/$3.json?ns=$NS&auth=$(tok "$1")")
	[ $# -ge 4 ] && args+=(-d "$4")
	curl "${args[@]}"
}

# check <name> <ok|no> <who> <method> <path> [body]
check() {
	local name="$1" want="$2" got
	shift 2
	got=$(code "$@")
	if { [ "$want" = ok ] && [ "$got" = 200 ]; } || { [ "$want" = no ] && [ "$got" = 401 ]; }; then
		pass=$((pass + 1)); printf 'PASS  %s (%s)\n' "$name" "$got"
	else
		fail=$((fail + 1)); printf 'FAIL  %s (wanted %s, got %s)\n' "$name" "$want" "$got"
	fi
}
skipped() { skip=$((skip + 1)); printf 'SKIP  %s\n' "$1"; }

ticket() { code "$1" PUT "queue/chess/$(uid "$1")" "{\"since\":$NOW,\"at\":$NOW}" >/dev/null; }

# claim_body <id> <p0> <p1> [ticket a] [ticket b]: the one PATCH at the root
claim_body() {
	local a="${4:-$2}" b="${5:-$3}"
	printf '{"matches/%s":{"game":"chess","p0":"%s","p1":"%s","first":0,"seed":7,"at":%s,"n":0,"turn":0,"turnAt":%s},"queue/chess/%s/match":"%s","queue/chess/%s/match":"%s"}' \
		"$1" "$(uid "$2")" "$(uid "$3")" "$NOW" "$NOW" "$(uid "$a")" "$1" "$(uid "$b")" "$1"
}
# match <id> <p0> <p1>: both tickets, then p1 claims p0
match() { ticket "$2"; ticket "$3"; code "$3" PATCH "" "$(claim_body "$1" "$2" "$3")" >/dev/null; }
# move_body <index> <seat> <n after> <turn after>
move_body() { printf '{"moves/%s":{"s":%s,"d":"{}"},"n":%s,"turn":%s,"turnAt":%s}' "$1" "$2" "$3" "$4" "$NOW"; }

# A code nobody has: eight of the alphabet the rules allow.
newcode() { LC_ALL=C tr -dc 'ABCDEFGHJKMNPQRSTUVWXYZ23456789' </dev/urandom | head -c 8; }
# both_halves <opener> <owner> [via]: the one PATCH that makes two friends
both_halves() {
	local via=""
	[ $# -ge 3 ] && via=",\"via\":\"$3\""
	printf '{"social/%s/friends/%s":{"at":%s%s},"social/%s/friends/%s":{"at":%s}}' \
		"$(uid "$2")" "$(uid "$1")" "$NOW" "$via" "$(uid "$1")" "$(uid "$2")" "$NOW"
}
# accept_body <id> <p0> <p1> <invited> <inviter> [game]: the private claim
accept_body() {
	printf '{"matches/%s":{"game":"%s","p0":"%s","p1":"%s","first":0,"seed":7,"at":%s,"n":0,"turn":0,"turnAt":%s},"social/%s/invites/%s/match":"%s"}' \
		"$1" "${6:-chess}" "$(uid "$2")" "$(uid "$3")" "$NOW" "$NOW" "$(uid "$4")" "$(uid "$5")" "$1"
}

if [ "$(curl -s -o /dev/null -w '%{http_code}' "$DB/.json?ns=$NS")" = 000 ]; then
	echo "no database emulator at $DB"; exit 2
fi

for u in A B C D E F G H I J K L P Q R; do user "$u"; done
M1="$RUN-1"; M2="$RUN-2"; M3="$RUN-3"; M4="$RUN-4"; M5="$RUN-5"
t0=$(date +%s)
# wait_until <seconds after t0>
wait_until() { local left=$(( t0 + $1 - $(date +%s) )); [ "$left" -gt 0 ] && sleep "$left"; return 0; }

echo "-- the queue"
check "a ticket is written by its owner" ok A PUT "queue/chess/$(uid A)" "{\"since\":$NOW,\"at\":$NOW}"
check "a ticket's clock cannot be made up" no B PUT "queue/chess/$(uid B)" '{"since":5,"at":5}'
check "a ticket for a game that is not one is refused" no B PUT "queue/ludo/$(uid B)" "{\"since\":$NOW,\"at\":$NOW}"
check "someone else's ticket cannot be written" no B PUT "queue/chess/$(uid A)" "{\"since\":$NOW,\"at\":$NOW}"
ticket B; ticket C; ticket I
check "the heartbeat moves at" ok A PATCH "queue/chess/$(uid A)" "{\"at\":$NOW}"
check "the queue is read in order of since" ok B GET "queue/chess" ""
got=$(curl -s -o /dev/null -w '%{http_code}' "$DB/queue/chess.json?ns=$NS&auth=$(tok B)&orderBy=%22since%22")
if [ "$got" = 200 ]; then pass=$((pass + 1)); echo "PASS  orderBy=\"since\" is indexed ($got)"; else fail=$((fail + 1)); echo "FAIL  orderBy=\"since\" is indexed ($got)"; fi
check "a fresh ticket cannot be removed by another" no B DELETE "queue/chess/$(uid I)"

echo "-- the claim"
check "a match with no tickets marked is refused" no B PUT "matches/$M1" "{\"game\":\"chess\",\"p0\":\"$(uid A)\",\"p1\":\"$(uid B)\",\"first\":0,\"seed\":7,\"at\":$NOW,\"n\":0,\"turn\":0,\"turnAt\":$NOW}"
check "a claim naming two others is refused" no C PATCH "" "$(claim_body "$M1" A B)"
check "a claim marking a ticket outside the match is refused" no B PATCH "" "$(claim_body "$M1" A B I B)"
check "a claim succeeds" ok B PATCH "" "$(claim_body "$M1" A B)"
check "a second claim of the same ticket is refused" no C PATCH "" "$(claim_body "$RUN-1b" A C)"
check "a claimer already in a match cannot claim again" no B PATCH "" "$(claim_body "$RUN-1c" C B)"
check "the owner cannot repoint its match" no A PATCH "queue/chess/$(uid A)" '{"match":"elsewhere"}'
check "the claimed ticket's heartbeat still goes" ok A PATCH "queue/chess/$(uid A)" "{\"at\":$NOW}"
check "the owner deletes its ticket" ok A DELETE "queue/chess/$(uid A)"
check "a claim of a ticket that is gone is refused" no C PATCH "" "$(claim_body "$RUN-1d" A C)"
check "a player reads its match" ok A GET "matches/$M1"
check "a stranger does not" no C GET "matches/$M1"

# The other four matches, made now so their clocks run while M1 is played.
match "$M2" C D   # timeout: C never moves
match "$M3" E F   # left: E is seen once and never again
match "$M4" G H   # void: H is never seen
match "$M5" K L   # end
code E PUT "matches/$M3/seen/0" "$NOW" >/dev/null
code F PUT "matches/$M3/seen/1" "$NOW" >/dev/null
code G PUT "matches/$M4/seen/0" "$NOW" >/dev/null

echo "-- moves (A is seat 0 and opens)"
check "seen is written by its seat" ok A PUT "matches/$M1/seen/0" "$NOW"
check "seen is not written by the other seat" no B PUT "matches/$M1/seen/0" "$NOW"
check "seen cannot be made up" no B PUT "matches/$M1/seen/1" "5"
code B PUT "matches/$M1/seen/1" "$NOW" >/dev/null
check "a move out of turn is refused" no B PATCH "matches/$M1" "$(move_body 0 1 1 0)"
check "a move in turn is accepted" ok A PATCH "matches/$M1" "$(move_body 0 0 1 1)"
check "the same seat again is refused" no A PATCH "matches/$M1" "$(move_body 1 0 2 0)"
check "a move that skips a number is refused" no B PATCH "matches/$M1" "$(move_body 2 1 3 0)"
check "a move that counts two is refused" no B PATCH "matches/$M1" "$(move_body 1 1 3 0)"
check "a move signed as the other seat is refused" no B PATCH "matches/$M1" "$(move_body 1 0 2 0)"
check "a move over an old one is refused" no B PATCH "matches/$M1" "$(move_body 0 1 2 0)"
check "the count alone is refused" no B PATCH "matches/$M1" "{\"n\":2,\"turnAt\":$NOW}"
check "the turn alone is refused" no B PATCH "matches/$M1" '{"turn":0}'
check "a made-up turn clock is refused" no B PATCH "matches/$M1" '{"moves/1":{"s":1,"d":"{}"},"n":2,"turn":0,"turnAt":5}'
check "the players cannot be changed" no B PATCH "matches/$M1" "{\"p0\":\"$(uid B)\"}"
check "the reply is accepted" ok B PATCH "matches/$M1" "$(move_body 1 1 2 0)"
check "a move that keeps the turn is accepted" ok A PATCH "matches/$M1" "$(move_body 2 0 3 0)"
check "and its seat moves again" ok A PATCH "matches/$M1" "$(move_body 3 0 4 1)"

echo "-- results"
check "an early timeout claim is refused" no A PUT "matches/$M1/result" '{"winner":0,"why":"timeout"}'
check "an early left claim is refused" no A PUT "matches/$M1/result" '{"winner":0,"why":"left"}'
check "void is refused once both were seen" no A PUT "matches/$M1/result" '{"winner":-1,"why":"void"}'
check "end by the seat that did not move last is refused" no B PUT "matches/$M1/result" '{"winner":1,"why":"end"}'
check "resigning to yourself is refused" no B PUT "matches/$M1/result" '{"winner":1,"why":"resign"}'
check "a reason that is not one is refused" no B PUT "matches/$M1/result" '{"winner":0,"why":"bored"}'
check "a stranger's result is refused" no C PUT "matches/$M1/result" '{"winner":0,"why":"resign"}'
check "resign is accepted" ok B PUT "matches/$M1/result" '{"winner":0,"why":"resign"}'
check "a second result is refused" no A PUT "matches/$M1/result" '{"winner":1,"why":"resign"}'
check "a move after the result is refused" no B PATCH "matches/$M1" "$(move_body 4 1 5 0)"

check "end before any move is refused" no K PUT "matches/$M5/result" '{"winner":0,"why":"end"}'
code K PATCH "matches/$M5" "$(move_body 0 0 1 1)" >/dev/null
check "end by the seat that moved last is accepted" ok K PUT "matches/$M5/result" '{"winner":-1,"why":"end"}'

# Friends (docs/superpowers/specs/2026-10-04-friends-design.md, section 1).
# P has a code, Q opens P's link, R is a stranger to both.
CP=$(newcode); CQ=$(newcode); CR=$(newcode)
INV="social/$(uid Q)/invites/$(uid P)"   # P asks Q
F1="$RUN-f1"

echo "-- codes"
check "a code is made by its owner" ok P PUT "codes/$CP" "\"$(uid P)\""
check "a code naming someone else is refused" no Q PUT "codes/$CQ" "\"$(uid P)\""
check "a code outside the alphabet is refused" no Q PUT "codes/ABCDEFG1" "\"$(uid Q)\""
check "a short code is refused" no Q PUT "codes/ABCDEFG" "\"$(uid Q)\""
check "a code is not overwritten by another player" no Q PUT "codes/$CP" "\"$(uid Q)\""
check "nor repointed by its owner" no P PUT "codes/$CP" "\"$(uid Q)\""
check "nor deleted by another player" no Q DELETE "codes/$CP"
check "one code is read by anyone signed in" ok R GET "codes/$CP"
check "the codes are not listed" no R GET "codes"
code Q PUT "codes/$CQ" "\"$(uid Q)\"" >/dev/null
code R PUT "codes/$CR" "\"$(uid R)\"" >/dev/null
check "a code is deleted by its owner" ok R DELETE "codes/$CR"

echo "-- friendships (Q opens P's link)"
check "a friendship without the code is refused" no Q PATCH "" "$(both_halves Q P)"
check "with the opener's own code" no Q PATCH "" "$(both_halves Q P "$CQ")"
check "with a code nobody has" no Q PATCH "" "$(both_halves Q P "$CR")"
check "their half alone" no Q PUT "social/$(uid P)/friends/$(uid Q)" "{\"at\":$NOW,\"via\":\"$CP\"}"
check "this player's half alone" no Q PUT "social/$(uid Q)/friends/$(uid P)" "{\"at\":$NOW}"
check "a friend of oneself" no P PUT "social/$(uid P)/friends/$(uid P)" "{\"at\":$NOW,\"via\":\"$CP\"}"
check "a made-up date" no Q PATCH "" "{\"social/$(uid P)/friends/$(uid Q)\":{\"at\":5,\"via\":\"$CP\"},\"social/$(uid Q)/friends/$(uid P)\":{\"at\":5}}"
check "two others made friends by a third who knows the code" no R PATCH "" "$(both_halves Q P "$CP")"
check "a friendship made with the code, both halves at once" ok Q PATCH "" "$(both_halves Q P "$CP")"
check "a friendship is not written twice" no Q PATCH "" "$(both_halves Q P "$CP")"
check "nor one half touched after" no P PUT "social/$(uid P)/friends/$(uid Q)" "{\"at\":$NOW}"
check "one half is not deleted alone" no Q DELETE "social/$(uid Q)/friends/$(uid P)"
check "a stranger does not end a friendship" no R PATCH "" "{\"social/$(uid P)/friends/$(uid Q)\":null,\"social/$(uid Q)/friends/$(uid P)\":null}"
check "a player reads their own social" ok P GET "social/$(uid P)"
check "a friend does not read it" no Q GET "social/$(uid P)"
check "a stranger does not read it" no R GET "social/$(uid P)"
check "anything else under social is refused" no P PUT "social/$(uid P)/note" '"x"'

echo "-- presence"
check "presence is written by its player" ok P PUT "presence/$(uid P)" "{\"at\":$NOW}"
check "presence cannot be made up" no P PUT "presence/$(uid P)" '{"at":5}'
check "nor written for another" no Q PUT "presence/$(uid P)" "{\"at\":$NOW}"
check "a friend reads it" ok Q GET "presence/$(uid P)"
check "a stranger does not" no R GET "presence/$(uid P)"

echo "-- invites (P asks Q)"
check "an invite from a player who is no friend is refused" no R PUT "social/$(uid Q)/invites/$(uid R)" "{\"game\":\"chess\",\"at\":$NOW}"
check "an invite written in another's name" no Q PUT "$INV" "{\"game\":\"chess\",\"at\":$NOW}"
check "an invite to a game that is not one" no P PUT "$INV" "{\"game\":\"ludo\",\"at\":$NOW}"
check "an invite with a made-up clock" no P PUT "$INV" '{"game":"chess","at":5}'
check "an invite from a friend" ok P PUT "$INV" "{\"game\":\"chess\",\"at\":$NOW}"
check "its heartbeat moves at" ok P PATCH "$INV" "{\"at\":$NOW}"
check "the one who asked reads it" ok P GET "$INV"
check "a stranger does not" no R GET "$INV"
check "a stranger does not delete it" no R DELETE "$INV"
check "match set with no match made is refused" no Q PUT "$INV/match" "\"$F1\""
check "a private match with no invite pointing at it" no Q PUT "matches/$F1" "{\"game\":\"chess\",\"p0\":\"$(uid P)\",\"p1\":\"$(uid Q)\",\"first\":0,\"seed\":7,\"at\":$NOW,\"n\":0,\"turn\":0,\"turnAt\":$NOW}"
check "match set by the one who asked (nobody said Play)" no P PATCH "" "$(accept_body "$F1" P Q Q P)"
check "match set by a stranger" no R PATCH "" "$(accept_body "$F1" P Q Q P)"
check "a match naming another in the inviter's seat" no Q PATCH "" "$(accept_body "$F1" R Q Q P)"
check "a match naming another in the invited seat" no Q PATCH "" "$(accept_body "$F1" P R Q P)"
check "a match with the seats the wrong way round" no Q PATCH "" "$(accept_body "$F1" Q P Q P)"
check "a match of another game than was asked" no Q PATCH "" "$(accept_body "$F1" P Q Q P checkers)"
check "a match with a stranger, on an invite that is not there" no Q PATCH "" "$(accept_body "$F1" R Q Q R)"
check "the invited player says Play: the match and the invite's match together" ok Q PATCH "" "$(accept_body "$F1" P Q Q P)"
check "an invite is taken once" no Q PATCH "" "$(accept_body "$RUN-f2" P Q Q P)"
check "the one who asked reads the match" ok P GET "matches/$F1"
check "a stranger does not" no R GET "matches/$F1"
check "a move in it, as in any match" ok P PATCH "matches/$F1" "$(move_body 0 0 1 1)"
check "the one who asked takes the invite back" ok P DELETE "$INV"
code Q PUT "social/$(uid P)/invites/$(uid Q)" "{\"game\":\"snooker\",\"at\":$NOW}" >/dev/null
check "the one asked declines (deletes it)" ok P DELETE "social/$(uid P)/invites/$(uid Q)"
# Left without a heartbeat, for the 10 s clock below.
code P PUT "$INV" "{\"game\":\"chess\",\"at\":$NOW}" >/dev/null

check "an early void is refused" no G PUT "matches/$M4/result" '{"winner":-1,"why":"void"}'
echo "   (waiting for the 10 s clocks)"
wait_until 12
check "void by the one who never showed is refused" no H PUT "matches/$M4/result" '{"winner":-1,"why":"void"}'
check "void after 10 s unseen is accepted" ok G PUT "matches/$M4/result" '{"winner":-1,"why":"void"}'
ticket J
check "a ticket 10 s without a heartbeat cannot be claimed" no J PATCH "" "$(claim_body "$RUN-6" I J)"
check "an invite 10 s without a heartbeat cannot be taken" no Q PATCH "" "$(accept_body "$RUN-f3" P Q Q P)"
check "a friendship is ended by either, both halves at once" ok P PATCH "" "{\"social/$(uid P)/friends/$(uid Q)\":null,\"social/$(uid Q)/friends/$(uid P)\":null,\"$INV\":null}"
check "after it, an invite is refused" no P PUT "$INV" "{\"game\":\"chess\",\"at\":$NOW}"
check "and presence is closed" no Q GET "presence/$(uid P)"
check "left before 20 s is refused" no F PUT "matches/$M3/result" '{"winner":1,"why":"left"}'

if [ -n "${QUICK:-}" ]; then
	skipped "left after 20 s unseen is accepted (QUICK)"
	skipped "a timeout by the seat whose turn it is is refused (QUICK)"
	skipped "a late timeout is accepted (QUICK)"
	skipped "a ticket older than 60 s is removed by anyone (QUICK)"
else
	echo "   (waiting for the 20 s clock)"
	wait_until 23
	code F PUT "matches/$M3/seen/1" "$NOW" >/dev/null
	check "left claimed by the one who left is refused" no E PUT "matches/$M3/result" '{"winner":0,"why":"left"}'
	check "left after 20 s unseen is accepted" ok F PUT "matches/$M3/result" '{"winner":1,"why":"left"}'
	echo "   (waiting for the 60 s clocks)"
	wait_until 63
	check "a timeout by the seat whose turn it is is refused" no C PUT "matches/$M2/result" '{"winner":0,"why":"timeout"}'
	check "a late timeout is accepted" ok D PUT "matches/$M2/result" '{"winner":1,"why":"timeout"}'
	check "a ticket older than 60 s is removed by anyone" ok B DELETE "queue/chess/$(uid I)"
fi

echo "-- $pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
