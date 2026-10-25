class_name Faction
extends RefCounted

## One side of the war: a colour kingdom, the Neutral towns or the Bandits.

var id: int
var name: String
var color: Color
var king_name: String = ""
var is_kingdom := true
var alive := true
var eliminated_at := -1.0
var upgrades := {}
var kills := 0
var battles_won := 0
var decision_timer := 0.0


func has(up: String) -> bool:
	return upgrades.get(up, 0) > 0


func count(up: String) -> int:
	return upgrades.get(up, 0)


func add_upgrade(up: String) -> void:
	upgrades[up] = count(up) + 1


func hp_mult() -> float:
	return 1.0 + 0.3 * count("giant")


func flat_hp() -> float:
	return 120.0 * count("vitality")


func dmg_mult() -> float:
	return 1.0 + 0.35 * count("sharp")


func speed_mult() -> float:
	return 1.0 + 0.25 * count("haste")


func armor() -> float:
	return 8.0 * count("armor")


func lifesteal() -> float:
	return 0.15 * count("vampirism")


func regen() -> float:
	return 10.0 * count("regen")


func display() -> String:
	return name + (" Kingdom" if is_kingdom else "")
