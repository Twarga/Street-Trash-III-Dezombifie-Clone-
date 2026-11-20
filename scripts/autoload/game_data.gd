extends Node

const CATEGORY_COLORS := {
	"COMBAT": Color(0.92, 0.24, 0.22),
	"SURVIVAL": Color(0.18, 0.85, 0.38),
	"MOBILITY": Color(0.98, 0.82, 0.16),
	"ECONOMY": Color(0.20, 0.65, 1.0),
	"LOADOUT": Color(0.56, 0.66, 0.34),
	"CHAOS": Color(1.0, 0.42, 0.08),
	"DUALITY": Color(0.74, 0.28, 0.96),
}

const CATEGORY_ART := {
	"COMBAT": "res://assets/ui/perk_combat.png",
	"SURVIVAL": "res://assets/ui/perk_survival.png",
	"MOBILITY": "res://assets/ui/perk_mobility.png",
	"ECONOMY": "res://assets/ui/perk_economy.png",
	"LOADOUT": "res://assets/ui/perk_loadout.png",
	"CHAOS": "res://assets/ui/perk_chaos.png",
	"DUALITY": "res://assets/ui/perk_duality.png",
}

const RARITY_COLORS := {
	"COMMON": Color(0.75, 0.78, 0.82),
	"RARE": Color(0.22, 0.72, 1.0),
	"EPIC": Color(0.84, 0.35, 1.0),
	"CHAOS": Color(1.0, 0.48, 0.10),
	"DUALITY": Color(0.95, 0.25, 0.65),
}

const WEAPONS := {
	"pistol": {
		"id": "pistol", "name": "9MM STREET PISTOL", "desc": "Reliable sidearm. Crisp accuracy & fast handling.",
		"damage": 28.0, "fire_rate": 4.2, "pellets": 1, "spread_deg": 2.2, "speed": 54.0,
		"range": 28.0, "shake": 0.07, "pierce": 0, "is_flame": false,
		"color": Color(1.0, 0.92, 0.62), "sfx": "pistol",
		"model": "res://assets/models/weapon_pistol.glb", "icon": "res://assets/ui/icon_pistol.png"
	},
	"smg": {
		"id": "smg", "name": "POCKET CAPPER SMG", "desc": "High-RPM micro submachine gun for shredding runners.",
		"damage": 19.0, "fire_rate": 11.5, "pellets": 1, "spread_deg": 6.5, "speed": 56.0,
		"range": 24.0, "shake": 0.06, "pierce": 0, "is_flame": false,
		"color": Color(1.0, 0.85, 0.42), "sfx": "smg",
		"model": "res://assets/models/weapon_smg.glb", "icon": "res://assets/ui/icon_smg.png"
	},
	"shotgun": {
		"id": "shotgun", "name": "BOOMSTICK SHOTGUN", "desc": "6-pellet buckshot blast with devastating close-range knockback.",
		"damage": 18.0, "fire_rate": 1.45, "pellets": 6, "spread_deg": 15.0, "speed": 48.0,
		"range": 17.0, "shake": 0.22, "pierce": 1, "is_flame": false,
		"color": Color(1.0, 0.62, 0.22), "sfx": "shotgun",
		"model": "res://assets/models/weapon_shotgun.glb", "icon": "res://assets/ui/icon_shotgun.png"
	},
	"rifle": {
		"id": "rifle", "name": "STREET SWEEPER RIFLE", "desc": "Heavy tactical carbine with high velocity & piercing slugs.",
		"damage": 34.0, "fire_rate": 6.8, "pellets": 1, "spread_deg": 2.8, "speed": 68.0,
		"range": 34.0, "shake": 0.10, "pierce": 1, "is_flame": false,
		"color": Color(0.55, 0.94, 1.0), "sfx": "rifle",
		"model": "res://assets/models/weapon_rifle.glb", "icon": "res://assets/ui/icon_rifle.png"
	},
	"hmg": {
		"id": "hmg", "name": "HEAVY MACHINE GUN", "desc": "CHAOS OVERRIDE: Twin-barrel wall of armor-piercing lead!",
		"damage": 36.0, "fire_rate": 13.5, "pellets": 1, "spread_deg": 5.2, "speed": 66.0,
		"range": 34.0, "shake": 0.14, "pierce": 2, "is_flame": false,
		"color": Color(1.0, 0.42, 0.14), "sfx": "hmg",
		"model": "res://assets/models/weapon_hmg.glb", "icon": "res://assets/ui/icon_hmg.png"
	},
	"autoshotgun": {
		"id": "autoshotgun", "name": "AUTO SHOTGUN", "desc": "CHAOS OVERRIDE: Drum-fed full-auto buckshot hurricane!",
		"damage": 20.0, "fire_rate": 4.2, "pellets": 7, "spread_deg": 16.0, "speed": 50.0,
		"range": 19.0, "shake": 0.24, "pierce": 1, "is_flame": false,
		"color": Color(1.0, 0.55, 0.12), "sfx": "shotgun",
		"model": "res://assets/models/weapon_autoshotgun.glb", "icon": "res://assets/ui/icon_autoshotgun.png"
	},
	"flamethrower": {
		"id": "flamethrower", "name": "INCINERATOR", "desc": "CHAOS OVERRIDE: Piercing torrent of liquid napalm that ignites hordes!",
		"damage": 15.0, "fire_rate": 18.0, "pellets": 2, "spread_deg": 12.0, "speed": 24.0,
		"range": 14.0, "shake": 0.05, "pierce": 4, "is_flame": true,
		"color": Color(1.0, 0.38, 0.04), "sfx": "flamethrower",
		"model": "res://assets/models/weapon_flamethrower.glb", "icon": "res://assets/ui/icon_flamethrower.png"
	},
}

const ENEMIES := {
	"shambler": {
		"id": "shambler", "name": "SHAMBLER", "hp": 55.0, "speed": 2.9, "damage": 12.0,
		"xp": 18.0, "score": 100, "radius": 0.55, "armor": 1.0, "knockback_resist": 0.0,
		"model": "res://assets/models/zombie_shambler.glb",
		"desc": "Relentless quarantined infected. Dangerous in dense packs."
	},
	"sprinter": {
		"id": "sprinter", "name": "SPRINTER", "hp": 36.0, "speed": 5.6, "damage": 14.0,
		"xp": 24.0, "score": 150, "radius": 0.48, "armor": 1.0, "knockback_resist": 0.0,
		"model": "res://assets/models/zombie_sprinter.glb",
		"desc": "Glowing red eyes. Sprints from dark alleys to flank survivors."
	},
	"bruiser": {
		"id": "bruiser", "name": "RIOT BRUISER", "hp": 220.0, "speed": 2.35, "damage": 24.0,
		"xp": 55.0, "score": 350, "radius": 0.72, "armor": 0.65, "knockback_resist": 0.72,
		"model": "res://assets/models/zombie_bruiser.glb",
		"desc": "Armored riot officer infected. Deflects light fire with metallic pings."
	},
	"bloater": {
		"id": "bloater", "name": "ACID BLOATER", "hp": 125.0, "speed": 2.2, "damage": 20.0,
		"xp": 45.0, "score": 300, "radius": 0.75, "armor": 1.0, "knockback_resist": 0.4,
		"model": "res://assets/models/zombie_bloater.glb",
		"desc": "Volatile toxic sacs burst into an acid pool on death-damages nearby zombies too!"
	},
	"spitter": {
		"id": "spitter", "name": "TOXIC SPITTER", "hp": 68.0, "speed": 3.4, "damage": 14.0,
		"xp": 38.0, "score": 240, "radius": 0.52, "armor": 1.0, "knockback_resist": 0.15,
		"ranged": true,
		"model": "res://assets/models/zombie_bloater.glb",
		"desc": "Mutated ranged bio-shooter that fires dodgeable acid-plasma bolts from medium range."
	},
	"charger": {
		"id": "charger", "name": "BULL CHARGER", "hp": 155.0, "speed": 3.1, "damage": 24.0,
		"xp": 65.0, "score": 420, "radius": 0.70, "armor": 0.78, "knockback_resist": 0.80,
		"model": "res://assets/models/zombie_bruiser.glb",
		"desc": "Horned crimson mutant that telegraphs and bull-rushes straight through lines."
	},
	"boss": {
		"id": "boss", "name": "HIGH-RISE BRUTE", "hp": 1150.0, "speed": 3.05, "damage": 34.0,
		"xp": 260.0, "score": 2000, "radius": 1.05, "armor": 0.78, "knockback_resist": 0.92,
		"model": "res://assets/models/zombie_boss.glb",
		"desc": "Apex quarantine abomination guarding late Gears and the High-Rise Extraction pad."
	},
}

const STARTING_TRAITS := {
	"street_rat": {
		"id": "street_rat", "name": "STREET RAT", "desc": "Balanced survivor. +10% Stamina Regen & 3 Perk Redraws."
	},
	"gunslinger": {
		"id": "gunslinger", "name": "GUNSLINGER", "desc": "Start with +15% Fire Rate & +8% Crit Chance."
	},
	"juggernaut": {
		"id": "juggernaut", "name": "JUGGERNAUT", "desc": "Start with +35 Max HP & 10% Armor."
	},
	"scavenger": {
		"id": "scavenger", "name": "SCAVENGER", "desc": "Start with +2 Perk Redraws & +15% XP from kills."
	},
}

const PERKS: Array[Dictionary] = [
	# ---- COMBAT (8 cards) ----
	{"id": "trigger_happy", "name": "TRIGGER HAPPY", "cat": "COMBAT", "rarity": "COMMON", "stat": "fire_rate", "step": 12.5, "max": 6, "desc": "Rate of Fire"},
	{"id": "brute_force", "name": "BRUTE FORCE", "cat": "COMBAT", "rarity": "COMMON", "stat": "damage", "step": 12.5, "max": 6, "desc": "Weapon Damage"},
	{"id": "dead_eye", "name": "DEAD EYE", "cat": "COMBAT", "rarity": "COMMON", "stat": "crit_chance", "step": 7.5, "max": 6, "desc": "Critical Chance"},
	{"id": "snipers_calm", "name": "SNIPER'S CALM", "cat": "COMBAT", "rarity": "RARE", "stat": "stationary_crit", "step": 30.0, "max": 2, "desc": "While Stationary: Crit Chance"},
	{"id": "fatal_precision", "name": "FATAL PRECISION", "cat": "COMBAT", "rarity": "RARE", "stat": "crit_damage", "step": 25.0, "max": 4, "desc": "Critical Damage"},
	{"id": "ricochet_rounds", "name": "RICOCHET ROUNDS", "cat": "COMBAT", "rarity": "EPIC", "stat": "ricochet", "step": 1.0, "max": 2, "is_int": true, "desc": "Bullets bounce off walls & cars (+1 bounce) with sparks."},
	{"id": "incendiary_crits", "name": "INCENDIARY CRITS", "cat": "COMBAT", "rarity": "EPIC", "stat": "incendiary", "step": 1.0, "max": 1, "special": true, "desc": "Critical hits ignite zombies & rapidly detonate burning cars."},
	{"id": "piercing_slugs", "name": "PIERCING SLUGS", "cat": "COMBAT", "rarity": "RARE", "stat": "pierce", "step": 1.0, "max": 3, "is_int": true, "desc": "Bullets over-penetrate +1 extra zombie in tight alleys."},

	# ---- SURVIVAL (5 cards) ----
	{"id": "built_different", "name": "BUILT DIFFERENT", "cat": "SURVIVAL", "rarity": "COMMON", "stat": "max_hp_pct", "step": 25.0, "max": 4, "desc": "Maximum Health"},
	{"id": "health_gains", "name": "HEALTH GAINS", "cat": "SURVIVAL", "rarity": "COMMON", "stat": "max_hp_flat", "step": 20.0, "max": 5, "is_int": true, "desc": "Permanently gain +20 Max Health & heal +20 HP."},
	{"id": "regeneration", "name": "REGENERATION", "cat": "SURVIVAL", "rarity": "RARE", "stat": "hp_regen", "step": 1.5, "max": 4, "desc": "Health Regen / sec"},
	{"id": "brace_for_impact", "name": "BRACE FOR IMPACT", "cat": "SURVIVAL", "rarity": "EPIC", "stat": "brace", "step": 1.0, "max": 1, "special": true, "desc": "Incoming damage drains Stamina first before Health."},
	{"id": "thick_skin", "name": "THICK SKIN", "cat": "SURVIVAL", "rarity": "RARE", "stat": "armor", "step": 8.0, "max": 4, "desc": "Damage Reduction"},

	# ---- MOBILITY (5 cards) ----
	{"id": "leg_day", "name": "LEG DAY", "cat": "MOBILITY", "rarity": "COMMON", "stat": "move_speed", "step": 10.0, "max": 4, "desc": "Movement Speed"},
	{"id": "cardio_training", "name": "CARDIO TRAINING", "cat": "MOBILITY", "rarity": "COMMON", "stat": "max_stamina", "step": 20.0, "max": 4, "desc": "Maximum Stamina"},
	{"id": "hit_and_run", "name": "HIT AND RUN", "cat": "MOBILITY", "rarity": "RARE", "stat": "stamina_on_hit", "step": 2.0, "max": 3, "desc": "Gain Stamina on hitting an enemy"},
	{"id": "shockwave_dash", "name": "SHOCKWAVE DASH", "cat": "MOBILITY", "rarity": "EPIC", "stat": "shock_dash", "step": 1.0, "max": 1, "special": true, "desc": "Dashing triggers an EMP blast knocking back & damaging nearby hordes."},
	{"id": "adrenaline_rush", "name": "ADRENALINE RUSH", "cat": "MOBILITY", "rarity": "RARE", "stat": "adrenaline", "step": 1.0, "max": 1, "special": true, "desc": "+15% Move Speed & +15% Fire Rate while Kill Streak >= 10."},

	# ---- ECONOMY (3 cards) ----
	{"id": "blood_money", "name": "BLOOD MONEY", "cat": "ECONOMY", "rarity": "COMMON", "stat": "xp_gain", "step": 10.0, "max": 5, "desc": "XP from Kills"},
	{"id": "magnetized", "name": "MAGNETIZED", "cat": "ECONOMY", "rarity": "RARE", "stat": "pickup_radius", "step": 40.0, "max": 3, "desc": "Pickup Pull Radius"},
	{"id": "scavenger_perk", "name": "SCAVENGER", "cat": "ECONOMY", "rarity": "RARE", "stat": "redraws", "step": 2.0, "max": 3, "special": true, "desc": "Gain +2 Perk Redraw charges & heal +25 HP."},

	# ---- LOADOUT (4 cards) ----
	{"id": "loadout_gear", "name": "SALVAGED GEAR", "cat": "LOADOUT", "rarity": "RARE", "stat": "gear", "step": 1.0, "max": 6, "special": true, "desc": "Receive +1 Objective Gear immediately!"},
	{"id": "pocket_capper", "name": "POCKET CAPPER", "cat": "LOADOUT", "rarity": "RARE", "weapon": "smg", "max": 1, "special": true, "desc": "Replace base weapon with a rapid-fire Micro SMG."},
	{"id": "boomstick", "name": "BOOMSTICK", "cat": "LOADOUT", "rarity": "RARE", "weapon": "shotgun", "max": 1, "special": true, "desc": "Replace base weapon with a 6-pellet Pump Shotgun."},
	{"id": "street_sweeper", "name": "STREET SWEEPER", "cat": "LOADOUT", "rarity": "EPIC", "weapon": "rifle", "max": 1, "special": true, "desc": "Replace base weapon with a piercing Tactical Rifle."},

	# ---- CHAOS (7 cards - 30-second high-dopamine power spikes!) ----
	{"id": "chaos_hmg", "name": "HEAVY MACHINE GUN", "cat": "CHAOS", "rarity": "CHAOS", "chaos_weapon": "hmg", "duration": 30.0, "max": 99, "special": true, "desc": "Equip a Heavy Machine Gun for 30 seconds."},
	{"id": "chaos_autoshotgun", "name": "AUTO SHOTGUN", "cat": "CHAOS", "rarity": "CHAOS", "chaos_weapon": "autoshotgun", "duration": 30.0, "max": 99, "special": true, "desc": "Equip an Automatic Drum Shotgun for 30 seconds."},
	{"id": "chaos_flamethrower", "name": "INCINERATOR", "cat": "CHAOS", "rarity": "CHAOS", "chaos_weapon": "flamethrower", "duration": 30.0, "max": 99, "special": true, "desc": "Equip a Napalm Flamethrower for 30 seconds."},
	{"id": "chaos_triggered", "name": "TRIGGERED", "cat": "CHAOS", "rarity": "CHAOS", "chaos_buff": "double_rof", "duration": 30.0, "max": 99, "special": true, "desc": "Double your Rate of Fire for 30 seconds."},
	{"id": "chaos_vaxxxed", "name": "FULLY VAXXXED", "cat": "CHAOS", "rarity": "CHAOS", "chaos_buff": "invuln", "duration": 30.0, "max": 99, "special": true, "desc": "Invulnerability + neon shock barrier for 30 seconds."},
	{"id": "chaos_cooked", "name": "GET COOKED", "cat": "CHAOS", "rarity": "CHAOS", "chaos_buff": "explosive", "duration": 30.0, "max": 99, "special": true, "desc": "Explosive fiery bullets for 30 seconds."},
	{"id": "chaos_chain", "name": "CHAIN OVERCHARGE", "cat": "CHAOS", "rarity": "CHAOS", "chaos_buff": "chain", "duration": 30.0, "max": 99, "special": true, "desc": "Kills arc chain lightning to 2 nearby zombies for 30 seconds."},

	# ---- DUALITY (4 cards - High-Stakes Risk/Reward) ----
	{"id": "duality_vampire", "name": "VAMPIRE", "cat": "DUALITY", "rarity": "DUALITY", "stat": "vampire", "step": 1.0, "max": 1, "special": true, "desc": "Gain Health by damaging zombies, but Health Pickups no longer spawn."},
	{"id": "duality_glass_cannon", "name": "GLASS CANNON", "cat": "DUALITY", "rarity": "DUALITY", "stat": "glass_cannon", "step": 1.0, "max": 1, "special": true, "desc": "+65% Weapon Damage, but -30% Maximum Health."},
	{"id": "duality_tunnel_vision", "name": "TUNNEL VISION", "cat": "DUALITY", "rarity": "DUALITY", "stat": "tunnel_vision", "step": 1.0, "max": 1, "special": true, "desc": "+40% Rate of Fire & brighter long flashlight beam, narrower cone."},
	{"id": "duality_blood_fuel", "name": "BLOOD FUEL", "cat": "DUALITY", "rarity": "DUALITY", "stat": "blood_fuel", "step": 1.0, "max": 1, "special": true, "desc": "+35% Rate of Fire while sprinting; sprinting at 0 Stamina drains HP."},
]

func get_perk_by_id(id: String) -> Dictionary:
	for p in PERKS:
		if p["id"] == id:
			return p
	return {}
