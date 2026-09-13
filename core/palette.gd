class_name Palette
extends RefCounted

# Deliberately flat and unfinished. We are judging mechanics, not art.
const BG          := Color("14161a")
const SURFACE     := Color("1d2026")
const SURFACE_HI  := Color("272b33")
const LINE        := Color("3a404a")
const TEXT        := Color("e6e8ec")
const TEXT_DIM    := Color("878d99")
const ACCENT      := Color("6ea8fe")
const ACCENT_2    := Color("f0a35e")
const GOOD        := Color("6ec48a")
const BAD         := Color("e0685f")

# Colour-blind-safe categorical ramp, used wherever colour carries meaning.
const CAT := [
	Color("6ea8fe"), Color("f0a35e"), Color("6ec48a"), Color("c792ea"),
	Color("e0685f"), Color("5fd3d0"), Color("d4c85f"), Color("9aa4b2"),
]
