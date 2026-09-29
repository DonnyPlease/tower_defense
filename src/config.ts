// Global constants. Game content (towers, enemies, levels, perks) lives in src/data/.

export const TILE = 40;
export const COLS = 20;
export const ROWS = 15;
export const FIELD_W = COLS * TILE; // 800 - the playing field
export const FIELD_H = ROWS * TILE; // 600
export const SIDEBAR_W = 200;
export const WIDTH = FIELD_W + SIDEBAR_W; // 1000 - logical game size
export const HEIGHT = FIELD_H;

// The simulation runs at a fixed rate, independent of the monitor refresh
// rate. All speeds are in pixels per tick, all times in seconds.
export const TICK_RATE = 60;
export const MAX_TICKS_PER_FRAME = 10; // protects against the "spiral of death"

export const SELL_REFUND = 0.5; // fraction of the money invested returned when selling
export const WAVE_HP_GROWTH = 0.1; // enemy hitpoints grow by 10 % per wave
export const ENDLESS_HP_GROWTH = 0.006; // extra quadratic growth in endless mode
export const HIGH_GROUND_RANGE = 1.25; // range multiplier for towers on high ground

// Economy between waves.
export const waveBonus = (waveIndex: number): number => 20 + 8 * waveIndex;
export const earlyBonus = (waveIndex: number): number => 10 + 4 * waveIndex;
export const INTEREST_RATE = 0.05;
export const interestCap = (waveIndex: number): number => 20 + 6 * waveIndex;
