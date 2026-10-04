extends Node

## A Match with nobody behind it: the signals and methods of
## versus/online/match.gd, and nothing happens until a harness says so
## (`say_*`). tests/_shot_online.gd hands it to versus/online/online.gd as
## `Online.stand_in`, so an online screen can be shot with no network.

signal found(seat: int, first: int, seed: int, opponent_uid: String)
signal nobody
signal move(d: Dictionary)
signal ended(winner: int, why: String)
signal clock(seat: int, seconds_left: int)
signal offline

const Match = preload("res://versus/online/match.gd")

var wait := 25.0
var phase: int = Match.Phase.IDLE
var game := ""
var seat := -1
var opponent := ""
## What turn() and seconds_left() answer.
var to_act := 0
var left := 60
## Everything the screen sent, for a harness to read.
var sent: Array = []
var result := {}

func seek(g: String) -> void:
	game = g
	seat = -1
	result = {}
	phase = Match.Phase.SEEKING

func cancel() -> void:
	leave()

func send(d: Dictionary, next_turn: int) -> void:
	sent.append(d)
	to_act = next_turn
	left = 60

func end(winner: int, why := "end") -> void:
	say_ended(winner, why)

func resign() -> void:
	say_ended(1 - seat, "resign")

func leave() -> void:
	phase = Match.Phase.IDLE

func seconds_left() -> int:
	return left if phase == Match.Phase.PLAYING else 0

func turn() -> int:
	return to_act if phase == Match.Phase.PLAYING else -1

# --- the harness's side ---

func say_nobody() -> void:
	nobody.emit()

func say_offline() -> void:
	phase = Match.Phase.IDLE
	offline.emit()

func say_found(the_seat: int, first: int, uid: String) -> void:
	seat = the_seat
	opponent = uid
	to_act = first
	left = 60
	phase = Match.Phase.PLAYING
	found.emit(seat, first, 12345, uid)

## The other seat's move; the turn comes back to this one.
func say_move(d: Dictionary) -> void:
	to_act = seat
	left = 60
	move.emit(d)

func say_clock(seconds: int) -> void:
	left = seconds
	clock.emit(to_act, left)

func say_ended(winner: int, why: String) -> void:
	if phase != Match.Phase.PLAYING:
		return
	phase = Match.Phase.OVER
	result = {"winner": winner, "why": why}
	ended.emit(winner, why)
