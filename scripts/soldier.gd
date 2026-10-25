class_name Soldier
extends RefCounted

## Persistent data for one marble. Lives in an army or a settlement garrison
## between battles; a Unit body is spawned from it while a battle is running.

## Base stats per unit type. weapon: shape drawn and used for collision.
## wlen/wwid: weapon length/width, dmg: damage per hit, spin: rad/s,
## ranged: projectile kind ("" = melee only), cd: ranged cooldown in seconds,
## armor: flat damage removed from every hit.
const TYPES := {
	"fighter":    {"hp": 100, "r": 12.0, "speed": 1.0,  "spin": 6.0,  "weapon": "sword",     "wlen": 18.0, "wwid": 4.0, "dmg": 22.0, "ranged": "",      "cd": 0.0},
	"footman":    {"hp": 130, "r": 12.0, "speed": 0.9,  "spin": 5.0,  "weapon": "sword",     "wlen": 18.0, "wwid": 4.0, "dmg": 22.0, "ranged": "",      "cd": 0.0, "shield": true},
	"spearman":   {"hp": 110, "r": 12.0, "speed": 1.0,  "spin": 3.5,  "weapon": "spear",     "wlen": 32.0, "wwid": 3.0, "dmg": 24.0, "ranged": "",      "cd": 0.0},
	"knight":     {"hp": 200, "r": 13.0, "speed": 0.9,  "spin": 5.0,  "weapon": "sword",     "wlen": 22.0, "wwid": 5.0, "dmg": 30.0, "ranged": "",      "cd": 0.0, "shield": true, "helmet": true, "armor": 4.0},
	"berserker":  {"hp": 140, "r": 13.0, "speed": 1.15, "spin": 12.0, "weapon": "axe",       "wlen": 18.0, "wwid": 5.0, "dmg": 26.0, "ranged": "",      "cd": 0.0},
	"hammerman":  {"hp": 230, "r": 15.0, "speed": 0.7,  "spin": 4.0,  "weapon": "hammer",    "wlen": 24.0, "wwid": 5.0, "dmg": 42.0, "ranged": "",      "cd": 0.0},
	"archer":     {"hp": 80,  "r": 11.0, "speed": 0.9,  "spin": 1.5,  "weapon": "bow",       "wlen": 10.0, "wwid": 3.0, "dmg": 8.0,  "ranged": "arrow", "cd": 1.6},
	"mage":       {"hp": 90,  "r": 11.0, "speed": 0.8,  "spin": 1.5,  "weapon": "staff",     "wlen": 14.0, "wwid": 3.0, "dmg": 8.0,  "ranged": "magic", "cd": 2.2},
	"farmer":     {"hp": 70,  "r": 11.0, "speed": 1.0,  "spin": 5.0,  "weapon": "pitchfork", "wlen": 22.0, "wwid": 3.0, "dmg": 14.0, "ranged": "",      "cd": 0.0},
	"kingsguard": {"hp": 320, "r": 13.0, "speed": 0.85, "spin": 4.0,  "weapon": "halberd",   "wlen": 28.0, "wwid": 4.0, "dmg": 34.0, "ranged": "",      "cd": 0.0, "helmet": true, "armor": 6.0},
	"captain":    {"hp": 320, "r": 14.0, "speed": 1.0,  "spin": 5.0,  "weapon": "sword",     "wlen": 22.0, "wwid": 5.0, "dmg": 32.0, "ranged": "",      "cd": 0.0, "helmet": true, "shield": true, "armor": 4.0},
	"king":       {"hp": 1400, "r": 19.0, "speed": 0.8, "spin": 4.0,  "weapon": "greatsword","wlen": 28.0, "wwid": 6.5, "dmg": 55.0, "ranged": "",      "cd": 0.0, "shield": true, "armor": 12.0},
	"bandit":     {"hp": 100, "r": 12.0, "speed": 1.05, "spin": 7.0,  "weapon": "axe",       "wlen": 16.0, "wwid": 5.0, "dmg": 22.0, "ranged": "",      "cd": 0.0},
	"villager":   {"hp": 70,  "r": 11.0, "speed": 1.0,  "spin": 5.0,  "weapon": "stick",     "wlen": 16.0, "wwid": 3.0, "dmg": 12.0, "ranged": "",      "cd": 0.0},
}

## Types that get a visible name over their head.
const ALWAYS_NAMED := ["king", "captain"]

var type: String = "fighter"
var faction: int = -1
var level: int = 0
var xp: float = 0.0
var hp: float = 0.0
var kills: int = 0
var name: String = ""
## Per-marble perks gained from level-ups.
var bonus_hp: float = 0.0
var bonus_dmg: float = 0.0
var bonus_speed: float = 0.0
var bonus_size: float = 0.0


static func create(t: String, f: int) -> Soldier:
	var s := Soldier.new()
	s.type = t
	s.faction = f
	s.hp = s.max_hp(null)
	return s


func stats() -> Dictionary:
	return TYPES[type]


func max_hp(fac: Faction) -> float:
	var v: float = stats()["hp"] + bonus_hp
	if fac:
		v = v * fac.hp_mult() + fac.flat_hp()
	return v


func radius(fac: Faction) -> float:
	var v: float = stats()["r"] * (1.0 + bonus_size)
	if fac and fac.has("giant"):
		v *= 1.1
	return v


func damage(fac: Faction) -> float:
	var v: float = stats()["dmg"] + bonus_dmg
	if fac:
		v *= fac.dmg_mult()
	return v


func xp_needed() -> float:
	return 3.0 + level * 3.0


## Returns true when the marble levelled up.
func add_xp(amount: float) -> bool:
	xp += amount
	if xp >= xp_needed() and level < 10:
		xp -= xp_needed()
		level += 1
		bonus_hp += stats()["hp"] * 0.25
		bonus_dmg += stats()["dmg"] * 0.12
		bonus_speed += 0.06
		bonus_size += 0.05
		return true
	return false


func is_named() -> bool:
	return name != ""


func display_name() -> String:
	match type:
		"king":
			return "King " + name
		"captain":
			return "Captain " + name
	return name


func power() -> float:
	return (stats()["hp"] + bonus_hp) * 0.01 + (stats()["dmg"] + bonus_dmg) * 0.05
