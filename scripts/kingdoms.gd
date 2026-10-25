class_name Kingdoms
extends RefCounted

## The colour kingdoms of Marble Kingdoms (see the fan wiki "Factions" page).
const LIST := [
	{"name": "Red",     "color": Color("e53b2f")},
	{"name": "Blue",    "color": Color("2e5bd6")},
	{"name": "Green",   "color": Color("3c9e48")},
	{"name": "Yellow",  "color": Color("f2d22a")},
	{"name": "Orange",  "color": Color("f28c1c")},
	{"name": "Cyan",    "color": Color("49d3e6")},
	{"name": "Purple",  "color": Color("7d3bc4")},
	{"name": "Magenta", "color": Color("e03fc9")},
	{"name": "Pink",    "color": Color("f6a5c8")},
	{"name": "Lime",    "color": Color("a6e34a")},
	{"name": "Teal",    "color": Color("1f9c8e")},
	{"name": "Beige",   "color": Color("dccaa2")},
	{"name": "Brown",   "color": Color("8a5a3a")},
]

const NEUTRAL := {"name": "Neutral", "color": Color("a5a5a5")}
const BANDITS := {"name": "Bandits", "color": Color("55565c")}

const SYL_A := ["Al", "Bra", "Cor", "Da", "El", "Fa", "Gor", "Hel", "Is", "Jor", "Ka", "Lu", "Mor", "Ne",
	"Or", "Pe", "Qua", "Ro", "Sa", "Ty", "Ul", "Va", "Wil", "Xan", "Yo", "Zel", "Fro", "Gla", "Tho", "Mi"]
const SYL_B := ["dan", "ric", "lia", "na", "mir", "bert", "sufa", "ka", "do", "vin", "rax", "len", "gar",
	"tis", "wyn", "mon", "ra", "lo", "zz", "beth", "ius", "ford", "ska", "ten", "dor", "ny", "phe"]
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII",
	"XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII", "XXIII", "XXIV"]


static func random_name(rng: RandomNumberGenerator) -> String:
	var n: String = SYL_A[rng.randi() % SYL_A.size()] + SYL_B[rng.randi() % SYL_B.size()]
	if rng.randf() < 0.35:
		n += SYL_B[rng.randi() % SYL_B.size()]
	return n


static func random_king_name(rng: RandomNumberGenerator) -> String:
	return random_name(rng) + " " + ROMAN[rng.randi_range(1, ROMAN.size() - 1)]


static func roman(n: int) -> String:
	return ROMAN[n] if n > 0 and n < ROMAN.size() else str(n)
