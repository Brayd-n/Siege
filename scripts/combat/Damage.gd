class_name Damage
extends RefCounted
## Damage types used by units, projectiles and enemy resistances.

enum Type { NORMAL, PIERCING, FIRE, ARCANE }

const NAMES: Array[String] = ["Normal", "Piercing", "Fire", "Arcane"]
