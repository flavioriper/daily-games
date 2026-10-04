extends RefCounted

## Handing a line of text to another app: the friend link, out through the
## phone's own share sheet. `Share.text(text, title)` answers **true** when
## the sheet was raised, and **false** when it could not be and the text was
## put on the clipboard instead -- the caller then says "Link copied". Either
## way the player leaves with the text somewhere they can send it from.
##
## On Android the sheet is `Intent.createChooser` over an ACTION_SEND, reached
## through the AndroidRuntime singleton and JavaClassWrapper like
## core/haptics.gd's vibrator, no plugin. The intent is not built with a
## constructor: `Intent.parseUri` reads the whole of it (action, type and the
## text as a string extra) out of one `intent:` uri, a static call that needs
## nothing but strings. The text is uri-encoded, so a `;` or a `#` in it
## cannot end the extra early.
##
## Everywhere else (desktop, a harness, iOS -- which has no share sheet
## without a native plugin) it is the clipboard. Rules and what is unproven
## on a device: docs/agents/friends.md, "The link".

## Android's Intent.ACTION_SEND and Intent.EXTRA_TEXT, spelled out: the uri
## names them by value.
const _SEND := "android.intent.action.SEND"
const _EXTRA_TEXT := "android.intent.extra.TEXT"

## What the last call did, for a harness: "sheet", "clipboard" or "".
static var last := ""

static func text(text: String, title := "") -> bool:
	if text == "":
		return false
	if _sheet(text, title):
		last = "sheet"
		return true
	DisplayServer.clipboard_set(text)
	last = "clipboard"
	return false

## The uri `Intent.parseUri` turns into the send intent. Its own function so
## a harness can read it off the phone.
static func send_uri(text: String) -> String:
	return "intent:#Intent;action=%s;type=text/plain;S.%s=%s;end" % [_SEND, _EXTRA_TEXT, text.uri_encode()]

## True only if every step answered with an object: a missing singleton, a
## class that will not wrap, a uri Android refuses or a chooser that comes
## back null all fall through to the clipboard.
static func _sheet(text: String, title: String) -> bool:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime := Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return false
	var intent_class: Variant = JavaClassWrapper.wrap("android.content.Intent")
	if intent_class == null:
		return false
	var intent: Variant = intent_class.parseUri(send_uri(text), 0)
	if intent == null:
		return false
	var chooser: Variant = intent_class.createChooser(intent, title)
	if chooser == null:
		return false
	activity.startActivity(chooser)
	return true
