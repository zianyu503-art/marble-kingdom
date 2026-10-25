class_name Upgrades
extends RefCounted

## Power-ups drawn on the plinko (based on the wiki's "Power Ups" page).
## kind "buff" is stored on the Faction, "recruit"/"special" are applied by Game.
const ALL := {
	"sharp":      {"title": "Sharpness",     "desc": "+35% weapon damage",          "kind": "buff",    "icon": "blade"},
	"regen":      {"title": "Regeneration",  "desc": "+10 HP/s while fighting",     "kind": "buff",    "icon": "cross"},
	"giant":      {"title": "Giant",         "desc": "Bigger marbles, +30% HP",     "kind": "buff",    "icon": "big"},
	"haste":      {"title": "Haste",         "desc": "+25% speed and spin",         "kind": "buff",    "icon": "wing"},
	"vitality":   {"title": "Vitality",      "desc": "+120 max HP",                 "kind": "buff",    "icon": "heart"},
	"armor":      {"title": "Helmets",       "desc": "-8 damage taken per hit",     "kind": "buff",    "icon": "helmet"},
	"vampirism":  {"title": "Vampirism",     "desc": "Heal 15% of damage dealt",    "kind": "buff",    "icon": "fang"},
	"spectral":   {"title": "Spectral Sword","desc": "A ghost sword orbits each marble", "kind": "buff", "icon": "ghost"},
	"wisdom":     {"title": "Wisdom",        "desc": "+1 XP per battle",            "kind": "buff",    "icon": "book"},
	"seek":       {"title": "Seek",          "desc": "Armies steer toward enemies", "kind": "buff",    "icon": "eye"},
	"muster":     {"title": "Muster",        "desc": "+12 soldiers in the city",    "kind": "recruit", "icon": "flag"},
	"farmers":    {"title": "Farmers",       "desc": "+20 farmers join",            "kind": "recruit", "icon": "fork"},
	"archers":    {"title": "Archers",       "desc": "+8 archers join",             "kind": "recruit", "icon": "bow"},
	"mage":       {"title": "Mage",          "desc": "+2 mages join",               "kind": "recruit", "icon": "star"},
	"kingsguard": {"title": "Kingsguard",    "desc": "+3 kingsguards in the city",  "kind": "recruit", "icon": "shield"},
	"berserkers": {"title": "Berserkers",    "desc": "+6 berserkers join",          "kind": "recruit", "icon": "axe"},
	"town":       {"title": "Build Town",    "desc": "Found a new town nearby",     "kind": "special", "icon": "house"},
	"declare":    {"title": "Declare King",  "desc": "Strongest marble is crowned, +2 kingsguards", "kind": "special", "icon": "crown"},
}

## Town decisions after an army wins at a settlement (wiki: "Town Decisions").
const TOWN := {
	"conquer": {"title": "Conquer", "desc": "Take the town, +10 soldiers", "icon": "flag"},
	"raze":    {"title": "Raze",    "desc": "Destroy it, gain an upgrade", "icon": "fire"},
	"occupy":  {"title": "Occupy",  "desc": "Take it, heal the army",      "icon": "cross"},
	"plunder": {"title": "Plunder", "desc": "+10 soldiers, leave it",      "icon": "bag"},
}


## Picks `n` distinct upgrade ids that make sense for faction `f`.
static func roll(rng: RandomNumberGenerator, f: Faction, has_king: bool, n := 4) -> Array:
	var pool: Array = []
	for k in ALL:
		if k == "declare" and has_king:
			continue
		if k in ["spectral", "seek"] and f.has(k):
			continue
		pool.append(k)
	var out: Array = []
	if not has_king and f.is_kingdom:
		out.append("declare")
		pool.erase("declare")
	while out.size() < n and pool.size() > 0:
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out


## Draws a small icon for a plinko bin.
static func draw_icon(ci: CanvasItem, icon: String, c: Vector2, r: float, col: Color) -> void:
	var ink := Color(0.1, 0.1, 0.12)
	var w := maxf(2.0, r * 0.18)
	match icon:
		"blade":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.15, r * 0.4), c + Vector2(0, -r), c + Vector2(r * 0.15, r * 0.4)]), Color(0.85, 0.87, 0.9))
			ci.draw_line(c + Vector2(-r * 0.45, r * 0.45), c + Vector2(r * 0.45, r * 0.45), ink, w)
			ci.draw_line(c + Vector2(0, r * 0.45), c + Vector2(0, r), Color("7a4a24"), w)
		"cross":
			ci.draw_rect(Rect2(c - Vector2(r * 0.22, r * 0.8), Vector2(r * 0.44, r * 1.6)), Color("e04848"))
			ci.draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.22), Vector2(r * 1.6, r * 0.44)), Color("e04848"))
		"big":
			ci.draw_circle(c, r * 0.8, col)
			ci.draw_arc(c, r * 0.8, 0, TAU, 24, ink, w)
			ci.draw_line(c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.3, 0), ink, w)
			ci.draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.3), ink, w)
		"wing":
			for i in 3:
				var y := (i - 1) * r * 0.4
				ci.draw_line(c + Vector2(-r * 0.8, y), c + Vector2(r * 0.4 - i * r * 0.1, y), Color("5fb0ff"), w)
			ci.draw_circle(c + Vector2(r * 0.5, 0), r * 0.35, col)
		"heart":
			ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.4, Color("e04848"))
			ci.draw_circle(c + Vector2(r * 0.35, -r * 0.2), r * 0.4, Color("e04848"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.74, 0), c + Vector2(r * 0.74, 0), c + Vector2(0, r * 0.8)]), Color("e04848"))
		"helmet":
			ci.draw_arc(c + Vector2(0, r * 0.2), r * 0.75, PI, TAU, 16, Color(0.6, 0.62, 0.66), r * 0.5)
			ci.draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.2), ink, w)
		"fang":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.5), c + Vector2(-r * 0.2, -r * 0.5), c + Vector2(-r * 0.4, r * 0.6)]), Color.WHITE)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, -r * 0.5), c + Vector2(r * 0.6, -r * 0.5), c + Vector2(r * 0.4, r * 0.6)]), Color.WHITE)
			ci.draw_line(c + Vector2(-r * 0.8, -r * 0.5), c + Vector2(r * 0.8, -r * 0.5), Color("b02020"), w)
		"ghost":
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), Color(0.6, 0.9, 1.0, 0.9), w * 1.6)
			ci.draw_arc(c, r * 0.9, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.6), w * 0.6)
		"book":
			ci.draw_rect(Rect2(c - Vector2(r * 0.7, r * 0.6), Vector2(r * 1.4, r * 1.2)), Color("7a3d2a"))
			ci.draw_rect(Rect2(c - Vector2(r * 0.55, r * 0.45), Vector2(r * 1.1, r * 0.9)), Color("f2e6c8"))
			ci.draw_line(c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.45), ink, w * 0.6)
		"eye":
			ci.draw_arc(c, r * 0.75, 0.3, PI - 0.3, 16, ink, w)
			ci.draw_arc(c, r * 0.75, PI + 0.3, TAU - 0.3, 16, ink, w)
			ci.draw_circle(c, r * 0.3, col)
		"flag":
			ci.draw_line(c + Vector2(-r * 0.5, r), c + Vector2(-r * 0.5, -r), ink, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r), c + Vector2(r * 0.8, -r * 0.6), c + Vector2(-r * 0.5, -r * 0.1)]), col)
		"fork":
			ci.draw_line(c + Vector2(0, r), c + Vector2(0, -r * 0.3), Color("7a4a24"), w)
			for x in [-0.4, 0.0, 0.4]:
				ci.draw_line(c + Vector2(r * x, -r * 0.3), c + Vector2(r * x, -r), Color(0.7, 0.7, 0.72), w * 0.7)
			ci.draw_line(c + Vector2(-r * 0.4, -r * 0.3), c + Vector2(r * 0.4, -r * 0.3), Color(0.7, 0.7, 0.72), w * 0.7)
		"bow":
			ci.draw_arc(c + Vector2(-r * 0.4, 0), r * 0.9, -1.1, 1.1, 16, Color("7a4a24"), w)
			ci.draw_line(c + Vector2(-r * 0.4 + cos(-1.1) * r * 0.9, sin(-1.1) * r * 0.9), c + Vector2(-r * 0.4 + cos(1.1) * r * 0.9, sin(1.1) * r * 0.9), ink, w * 0.4)
			ci.draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.8, 0), ink, w * 0.6)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
			ci.draw_colored_polygon(pts, Color("a070ff"))
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), col)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0), c + Vector2(-r * 0.7, -r * 0.8)]), ink, w * 0.6)
		"axe":
			ci.draw_line(c + Vector2(-r * 0.5, r), c + Vector2(r * 0.3, -r), Color("7a4a24"), w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.1, -r * 0.6), c + Vector2(r * 0.9, -r * 0.8), c + Vector2(r * 0.7, 0)]), Color(0.75, 0.77, 0.8))
		"house":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.1), Vector2(r * 1.2, r * 0.9)), Color("c9a77a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.1), c + Vector2(0, -r * 0.9), c + Vector2(r * 0.8, -r * 0.1)]), Color("b0473a"))
		"crown":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, r * 0.5), c + Vector2(-r * 0.8, -r * 0.5), c + Vector2(-r * 0.4, 0), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.4, 0), c + Vector2(r * 0.8, -r * 0.5), c + Vector2(r * 0.8, r * 0.5)]), Color("ffcf33"))
		"fire":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.6, 0), c + Vector2(r * 0.4, r * 0.8), c + Vector2(-r * 0.4, r * 0.8), c + Vector2(-r * 0.6, 0)]), Color("ff7a1a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.3), c + Vector2(r * 0.3, r * 0.3), c + Vector2(0, r * 0.7), c + Vector2(-r * 0.3, r * 0.3)]), Color("ffd84a"))
		"bag":
			ci.draw_circle(c + Vector2(0, r * 0.2), r * 0.65, Color("b08850"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.25, -r * 0.8), Vector2(r * 0.5, r * 0.4)), Color("b08850"))
			ci.draw_string(ThemeDB.fallback_font, c + Vector2(-r * 0.25, r * 0.5), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r), Color("ffe066"))
		_:
			ci.draw_circle(c, r * 0.6, col)
