class_name WorldEvent
extends RefCounted
## Something that happened during a tick; the view drains them for effects and sound.

enum Type {
	BUILD, ## x, y, kind
	UPGRADE, ## x, y, level
	SELL, ## x, y, amount
	SHOT, ## x, y, kind
	HIT, ## x, y, bullet
	EXPLODE, ## x, y, radius
	PULSE, ## x, y, radius
	KILL, ## x, y, amount, enemy
	LEAK, ## x, y, amount
	HEAL, ## x, y, radius
	SUMMON, ## x, y
	WAVE_STARTED, ## wave, early
	WAVE_CLEARED, ## wave, bonus, interest
	WON,
	LOST,
	WALL_BUILT, ## x, y, amount (price)
	WALL_SOLD, ## x, y, amount
	ABILITY, ## x, y, kind (ability id), radius; used (at the spot, if it has one)
	STRIKE, ## x, y, radius: an airstrike landed
	MINE_PLACED, ## x, y
	MINE_BLAST, ## x, y, radius
}

var type: Type
var x: float = 0.0
var y: float = 0.0
var kind: String = "" ## tower kind (build, shot) or ability id
var enemy: String = "" ## enemy type (kill)
var level: int = 0
var amount: int = 0
var bullet: Towers.BulletType = Towers.BulletType.NORMAL
var radius: float = 0.0
var wave: int = 0
var early: int = 0
var bonus: int = 0
var interest: int = 0


func _init(p_type: Type, p_x: float = 0.0, p_y: float = 0.0) -> void:
	type = p_type
	x = p_x
	y = p_y
