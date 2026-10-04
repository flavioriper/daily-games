extends RefCounted

## Who the stranger across the board is: a face and a name, both dealt from a
## hash of the uid, so each end draws the other alike and nobody types a
## thing (the game has an age gate; there is no text and no chat online).
##
## The face is one of the drawn characters in ui/faces/ that sits on a
## scoreboard as the sun and the moon do -- a plain Face that needs nothing
## set but its size and answers to the expressions the screens ask of it
## (HAPPY, JOY, WORRIED, SLEEPY). The name is that character's, translated,
## and a three-digit number: "Hedgehog 482". No adjective, so Portuguese and
## Spanish need no agreement. Characters are code: no image.
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 3.

## Name key and drawing. The order is the deal: adding one at the end
## renames players, so it is done between versions, not within one.
const CAST := [
	["VS_NAME_BERRY", preload("res://ui/faces/berry_face.gd")],
	["VS_NAME_ACORN", preload("res://ui/faces/acorn_face.gd")],
	["VS_NAME_CLOUD", preload("res://ui/faces/cloud_face.gd")],
	["VS_NAME_LEAF", preload("res://ui/faces/leaf_face.gd")],
	["VS_NAME_FLOWER", preload("res://ui/faces/flower_face.gd")],
	["VS_NAME_PEAR", preload("res://ui/faces/pear_face.gd")],
	["VS_NAME_PUMPKIN", preload("res://ui/faces/pumpkin_face.gd")],
	["VS_NAME_MUSHROOM", preload("res://ui/faces/mushroom_face.gd")],
	["VS_NAME_HEDGEHOG", preload("res://ui/faces/hedgehog_face.gd")],
]

## String.hash() is the same 32-bit number on every platform, which is the
## whole requirement: both phones must deal the same.
static func _index(uid: String) -> int:
	return uid.hash() % CAST.size()

## A new face for `uid`; the caller sizes it and seats it.
static func face_of(uid: String) -> Control:
	return CAST[_index(uid)][1].new()

## The key of the character's name, for a Label that translates itself.
static func key_of(uid: String) -> String:
	return CAST[_index(uid)][0]

## 100 to 999, so it is always three digits.
static func number_of(uid: String) -> int:
	@warning_ignore("integer_division")
	return 100 + (uid.hash() / CAST.size()) % 900

## "Hedgehog 482" in the language the game is in now.
static func name_of(uid: String) -> String:
	return "%s %d" % [TranslationServer.translate(key_of(uid)), number_of(uid)]
