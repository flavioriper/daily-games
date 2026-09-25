extends "res://ui/hud/sheet.gd"

## Who made what the game is built on: the two typefaces, the word lists
## the word boards deal from, the sound and the engine, with the notices
## their licences ask a shipped game to carry (the SIL OFL for the fonts,
## CC-BY-SA 4.0 attribution for wordfreq, and the MIT notice for Godot and
## the FreeType notice it passes on). Opened from the settings sheet, over
## it, so closing it lands back there. The engine's licence text is long, so
## the body scrolls inside the sheet.

const BODY_H := 1000.0

var close_button: Button

func _card_style() -> StyleBox:
	return CozyTheme.parchment_card()

func _build_sheet(col: VBoxContainer) -> void:
	var heading := Label.new()
	heading.theme_type_variation = "SheetTitle"
	heading.text = "CREDITS_TITLE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = BODY_H
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	_section(body, "CREDITS_FONTS",
		"Fredoka, copyright 2016 The Fredoka Project Authors (github.com/hafontia/Fredoka-One). Nunito, copyright 2014 The Nunito Project Authors (github.com/googlefonts/nunito). Both under the SIL Open Font License 1.1.")
	_section(body, "CREDITS_WORDS",
		"Word lists drawn from and ordered by wordfreq, by Robyn Speer et al. (github.com/rspeer/wordfreq), licensed CC-BY-SA 4.0.")
	_section(body, "CREDITS_SOUND", "Sound effects made with ElevenLabs.")
	_section(body, "CREDITS_ENGINE",
		"Made with the Godot Engine (godotengine.org). Portions of this software are copyright © 2014-present the Godot Engine contributors. Portions of this software are copyright © The FreeType Project (freetype.org). All rights reserved.")
	var licence := Label.new()
	licence.theme_type_variation = "SheetBodyDim"
	licence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	licence.text = Engine.get_license_text()
	body.add_child(licence)
	close_button = IconButton.new("check", "BTN_CLOSE", "PrimaryButton")
	close_button.custom_minimum_size.y = ROW
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	col.add_child(close_button)

## A heading in the reader's language over a line that names people and
## licences, which stay as written.
func _section(body: VBoxContainer, key: String, text: String) -> void:
	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = key
	body.add_child(title)
	var line := Label.new()
	line.theme_type_variation = "SheetBody"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.text = text
	# Proper names and licence names are not keys.
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.add_child(line)
