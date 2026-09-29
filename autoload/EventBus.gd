extends Node
## Global signal hub. Systems emit and listen here instead of holding
## direct references to each other.

# --- enemies / waves
signal enemy_spawned(enemy)
signal enemy_killed(enemy, killer)
signal enemy_reached_castle(enemy)
signal elite_killed(enemy)
signal boss_spawned(enemy)
signal boss_phase(enemy, text: String)
signal wave_started(number: int)
signal wave_completed(number: int)

# --- economy / castle
signal gold_changed(amount: int)
signal lives_changed(amount: int)

# --- units
signal unit_placed(unit)
signal unit_sold(unit)
signal unit_selected(unit)
signal unit_deselected
signal unit_stats_changed(unit)
signal unit_downed(unit)
signal unit_upgraded(unit)
signal special_used(unit)
signal player_talked(unit)
signal cavalry_spotted(enemy, unit)
signal placement_mode_changed(unit_type: String)

# --- NPC communication (NPC -> NPC)
signal heavy_enemy_spotted(enemy, unit)
signal ally_needs_support(unit, threat)
signal dragon_spotted(dragon, unit)
signal threat_spotted(enemy, unit, kind: String)   ## sapper / necromancer / shields / bats
signal npc_said(unit, text: String)

# --- presentation
signal feed_message(speaker: String, text: String, color: Color)
signal banner(text: String, sub: String, color: Color)
signal camera_shake(strength: float)

# --- roguelike layer
signal boon_draft_opened(options: Array)
signal boon_picked(boon: Dictionary)
signal omen_changed(omen: Dictionary)
signal relic_draft_opened(options: Array)
signal relic_gained(relic: Dictionary)
signal relic_picked_continue    ## relic chest taken; the normal draft follows

# --- heroes
signal hero_ability_used(hero, index: int)
signal targeting_mode_changed(active: bool, label: String)

# --- flow
signal game_over(victory: bool)
signal state_changed(state: int)
