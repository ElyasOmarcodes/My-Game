// Procedural city — the JS twin of Assets/Scripts/Gameplay/World/CityBuilder.cs.
// Same block grid, same districts, same rules; one seed builds the same map.
import { MaterialGroup } from './boxmesh.js';
import { SURFACE, EMISSIVE } from './palette.js';
import { mulberry32 } from './gl.js';

export const BLOCKS_PER_SIDE = 6;
export const BLOCK_SIZE = 58;
export const ROAD_WIDTH = 16;
export const SIDEWALK_H = 0.16;
export const SIDEWALK_INSET = 3.4;
export const SPAN = BLOCKS_PER_SIDE * BLOCK_SIZE + (BLOCKS_PER_SIDE + 1) * ROAD_WIDTH;

const DISTRICT = { downtown: 0, residential: 1, industrial: 2, park: 3, waterfront: 4 };

/// World centre of block (gx, gz) — exported so a camera can be aimed at a
/// district by name rather than by hand-copied coordinates.
export function blockCentreOf(gx, gz) {
  const step = BLOCK_SIZE + ROAD_WIDTH;
  const half = SPAN / 2;
  return [
    -half + ROAD_WIDTH + BLOCK_SIZE / 2 + gx * step, 0,
    -half + ROAD_WIDTH + BLOCK_SIZE / 2 + gz * step,
  ];
}

/// Centre line of road `i` on either axis — the streets the player drives down.
export function roadOffset(i) {
  return -SPAN / 2 + ROAD_WIDTH / 2 + i * (BLOCK_SIZE + ROAD_WIDTH);
}

export const DISTRICTS = { park: [1, 3], industrial: [5, 1], downtown: [3, 3], waterfront: [3, 0] };

export function buildCity(seed) {
  const rand = mulberry32(seed);
  const g = {};

  const surface = (key, name) => (g[name] = new MaterialGroup(name, SURFACE[key].color,
    { specular: SURFACE[key].specular }));
  const glow = (key, name) => (g[name] = new MaterialGroup(name, [0.02, 0.02, 0.03], {
    emissive: EMISSIVE[key].color.map((c) => c * EMISSIVE[key].intensity),
    specular: 0.4,
  }));

  surface('asphalt', 'asphalt'); surface('pavement', 'pavement');
  surface('marking', 'marking'); surface('concrete', 'concrete');
  surface('brick', 'brick'); surface('steel', 'steel'); surface('glass', 'glass');
  surface('grass', 'grass'); surface('foliage', 'foliage'); surface('bark', 'bark');
  surface('water', 'water');
  surface('concrete', 'roof');
  glow('windowsWarm', 'windowsWarm'); glow('windowsCool', 'windowsCool');
  glow('streetLight', 'lamps'); glow('neonCyan', 'neonCyan');
  glow('neonAmber', 'neonAmber'); glow('neonPink', 'neonPink');

  const colliders = [];   // {min:[x,y,z], max:[x,y,z]} for movement and weapon rays
  const spawns = [];
  const half = SPAN / 2;

  const addCollider = (center, size) => colliders.push({
    min: [center[0] - size[0] / 2, center[1] - size[1] / 2, center[2] - size[2] / 2],
    max: [center[0] + size[0] / 2, center[1] + size[1] / 2, center[2] + size[2] / 2],
  });

  // --- ground and water -----------------------------------------------------
  g.asphalt.add([0, -0.25, 0], [SPAN + 60, 0.5, SPAN + 60]);
  g.water.add([0, -0.10, -half - 26], [SPAN + 60, 0.3, 44]);

  // --- blocks ---------------------------------------------------------------
  const blockCentre = blockCentreOf;

  const districtFor = (gx, gz) => {
    const mid = (BLOCKS_PER_SIDE - 1) / 2;
    const distance = Math.max(Math.abs(gx - mid), Math.abs(gz - mid));
    if (gx === 1 && gz === 3) return DISTRICT.park;
    if (gz === 0) return DISTRICT.waterfront;
    if (gx >= BLOCKS_PER_SIDE - 2 && gz <= 1) return DISTRICT.industrial;
    return distance <= 1 ? DISTRICT.downtown : DISTRICT.residential;
  };

  /// Emissive strips standing in for lit windows. Random dark floors and faces are
  /// what keep a facade from reading as a repeating texture.
  function windows(position, footprint, from, height, cool) {
    const target = cool ? g.windowsCool : g.windowsWarm;
    const FLOOR = 3.4;
    const floors = Math.floor(height / FLOOR);

    for (let floor = 1; floor < floors; floor++) {
      if (rand() < 0.22) continue;
      const y = from + floor * FLOOR;

      for (let side = 0; side < 4; side++) {
        if (rand() < 0.18) continue;
        const alongX = side < 2;
        const length = (alongX ? footprint[0] : footprint[1]) - 1.4;
        if (length < 2) continue;

        const offset = (alongX ? footprint[1] : footprint[0]) / 2 + 0.03;
        const sign = side % 2 === 0 ? 1 : -1;

        // Split the row into panes with piers between them: a single strip the
        // width of the facade reads as a light bar, not as windows.
        const panes = Math.max(1, Math.round(length / 3.4));
        const pitch = length / panes;
        const paneWidth = pitch * 0.62;

        for (let pane = 0; pane < panes; pane++) {
          if (rand() < 0.25) continue;                 // a dark room here and there
          const along = -length / 2 + pitch * (pane + 0.5);
          target.add(
            alongX ? [position[0] + along, y, position[2] + offset * sign]
                   : [position[0] + offset * sign, y, position[2] + along],
            alongX ? [paneWidth, 1.35, 0.06] : [0.06, 1.35, paneWidth]);
        }
      }
    }
  }

  function roofClutter(position, footprint, roofY) {
    const units = 1 + Math.floor(rand() * 3);
    for (let i = 0; i < units; i++) {
      const x = (rand() - 0.5) * (footprint[0] - 3);
      const z = (rand() - 0.5) * (footprint[1] - 3);
      const w = 1.4 + rand() * 2.2;
      const h = 0.8 + rand() * 1.6;
      g.steel.add([position[0] + x, roofY + h / 2, position[2] + z], [w, h, w]);
    }
    if (rand() > 0.6) {
      const mast = 3 + rand() * 5;
      g.steel.add([position[0], roofY + mast / 2, position[2]], [0.18, mast, 0.18]);
      g.neonPink.add([position[0], roofY + mast + 0.2, position[2]], [0.34, 0.34, 0.34]);
    }
  }

  function neonSign(position, footprint, height) {
    const target = rand() > 0.5 ? g.neonCyan : g.neonAmber;
    const y = 6 + rand() * Math.max(2, height - 10);
    const vertical = rand() > 0.5;
    const offset = footprint[1] / 2 + 0.25;
    target.add([position[0], y, position[2] + offset],
      vertical ? [0.9, 5.5, 0.25] : [6.5, 1.1, 0.25]);
  }

  function building(position, footprint, height, downtown) {
    const glassy = downtown && rand() > 0.35;
    const shell = glassy ? g.glass : (downtown ? g.concrete : g.brick);

    let baseHeight = height;
    const setback = downtown && height > 34 && rand() > 0.4;
    if (setback) baseHeight = height * (0.55 + rand() * 0.2);

    const baseCentre = [position[0], baseHeight / 2 + SIDEWALK_H, position[2]];
    shell.add(baseCentre, [footprint[0], baseHeight, footprint[1]]);
    addCollider(baseCentre, [footprint[0], baseHeight, footprint[1]]);
    windows(position, footprint, SIDEWALK_H, baseHeight, glassy);

    if (setback) {
      const tower = [footprint[0] * 0.62, footprint[1] * 0.62];
      const towerHeight = height - baseHeight;
      const towerCentre = [position[0], baseHeight + towerHeight / 2 + SIDEWALK_H, position[2]];
      shell.add(towerCentre, [tower[0], towerHeight, tower[1]]);
      addCollider(towerCentre, [tower[0], towerHeight, tower[1]]);
      windows(position, tower, baseHeight + SIDEWALK_H, towerHeight, glassy);
      g.neonPink.add([position[0], height + SIDEWALK_H + 0.3, position[2]], [0.5, 0.5, 0.5]);
    }

    // A darker cap so roofs separate from facades when seen from above.
    g.roof.add([position[0], height + SIDEWALK_H + 0.12, position[2]],
      [footprint[0] + 0.25, 0.24, footprint[1] + 0.25]);
    roofClutter(position, footprint, height + SIDEWALK_H + 0.24);
    if (downtown && rand() > 0.55) neonSign(position, footprint, baseHeight);
  }

  function buildLots(centre, minHeight, maxHeight, downtown) {
    const usable = BLOCK_SIZE - SIDEWALK_INSET * 2;
    const split = usable * (0.38 + rand() * 0.24);
    const lots = [
      [-usable / 2, -usable / 2, split, split],
      [-usable / 2 + split, -usable / 2, usable - split, split],
      [-usable / 2, -usable / 2 + split, split, usable - split],
      [-usable / 2 + split, -usable / 2 + split, usable - split, usable - split],
    ];

    for (const [lx, lz, lw, ld] of lots) {
      const w = lw - 1.2, d = ld - 1.2;
      if (w < 6 || d < 6) continue;
      const position = [centre[0] + lx + lw / 2, 0, centre[2] + lz + ld / 2];
      building(position, [w, d], minHeight + rand() * (maxHeight - minHeight), downtown);
    }
  }

  function tree(base) {
    const height = 4.5 + rand() * 3.5;
    g.bark.add([base[0], height * 0.35, base[2]], [0.4, height * 0.7, 0.4]);
    const canopy = 2.6 + rand() * 1.8;
    g.foliage.add([base[0], height * 0.78, base[2]],
      [canopy, canopy * 0.75, canopy], rand() * 45);
    g.foliage.add([base[0], height * 1.02, base[2]],
      [canopy * 0.7, canopy * 0.55, canopy * 0.7], rand() * 45);
  }

  function buildPark(centre) {
    const size = BLOCK_SIZE - 3;
    g.grass.add([centre[0], SIDEWALK_H + 0.06, centre[2]], [size, 0.12, size]);
    g.water.add([centre[0] + 6, SIDEWALK_H + 0.10, centre[2] - 5], [18, 0.14, 13]);
    g.pavement.add([centre[0], SIDEWALK_H + 0.13, centre[2] + 12], [size, 0.05, 3]);
    g.pavement.add([centre[0] - 14, SIDEWALK_H + 0.13, centre[2]], [3, 0.05, size]);

    for (let i = 0; i < 16; i++) {
      const x = (rand() - 0.5) * (size - 6);
      const z = (rand() - 0.5) * (size - 6);
      if (x > -2 && x < 14 && z > -12 && z < 2) continue;
      tree([centre[0] + x, SIDEWALK_H, centre[2] + z]);
    }
    for (let i = 0; i < 5; i++)
      g.steel.add([centre[0] - 14, SIDEWALK_H + 0.45, centre[2] - 20 + i * 10], [1.8, 0.12, 0.6]);
  }

  function buildIndustrial(centre) {
    const w = BLOCK_SIZE - 10;
    const d = BLOCK_SIZE / 2;
    const shed = [centre[0], 5 + SIDEWALK_H, centre[2] + 8];

    g.steel.add(shed, [w, 10, d]);
    addCollider(shed, [w, 10, d]);
    for (let i = 0; i < 5; i++)
      g.steel.add([centre[0] - w * 0.4 + i * (w * 0.2), 10.6 + SIDEWALK_H, centre[2] + 8],
        [w * 0.16, 1.4, d]);
    g.windowsCool.add([centre[0], 7.5 + SIDEWALK_H, centre[2] + 8 - d / 2 - 0.05],
      [w - 6, 1.2, 0.06]);

    const palette = [g.brick, g.steel, g.concrete];
    for (let i = 0; i < 9; i++) {
      const x = (rand() - 0.5) * (w - 8);
      const z = -14 + rand() * 10;
      const stacked = rand() > 0.6;
      const yaw = rand() > 0.5 ? 0 : 90;
      const target = palette[Math.floor(rand() * palette.length)];

      target.add([centre[0] + x, 1.3 + SIDEWALK_H, centre[2] + z], [6.1, 2.6, 2.4], yaw);
      if (stacked)
        target.add([centre[0] + x, 3.9 + SIDEWALK_H, centre[2] + z], [6.1, 2.6, 2.4], yaw);
      addCollider([centre[0] + x, (stacked ? 2.6 : 1.3) + SIDEWALK_H, centre[2] + z],
        [6.4, stacked ? 5.2 : 2.6, 6.4]);
    }
    g.neonAmber.add([centre[0], 11.6 + SIDEWALK_H, centre[2] + 8], [7, 0.9, 0.3]);
  }

  function buildWaterfront(centre) {
    g.pavement.add([centre[0], SIDEWALK_H + 0.08, centre[2] - BLOCK_SIZE * 0.32],
      [BLOCK_SIZE - 4, 0.1, BLOCK_SIZE * 0.3]);

    for (let i = 0; i < 2; i++) {
      const w = BLOCK_SIZE * 0.42;
      const x = -BLOCK_SIZE * 0.24 + i * BLOCK_SIZE * 0.48;
      const height = 7 + rand() * 6;
      const position = [centre[0] + x, 0, centre[2] + BLOCK_SIZE * 0.18];
      const c = [position[0], height / 2 + SIDEWALK_H, position[2]];

      g.brick.add(c, [w, height, BLOCK_SIZE * 0.34]);
      addCollider(c, [w, height, BLOCK_SIZE * 0.34]);
      windows(position, [w, BLOCK_SIZE * 0.34], SIDEWALK_H, height, false);
    }
    for (let i = 0; i < 4; i++)
      g.steel.add([centre[0] - 20 + i * 13, SIDEWALK_H + 0.6, centre[2] - BLOCK_SIZE * 0.45],
        [1.2, 1.2, 1.2]);
  }

  for (let gx = 0; gx < BLOCKS_PER_SIDE; gx++)
    for (let gz = 0; gz < BLOCKS_PER_SIDE; gz++) {
      const centre = blockCentre(gx, gz);
      g.pavement.add([centre[0], SIDEWALK_H / 2, centre[2]],
        [BLOCK_SIZE, SIDEWALK_H, BLOCK_SIZE]);

      switch (districtFor(gx, gz)) {
        case DISTRICT.park: buildPark(centre); break;
        case DISTRICT.industrial: buildIndustrial(centre); break;
        case DISTRICT.waterfront: buildWaterfront(centre); break;
        case DISTRICT.downtown: buildLots(centre, 26, 58, true); break;
        default: buildLots(centre, 9, 22, false); break;
      }
    }

  // --- streets --------------------------------------------------------------
  function streetLight(base, yaw) {
    const H = 7.2;
    g.steel.add([base[0], H / 2, base[2]], [0.22, H, 0.22]);
    const rad = yaw * Math.PI / 180;
    const dir = [Math.sin(rad), 0, Math.cos(rad)];
    g.steel.add([base[0] + dir[0] * 0.7, H - 0.1, base[2] + dir[2] * 0.7], [0.14, 0.14, 1.5], yaw);
    g.lamps.add([base[0] + dir[0] * 1.3, H - 0.18, base[2] + dir[2] * 1.3], [0.55, 0.14, 0.95], yaw);
  }

  for (let i = 0; i <= BLOCKS_PER_SIDE; i++) {
    const offset = -half + ROAD_WIDTH / 2 + i * (BLOCK_SIZE + ROAD_WIDTH);
    for (let t = -half; t < half; t += 8) {
      g.marking.add([offset, 0.02, t + 2], [0.35, 0.02, 3.4]);
      g.marking.add([t + 2, 0.02, offset], [3.4, 0.02, 0.35]);
    }
    for (let j = 0; j < BLOCKS_PER_SIDE; j++) {
      const along = -half + ROAD_WIDTH + j * (BLOCK_SIZE + ROAD_WIDTH) + BLOCK_SIZE / 2;
      streetLight([offset - ROAD_WIDTH * 0.42, 0, along], 90);
      streetLight([along, 0, offset + ROAD_WIDTH * 0.42], 0);
    }
  }

  // --- spawns ---------------------------------------------------------------
  const step = BLOCK_SIZE + ROAD_WIDTH;
  for (let gx = 0; gx < BLOCKS_PER_SIDE; gx++)
    for (let gz = 0; gz < BLOCKS_PER_SIDE; gz++) {
      if ((gx + gz) % 2 !== 0) continue;
      spawns.push({
        position: [
          -half + ROAD_WIDTH / 2 + (gx + 1) * step - BLOCK_SIZE / 2 - ROAD_WIDTH / 2, 1.2,
          -half + ROAD_WIDTH / 2 + (gz + 1) * step - BLOCK_SIZE / 2 - ROAD_WIDTH / 2,
        ],
        yaw: Math.floor(rand() * 4) * 90,
      });
    }

  return { groups: Object.values(g), named: g, colliders, spawns, span: SPAN };
}
