extends Node

## One live game against a stranger, from looking for one to the result: the
## ticket in the queue, the claim, both streams, the heartbeats, the clock
## and the claims a clock allows. Or against a friend (`invite`, `accept`):
## the ticket is then an invite only they can take, nothing is looked for,
## and from the match on it is the same game. It knows no game -- a move is a Dictionary
## it carries from one end to the other -- and a screen talks to nothing
## else: `seek`, then `found`, then `send` and `move` until `ended`.
##
## It is a **follower of state**. The match is one document; the stream hands
## it over whole when it opens and piece by piece after, this keeps it
## (`_m`), applies each event by its path, and after every one hands the game
## the other seat's moves from the count already handed out up to `n`. A
## stream that drops and comes back sends the whole document again, so a move
## made during the gap is simply there to be handed out: reconnecting has no
## code of its own.
##
## The server is rules and nothing else (server/database.rules.json), and its
## clock is the judge: a claim of timeout or of the other having left is made
## when this end's estimate says so (Live.server_now()) and is refused if the
## estimate was wrong, at no cost.
##
## Offline -- Backend not started, or the ticket cannot be written -- it says
## `offline` and stays idle.
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, sections
## 2 and 3; 2026-10-04-friends-design.md, section 3.

const Backend = preload("res://core/backend.gd")
const Live = preload("res://core/live.gd")

## A player was found and both are present. `first` is the seat that opens.
signal found(seat: int, first: int, seed: int, opponent_uid: String)
## `wait` seconds have gone by with nobody to play. It is said once a seek,
## and the looking goes on behind it until `cancel()`.
signal nobody
## The other seat's move, in order, each one once.
signal move(d: Dictionary)
## The game is over. `winner` is a seat, or -1 (a draw); `why` is "resign",
## "timeout", "left" or "end".
signal ended(winner: int, why: String)
## The seat to act and its whole seconds left, when either changes.
signal clock(seat: int, seconds_left: int)
## There is no network to play over.
signal offline
## A game with a friend will not come of this asking, and nothing is looked
## for in its place: "declined" (the invite was deleted under this player:
## they said no, or are in a game), "expired" (the invite was not there to
## take, or too old), "void" (the match was made and they never arrived, or
## left before it began), "unfriend" (the rules refuse the invite: the two
## are not friends).
signal gone(why: String)

enum Phase { IDLE, SEEKING, JOINING, PLAYING, OVER }

## The ticket's heartbeat, the queue's re-read, and how old a heartbeat may be
## for its ticket to be claimed (the rules' 10 s, less a margin for the trip).
const TICKET_BEAT := 4.0
const QUEUE_POLL := 3.0
const FRESH_MS := 8500.0
## A ticket this stale is swept by whoever reads it (the rules' 60 s).
const STALE_MS := 61000.0
const SWEEP_MAX := 4
## The match's heartbeat, and the rules' three clocks.
const SEEN_BEAT := 5.0
const VOID_MS := 10000.0
const LIMIT_MS := 60000.0
const LEFT_MS := 20000.0
## How far past a clock this end waits before claiming on it, since its
## idea of the server's time is an estimate; and the gap between claims.
const GRACE_MS := 1500.0
const CLAIM_GAP := 3.0
## The other's heartbeat arrives every 5 s. A match stream quiet this long is
## dead without having said so, and is cut so it reopens.
const QUIET_MAX := 12.0
## A match whose document never arrives.
const JOIN_MAX := 20.0
const RETRY := 1.0

## Seconds of looking before `nobody`. A var so a probe can shorten it.
var wait := 25.0

var phase: int = Phase.IDLE
var game := ""
## The match's id, this end's seat and the other end's uid, once joined.
var id := ""
var seat := -1
var opponent := ""

var _uid := ""
var _ticket := ""
var _since := 0.0
## The friend this is with ("" against a stranger): the ticket is an invite,
## the queue is not read, and a match that comes to nothing is `gone`.
var _friend := ""
var _path := ""
## The match document as last known, with every array turned back into the
## keyed object it was written as.
var _m: Dictionary = {}
var _t: Variant = null
var _handed := 0
var _outbox: Array = []
var _sending := false
var _scanning := false
var _ticketing := false
var _claiming := false
var _refused := false
var _said_nobody := false
var _seek_t := 0.0
var _beat_t := 0.0
var _poll_t := 0.0
var _seen_t := 0.0
var _join_t := 0.0
var _quiet := 0.0
var _claim_wait := 0.0
var _last_clock := Vector2i(-1, -1)
## Goes up whenever the phase is left, so an answer that arrives for
## something already abandoned is dropped.
var _gen := 0

## The seat this player takes in the match it is joining, known from how it
## got there (the claimed ticket's owner is p0, the claimer p1) before the
## document has said so: walking away in that gap is still a resignation.
var _sits := -1
## The match a claim on its way would make, for a probe to see the moment.
var _claim_mid := ""

var _ticket_stream: Live.Stream
var _stream: Live.Stream

func _init() -> void:
	_ticket_stream = Live.Stream.new()
	_ticket_stream.name = "TicketStream"
	_ticket_stream.event.connect(_on_ticket)
	add_child(_ticket_stream)
	_stream = Live.Stream.new()
	_stream.name = "MatchStream"
	_stream.event.connect(_on_match)
	add_child(_stream)

func _exit_tree() -> void:
	leave()

# --- the screen's side ---

## Looks for a player of `game` ("snooker", "chess", "checkers").
func seek(g: String) -> void:
	leave()
	game = g
	_seek_t = 0.0
	_said_nobody = false
	_seek()

## Asks the friend `uid` to a game of `g`: the ticket is
## social/{uid}/invites/{me}, kept fresh as a queue ticket is, and nobody
## else can take it. `found` when they say Play and both are in the match;
## `gone` when they say no; `nobody` after `wait`, and the asking goes on.
func invite(g: String, uid: String) -> void:
	leave()
	game = g
	_friend = uid
	_seek_t = 0.0
	_said_nobody = false
	_seek()

## Takes the friend `uid`'s invite to a game of `g`: the match and `match` on
## their invite in one write, as a claim is. `found` as ever; `gone` when the
## invite was not there to take.
func accept(g: String, uid: String) -> void:
	leave()
	game = g
	_friend = uid
	_seek_t = 0.0
	_said_nobody = true  # nothing is waited for
	_accept()

## Stops looking. During a game it is leave().
func cancel() -> void:
	leave()

## This seat's move, and the seat to act after it (the same seat again for a
## move that keeps the turn). Moves go out in the order they were sent.
func send(d: Dictionary, next_turn: int) -> void:
	if phase != Phase.PLAYING:
		return
	_outbox.append({"d": JSON.stringify(d), "turn": next_turn})
	_pump()

## The game's own ending, said by the seat that made the last move (the
## rules take it from nobody else). `winner` is a seat or -1. `why` is "end":
## the rules know no other word for it, and each end's own rules know how.
func end(winner: int, why := "end") -> void:
	if phase != Phase.PLAYING:
		return
	_outbox.append({"result": {"winner": winner, "why": why}})
	_pump()

## Gives the game to the other seat.
func resign() -> void:
	if phase != Phase.PLAYING:
		return
	_outbox.append({"result": {"winner": 1 - seat, "why": "resign"}})
	_pump()

## Walks away from whatever this is: the ticket is taken out of the queue, a
## game in progress is resigned, both streams shut. Nothing is emitted.
func leave() -> void:
	if phase == Phase.SEEKING and not _ticket.is_empty():
		@warning_ignore("return_value_discarded")
		Live.remove(_ticket)  # deliberately not awaited
	elif (phase == Phase.JOINING or phase == Phase.PLAYING) and not _m.has("result"):
		var mine := seat if seat >= 0 else _sits
		if mine >= 0:
			@warning_ignore("return_value_discarded")
			Live.write(_path + "/result", {"winner": 1 - mine, "why": "resign"})
	_stop()

## Seconds left to the seat to act, by this end's estimate; 0 outside a game.
func seconds_left() -> int:
	if phase != Phase.PLAYING:
		return 0
	return maxi(0, ceili((float(_m.get("turnAt", 0.0)) + LIMIT_MS - Live.server_now()) / 1000.0))

## The seat to act; -1 outside a game.
func turn() -> int:
	return int(_m.get("turn", -1)) if phase == Phase.PLAYING else -1

func _stop() -> void:
	_gen += 1
	phase = Phase.IDLE
	_ticket_stream.close()
	_stream.close()
	_outbox.clear()
	_sending = false
	_scanning = false
	_ticketing = false
	_claiming = false
	_m = {}
	_t = null
	_handed = 0
	id = ""
	seat = -1
	_sits = -1
	opponent = ""
	_friend = ""
	_last_clock = Vector2i(-1, -1)

func _go_offline() -> void:
	_stop()
	offline.emit()

func _go(why: String) -> void:
	_stop()
	gone.emit(why)

# --- looking ---

func _seek() -> void:
	_gen += 1
	var gen := _gen
	phase = Phase.SEEKING
	_ticket = ""
	if not Live.online():
		# Deferred, so it is heard whichever of seek() and connect() came first.
		_go_offline.call_deferred()
		return
	var token := await Backend.token()
	if gen != _gen:
		return
	if token.is_empty():
		_go_offline()
		return
	_uid = Backend.uid()
	_ticket = "queue/%s/%s" % [game, _uid] if _friend.is_empty() \
		else "social/%s/invites/%s" % [_friend, _uid]
	var ok := await _write_ticket()
	if gen != _gen:
		return
	if not ok:
		if _refused and not _friend.is_empty():
			_go("unfriend")
		else:
			_go_offline()
		return
	_beat_t = 0.0
	_poll_t = QUEUE_POLL  # the first read is at once
	_ticket_stream.open(_ticket)

## The claim an invite is taken with: the match (the one who asked is p0,
## this player p1) and `match` on their invite, together or not at all.
func _accept() -> void:
	_gen += 1
	var gen := _gen
	phase = Phase.SEEKING
	_ticket = ""
	if not Live.online():
		_go_offline.call_deferred()
		return
	var token := await Backend.token()
	if gen != _gen:
		return
	if token.is_empty():
		_go_offline()
		return
	_uid = Backend.uid()
	var ticket := "social/%s/invites/%s" % [_uid, _friend]
	var mid := "%08x%08x%08x" % [randi(), randi(), Time.get_ticks_usec() & 0xffffffff]
	var first := randi() % 2
	_claim_mid = mid
	var claim := await Live.patch("", {
		"matches/%s" % mid: {
			"game": game, "p0": _friend, "p1": _uid,
			"first": first, "seed": randi() & 0x7fffffff, "at": Live.STAMP,
			"n": 0, "turn": first, "turnAt": Live.STAMP,
		},
		"%s/match" % ticket: mid,
	})
	_claim_mid = ""
	if gen != _gen:
		# Abandoned with the claim on its way, as in _scan: a match that was
		# made all the same is resigned, so the friend is not left to wait
		# the void clock out.
		if claim.ok:
			@warning_ignore("return_value_discarded")
			Live.write("matches/%s/result" % mid, {"winner": 0, "why": "resign"})
		return
	if claim.ok:
		_ticket = ticket  # _join takes it away
		_join(mid, 1)
	elif int(claim.code) == 0:
		_go_offline()
	else:
		_go("expired")

## Writes the ticket new: `since` and `at` are the server's clock, as the
## rules insist (an invite's are `game` and `at`). False when it would not
## go, and `_refused` when it was the rules that said so.
func _write_ticket() -> bool:
	var gen := _gen
	var path := _ticket
	_ticketing = true
	_refused = false
	var res := await Live.write(path, {"since": Live.STAMP, "at": Live.STAMP} if _friend.is_empty() \
		else {"game": game, "at": Live.STAMP})
	if gen != _gen:
		# Abandoned while the write was on its way, and it may have landed
		# after the delete that abandoning sent.
		if res.ok and (phase != Phase.SEEKING or _ticket != path):
			@warning_ignore("return_value_discarded")
			Live.remove(path)
		return false
	_ticketing = false
	if not res.ok or typeof(res.data) != TYPE_DICTIONARY:
		_refused = int(res.code) == 401
		return false
	_since = float(res.data.get("since", 0.0))
	return true

func _seek_tick(delta: float) -> void:
	_seek_t += delta
	if not _said_nobody and _seek_t >= wait:
		_said_nobody = true
		nobody.emit()
		if phase != Phase.SEEKING:
			return
	if _ticket.is_empty() or _ticketing:
		return
	_beat_t += delta
	if _beat_t >= TICKET_BEAT:
		_beat_t = 0.0
		@warning_ignore("return_value_discarded")
		Live.patch(_ticket, {"at": Live.STAMP})  # deliberately not awaited
	_poll_t += delta
	if _friend.is_empty() and _poll_t >= QUEUE_POLL and not _scanning:
		_poll_t = 0.0
		_scan()

## Reads the queue and claims the oldest ticket that is fresh, unmatched and
## older than this one. Older tickets are claimed and newer ones claim, so
## two seekers never claim each other at once.
func _scan() -> void:
	var gen := _gen
	_scanning = true
	var res := await Live.read("queue/%s" % game, {"orderBy": "since"})
	if gen != _gen:
		return
	_scanning = false
	if not res.ok:
		return
	var queue: Dictionary = res.data if typeof(res.data) == TYPE_DICTIONARY else {}
	var mine: Variant = queue.get(_uid)
	if typeof(mine) != TYPE_DICTIONARY:
		# Swept or lost: back in the queue, at its end.
		@warning_ignore("return_value_discarded")
		_write_ticket()
		return
	if mine.has("match"):
		_join(str(mine.match), 0)  # the stream should have said so; this is the net under it
		return
	var now := Live.server_now()
	var best := ""
	var best_since := INF
	var swept := 0
	for u in queue:
		var t: Variant = queue[u]
		if str(u) == _uid or typeof(t) != TYPE_DICTIONARY:
			continue
		var age := now - float(t.get("at", 0.0))
		if age > STALE_MS and swept < SWEEP_MAX:
			swept += 1
			@warning_ignore("return_value_discarded")
			Live.remove("queue/%s/%s" % [game, u])  # deliberately not awaited
			continue
		if t.has("match") or age > FRESH_MS:
			continue
		var s := float(t.get("since", 0.0))
		if s > _since or (s == _since and str(u) > _uid):
			continue
		if s < best_since or (s == best_since and str(u) < best):
			best = str(u)
			best_since = s
	if best.is_empty():
		return
	# The claim: the match and `match` on both tickets land together or not at
	# all. The claimed ticket's owner is p0. Refused means someone else got
	# there first, or the ticket went; the next read finds another.
	var mid := "%08x%08x%08x" % [randi(), randi(), Time.get_ticks_usec() & 0xffffffff]
	var first := randi() % 2
	_scanning = true
	_claim_mid = mid
	var claim := await Live.patch("", {
		"matches/%s" % mid: {
			"game": game, "p0": best, "p1": _uid,
			"first": first, "seed": randi() & 0x7fffffff, "at": Live.STAMP,
			"n": 0, "turn": first, "turnAt": Live.STAMP,
		},
		"queue/%s/%s/match" % [game, best]: mid,
		"queue/%s/%s/match" % [game, _uid]: mid,
	})
	_claim_mid = ""
	if gen != _gen:
		# Abandoned while the claim was on its way. If it landed all the same
		# there is a match the other player is being sent to: it is resigned at
		# once (the claimer is p1), so they go back to looking now and not when
		# the void clock runs out. Unless the stream said so first and this is
		# the match already joined.
		if claim.ok and id != mid:
			@warning_ignore("return_value_discarded")
			Live.write("matches/%s/result" % mid, {"winner": 0, "why": "resign"})
		return
	_scanning = false
	if claim.ok:
		_join(mid, 1)

func _on_ticket(kind: String, path: String, data: Variant) -> void:
	if phase != Phase.SEEKING or kind == "cancel":
		return
	_t = _apply(_t, kind, path, data)
	if typeof(_t) == TYPE_DICTIONARY and _t.has("match"):
		# This player's own claim is heard of here too, and sometimes first.
		_join(str(_t.match), 1 if str(_t.match) == _claim_mid else 0)
	elif _t == null and not _friend.is_empty():
		# The stream opens after the invite is written, so an invite that is
		# not there was deleted: the friend said no (or has gone from the
		# friends, and took it with them).
		_go("declined")

# --- joining ---

## A match names this player. The ticket has done its work and goes; the
## match is listened to, and is a game once both have been seen in it.
func _join(mid: String, sits: int) -> void:
	if phase != Phase.SEEKING:
		return
	_gen += 1
	phase = Phase.JOINING
	_ticket_stream.close()
	# A friend's invite is taken away by the one who asked (p0): were the one
	# who accepted to delete it, an asker whose stream reopened just then would
	# read nothing there and call it declined. `match` on it keeps it quiet.
	if not _ticket.is_empty() and (_friend.is_empty() or sits == 0):
		@warning_ignore("return_value_discarded")
		Live.remove(_ticket)  # deliberately not awaited
	_scanning = false
	_ticketing = false
	id = mid
	_path = "matches/%s" % id
	_m = {}
	_t = null
	_handed = 0
	seat = -1
	_sits = sits
	_seen_t = SEEN_BEAT  # the first heartbeat goes as soon as the seat is known
	_join_t = 0.0
	_quiet = 0.0
	_claim_wait = 0.0
	_stream.open(_path)

## Back to looking, without a word: the match was void. A friend's match
## is not looked for again: it is `gone`.
func _reseek() -> void:
	if not _friend.is_empty():
		_go("void")
		return
	var g := game
	var looked := _seek_t
	var said := _said_nobody
	_stop()
	game = g
	_seek_t = looked
	_said_nobody = said
	_seek()

# --- the match ---

func _on_match(kind: String, path: String, data: Variant) -> void:
	if phase != Phase.JOINING and phase != Phase.PLAYING:
		return
	if kind == "cancel":
		# The rules will not let this player read it: no match of ours.
		if phase == Phase.JOINING:
			_reseek()
		return
	_quiet = 0.0
	var m: Variant = _apply(_m, kind, path, data)
	_m = m if typeof(m) == TYPE_DICTIONARY else {}
	_follow()

## Everything the document implies that has not been said yet.
func _follow() -> void:
	if _m.is_empty():
		return
	if seat < 0:
		if str(_m.get("p0", "")) == _uid:
			seat = 0
		elif str(_m.get("p1", "")) == _uid:
			seat = 1
		else:
			return
		opponent = str(_m.get("p1" if seat == 0 else "p0", ""))
	var result: Variant = _m.get("result")
	if phase == Phase.JOINING:
		var seen: Variant = _m.get("seen")
		if typeof(seen) == TYPE_DICTIONARY and seen.has("0") and seen.has("1"):
			phase = Phase.PLAYING
			found.emit(seat, int(_m.get("first", 0)), int(_m.get("seed", 0)), opponent)
		elif typeof(result) == TYPE_DICTIONARY:
			_reseek()  # void, or the other left before it began
			return
		else:
			return
	var gen := _gen
	var moves: Variant = _m.get("moves")
	if typeof(moves) == TYPE_DICTIONARY:
		var n := int(_m.get("n", 0))
		while phase == Phase.PLAYING and gen == _gen and _handed < n and moves.has(str(_handed)):
			var mv: Variant = moves[str(_handed)]
			_handed += 1
			if typeof(mv) == TYPE_DICTIONARY and int(mv.get("s", -1)) != seat:
				var d: Variant = JSON.parse_string(str(mv.get("d", "")))
				move.emit(d if typeof(d) == TYPE_DICTIONARY else {})
	if phase != Phase.PLAYING or gen != _gen:
		return
	if typeof(result) == TYPE_DICTIONARY:
		phase = Phase.OVER
		_gen += 1
		_stream.close()
		_outbox.clear()
		ended.emit(int(result.get("winner", -1)), str(result.get("why", "")))
		return
	_tell_clock()

func _tell_clock() -> void:
	var now := Vector2i(int(_m.get("turn", 0)), seconds_left())
	if now != _last_clock:
		_last_clock = now
		clock.emit(now.x, now.y)

func _match_tick(delta: float) -> void:
	_claim_wait = maxf(0.0, _claim_wait - delta)
	_quiet += delta
	if _quiet > QUIET_MAX:
		_quiet = 0.0
		if _stream.is_open():
			_stream.drop()
	if seat < 0:
		_join_t += delta
		if _join_t > JOIN_MAX:
			_go_offline()
		return
	_seen_t += delta
	if _seen_t >= SEEN_BEAT:
		_seen_t = 0.0
		@warning_ignore("return_value_discarded")
		Live.write("%s/seen/%d" % [_path, seat], Live.STAMP)  # deliberately not awaited
	var now := Live.server_now()
	var seen: Variant = _m.get("seen")
	var theirs: Variant = seen.get(str(1 - seat)) if typeof(seen) == TYPE_DICTIONARY else null
	if phase == Phase.JOINING:
		# Claimed, and the other never came: void, and back to looking.
		if theirs == null and now - float(_m.get("at", now)) > VOID_MS + GRACE_MS:
			_claim({"winner": -1, "why": "void"})
		return
	_tell_clock()
	if int(_m.get("turn", seat)) != seat \
			and now - float(_m.get("turnAt", now)) > LIMIT_MS + GRACE_MS:
		_claim({"winner": seat, "why": "timeout"})
	elif theirs != null and now - float(theirs) > LEFT_MS + GRACE_MS:
		_claim({"winner": seat, "why": "left"})

## Asks the rules for a result a clock allows. Refused means this end's clock
## or its copy of the match was behind; it asks again after CLAIM_GAP if the
## reason still stands.
func _claim(result: Dictionary) -> void:
	if _claiming or _claim_wait > 0.0:
		return
	var gen := _gen
	_claiming = true
	var res := await Live.write(_path + "/result", result)
	if gen != _gen:
		return
	_claiming = false
	_claim_wait = CLAIM_GAP
	if res.ok:
		_on_match("put", "/result", result)

## Sends what is waiting, one at a time and in order. A move is a PATCH of
## moves/{n}, n, turn and turnAt together; what the server answered is applied
## here at once, so a second move right behind it counts from the right n
## without waiting for the stream to say so.
##
## A move keeps the `n` it was first sent at. Anything but a yes -- no answer,
## or a refusal -- is settled by reading moves/{n}: the PATCH may have landed
## with its answer lost, and the same thing sent again is then refused because
## it is already there (or, had `n` been counted afresh from a stream that has
## caught up, would go in twice). If the move is there it was sent, and what is
## queued behind it goes out one further on.
func _pump() -> void:
	if _sending:
		return
	var gen := _gen
	_sending = true
	while gen == _gen and phase == Phase.PLAYING and not _outbox.is_empty():
		var item: Dictionary = _outbox[0]
		if item.has("result"):
			var res := await Live.write(_path + "/result", item.result)
			if gen != _gen:
				return
			if res.ok or res.code == 401:
				# Refused is final: there is a result already, or the rules
				# do not allow this one.
				_outbox.pop_front()
				if res.ok:
					_on_match("put", "/result", item.result)
				continue
		else:
			# _handed too: a stream that reopens may hand over a copy taken
			# just before this end's last move, and n steps back for a moment.
			if not item.has("n"):
				item["n"] = maxi(int(_m.get("n", 0)), _handed)
			var n: int = item.n
			var body := {
				"moves/%d" % n: {"s": seat, "d": item.d},
				"n": n + 1, "turn": item.turn, "turnAt": Live.STAMP,
			}
			var res := await Live.patch(_path, body)
			if gen != _gen:
				return
			var echo: Variant = res.data if res.ok else null
			var settled: bool = res.ok
			if not res.ok:
				var there := await Live.read("%s/moves/%d" % [_path, n])
				if gen != _gen:
					return
				if there.ok and typeof(there.data) == TYPE_DICTIONARY \
						and int(there.data.get("s", -1)) == seat and str(there.data.get("d", "")) == item.d:
					body.erase("turnAt")  # the stream brings the real one
					echo = body
					settled = true
				elif res.code == 401 and (there.ok or there.code == 401):
					# Refused, and not there: final. The game is over, or this end
					# is out of step, and the clock settles it.
					settled = true
			if settled:
				_outbox.pop_front()
				# The stream may have said all this already, and the answer to it
				# too: an echo behind what the copy holds would roll n, the turn
				# and its clock back.
				if typeof(echo) == TYPE_DICTIONARY and int(_m.get("n", 0)) <= n:
					_on_match("patch", "/", echo)
				continue
		# The network did not answer. The same thing again, a little later.
		await get_tree().create_timer(RETRY).timeout
		if gen != _gen:
			return
	_sending = false

func _process(delta: float) -> void:
	match phase:
		Phase.SEEKING:
			_seek_tick(delta)
		Phase.JOINING, Phase.PLAYING:
			_match_tick(delta)

# --- following ---

## `root` after one stream event. A `put` replaces what is at `path`; a
## `patch` sets each of its keys under `path`, and a key may itself be a path
## ("moves/3"), which is how a multi-path PATCH is echoed.
static func _apply(root: Variant, kind: String, path: String, data: Variant) -> Variant:
	var keys := path.split("/", false)
	if kind != "patch":
		return _set_at(root, keys, data)
	if typeof(data) != TYPE_DICTIONARY:
		return root
	for k in data:
		var deep := keys.duplicate()
		deep.append_array(str(k).split("/", false))
		root = _set_at(root, deep, data[k])
	return root

static func _set_at(root: Variant, keys: PackedStringArray, value: Variant) -> Variant:
	if keys.is_empty():
		return _keyed(value)
	var node: Dictionary = root if typeof(root) == TYPE_DICTIONARY else {}
	var child: Variant = _set_at(node.get(keys[0]), keys.slice(1), value)
	if child == null:
		node.erase(keys[0])
	else:
		node[keys[0]] = child
	return null if node.is_empty() else node

## The database hands an object whose keys are 0, 1, 2... back as an array
## (`moves`, `seen`). This turns every array into the keyed object it was
## written as, so a path means one thing.
static func _keyed(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var out := {}
		for i in value.size():
			if value[i] != null:
				out[str(i)] = _keyed(value[i])
		return null if out.is_empty() else out
	if typeof(value) == TYPE_DICTIONARY:
		var out := {}
		for k in value:
			var v: Variant = _keyed(value[k])
			if v != null:
				out[str(k)] = v
		return null if out.is_empty() else out
	return value
