class_name Tech
extends RefCounted
## The tech tree: everything stars buy. A node needs its parents first and a
## number of stars *earned* in total (so the early game can't be skipped),
## and costs stars to *spend*. The tree is where locked content lives: the
## game screen only shows what the player owns.
##
## The screen lays the nodes out on a grid (`col`, `row`): towers and their
## branches on the left, perks, starting bonuses and challenges on the right.

enum Kind { TOWER, BRANCH, PERK, BONUS, VARIANT }

## Owned from the start, for free.
const START: Array[String] = ["gun", "missile"]
const COLS: int = 7
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]
const ROWS: int = 6


class TechNode:
	var id: String
	var name: String
	var description: String
	var kind: Kind
	var cost: int ## stars to spend
	var parents: Array[String]
	var earned: int ## total stars earned before it can be bought
	var col: int
	var row: int
	var target: String ## tower kind, branch id, or perk id

	func _init(p_id: String, p_name: String, p_kind: Kind, p_cost: int, p_parents: Array[String], p_earned: int,
			p_col: int, p_row: int, p_description: String, p_target: String = "") -> void:
		id = p_id
		name = p_name
		kind = p_kind
		cost = p_cost
		parents = p_parents
		earned = p_earned
		col = p_col
		row = p_row
		description = p_description
		target = p_target if not p_target.is_empty() else p_id


static var NODES: Array[TechNode] = _build()
static var _by_id: Dictionary[String, TechNode] = _index()


static func get_node(id: String) -> TechNode:
	assert(_by_id.has(id), "Unknown tech node '%s'" % id)
	return _by_id[id]


static func is_node(id: String) -> bool:
	return _by_id.has(id)


static func _index() -> Dictionary[String, TechNode]:
	var out: Dictionary[String, TechNode] = {}
	for n: TechNode in NODES:
		out[n.id] = n
	return out


## Node id of a perk's rank (1-based), e.g. "capital2".
static func perk_node(perk: String, rank: int) -> String:
	return "%s%d" % [perk, rank]


static func _build() -> Array[TechNode]:
	var out: Array[TechNode] = []
	# Towers down the first column, each followed by its two branches. The
	# tower thresholds are the old "unlocks at N total stars".
	var tower_rules: Dictionary[String, Array] = {
		"gun": [0, 0, []], "missile": [0, 0, []], "cannon": [1, 1, ["missile"]], "frost": [2, 3, ["cannon"]],
		"laser": [2, 5, ["frost"]], "support": [3, 7, ["laser"]],
	}
	for i: int in Towers.KINDS.size():
		var kind: String = Towers.KINDS[i]
		var d: TowerDef = Towers.get_def(kind)
		var rule: Array = tower_rules[kind]
		var cost: int = rule[0]
		var need: int = rule[1]
		var parent_list: Array = rule[2]
		var parents: Array[String] = []
		parents.assign(parent_list)
		out.append(TechNode.new(kind, d.name, Kind.TOWER, cost, parents, need, 0, i, d.description))
		for j: int in d.branches.size():
			var b: TowerBranch = d.branches[j]
			out.append(TechNode.new(b.id, b.name, Kind.BRANCH, 1 if i < 2 else 2, [kind], need + 2, 1 + j, i,
				"%s branch (level 4-5). %s" % [d.name, b.description]))

	# Perks: each rank is a node after the one before.
	for r: int in Perks.IDS.size():
		var perk: Perks.PerkDef = Perks.get_def(Perks.IDS[r])
		for k: int in perk.costs.size():
			var parents: Array[String] = []
			if k > 0:
				parents.append(perk_node(perk.id, k))
			var n := TechNode.new(perk_node(perk.id, k + 1), "%s %s" % [perk.name, ROMAN[k]],
				Kind.PERK, perk.costs[k], parents, 0, 3 + k, r, perk.effect(1) + " (each rank)", perk.id)
			out.append(n)

	# Starting bonuses.
	out.append(TechNode.new("masonry", "Masonry", Kind.BONUS, 2, ["fortify2"], 3, 6, 1,
		"Your first %d walls in every game are free." % MASONRY_WALLS))
	out.append(TechNode.new("veterans", "Veterans", Kind.BONUS, 2, ["engineering2"], 4, 6, 2,
		"The first tower you build in every game starts at level 2."))

	# Level variants: the same maps with a twist, each with stars of its own.
	var earned_for: Array[int] = [4, 6, 8, 10]
	for i: int in Levels.VARIANTS.size():
		var v: Levels.LevelVariant = Levels.get_variant(Levels.VARIANTS[i])
		out.append(TechNode.new(v.id, v.name, Kind.VARIANT, 1, [], earned_for[i], 3 + i, 4,
			"Level variant: %s Every level can be played this way, for 3 more stars each." % v.description))
	# Run perks.
	out.append(TechNode.new("orders", "Field Orders", Kind.BONUS, 2, [], 6, 3, 5,
		"Run perks: at the start of every game, and after waves 5 and 10, choose 1 of 3 perks for that game."))
	out.append(TechNode.new("orders2", "Wider Choice", Kind.BONUS, 1, ["orders"], 9, 4, 5,
		"Field orders offer 4 perks to choose from instead of 3."))
	return out


## Free walls per game with Masonry.
const MASONRY_WALLS: int = 3
