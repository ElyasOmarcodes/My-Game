// Agent and weapon models — the JS twins of Assets/Scripts/Gameplay/Models/*.cs.
//
// Four body archetypes, not six, because shape is what a player reads at forty
// metres; the six roster agents are told apart by accent colour on top of these.
import { MaterialGroup } from './boxmesh.js';
import { SURFACE, THEME } from './palette.js';

export const ARCHETYPES = ['heavy', 'scout', 'engineer', 'marksman'];

export const AGENTS = [
  { id: 'vanguard', name: 'Vanguard', role: 'Assault',    archetype: 'heavy',    accent: THEME.cyan,    weapon: 'carbine' },
  { id: 'spectre',  name: 'Spectre',  role: 'Recon',      archetype: 'scout',    accent: THEME.violet,  weapon: 'smg' },
  { id: 'forge',    name: 'Forge',    role: 'Engineer',   archetype: 'engineer', accent: THEME.amber,   weapon: 'carbine' },
  { id: 'reaper',   name: 'Reaper',   role: 'Marksman',   archetype: 'marksman', accent: THEME.danger,  weapon: 'sniper' },
  { id: 'medic',    name: 'Halo',     role: 'Support',    archetype: 'scout',    accent: THEME.success, weapon: 'pistol' },
  { id: 'havoc',    name: 'Havoc',    role: 'Demolition', archetype: 'engineer', accent: THEME.teamBravo, weapon: 'shotgun' },
];

export const WEAPONS = [
  { id: 'carbine', name: 'MK-7 Carbine',    class: 'Assault rifle',  damage: 22, rate: 8.5, clip: 30, spread: 0.016, range: 110 },
  { id: 'smg',     name: 'Wasp SMG',        class: 'Submachine gun', damage: 15, rate: 14,  clip: 35, spread: 0.030, range: 55 },
  { id: 'sniper',  name: 'Longbow DMR',     class: 'Marksman rifle', damage: 78, rate: 1.4, clip: 6,  spread: 0.002, range: 220 },
  { id: 'shotgun', name: 'Breaker 12',      class: 'Shotgun',        damage: 14, rate: 1.6, clip: 7,  spread: 0.075, range: 26 },
  { id: 'pistol',  name: 'Vector Sidearm',  class: 'Sidearm',        damage: 26, rate: 4.5, clip: 15, spread: 0.020, range: 45 },
];

export const agent = (id) => AGENTS.find((a) => a.id === id) || AGENTS[0];
export const weapon = (id) => WEAPONS.find((w) => w.id === id) || WEAPONS[0];

const surfaceGroup = (key, name, extra = {}) =>
  new MaterialGroup(name, SURFACE[key].color, { specular: SURFACE[key].specular, ...extra });

const glowGroup = (name, color, intensity = 2.6) =>
  new MaterialGroup(name, [0.02, 0.02, 0.03], {
    emissive: color.map((c) => c * intensity), specular: 0.4,
  });

/// Per-archetype skeleton: where the joints sit and how thick the limbs are.
/// Torso details are added on top of this in `DETAIL`.
const SKELETON = {
  heavy:    { shoulderY: 1.46, shoulderX: 0.30, armLen: 0.62, armThick: 0.19,
              hipY: 0.92, hipX: 0.13, legLen: 0.86, legThick: 0.22, legMat: 'fabric' },
  scout:    { shoulderY: 1.40, shoulderX: 0.24, armLen: 0.60, armThick: 0.14,
              hipY: 0.88, hipX: 0.11, legLen: 0.84, legThick: 0.17, legMat: null },
  engineer: { shoulderY: 1.42, shoulderX: 0.29, armLen: 0.60, armThick: 0.18,
              hipY: 0.90, hipX: 0.13, legLen: 0.84, legThick: 0.21, legMat: null },
  marksman: { shoulderY: 1.56, shoulderX: 0.25, armLen: 0.64, armThick: 0.14,
              hipY: 0.98, hipX: 0.12, legLen: 0.92, legThick: 0.17, legMat: null },
};

const AIM_PITCH = 74;   // how far forward the weapon arm is raised, in degrees

/// Builds one agent at `origin`, facing `yaw` (0 faces +Z).
/// `stride` drives the walk cycle; 0 is a standing pose.
export function buildAgent(id, origin, yaw = 0, teamColor = THEME.teamAlpha, options = {}) {
  const def = agent(id);
  const bone = SKELETON[def.archetype];
  const stride = options.stride ?? 0;
  const swing = Math.sin(stride) * 34;

  const groups = {};
  const push = (group) => (groups[group.name] = groups[group.name] || group);

  const bodyKey = { heavy: 'armour', scout: 'suit', engineer: 'overall', marksman: 'coat' }[def.archetype];
  const shell = push(surfaceGroup(bodyKey, 'agent_' + bodyKey));
  const accent = push(glowGroup('agent_accent_' + def.id, def.accent));
  const team = push(glowGroup('agent_team_' + teamColor.join('_'), teamColor, 2.0));
  const cloth = push(surfaceGroup('fabric', 'agent_fabric'));
  const steel = push(surfaceGroup('steel', 'agent_steel'));

  // Local space is body space: +Z forward, +Y up. `add` turns it into world space.
  const add = (group, centre, size, pitch = 0) => group.add(
    localToWorld(origin, yaw, centre), size, yaw, pitch);

  /// A limb pinned at its joint and swung forward by `pitch` degrees, so the free
  /// end travels the way a real arm or leg does.
  const limb = (group, side, pitch, isLeg) => {
    const rad = pitch * Math.PI / 180;
    const length = isLeg ? bone.legLen : bone.armLen;
    const thick = isLeg ? bone.legThick : bone.armThick;
    const joint = [side * (isLeg ? bone.hipX : bone.shoulderX),
                   isLeg ? bone.hipY : bone.shoulderY, 0];

    const centre = [joint[0],
                    joint[1] - Math.cos(rad) * length * 0.5,
                    joint[2] + Math.sin(rad) * length * 0.5];
    add(group, centre, [thick, length, thick], pitch);

    if (isLeg) {
      const foot = [joint[0],
                    joint[1] - Math.cos(rad) * length + 0.05,
                    joint[2] + Math.sin(rad) * length + 0.04];
      add(group, foot, [thick + 0.03, 0.10, thick + 0.10], pitch);
    }
    return [joint[0], joint[1] - Math.cos(rad) * length, joint[2] + Math.sin(rad) * length];
  };

  DETAIL[def.archetype]({ add, shell, accent, team, cloth, steel, push, surfaceGroup });

  const legMat = bone.legMat ? push(surfaceGroup(bone.legMat, 'agent_' + bone.legMat)) : shell;
  limb(legMat, -1, swing, true);
  limb(legMat, 1, -swing, true);
  limb(shell, -1, -swing * 0.7, false);
  const hand = limb(shell, 1, AIM_PITCH + swing * 0.15, false);

  // The weapon sits in that hand, levelled off rather than following the arm all
  // the way — which is what a shooter's grip actually does.
  buildWeapon(def.weapon, localToWorld(origin, yaw, [hand[0] * 0.5, hand[1] + 0.06, hand[2] + 0.08]),
    yaw, def.accent, groups);

  return Object.values(groups);
}

function localToWorld(origin, yaw, [x, y, z]) {
  const rad = yaw * Math.PI / 180;
  const cos = Math.cos(rad), sin = Math.sin(rad);
  return [origin[0] + x * cos + z * sin, origin[1] + y, origin[2] - x * sin + z * cos];
}

/// Everything above the hips that makes each archetype recognisable.
const DETAIL = {
  heavy: ({ add, shell, accent, team }) => {
    add(shell, [0, 1.20, 0], [0.60, 0.56, 0.36]);          // chest
    add(shell, [0, 1.44, 0.02], [0.66, 0.20, 0.40]);       // plate
    add(shell, [-0.34, 1.42, 0], [0.20, 0.24, 0.34]);      // pauldrons
    add(shell, [0.34, 1.42, 0], [0.20, 0.24, 0.34]);
    add(shell, [0, 0.90, 0], [0.44, 0.24, 0.30]);          // belt
    add(team,  [0, 1.52, 0.19], [0.34, 0.05, 0.03]);
    add(team,  [-0.34, 1.52, 0], [0.16, 0.03, 0.28]);
    add(shell, [0, 1.66, 0], [0.30, 0.30, 0.32]);          // helmet
    add(shell, [0, 1.81, -0.02], [0.32, 0.06, 0.34]);      // crest
    add(accent, [0, 1.66, 0.17], [0.24, 0.08, 0.04]);      // visor
  },

  scout: ({ add, shell, accent, team, cloth }) => {
    add(shell, [0, 1.14, 0], [0.46, 0.54, 0.28]);
    add(shell, [0, 1.32, -0.02], [0.50, 0.16, 0.30]);
    add(shell, [0, 0.70, -0.10], [0.44, 0.46, 0.08]);      // coat tail
    add(shell, [0.16, 0.98, 0.15], [0.12, 0.20, 0.06]);    // chest pouch
    add(team,  [0, 0.93, 0.145], [0.30, 0.03, 0.02]);
    add(team,  [-0.24, 1.32, 0], [0.03, 0.10, 0.24]);
    add(cloth, [0, 1.56, 0], [0.24, 0.28, 0.26]);          // masked head
    add(cloth, [0, 1.66, -0.10], [0.32, 0.26, 0.20]);      // hood
    add(cloth, [0, 1.75, 0.02], [0.30, 0.10, 0.30]);
    add(accent, [0, 1.56, 0.14], [0.18, 0.05, 0.03]);
  },

  engineer: ({ add, shell, accent, team, steel, push, surfaceGroup }) => {
    add(shell, [0, 1.16, 0], [0.56, 0.54, 0.34]);
    add(shell, [0, 0.92, 0], [0.52, 0.14, 0.36]);          // tool belt
    add(steel, [0, 1.20, -0.26], [0.44, 0.44, 0.20]);      // backpack
    add(steel, [-0.13, 1.24, -0.40], [0.14, 0.46, 0.14]);  // tanks
    add(steel, [0.13, 1.24, -0.40], [0.14, 0.46, 0.14]);
    add(steel, [0, 1.50, -0.34], [0.34, 0.06, 0.10]);
    add(team,  [0, 0.99, 0.175], [0.34, 0.04, 0.02]);

    const hardhat = push(surfaceGroup('hardhat', 'agent_hardhat'));
    add(hardhat, [0, 1.58, 0], [0.28, 0.30, 0.28]);
    add(hardhat, [0, 1.75, 0.06], [0.34, 0.05, 0.40]);     // brim
    add(accent, [0, 1.58, 0.15], [0.22, 0.11, 0.03]);      // welding visor
  },

  marksman: ({ add, shell, accent, team }) => {
    add(shell, [0, 1.26, 0], [0.46, 0.58, 0.28]);
    add(shell, [0, 0.68, -0.03], [0.50, 0.68, 0.24]);      // long coat
    add(shell, [0, 1.48, 0.04], [0.34, 0.18, 0.26]);       // collar
    add(team,  [0, 1.00, 0.145], [0.26, 0.03, 0.02]);
    add(team,  [0, 0.40, -0.04], [0.46, 0.03, 0.22]);
    add(shell, [0, 1.74, 0], [0.24, 0.28, 0.26]);          // head
    add(shell, [0, 1.90, -0.04], [0.26, 0.06, 0.30]);      // cap
    add(accent, [0.06, 1.76, 0.14], [0.09, 0.05, 0.05]);   // monocular
  },
};

/// Five silhouettes rather than five re-skins — a weapon has to be identifiable
/// in someone else's hands at thirty metres.
export function buildWeapon(id, origin, yaw, accentColor, intoGroups) {
  const groups = intoGroups || {};
  const push = (group) => (groups[group.name] = groups[group.name] || group);

  const metal = push(surfaceGroup('gunmetal', 'weapon_metal'));
  const shell = push(surfaceGroup('polymer', 'weapon_shell'));
  const accent = push(glowGroup('weapon_accent_' + accentColor.join('_'), accentColor, 3.0));

  const rad = yaw * Math.PI / 180;
  const cos = Math.cos(rad), sin = Math.sin(rad);
  const add = (group, [x, y, z], size, tilt = 0) => group.add(
    [origin[0] + x * cos + z * sin, origin[1] + y, origin[2] - x * sin + z * cos],
    size, yaw, tilt);

  switch (id) {
    case 'smg':
      add(metal, [0, 0, 0.02], [0.070, 0.110, 0.30]);
      add(metal, [0, 0.010, 0.26], [0.040, 0.040, 0.20]);
      add(shell, [0, -0.12, -0.01], [0.052, 0.24, 0.075]);
      add(shell, [0, -0.07, -0.13], [0.050, 0.14, 0.085]);
      add(shell, [0, 0.065, -0.14], [0.045, 0.030, 0.22]);
      add(accent, [0, 0.070, 0.10], [0.018, 0.014, 0.040]);
      add(accent, [0.037, -0.02, 0.02], [0.004, 0.045, 0.12]);
      break;
    case 'sniper':
      add(metal, [0, 0, 0.08], [0.070, 0.120, 0.52]);
      add(metal, [0, 0.010, 0.60], [0.040, 0.040, 0.66]);
      add(metal, [0, 0.010, 0.92], [0.055, 0.055, 0.12]);
      add(metal, [0, 0.105, 0.22], [0.058, 0.075, 0.30]);
      add(shell, [0, -0.08, 0.00], [0.055, 0.16, 0.10]);
      add(shell, [0, -0.07, -0.18], [0.052, 0.14, 0.09]);
      add(shell, [0, -0.005, -0.36], [0.070, 0.125, 0.32]);
      add(shell, [-0.05, -0.10, 0.52], [0.016, 0.20, 0.016], 12);
      add(shell, [0.05, -0.10, 0.52], [0.016, 0.20, 0.016], -12);
      add(accent, [0, 0.105, 0.375], [0.038, 0.038, 0.012]);
      add(accent, [0.036, 0, 0.14], [0.004, 0.024, 0.26]);
      break;
    case 'shotgun':
      add(metal, [0, 0, 0.04], [0.085, 0.125, 0.36]);
      add(metal, [0, 0.020, 0.38], [0.070, 0.070, 0.44]);
      add(metal, [0, -0.045, 0.38], [0.060, 0.055, 0.42]);
      add(shell, [0, -0.048, 0.30], [0.080, 0.075, 0.16]);
      add(shell, [0, -0.08, -0.14], [0.055, 0.15, 0.09]);
      add(shell, [0, -0.02, -0.32], [0.080, 0.145, 0.28]);
      add(accent, [0, 0.070, 0.14], [0.022, 0.014, 0.05]);
      add(accent, [0.044, 0, 0.06], [0.004, 0.030, 0.16]);
      break;
    case 'pistol':
      add(metal, [0, 0.02, 0.02], [0.055, 0.095, 0.22]);
      add(metal, [0, 0.015, 0.14], [0.030, 0.030, 0.06]);
      add(shell, [0, -0.10, -0.04], [0.048, 0.17, 0.075], 8);
      add(accent, [0, 0.062, 0.06], [0.014, 0.012, 0.03]);
      add(accent, [0.029, 0.02, 0.02], [0.003, 0.020, 0.12]);
      break;
    default:
      add(metal, [0, 0, 0.06], [0.075, 0.115, 0.44]);
      add(metal, [0, 0.012, 0.44], [0.045, 0.045, 0.40]);
      add(metal, [0, 0.030, 0.30], [0.055, 0.030, 0.16]);
      add(shell, [0, -0.10, -0.02], [0.060, 0.20, 0.10]);
      add(shell, [0, -0.08, -0.16], [0.055, 0.15, 0.09]);
      add(shell, [0, 0.005, -0.30], [0.065, 0.105, 0.26]);
      add(shell, [0, 0.070, 0.10], [0.050, 0.022, 0.30]);
      add(accent, [0, 0.088, 0.20], [0.020, 0.016, 0.045]);
      add(accent, [0.039, 0, 0.10], [0.004, 0.020, 0.20]);
      break;
  }
  return Object.values(groups);
}
