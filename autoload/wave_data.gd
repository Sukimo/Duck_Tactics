extends Node
# NOT an autoload — WaveManager loads this as a plain script reference
# All wave/pattern data lives here. Edit this file to balance the game.

# ── Scene preloads ────────────────────────────────────────────────────────────
const MATTHEW_SCENE    := preload("res://units/ducks/matthew_duck.tscn")
const MELEE_MOB_SCENE  := preload("res://enemies/mob/melee_mob.tscn")
const RANGE_MOB_SCENE  := preload("res://enemies/mob/range_mob.tscn")
const MELEE_DUCK_SCENE := preload("res://units/ducks/melee_duck.tscn")
const RANGE_DUCK_SCENE := preload("res://units/ducks/range_duck.tscn")

# ── Starter ducks (given at game start) ───────────────────────────────────────
const STARTER_DUCKS : Array = [
	MELEE_DUCK_SCENE,
	RANGE_DUCK_SCENE,
	MELEE_DUCK_SCENE,
]

# ── Story config ──────────────────────────────────────────────────────────────
const STORY_WAVE_COUNT     : int = 3
const SPECIAL_REWARD_EVERY : int = 3   # endless: special reward every N waves

# ── Patterns ──────────────────────────────────────────────────────────────────
# Each pattern = one spawn group: a mob type, count, interval between spawns, edge
# Name by behavior so waves are self-documenting
const PATTERNS : Dictionary = {
	"melee_patrol_left": {
		"scene": MELEE_MOB_SCENE, "count": 3, "interval": 1.2, "edge": "left"
	},
	"melee_rush_left": {
		"scene": MELEE_MOB_SCENE, "count": 5, "interval": 0.8, "edge": "left"
	},
	"range_sniper_right": {
		"scene": RANGE_MOB_SCENE, "count": 2, "interval": 1.5, "edge": "right"
	},
	"range_rain_top": {
		"scene": RANGE_MOB_SCENE, "count": 3, "interval": 1.2, "edge": "top"
	},
}

# ── Story waves ───────────────────────────────────────────────────────────────
# Each wave = list of pattern names to run together
const WAVE_DATA : Array = [
	{ "patterns": ["melee_patrol_left"] },
	{ "patterns": ["melee_patrol_left", "range_sniper_right"] },
	{ "patterns": ["melee_rush_left",   "range_rain_top"] },
]

# ── Public API ────────────────────────────────────────────────────────────────
 
## Returns Array of resolved pattern dicts for the given wave.
## For endless mode pass endless_loop >= 0 and wave_index is ignored.
static func get_patterns(wave_index: int, endless_loop: int = -1)->Array:
	if endless_loop >= 0:
		return _scale_endless(endless_loop)
	if wave_index < 0 or wave_index >= WAVE_DATA.size():
		push_warning("[WaveData] wave_index %d out of range" % wave_index)
		return[]
	var result : Array = []
	for name in WAVE_DATA[wave_index]["patterns"]:
		if PATTERNS.has(name):
			result.append(PATTERNS[name])
		else:
			push_warning("[WaveData] Unknown pattern: %s" % name)
	return result

## Returns the active edges for a wave (used by ArenaZone for arrow hints)
static func get_edges(wave_index: int, endless_loop: int = -1) -> Array:
	var patterns := get_patterns(wave_index, endless_loop)
	var edges : Array = []
	for p in patterns:
		var edge : String = p.get("edge", "left")
		if not edges.has(edge):
			edges.append(edge)
	return edges
	
# ── Endless scaling ───────────────────────────────────────────────────────────
static func _scale_endless(loop: int) -> Array:
	var melee_count : int   = 4 + loop * 2
	var range_count : int   = 3 + loop
	var interval    : float = max(0.4, 0.8 - loop * 0.05)
	return [
		{ "scene": MELEE_MOB_SCENE, "count": melee_count, "interval": interval,       "edge": "left"  },
		{ "scene": RANGE_MOB_SCENE, "count": range_count, "interval": interval + 0.2, "edge": "right" },
	]
 
