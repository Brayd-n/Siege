# Siegewatch

A 3D medieval fantasy tower defense for **Godot 4.3+** (GDScript, Forward+ renderer).
Your "towers" are NPC soldiers with names, personalities and voices. You can talk to them,
give them orders, and watch them warn each other, call for help and react to one another.

## Running it

1. Open Godot 4.7 (4.3+ works), click **Import**, pick this folder's `project.godot`.
2. Press **F5**. The game opens on the campaign map (main menu).

For a class demo: **Settings > Unlock all levels & soldiers (demo)** opens everything at once.

## Controls (in battle)

| Input | Action |
|---|---|
| WASD / arrows, wheel, Q/E or right/middle drag | Pan, zoom, rotate camera |
| 1-8 or the bottom bar | Pick a soldier to recruit (locked ones show a padlock) |
| H or the gold HERO card | Place your hero (free, once per battle) |
| Z / X | Hero abilities (aim with the mouse, left-click to cast) |
| Right-click the ground (hero selected) | Move the hero |
| F11 | Toggle fullscreen |
| Settings > Key bindings | Rebind every gameplay key |
| Left click / Shift+click | Place (Shift keeps placing), or select a soldier |
| Right click | Cancel placement / deselect |
| Space | Start next wave |
| T / G / Tab | Talk, special ability, cycle targeting (selected soldier) |
| Esc | Cancel, deselect, or open the pause menu |
| P, F | Pause, toggle 1x/2x |
| F1-F8 | Debug: gold, spawn goblin/orc/troll/dragon, end wave, lives, next wave |

## Campaign and progression

Nine maps, each with its own road, look and enemy mix. Beating a map for the first time unlocks a
new soldier (you start with only Archers and Knights), like Bloons' progression:

| # | Map | Theme | Waves | Unlocks |
|---|---|---|---|---|
| 1 | Greenvale Road | summer | 8 | Crossbowman |
| 2 | Millbrook Crossing | summer | 10 | Torch Thrower |
| 3 | Autumn Marches | autumn | 12 | Spearman |
| 4 | Frostpeak Pass | snow | 12 (Frost Wyrm) | Battle Mage |
| 5 | Ashen Wastes | burnt, red sky | 14 (Ashmaw) | Cleric |
| 6 | Dragon's Reach | dusk | 15 (Vyraxis) | Trebuchet + Endless mode |
| 7 | Twin Fords | spring, 2 roads | 14 (Twin Warlords) | Epic gear on first clear |
| 8 | Riverwatch | misty, river | 14 (Riverbane) | Epic gear on first clear |
| 9 | Blackwood by Night | night | 15 (Night Shade) | Epic gear on first clear |

- **Difficulties** Easy / Normal / Hard (lives, enemy HP, gold, Crown multiplier). Each gives a medal.
- **Waves** are generated from a threat budget per map (seeded, so a map always plays the same), with
  new enemy types introduced gently and a boss wave at the end.
- **Endless mode** (after beating the final map): infinite, escalating waves with a dragon every 10
  waves. Best wave per map is saved.

### Live-service layer

- **Profile save** (`user://siegewatch_profile.json`): Commander rank (XP), Crowns, unlocks, medals, records.
- **Crowns** from waves, wins, first clears, quests, achievements and rank-ups.
- **Armory**: permanent upgrades bought with Crowns (starting gold, lives, damage, health, cheaper
  upgrades, faster revives, longer warning range, free boon rerolls).
- **Daily quests**: three per day (for example "Talk to your soldiers 5 times", "Topple 3 trolls").
- **Daily Challenge**: a map of the day on Hard with an omen on every wave, +100 Crowns once per day.
- **Login streak** rewards (up to day 7).
- **Achievements** (16) with Crown rewards and lifetime stats.
- **Live events** by date: Weekend War Chest (double Crowns) and Dragon Week (first week of each month).
- **Toast notifications** for level-ups, quests and achievements; **settings** for volume, graphics
  quality, fullscreen, camera speed and the battlefield chat; pause menu with restart and quit.

## Heroes

Pick a hero on the level screen. The hero is free, placed **once** per battle, can't be sold, can be
**moved** (right-click), levels up after every wave (max 10) and has two **targeted abilities** (Z / X).
Each hero plays differently:

| Hero | Unique mechanic | Abilities (Z / X) | Unlock |
|---|---|---|---|
| Sir Aldric Lionheart | Stands ON the road and holds up to 3 enemies in place; tougher, stronger when hurt | Heroic Charge, Lion's Roar | start |
| Lyra Windrunner | Hunter's Mark (marked enemies take more damage from everyone), executes wounded enemies, falcon companion | Rain of Arrows, Piercing Gale | start |
| Magister Voss | Channelled lightning beam that ramps up to 3x on one target and arcs; teleports instead of walking | Meteor, Time Warp | beat Millbrook |
| Brunhild Ironpike | Builds road barricades enemies must smash, sweeping pike, thorns | Raise Barricade, Iron Wall | beat Autumn Marches |
| Mother Elowen | Guardian Angel: soldiers in her aura survive a killing blow once per wave | Consecrate, Resurrection | beat Ashen Wastes |

Hero level milestones: Lv3 second ability, Lv5 +15% stats, Lv8 faster abilities, Lv10 Legend.

### Hero gear and mastery

- Finishing a battle drops a **gear piece for the hero you used** (Weapon / Armor / Trinket;
  Common to Legendary). Wins, harder difficulties, Heat and waves survived improve the odds. New maps
  guarantee an Epic on first clear. Legendary pieces carry a hero-specific effect.
- **Heroes & Gear** screen (main menu): equip, compare, salvage for Crowns, see total bonuses.
- **Mastery**: heroes earn XP across battles. Rewards: second aura choice, three skins,
  starting hero levels and a stat bonus.

## Tier-3 specializations

After 3 upgrade tiers every soldier can specialize into one of two forms, e.g. Archer -> Ranger (multishot)
or Longbowman (huge range, anti-air); Knight -> Paladin (holy, lifesteal) or Berserker (cleave);
Crossbowman -> Arbalest (knockback) or Repeater (bursts); Torch Thrower -> Alchemist (acid) or Firebomber;
Spearman -> Halberdier or Pikemaster; Battle Mage -> Stormcaller or Frost Mage; Cleric -> High Priest or
Inquisitor; Trebuchet -> Siege Master or Hellfire Engine. Upgrade buttons show before/after numbers.

## Roguelike layer (Spoils of War)

- After each wave: pick 1 of 3 boons (4 with Royal Favor), reroll for gold, or **Pillage** for gold instead.
- 48 boons: common/rare/legendary stat and mechanic boons, hero boons, and cursed pacts
  (Glass Cannon, Devil's Bargain, Forced March, Pact of Greed...). Mechanic boons include Last Stand,
  Veteran's Resolve, Martyr's Oath, Phalanx, Greek Fire, Storm Conduit, Bounty Hunters and Lucky Horseshoe.
- **Boons only offer soldiers you have unlocked.** Boons for soldiers already on the field are twice as likely.
- **Crossroads events** (about 30% of drafts from wave 3): story choices like the Wandering Merchant,
  the Forgotten Shrine, the Dragon's Map, the Dwarven Forge, the Gambler's Table, Deserters at the Gate,
  and a Bard's Ballad for your hero. Options can cost gold, grant random relics, gamble, or force the next omen.
- **Omens** can change the next wave (Swift Feet, Ironhide, The Horde, Blood Moon).
- **Relics**: bigger rule-changers. Elites (one halfway through every map) drop a relic chest;
  the Wandering Merchant sells them. Examples: Crown of Command, Phoenix Feather, Mirror of Echoes.
- **Heat trials** (level screen): 10 optional challenges (Iron Hides, Swift Horde, No Heroes...).
  More Heat = more Crowns, better gear, more hero XP; best Heat per map is recorded.
- **Daily Challenge**: same map, trials and boon offers for everyone that day.
- **Hall of Records**: medals, best Heat, Endless bests, daily history and recent battles.

## Soldiers

| Soldier | Cost | Role | Special |
|---|---|---|---|
| Archer | 150 | fast shots; faster next to a Knight | Volley |
| Knight | 200 | melee guard; answers calls for help | Shield Wall |
| Crossbowman | 250 | long range, armour piercing, pierces lines | Piercing Shot |
| Torch Thrower | 300 | exploding torches, burning | Fire Patch |
| Spearman | 220 | reach 4.6, hits two in a line, slows, x1.8 vs wolf riders | Brace (stops everything in reach) |
| Battle Mage | 350 | arcane bolts ignore armour and chain to 2+ enemies | Frost Nova |
| Cleric | 280 | heals allies, +12% damage blessing, faster revives | Divine Light (mass revive) |
| Trebuchet | 450 | 22 m range, big splash, can't hit flyers or close targets | Barrage (5 boulders) |

### Enemies and bosses

New enemies, each countered by a particular soldier: **Shieldbearer** (blocks frontal arrows; crossbows and
magic go through), **Goblin Sapper** (charges and explodes; kill it in a crowd), **Cave Bats** (flying swarm),
**Necromancer** (raises skeletons; Clerics deal double damage to the dead), plus **Goblin Shaman** (heals).
Soldiers call each new threat out and the right soldiers switch to it.

Every map ends with its own boss: Grukk the Warlord (buffs goblins, calls reinforcements), Old Mossback
(throws boulders that stun), the Hollow King (raises the dead, immune phases), the Frost Wyrm (freezes
soldiers), Ashmaw the Red, Vyraxis the Elder (bats, enrages), Twin Warlords, Riverbane (regenerates unless
burning) and the Night Shade (blinks, only visible in light). A boss health bar shows at the top.

### New maps

Twin Fords (two roads merge), Riverwatch (build only on river platforms, bridges), Blackwood by Night
(enemies are only targetable in light: torches, Torch Throwers, fire, lanterns).

### Quality of life

Save & Quit mid-run and **Continue** from the main menu, 3x speed and Auto-start waves, Codex, colour-blind
range circles, UI scale, key rebinding, credits, app icon and splash screen.

## NPC requirements

1. **3D**: fully 3D battlefield, orbiting strategy camera.
2. **Talk to NPCs**: select a soldier, press TALK. Lines depend on personality, class, wave, kills,
   health, nearby enemies/allies, orders and recent events.
3. **Direct NPCs**: targeting modes, Hold Fire, Assist Nearby, specials, upgrades, sell.
4. **NPC to NPC** (real behaviour changes, see `DialogueManager.gd`):
   - troll/orc warning: Crossbowmen, Torch Throwers, Mages and Trebuchets focus it
   - call for help: nearest Knight leaves its post and walks over to fight beside the ally
   - cavalry warning: Spearmen brace and focus the wolf riders
   - soldier knocked down: nearest Cleric answers and gets them up in 3 seconds
   - dragon alarm: every ranged soldier turns on the dragon
   - plus kill praise, man-down callouts, wave-end chatter and banter.
   All of it appears in the compact Battlefield chat (bottom-left) and each behaviour change is logged as an "Orders" line.

## Visuals

No external art was available, so all art is procedural but built to look like a real game rather
than flat-coloured blocks:

- Tileable PBR texture sets (albedo, normal, roughness) generated for grass, dirt road, cobblestone,
  castle bricks, roof tiles, planks, bark, rock, plaster, fabric, leather, metal, dragon scales,
  plus alpha-cut leaf and pine-needle cards (`assets/textures`).
- A terrain shader that blends grass, dirt road, cobble plaza and rock slopes using a signed distance
  field of the road, with anti-tiling and macro colour variation.
- ~20k wind-animated grass tufts, card-based trees with soft spherical normals, noise-displaced rocks.
- ACES tonemapping, SSAO, glow, distance fog, 4-split soft shadows, flickering torch lights,
  GPU particle fire/smoke/explosions, animated cloth banners and a swirling spawn portal.
- Fonts: Cinzel and Alegreya (SIL Open Font License, see `assets/fonts`).

Real models can replace the procedural ones later: `ModelBuilder.gd` returns a "rig" dictionary
(arms, legs, head, weapon pivots), so a new model only needs to provide the same pivots.

## Project layout

```
autoload/        EventBus, Profile (save/meta), GameManager, EconomyManager, BoonManager, Mats, FX, Sfx, Toasts
scenes/          menu/ (MainMenu), main/ (battle, CameraRig), map/, units/, enemies/, projectiles/, ui/
scripts/
  main/          Main.gd (input, lighting), CameraRig.gd
  map/           Map.gd (road Path3D, distance field, terrain, castle, village, foliage)
  units/         FriendlyUnit.gd base + Archer, Knight, Crossbowman, TorchThrower, ModelBuilder
  enemies/       Enemy.gd base + Goblin, GoblinArcher, Orc, Troll, WolfRider, Dragon
  heroes/        HeroKit + one Kit per hero, HeroGear (gear, mastery), AbilityZone, Barricade
  managers/      WaveManager, EnemyManager, UnitManager, PlacementManager, DialogueManager
  combat/        Damage, Projectile, FirePatch
  npc/           DialogueDB.gd (all NPC lines)
  ui/            HUD.gd, UiTheme.gd, HudIcon.gd
resources/       levels/LevelDefs.gd (maps, themes, difficulties), unit_data/ (UnitDefs, HeroDefs), heat/HeatDefs.gd, enemy_data/, waves/WaveDefs.gd (generator)
assets/          textures/, shaders/, fonts/, audio/
tests/           AutoTest (bot plays a level: -- level=N hero=ID), BehaviorTest, FeatureTest, HeroTest, KitTest,
                 EnemyTest, MapsTest, MenuTest, FlowTest, Showcase, Screenshot/MenuShot
```

Balance lives in the three `resources/*Defs.gd` files and `BoonManager.gd`.

Headless playtest: `godot --headless --fixed-fps 30 --path . res://tests/AutoTest.tscn`
