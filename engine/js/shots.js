// Screenshot harness: builds a named scene, renders exactly one frame, and leaves
// it on the canvas for headless Chromium to capture.
import { Renderer } from './renderer.js';
import { buildCity, SPAN, blockCentreOf, roadOffset, DISTRICTS } from './city.js';
import { buildAgent, buildWeapon, AGENTS, WEAPONS, agent as agentDef, weapon as weaponDef } from './models.js';
import { MaterialGroup } from './boxmesh.js';
import { THEME, SURFACE } from './palette.js';

window.addEventListener('error', (e) => {
  document.getElementById('caption').innerHTML =
    '<b style="color:#FF4D5E">' + (e.message || e.error) + '</b>';
});

const params = new URLSearchParams(location.search);
const shot = params.get('shot') || 'city-aerial';
const seed = Number(params.get('seed') || 20260821);

const canvas = document.getElementById('view');
canvas.width = Number(params.get('w') || 1920);
canvas.height = Number(params.get('h') || 1080);

const label = (title, sub) => {
  document.getElementById('label').innerHTML =
    title + (sub ? '<small>' + sub + '</small>' : '');
};
const caption = (html) => { document.getElementById('caption').innerHTML = html || ''; };

/// A dark studio floor so a lone model is not floating in a void.
function studioFloor(groups, radius = 9) {
  const floor = new MaterialGroup('studio_floor', [0.038, 0.043, 0.053], { specular: 0.35 });
  floor.add([0, -0.06, 0], [radius * 2, 0.12, radius * 2]);
  const grid = new MaterialGroup('studio_grid', [0.02, 0.02, 0.03], {
    emissive: THEME.cyan.map((c) => c * 0.22), specular: 0.2,
  });
  for (let i = -radius; i <= radius; i += 2) {
    grid.add([i, 0.005, 0], [0.010, 0.01, radius * 2]);
    grid.add([0, 0.005, i], [radius * 2, 0.01, 0.010]);
  }
  groups.push(floor, grid);
}

/// Studio lighting: brighter and flatter than the city, so the silhouette and the
/// gear read instead of the mood.
const STUDIO = {
  sunDir: [0.42, 0.55, 0.72],
  sunColor: [2.30, 1.95, 1.65],
  skyColor: [0.48, 0.58, 0.74],
  groundColor: [0.105, 0.115, 0.140],
  fogColor: [0.045, 0.060, 0.090],
  fogDensity: 0.008,
  clear: [0.022, 0.030, 0.045],
};

function walkers(city, groups, entries) {
  for (const e of entries)
    groups.push(...buildAgent(e.id, e.at, e.yaw ?? 0,
      e.team === 'bravo' ? THEME.teamBravo : THEME.teamAlpha, { stride: e.stride ?? 0 }));
}

const SCENES = {
  'city-aerial': () => {
    const city = buildCity(seed);
    label('Free-roam city', SPAN.toFixed(0) + ' m across · 6×6 blocks · one seed');
    caption('<b>Districts</b> · downtown towers, residential blocks, industrial yard, park, waterfront');
    return {
      groups: city.groups,
      camera: { position: [-270, 132, -288], target: [16, 24, 8], fov: 44 },
      env: { fogDensity: 0.0016 },
    };
  },

  'city-street': () => {
    const city = buildCity(seed);
    const groups = [...city.groups];
    // Stand in the middle of the road that runs through downtown and look down it.
    const x = roadOffset(3);
    walkers(city, groups, [
      { id: 'vanguard', at: [x - 3.4, 0, -44], yaw: 14, stride: 1.1 },
      { id: 'spectre', at: [x + 2.6, 0, -49], yaw: 26, stride: 2.4 },
      { id: 'reaper', at: [x + 5.2, 0, -28], yaw: 186, stride: 0.4, team: 'bravo' },
    ]);
    label('Street level', 'Downtown avenue · dusk');
    caption('<b>Agents in scale</b> · 1.7–1.9 m tall against a 3.4 m storey');
    return {
      groups,
      camera: { position: [x - 1.2, 1.75, -56], target: [x + 1.5, 7.5, 26], fov: 62 },
      env: { fogDensity: 0.0040 },
    };
  },

  'city-park': () => {
    const city = buildCity(seed);
    const groups = [...city.groups];
    const [px, , pz] = blockCentreOf(...DISTRICTS.park);
    walkers(city, groups, [
      { id: 'medic', at: [px - 14, 0.16, pz + 4], yaw: 120, stride: 1.8 },
      { id: 'forge', at: [px - 20, 0.16, pz - 4], yaw: 84, stride: 0.6 },
    ]);
    label('Park district', 'Pond, paths and tree cover');
    caption('<b>Cover variety</b> · open sightlines broken by canopies and benches');
    return {
      groups,
      camera: { position: [px - 40, 6.5, pz - 34], target: [px + 6, 3, pz + 6], fov: 58 },
      env: { fogDensity: 0.0038 },
    };
  },

  'city-industrial': () => {
    const city = buildCity(seed);
    const groups = [...city.groups];
    const [ix, , iz] = blockCentreOf(...DISTRICTS.industrial);
    walkers(city, groups, [
      { id: 'havoc', at: [ix - 6, 0.16, iz - 16], yaw: 22, stride: 1.4, team: 'bravo' },
      { id: 'forge', at: [ix + 4, 0.16, iz - 20], yaw: 350, stride: 2.9, team: 'bravo' },
    ]);
    label('Industrial yard', 'Warehouse, stacked containers, close-quarters lanes');
    caption('<b>Container maze</b> · stacked cover that changes every seed');
    return {
      groups,
      camera: { position: [ix - 24, 4.4, iz - 40], target: [ix + 6, 6, iz + 4], fov: 62 },
      env: { fogDensity: 0.0042 },
    };
  },

  agents: () => {
    const groups = [];
    studioFloor(groups, 11);
    const line = ['vanguard', 'spectre', 'forge', 'reaper'];
    line.forEach((id, i) => {
      const x = -2.55 + i * 1.7;
      // Three-quarter view: weapons read across the frame instead of pointing
      // straight down the lens.
      groups.push(...buildAgent(id, [x, 0, 0], 30 + (i - 1.5) * 5,
        i % 2 ? THEME.teamBravo : THEME.teamAlpha, { stride: 0 }));
    });
    label('Agent models', 'Four body archetypes · built from code, no mesh assets');
    caption(line.map((id) => {
      const d = agentDef(id);
      return '<b>' + d.name + '</b> — ' + d.role + ' · ' + weaponDef(d.weapon).name;
    }).join('&nbsp; &nbsp;·&nbsp; &nbsp;'));
    return {
      groups,
      camera: { position: [0.5, 1.22, 5.2], target: [0.1, 0.92, 0], fov: 46 },
      env: STUDIO,
      bloom: 0.85,
    };
  },

  weapons: () => {
    const groups = [];
    studioFloor(groups, 7);
    const accents = [THEME.cyan, THEME.violet, THEME.danger, THEME.teamBravo, THEME.success];
    const shared = {};
    WEAPONS.forEach((w, i) => {
      // Laid out nose-left on invisible racks, one above the other.
      buildWeapon(w.id, [0, 1.62 - i * 0.34, 0], 90, accents[i % accents.length], shared);
    });
    Object.values(shared).forEach((g) => groups.push(g));
    label('Weapon models', 'Five silhouettes · shared handling stats with the Unity build');
    caption(WEAPONS.map((w) =>
      '<b>' + w.name + '</b> · ' + w.damage + ' dmg · ' + w.rate + '/s').join('&nbsp; &nbsp;·&nbsp; &nbsp;'));
    return {
      groups,
      camera: { position: [0.9, 1.15, 3.5], target: [0, 0.92, 0], fov: 40 },
      env: STUDIO,
      bloom: 0.9,
    };
  },
};

const scene = (SCENES[shot] || SCENES['city-aerial'])();

const renderer = new Renderer(canvas, {
  preserveDrawingBuffer: true,
  environment: scene.env,
  bloomIntensity: scene.bloom ?? 1.2,
});
renderer.upload(scene.groups);
renderer.render(scene.groups, scene.camera);

// Render twice: the first frame warms every shader and buffer, and Chromium
// occasionally captures before the first draw has landed.
requestAnimationFrame(() => {
  renderer.render(scene.groups, scene.camera);
  window.__ready = true;
  document.title = 'ready:' + shot + ':' + renderer.drawCalls;
});
