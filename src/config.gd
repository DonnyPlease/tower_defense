class_name Config
extends RefCounted
## Global constants. Game content (towers, enemies, levels, perks) lives in src/data/.

const TILE: int = 40
const COLS: int = 20
const ROWS: int = 15
const FIELD_W: int = COLS * TILE # 800 - the playing field
const FIELD_H: int = ROWS * TILE # 600
const SIDEBAR_W: int = 200
const WIDTH: int = FIELD_W + SIDEBAR_W # 1000 - logical game size
const HEIGHT: int = FIELD_H

## The simulation runs at a fixed rate, independent of the monitor refresh
## rate. All speeds are in pixels per tick, all times in seconds.
const TICK_RATE: int = 60
const MAX_TICKS_PER_FRAME: int = 10 # protects against the "spiral of death"

const SELL_REFUND: float = 0.5 # fraction of the money invested returned when selling
const WAVE_HP_GROWTH: float = 0.1 # enemy hitpoints grow by 10 % per wave
const ENDLESS_HP_GROWTH: float = 0.006 # extra quadratic growth in endless mode
const HIGH_GROUND_RANGE: float = 1.25 # range multiplier for towers on high ground

# Economy between waves.
const INTEREST_RATE: float = 0.05


static func wave_bonus(wave_index: int) -> int:
	return 20 + 8 * wave_index


static func early_bonus(wave_index: int) -> int:
	return 10 + 4 * wave_index


static func interest_cap(wave_index: int) -> int:
	return 20 + 6 * wave_index
