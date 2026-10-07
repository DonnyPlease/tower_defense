class_name TowerDef
extends RefCounted
## One tower type. It has 3 levels: levels[0].cost is the build price,
## levels[1] and levels[2] cost is the price of that upgrade. After level 3
## it grows into one of its two `branches` (levels 4 and 5).

var kind: String
var name: String
var description: String
var behavior: Towers.Behavior
var bullet: Towers.BulletType = Towers.BulletType.NORMAL
var bullet_speed: float = 10.0 ## pixels per tick
var hits_air: bool
var hits_ground: bool
var ignores_armor: bool = false
## Optional folder in res://assets/towers with `frames` PNGs pointing up;
## otherwise the art is drawn in code (src/view/tower_art.gd).
var sprite: String = ""
var frames: int = 1
## Total stars that unlocked the tower before the tech tree (Tech): old
## profiles keep these towers, and simulated players use it as "typical unlocks".
var unlock_stars: int
var color: Color ## accent colour for UI and effects
var levels: Array[TowerLevel]
var branches: Array[TowerBranch] = []
## Magnet: enemies that re-route prefer ways through its field (see World).
var pulls: bool = false
