# Marble Kingdom (Godot 4)

A marble war simulation in the style of the **Marble Kingdoms** YouTube series by
[Lost Marbles](https://marble-kingdoms.fandom.com/wiki/Lost_Marbles). This is a fan-made
remake, built in Godot 4.6, and is not affiliated with Lost Marbles.

一個仿照 Lost Marbles《Marble Kingdoms》系列製作的彈珠王國戰爭模擬遊戲（Godot 4.6）。

## How it plays

- **Choose kingdoms**: pick 2–13 colour kingdoms (Red, Blue, Green, Yellow, Orange, Cyan,
  Purple, Magenta, Pink, Lime, Teal, Beige, Brown), name each king, and set the number of
  neutral towns, bandits and the map seed.
- **World map**: a parchment map with mountains, forests, a river and roads. Each kingdom
  starts with a city (its king plus two kingsguards). Hatched colour shows each kingdom's
  territory.
- **Armies** wander the map at random. Cities and towns keep producing soldiers, and a full
  city musters a new army led by a captain. An army reinforces and heals when it reaches a
  friendly settlement.
- **Battles**: when two enemy armies meet, or an army attacks a town, the battle opens on a
  terrain picked from that spot on the map: field, forest, mountain, river with bridges,
  castle, or town.
- **Marble physics**: every marble is a `RigidBody2D`. Its weapon is part of the same body
  (its own `ConvexPolygonShape2D` parts), so weapons physically block other weapons, scrape
  along walls and shove enemies. Spin comes from torque, so weapon clashes can stall or
  reverse it. Damage happens when a weapon touches an enemy body and grows with impact speed.
  Arrows, magic missiles and fireballs work the same way.
- **Units**: King, Kingsguard, Captain, Fighter, Footman, Spearman, Knight, Berserker,
  Hammerman, Archer, Mage, Farmer, Bandit, Villager.
- **XP and levels**: kills give XP. A level-up raises HP, damage, speed and size, and a
  marble that reaches level 2 gets a name. The event feed reports "X has leveled up!" and
  "Captain Y has been slain by Z".
- **Plinko lottery**: a marble falls through pegs to pick the upgrade. Each kingdom gets a
  periodic royal decision. Taking a town opens a town decision (Conquer, Raze, Occupy or
  Plunder). Beating bandits earns a reward.
- **Upgrades**: Sharpness, Regeneration, Giant, Haste, Vitality, Helmets, Vampirism,
  Spectral Sword, Wisdom, Seek, Muster, Farmers, Archers, Mage, Kingsguard, Berserkers,
  Build Town, Declare King.
- **Winning**: a kingdom is eliminated once it has no marbles left. The last kingdom
  standing wins, and the end screen shows a podium and the Hall of Heroes.

## Controls

| Key | Action |
| --- | --- |
| Space | Pause |
| 1 / 2 / 4 | Speed 1x / 2x / 4x |
| M | Mute |
| Esc | Back to the menu |

## Run

Open the folder in Godot 4.6 and press F5, or run:

```bash
godot --path .
```

To start a 6-kingdom war straight away, without the menu: `godot --path . -- --autostart`

## References

- Game rules and units: [Marble Kingdoms Wiki](https://marble-kingdoms.fandom.com/wiki/Marble_Kingdoms_Wiki):
  Kingdom Units, Power Ups, Factions and Maps pages
- Physics: Godot Physics 2D, using [RigidBody2D](https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html)
  and [PhysicsMaterial](https://docs.godotengine.org/en/stable/classes/class_physicsmaterial.html).
  The marble-and-pegs setup follows the
  [Kodeco Godot 2D physics tutorial](https://www.kodeco.com/44858551-getting-started-with-2d-physics-in-godot)
  (RigidBody2D marble, StaticBody2D pegs).

All graphics are drawn in code and all sounds are synthesised at runtime, so the project
has no external asset files.
