import { TOWERS, ENEMIES } from './config.js';

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Failed to load ${src}`));
    img.src = src;
  });
}

// Loads every sprite the game needs. Result:
// { towers: { missile: [7 frames] }, enemies: { scout: img }, sell: img }
export async function loadAssets() {
  const towers = {};
  for (const [kind, def] of Object.entries(TOWERS)) {
    towers[kind] = await Promise.all(
      Array.from({ length: 7 }, (_, i) => loadImage(`assets/towers/${def.sprite}/${i}.png`)));
  }
  const enemies = {};
  for (const [type, def] of Object.entries(ENEMIES)) {
    enemies[type] = await loadImage(`assets/enemies/${def.sprite}/0.png`);
  }
  const sell = await loadImage('assets/sell/icon.png');
  return { towers, enemies, sell };
}
