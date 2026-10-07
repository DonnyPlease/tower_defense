class_name LevelDef
extends RefCounted
## A level.
##
## Map tiles (20 x 15):
##   .  grass (buildable)          #  road
##   S  road where enemies enter   E  road where enemies leave (on the border)
##   H  high ground (buildable, +25 % tower range)
##   R  rock (blocked)             ~  water (blocked)     =  bridge (road over water)
## In maze levels enemies may also walk on grass and high ground, so the
## towers themselves form the walls.
## In `road_walls` levels enemies stay on the road, but walls (and towers on
## walls) can be built on it where it is wide enough, and enemies walk around them.

var id: String
var name: String
var description: String
var tiles: PackedStringArray
var maze: bool = false
var road_walls: bool = false
var money: int
var lives: int
## Multiplies every enemy's hitpoints on this level (the main difficulty knob).
var hp_scale: float = 1.0
var waves: Array[Wave] = []


## A copy with a different hitpoint scale (used by the balance tuner).
func with_hp_scale(value: float) -> LevelDef:
	var copy := LevelDef.new()
	copy.id = id
	copy.name = name
	copy.description = description
	copy.tiles = tiles
	copy.maze = maze
	copy.road_walls = road_walls
	copy.money = money
	copy.lives = lives
	copy.hp_scale = value
	copy.waves = waves
	return copy
