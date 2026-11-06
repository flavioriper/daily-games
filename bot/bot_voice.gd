class_name BotVoice
extends RefCounted
## Which of the Swarm's ten voices this phone hears (the user, 2026-11-06): a
## woman's or a man's, in the accent of the phone's region. The first time
## it is a coin toss; the player changes it by asking the Swarm on a call
## (the server's `voice` tool sends `tool {name: voice, cmd}`), and it is
## kept in `user://bot_voice` and sent in every hello. The accents and
## regions are server/bot/seeds/swarm_voices.json's; the intro's clips are
## assets/voice/swarm/<KEY>_<language>-<accent>-<gender>.mp3
## (tools/gen_swarm_voice.py).

const FILE := "user://bot_voice"
const GENDERS := ["female", "male"]
const ACCENTS := {"en": ["us", "uk"], "pt": ["br"], "es": ["latam", "spain"]}
const REGIONS := {"en": {"GB": "uk", "IE": "uk"}, "es": {"ES": "spain"}}
## Lines where the Swarm speaks of itself, with a feminine row `<KEY>_F`.
const GENDERED := ["SWARM_L1"]


## "female" or "male": the kept one, or a coin toss that is kept from now on.
static func gender() -> String:
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f != null:
		var g := f.get_as_text().strip_edges()
		if g in GENDERS:
			return g
	var pick: String = GENDERS[randi() % 2]
	keep(pick)
	return pick


static func keep(g: String) -> void:
	if not (g in GENDERS):
		return
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(g)


## The phone's country code ("BR", "GB"), or "" when its locale has none.
static func region() -> String:
	var parts := OS.get_locale().replace("-", "_").split("_")
	for i in range(1, parts.size()):
		if parts[i].length() == 2:
			return parts[i].to_upper()
	return ""


static func accent(lang: String) -> String:
	var r: Dictionary = REGIONS.get(lang, {})
	return String(r.get(region(), ACCENTS.get(lang, ["us"])[0]))


## The voice's folder name, e.g. "pt-br-female".
static func voice_set(lang: String) -> String:
	return "%s-%s-%s" % [lang, accent(lang), gender()]


## The locale key for `key` in this voice: the feminine row where there is one.
static func line_key(key: String) -> String:
	return key + "_F" if key in GENDERED and gender() == "female" else key
