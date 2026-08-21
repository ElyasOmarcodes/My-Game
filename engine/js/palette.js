// Mirrors Assets/Scripts/Gameplay/Models/MaterialLibrary.cs and Assets/Scripts/UI/Theme.cs.
import { hex } from './gl.js';

export const THEME = {
  cyan: hex('#3BE8FF'),
  amber: hex('#FFB23B'),
  danger: hex('#FF4D5E'),
  success: hex('#4DFFA6'),
  teamAlpha: hex('#3BE8FF'),
  teamBravo: hex('#FF7A3B'),
  violet: hex('#B58CFF'),
  pink: hex('#FF4D9E'),
};

export const SURFACE = {
  asphalt:  { color: [0.045, 0.050, 0.062], specular: 0.20 },
  pavement: { color: [0.072, 0.078, 0.092], specular: 0.10 },
  concrete: { color: [0.145, 0.152, 0.168], specular: 0.08 },
  brick:    { color: [0.165, 0.108, 0.092], specular: 0.06 },
  steel:    { color: [0.118, 0.130, 0.152], specular: 0.55 },
  glass:    { color: [0.055, 0.085, 0.115], specular: 0.95 },
  grass:    { color: [0.062, 0.115, 0.072], specular: 0.04 },
  foliage:  { color: [0.075, 0.145, 0.085], specular: 0.06 },
  bark:     { color: [0.085, 0.070, 0.058], specular: 0.04 },
  water:    { color: [0.030, 0.075, 0.105], specular: 1.00 },
  marking:  { color: [0.55, 0.52, 0.42],    specular: 0.10 },
  gunmetal: { color: [0.105, 0.112, 0.130], specular: 0.60 },
  polymer:  { color: [0.072, 0.076, 0.086], specular: 0.20 },
  fabric:   { color: [0.150, 0.155, 0.172], specular: 0.05 },
  armour:   { color: [0.175, 0.190, 0.215], specular: 0.35 },
  suit:     { color: [0.125, 0.135, 0.158], specular: 0.20 },
  overall:  { color: [0.205, 0.150, 0.080], specular: 0.10 },
  hardhat:  { color: [0.300, 0.200, 0.050], specular: 0.30 },
  coat:     { color: [0.105, 0.115, 0.140], specular: 0.12 },
};

export const EMISSIVE = {
  windowsWarm: { color: [1.0, 0.78, 0.45], intensity: 0.95 },
  windowsCool: { color: [0.55, 0.80, 1.0], intensity: 0.85 },
  streetLight: { color: [1.0, 0.85, 0.60], intensity: 2.0 },
  neonCyan:    { color: THEME.cyan,        intensity: 2.4 },
  neonAmber:   { color: THEME.amber,       intensity: 2.4 },
  neonPink:    { color: THEME.pink,        intensity: 2.2 },
};

/// The sky/sun setup every scene shares — dusk, low warm key, cool sky bounce.
export const ENVIRONMENT = {
  sunDir: [0.42, 0.58, 0.70],
  sunColor: [1.05, 0.80, 0.58],
  skyColor: [0.16, 0.22, 0.32],
  groundColor: [0.030, 0.034, 0.042],
  fogColor: [0.055, 0.075, 0.115],
  fogDensity: 0.0032,
  clear: [0.035, 0.050, 0.080],
};
