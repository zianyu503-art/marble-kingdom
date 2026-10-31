class_name Skills
extends RefCounted

## Active abilities marbles use in battle. A unit type lists its skills in
## Soldier.TYPES; some come from kingdom upgrades (dash, whirl, volley).
## title: text shown over the marble when cast ("" = silent), cd: seconds.
const INFO := {
	"whirlwind": {"title": "WHIRLWIND!",   "cd": 7.0,  "col": Color("ff9a4a")},
	"bash":      {"title": "SHIELD BASH!", "cd": 4.5,  "col": Color("cfd6e0")},
	"lunge":     {"title": "LUNGE!",       "cd": 5.0,  "col": Color("ffe08a")},
	"slam":      {"title": "GROUND SLAM!", "cd": 7.0,  "col": Color("e0b070")},
	"warcry":    {"title": "WAR CRY!",     "cd": 12.0, "col": Color("ffd84a")},
	"volley":    {"title": "VOLLEY!",      "cd": 8.0,  "col": Color("bfe3ff")},
	"convert":   {"title": "CONVERT",      "cd": 9.0,  "col": Color("fff2a8")},
	"heal":      {"title": "",             "cd": 1.0,  "col": Color("7dff9a")},
	"raise":     {"title": "RISE!",        "cd": 9.0,  "col": Color("b78cff")},
	"dash":      {"title": "",             "cd": 6.0,  "col": Color.WHITE},
}

## Units that monks cannot convert (wiki: kings, princes and leaders are immune).
const UNCONVERTIBLE := ["king", "captain", "kingsguard", "skeleton"]


## Skills for a soldier: its type's own plus the ones its kingdom unlocked.
static func for_soldier(s: Soldier, f: Faction) -> Array:
	var st := s.stats()
	var out: Array = st.get("skills", []).duplicate()
	if f.has("dash") and not out.has("dash"):
		out.append("dash")
	if f.has("whirl") and st["ranged"] == "" and not out.has("whirlwind"):
		out.append("whirlwind")
	if f.has("volley") and st["ranged"] != "" and not out.has("volley"):
		out.append("volley")
	return out
