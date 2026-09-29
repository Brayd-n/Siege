class_name DialogueDB
extends RefCounted
## All NPC lines. Lines are chosen by context (wave, threats, health, allies,
## commands, recent events) and flavoured by personality and class.
## "%s" in a line is replaced with a relevant name (ally or enemy).

# ------------------------------------------------------------- player TALK
const OPENING := [
	"The road is quiet... too quiet.",
	"Smell that? Smoke from the east. They're coming.",
	"I've checked my gear twice. Ready when you are.",
	"Whatever comes through that gate, we meet it here.",
]

const IDLE := {
	"Brave": ["Let them come. We hold this ground.", "I'd rather die on my feet than watch the castle burn.", "Give the word and I'll stand here till sunrise."],
	"Nervous": ["Is it... is it always this cold before a battle?", "I keep hearing drums. Tell me you hear them too.", "I-I'm fine. Just point me at something."],
	"Veteran": ["Stay focused. They'll send stronger ones.", "Seen a dozen sieges. The quiet part is the worst.", "Check your footing. Mud kills more men than goblins."],
	"Cocky": ["Is that all they've got?", "Honestly, you could've hired half as many of us.", "Put a crown on my head and I'd still be the best shot here."],
	"Serious": ["Awaiting orders.", "Position secured. Lines of fire are clear.", "Every arrow counts. I don't waste them."],
	"Friendly": ["Good to see you, my lord! Bread's still warm back at camp.", "We'll be telling stories about this one by the fire.", "Chin up. We've got each other."],
}

const CLASS_IDLE := {
	"archer": ["Give me a clear shot and I'll make them regret coming here.", "Wind's out of the west. I'll aim a hair left.", "Forty arrows in the quiver. Forty goblins, then."],
	"knight": ["If anything reaches this position, I'll handle it.", "My blade is sharp and my shield is sound.", "Stand behind me and you'll live to see morning."],
	"crossbowman": ["Armor won't help them against this.", "Slow to load, sure. But nothing gets up after a bolt.", "Point me at the biggest one."],
	"torch_thrower": ["Let's see how well goblins burn.", "Pitch, rags and a steady arm. That's all I need.", "Fire doesn't care how thick their hide is."],
	"spearman": ["Horses hate pikes. Wolves hate them more.", "Ten feet of ash and steel between me and them. I like those odds.", "Let the riders come. I'll be waiting."],
	"battle_mage": ["Armour is just metal. Metal conducts.", "I studied thirty years for this. Try not to get in the way.", "The air tastes of storm. Good."],
	"cleric": ["Stay close and I'll keep you standing.", "The Light watches this road, and so do I.", "Wounds close. Courage holds. Go on."],
	"trebuchet": ["Counterweight's set. Just give me something big to aim at.", "She's slow, but she hits like the wrath of heaven.", "Nobody stand in front of the arm. I mean it."],
}

const CROWD := {
	"Brave": ["More of them? Good, more to cut down!", "They can bring the whole horde!"],
	"Nervous": ["That's... a lot of goblins.", "Oh no. Oh no no no. There are so many."],
	"Veteran": ["Thin them out at the edges. Don't let them bunch.", "Pace yourselves. It's a long fight."],
	"Cocky": ["Finally, a real crowd!", "Line them up, I'll take three with one arrow."],
	"Serious": ["Heavy contact. Keep firing.", "Multiple targets. Prioritising."],
	"Friendly": ["Stay close, friends. We'll get through this!", "Deep breaths, everyone. One at a time."],
}

const COMBAT := {
	"archer": ["Loose! Loose!", "Got one!", "Keep them coming, I've got arrows."],
	"knight": ["For the King!", "Come closer, beast.", "Steel meets flesh!"],
	"crossbowman": ["Reloading... there.", "Another bolt, another body.", "Steady... fire."],
	"torch_thrower": ["Burn!", "Catch!", "Nice and toasty now."],
	"spearman": ["Hold the line!", "Skewered!", "Pikes forward!"],
	"battle_mage": ["Arcanum!", "Feel that?", "Chain it through them!"],
	"cleric": ["Light, guide my hand.", "Stand fast, I'm here!", "Mend and fight on!"],
	"trebuchet": ["Loose!", "Stone away!", "Reload, reload!"],
}

const HURT := {
	"Brave": ["Just a scratch. I'm still standing!", "It'll take more than that!"],
	"Nervous": ["I'm bleeding! Is that bad? That looks bad!", "I want to go home..."],
	"Veteran": ["Took a hit. Still in the fight.", "I've had worse. Not much worse."],
	"Cocky": ["Hey! That was my good side!", "Lucky shot. Won't happen twice."],
	"Serious": ["Wounded. Holding position.", "Injury sustained. Continuing."],
	"Friendly": ["Ow! Someone tell my mother I was brave.", "I could use a hand here, friends."],
}

const TROLL_TALK := ["That troll is going to be a problem.", "Look at the size of it. Aim for the knees.", "Crossbows and fire. Nothing else scratches a troll."]
const DRAGON_TALK := ["Dragon! Keep shooting, don't let it reach the walls!", "I've heard songs about dragons. None of them end well.", "Aim for the wings! Bring it down!"]
const LATE_WAVE := {
	"Brave": ["We've come this far. We finish it.", "Whatever is left out there, we can take it."],
	"Nervous": ["How many more waves? Please say not many.", "My hands won't stop shaking."],
	"Veteran": ["They're throwing everything at us now. Good. It means they're desperate.", "This is where sieges are won or lost."],
	"Cocky": ["Still here. Still the best.", "Tell the bards to start writing."],
	"Serious": ["Final waves approaching. Stay sharp.", "Supplies are thin. Make every shot count."],
	"Friendly": ["Whatever happens, it's been an honour.", "When this is over, the first round's on me."],
}
const BOAST := ["That's %d kills. Someone keep count, I've lost track.", "%d down. Who's next?", "%d kills and not a scratch on my pride."]
const ALLY_MENTION := ["Glad %s is covering my flank.", "With %s beside me, I almost feel safe.", "%s and I have this stretch of road handled."]
const HOLD_FIRE := ["Holding fire, as ordered. My fingers are itching though.", "Weapon lowered. Say the word and I'll let loose.", "Holding. They're walking right past me..."]
const ASSISTING := ["I'm backing up %s, as ordered.", "Keeping an eye on %s's targets.", "Wherever %s shoots, I shoot."]
const TARGETING := {
	0: ["Hitting the ones closest to the gate first.", "Front of the column. Got it."],
	1: ["Picking off the stragglers at the back.", "Last in line gets it first."],
	2: ["Going for the biggest brutes.", "Strongest first. Makes sense."],
	3: ["Finishing off the wounded ones.", "Weak ones first. Quick kills."],
	4: ["Whatever's nearest gets the point.", "Closest target, understood."],
}
const DOWNED := ["...still breathing. Barely.", "Give me a moment... I'll be back up.", "Everything's spinning..."]
const SAVED_BY := ["%s pulled me out of that one. I owe them a drink.", "Did you see %s charge in? Saved my hide!"]
const SUPPORTED := ["Went to help %s. Wouldn't leave a friend alone out there.", "%s needed me. That's what the shield's for."]
const SPECIAL_READY := {
	"archer": "My volley is ready. Just give the word.",
	"knight": "Shield wall is ready when you need it.",
	"crossbowman": "I've got a piercing shot loaded.",
	"torch_thrower": "Got a barrel of pitch for the road. Say when.",
	"spearman": "Say the word and we brace. Nothing gets past a braced pike.",
	"battle_mage": "Frost Nova is ready. Point me at the thickest crowd.",
	"cleric": "The Light is gathered. I can raise the fallen.",
	"trebuchet": "We've stacked five stones for a barrage.",
}

# ------------------------------------------------------------- NPC <-> NPC
const HEAVY_SPOT := {
	"troll": ["Troll coming down the road!", "TROLL! Big one!", "Troll sighted! Heavy weapons, now!"],
	"orc": ["Armored orcs! Arrows won't cut it!", "Orcs in plate! Need bolts!", "Orc brutes on the road!"],
}
const HEAVY_REPLY := {
	"crossbowman": ["I'll deal with it.", "I've got it.", "Bolt's loaded. It's mine."],
	"battle_mage": ["Armour means nothing to me. It's mine.", "I'll burn through that plate.", "Leave it to the arcane."],
	"trebuchet": ["Big target? Oh, that's mine.", "Swinging the arm around!", "Adjusting aim... got it."],
	"torch_thrower": ["Let's see it burn.", "Leave that one to the fire.", "I'll light it up!"],
}
const SUPPORT_CALL := {
	"Brave": ["Knight! They're on me, lend a sword!", "Close quarters here! Knight!"],
	"Nervous": ["Knight! I need help! Please!", "They're too close! Someone! Anyone!"],
	"Veteran": ["Knight, enemies at my position. Now.", "Contact at close range, need a blade."],
	"Cocky": ["Knight! A little help! Not that I need it!", "Could use a tin can over here!"],
	"Serious": ["Requesting melee support.", "Enemies in close. Knight, respond."],
	"Friendly": ["Knight, friend! They're right on top of me!", "Help! Knight! Over here!"],
}
const SUPPORT_REPLY := ["Hold your ground!", "I'm coming!", "On my way! Stay behind me!", "I've got you!"]
const DRAGON_SHOUT := ["DRAGON!", "DRAGON! TO ARMS!", "Gods above... DRAGON!"]
const BOSS_SHOUT := ["Something big is coming!", "That's their leader! Bring it down!", "Here comes the big one! Everyone on it!"]
const THREAT_SHOUT := {
	"sapper": ["SAPPER! It's got a bomb!", "Keg runner! Shoot it before it reaches us!", "Powder keg on the road!"],
	"necromancer": ["Necromancer! It's raising the dead!", "Dark magic! Kill the one in the robes!", "The dead are getting up! Find the caster!"],
	"shields": ["Shield wall! Arrows won't get through!", "They've got tower shields!", "Shields up front! We need bolts!"],
	"bats": ["Bats! Up in the air!", "Swarm overhead!", "Flyers! Blades can't reach them!"],
}
const THREAT_REPLY := {
	"sapper": ["Got it in my sights!", "It won't make it!", "Blowing it up early!"],
	"necromancer": ["Unholy magic! The Light will burn it!", "I'll put that one down.", "On the caster!"],
	"shields": ["Bolts go straight through shields. Leave it to me.", "Shields don't stop magic!", "I'll crack that shell."],
	"bats": ["I'll swat them out of the sky!", "Aiming high!", "Nothing flies past me."],
}
const THREAT_RESPONDERS := {
	"sapper": ["archer", "crossbowman", "battle_mage", "trebuchet"],
	"necromancer": ["cleric", "crossbowman", "battle_mage", "archer"],
	"shields": ["crossbowman", "battle_mage", "torch_thrower"],
	"bats": ["archer", "battle_mage", "crossbowman"],
}
const DRAGON_REPLY := {
	"archer": ["Aim high!", "Everyone spread out!", "Aim for the beast!"],
	"knight": ["Protect the castle!", "Hold the line! Don't break!", "Shields up!"],
	"crossbowman": ["I'll find a weak spot!", "Bolts for the wings!", "Aim for the beast!"],
	"torch_thrower": ["Fire won't hurt it, but I'll try anyway!", "Let's see if dragons like pitch!", "Everyone spread out!"],
	"spearman": ["Pikes won't reach it! Guard the others!", "Shields up, it's coming low!"],
	"battle_mage": ["Lightning finds wings just fine!", "Now THAT is a worthy target!"],
	"cleric": ["Stay near me, I'll keep you breathing!", "Light protect us!"],
	"trebuchet": ["Can't lob at a flyer! Keep the ground clear for them!"],
}
const KILL_PRAISE := {
	"Brave": ["Nice one!", "Glorious strike!"],
	"Nervous": ["You... you actually killed it!", "Thank the gods!"],
	"Veteran": ["Clean kill.", "Good work. Reset."],
	"Cocky": ["Not bad. Almost as good as me.", "Lucky hit!"],
	"Serious": ["Target down.", "Confirmed kill."],
	"Friendly": ["Nice one!", "Huzzah! Well done!"],
}
const KILL_ANSWER := ["Keep shooting!", "Eyes up, more coming!", "Thanks! Now back to it!", "That's how it's done!"]
const WAVE_END_A := ["We survived that one.", "That's the last of them. For now.", "Road's clear!", "Is everyone still breathing?"]
const WAVE_END_B := ["More will come.", "Don't celebrate yet.", "Catch your breath while you can.", "Aye. Barely."]
const CAVALRY_SHOUT := ["Riders! Wolf riders on the road!", "Cavalry incoming! Pikes!", "Wolves! Fast ones!"]
const CAVALRY_REPLY := ["Pikes up! Let them run onto them!", "Brace for the riders!", "I see them. They won't get past me."]
const CLERIC_RESCUE := ["Hold on, %s! I'm coming!", "Stay with me, %s!", "The Light isn't done with you yet, %s!"]
const DOWN_CALLOUT := ["Man down!", "%s is hit!", "They got %s!"]
const BANTER := [
	["Quite a crowd coming.", "Then don't miss."],
	["Anything gets past you, I'll handle it.", "Let's hope it doesn't come to that."],
	["You smell that? Goblin.", "That's not goblin, that's you."],
	["How many have you got?", "Enough to buy the first round."],
	["If I fall, tell them I was handsome.", "I'd have to lie."],
	["My arm's getting tired.", "Tired arms still shoot straight. Keep at it."],
	["Remind me why we volunteered?", "The pay. And the glory. Mostly the pay."],
	["Watch the road, not the sky.", "The sky's where dragons come from!"],
]
const BOON_REACT := ["The King's favour is with us!", "Supplies from the castle! Now we're talking.", "That'll help. Every bit helps.", "Now THIS is how you fight a war."]
const PLACED := {
	"archer": ["Archer reporting. Where do you want them dead?", "Bowstring's waxed. I'm ready."],
	"knight": ["Sir, reporting for duty. None shall pass.", "My sword is yours."],
	"crossbowman": ["Crossbow's cranked. Point me at something big.", "Reporting. Bring me armour to crack."],
	"torch_thrower": ["Brought my own matches. Where's the fire?", "Reporting. Stand back, I get enthusiastic."],
	"spearman": ["Pikeman reporting. Point me at the road.", "Spear's sharp, feet are planted."],
	"battle_mage": ["You summoned me? Excellent.", "Arcane support has arrived. You're welcome."],
	"cleric": ["The Light sends me. Who's hurt?", "I'll keep them standing, my lord."],
	"trebuchet": ["Crew and engine ready. Give us room.", "Assembled! Now where's something big?"],
}
const UPGRADED := ["Much better. Feel the difference?", "New gear! I won't let you down.", "Now we're talking.", "They'll feel that."]
const ORDER_ACK := ["Understood.", "As you command.", "Aye!", "Right away.", "On it."]


static func pick(arr: Array, avoid: String = "") -> String:
	if arr.is_empty():
		return ""
	if arr.size() == 1:
		return arr[0]
	for i in 6:
		var s: String = arr[randi() % arr.size()]
		if s != avoid:
			return s
	return arr[0]


static func by_personality(table: Dictionary, personality: String) -> Array:
	return table.get(personality, table.get("Brave", []))


## Context-aware line when the player presses TALK.
static func talk_line(u: FriendlyUnit) -> String:
	var em = GameManager.enemy_manager
	var pools: Array = []
	if u.downed:
		return pick(DOWNED, u.last_line)
	if u.recent_event != "" and u.recent_event_timer > 0.0:
		var who := u.recent_event_name
		if u.recent_event == "saved_by":
			return pick(SAVED_BY, u.last_line) % who
		if u.recent_event == "supported":
			return pick(SUPPORTED, u.last_line) % who
	if u.hp < u.get_max_hp() * 0.45:
		pools.append(by_personality(HURT, u.personality))
	if em and em.has_type_alive("dragon"):
		return pick(DRAGON_TALK, u.last_line)
	if u.command == "Hold Fire":
		return pick(HOLD_FIRE, u.last_line)
	if u.command == "Assist" and is_instance_valid(u.assist_unit):
		return pick(ASSISTING, u.last_line) % u.assist_unit.display_name
	var near: Array = em.enemies_near(u.global_position, u.get_range() + 3.0, true) if em else []
	var has_troll := false
	for e in near:
		if (e as Enemy).enemy_type == "troll":
			has_troll = true
	if has_troll:
		pools.append(TROLL_TALK)
	if near.size() >= 5:
		pools.append(by_personality(CROWD, u.personality))
	elif near.size() > 0:
		pools.append(COMBAT.get(u.unit_type, []))
	if pools.is_empty():
		if GameManager.wave == 0:
			if randf() < 0.7:
				return pick(OPENING, u.last_line)
			pools.append(OPENING)
		if u.kills >= 20:
			var line := pick(BOAST, u.last_line)
			return line % u.kills
		if GameManager.wave >= 7:
			pools.append(by_personality(LATE_WAVE, u.personality))
		var um = GameManager.unit_manager
		if um:
			var ally: FriendlyUnit = um.nearest_unit(u.global_position, 9.0, "", false, u)
			if ally and randf() < 0.35:
				return pick(ALLY_MENTION, u.last_line) % ally.display_name
		if u.special_ready() and randf() < 0.3:
			return SPECIAL_READY.get(u.unit_type, "Ready.")
		if randf() < 0.25:
			pools.append(TARGETING.get(u.targeting, []))
		pools.append(by_personality(IDLE, u.personality))
		pools.append(CLASS_IDLE.get(u.unit_type, []))
	var pool: Array = pools[randi() % pools.size()]
	return pick(pool, u.last_line)
