// The playable build: free-roam the procedural city in third person.
//
// Runs both in a desktop browser and inside the Android WebView that ships as
// the preview APK. The Wi-Fi room list comes from the Android side through
// `window.BoaLan` when it is present, and is simply hidden when it is not.
import { Renderer } from './renderer.js';
import { buildCity, roadOffset } from './city.js';
import { buildAgentRig, AGENTS, weapon as weaponDef } from './models.js';
import { BoxWorld } from './physics.js';
import { Input } from './input.js';
import { mat4, norm } from './gl.js';
import { THEME } from './palette.js';

const canvas = document.getElementById('view');
const hud = {
  health: document.getElementById('health'),
  healthBar: document.getElementById('healthBar'),
  ammo: document.getElementById('ammo'),
  weapon: document.getElementById('weaponName'),
  agent: document.getElementById('agentName'),
  fps: document.getElementById('fps'),
  rooms: document.getElementById('rooms'),
  roomList: document.getElementById('roomList'),
  stick: document.getElementById('stick'),
  stickKnob: document.getElementById('stickKnob'),
  banner: document.getElementById('banner'),
};

const state = {
  agentId: 'vanguard',
  health: 100,
  maxHealth: 120,
  ammo: 30,
  reserve: 150,
  yaw: 0,
  pitch: 6,
  position: [roadOffset(3), 1.2, -60],
  velocity: [0, 0, 0],
  grounded: false,
  stride: 0,
  nextShotAt: 0,
  reloadUntil: 0,
  recoil: 0,
  seed: 20260821,
};

const renderer = new Renderer(canvas, { bloomIntensity: 1.1 });
const input = new Input(canvas);

const city = buildCity(state.seed);
const world = new BoxWorld(city.colliders);
renderer.upload(city.groups);

// The local agent plus a handful of others standing around the district, so the
// city is not empty before anyone else joins over Wi-Fi.
const rigs = new Map();
function rigFor(agentId, team) {
  const key = agentId + ':' + team;
  if (!rigs.has(key)) {
    const rig = buildAgentRig(agentId, team === 'bravo' ? THEME.teamBravo : THEME.teamAlpha);
    for (const part of [rig.body, rig.legLeft.groups, rig.legRight.groups,
                        rig.armLeft.groups, rig.armRight.groups])
      renderer.upload(part);
    rigs.set(key, rig);
  }
  return rigs.get(key);
}

const bystanders = [
  { agentId: 'spectre', team: 'alpha', position: [roadOffset(3) + 6, 0.16, -30], yaw: 190 },
  { agentId: 'forge', team: 'alpha', position: [roadOffset(3) - 7, 0.16, -18], yaw: 20 },
  { agentId: 'reaper', team: 'bravo', position: [roadOffset(3) + 3, 0.16, 8], yaw: 176 },
  { agentId: 'havoc', team: 'bravo', position: [roadOffset(3) - 4, 0.16, 24], yaw: 150 },
];
for (const other of bystanders) rigFor(other.agentId, other.team);
const localRig = rigFor(state.agentId, 'alpha');
state.maxHealth = { vanguard: 120, spectre: 90, forge: 110, reaper: 80, medic: 100, havoc: 105 }[state.agentId];
state.health = state.maxHealth;

const HALF = [0.35, 0.9, 0.35];
const GRAVITY = -22;
const JUMP = 7.4;
const LOOK_SENSITIVITY = 0.16;

/// Draws one rigged agent: body, both legs, both arms, each with its own matrix.
function agentItems(rig, position, yaw, stride, aimPitch) {
  const swing = Math.sin(stride) * 34;
  const bob = Math.abs(Math.sin(stride)) * 0.05;
  const base = [position[0], position[1] + bob, position[2]];

  const joint = (j) => [
    base[0] + j[0] * Math.cos(yaw * Math.PI / 180) + j[2] * Math.sin(yaw * Math.PI / 180),
    base[1] + j[1],
    base[2] - j[0] * Math.sin(yaw * Math.PI / 180) + j[2] * Math.cos(yaw * Math.PI / 180),
  ];

  return [
    { groups: rig.body, matrix: mat4.compose(base, yaw) },
    { groups: rig.legLeft.groups, matrix: mat4.compose(joint(rig.legLeft.joint), yaw, swing) },
    { groups: rig.legRight.groups, matrix: mat4.compose(joint(rig.legRight.joint), yaw, -swing) },
    { groups: rig.armLeft.groups, matrix: mat4.compose(joint(rig.armLeft.joint), yaw, -swing * 0.7) },
    { groups: rig.armRight.groups,
      matrix: mat4.compose(joint(rig.armRight.joint), yaw, rig.aimPitch + aimPitch * 0.35) },
  ];
}

function fire(now) {
  const gun = weaponDef(localRig.def.weapon);
  if (now < state.reloadUntil || now < state.nextShotAt) return;
  if (state.ammo <= 0) { reload(now); return; }

  state.nextShotAt = now + 1 / gun.rate;
  state.ammo--;
  state.recoil = Math.min(3.5, state.recoil + gun.spread * 40 + 0.6);

  const eye = [state.position[0], state.position[1] + 0.7, state.position[2]];
  const dir = forward(state.yaw, state.pitch);
  const hit = world.raycast(eye, dir, gun.range);
  if (hit) spark(hit.point);
}

function reload(now) {
  const gun = weaponDef(localRig.def.weapon);
  if (state.reserve <= 0 || state.ammo === gun.clip) return;
  state.reloadUntil = now + 1.6;
  setTimeout(() => {
    const needed = gun.clip - state.ammo;
    const taken = Math.min(needed, state.reserve);
    state.ammo += taken;
    state.reserve -= taken;
  }, 1600);
}

// Impact sparks are drawn as short-lived emissive cubes: no particle system, and
// they cost one buffer that is rewritten as they expire.
const sparks = [];
function spark(point) {
  sparks.push({ point, until: performance.now() + 180 });
  if (sparks.length > 12) sparks.shift();
}

function forward(yawDeg, pitchDeg) {
  const y = yawDeg * Math.PI / 180, p = pitchDeg * Math.PI / 180;
  return norm([Math.sin(y) * Math.cos(p), -Math.sin(p), Math.cos(y) * Math.cos(p)]);
}

let last = performance.now();
let frames = 0, fpsTime = 0;

function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;

  // --- input ---------------------------------------------------------------
  const look = input.consumeLook();
  state.yaw += look[0] * LOOK_SENSITIVITY;
  state.pitch = Math.max(-40, Math.min(55, state.pitch + look[1] * LOOK_SENSITIVITY));

  const axis = input.moveAxis;
  const speed = (input.sprinting ? 9.5 : 6.2);
  const yawRad = state.yaw * Math.PI / 180;
  const right = [Math.cos(yawRad), 0, -Math.sin(yawRad)];
  const ahead = [Math.sin(yawRad), 0, Math.cos(yawRad)];

  state.velocity[0] = (right[0] * axis[0] + ahead[0] * axis[1]) * speed;
  state.velocity[2] = (right[2] * axis[0] + ahead[2] * axis[1]) * speed;

  if (input.consumeJump() && state.grounded) state.velocity[1] = JUMP;
  state.velocity[1] += GRAVITY * dt;

  const moved = world.moveBody(state.position, state.velocity, HALF, dt);
  state.position = moved.position;
  state.grounded = moved.grounded;

  const planarSpeed = Math.hypot(state.velocity[0], state.velocity[2]);
  state.stride += planarSpeed * dt * 2.6;
  state.recoil *= Math.exp(-9 * dt);

  if (input.firing) fire(now / 1000);

  // --- camera --------------------------------------------------------------
  const pivot = [state.position[0], state.position[1] + 0.85, state.position[2]];
  const back = forward(state.yaw, state.pitch);
  let distance = 5.6;
  const behind = [pivot[0] - back[0] * distance, pivot[1] - back[1] * distance + 0.65,
                  pivot[2] - back[2] * distance];

  const blocked = world.raycast(pivot, norm([behind[0] - pivot[0], behind[1] - pivot[1],
                                             behind[2] - pivot[2]]), distance);
  if (blocked) distance = Math.max(1.2, blocked.distance - 0.25);

  const camera = {
    position: [pivot[0] - back[0] * distance, pivot[1] - back[1] * distance + 0.65,
               pivot[2] - back[2] * distance],
    target: [pivot[0] + back[0] * 8, pivot[1] + back[1] * 8 - state.recoil * 0.15,
             pivot[2] + back[2] * 8],
    fov: 64 + Math.min(6, planarSpeed * 0.5),
  };

  // --- draw ----------------------------------------------------------------
  const items = [{ groups: city.groups, matrix: null }];
  items.push(...agentItems(localRig, [state.position[0], state.position[1] - HALF[1],
    state.position[2]], state.yaw, state.stride, state.pitch));

  for (const other of bystanders)
    items.push(...agentItems(rigFor(other.agentId, other.team), other.position, other.yaw, 0, 0));

  renderer.render(items, camera);

  // --- hud -----------------------------------------------------------------
  const gun = weaponDef(localRig.def.weapon);
  hud.health.textContent = Math.ceil(state.health);
  hud.healthBar.style.width = (state.health / state.maxHealth * 100).toFixed(0) + '%';
  hud.ammo.textContent = (now / 1000 < state.reloadUntil ? '· · ·' : state.ammo) + ' / ' + state.reserve;
  hud.weapon.textContent = gun.name.toUpperCase();
  hud.agent.textContent = localRig.def.name.toUpperCase();

  if (input.stick.active) {
    hud.stick.style.display = 'block';
    hud.stick.style.left = (input.stick.origin[0] - 75) + 'px';
    hud.stick.style.top = (input.stick.origin[1] - 75) + 'px';
    hud.stickKnob.style.transform =
      `translate(${input.stick.handle[0] - input.stick.origin[0]}px, ${input.stick.handle[1] - input.stick.origin[1]}px)`;
  } else {
    hud.stick.style.display = 'none';
  }

  frames++; fpsTime += dt;
  if (fpsTime >= 0.5) {
    hud.fps.textContent = Math.round(frames / fpsTime) + ' FPS · ' + renderer.drawCalls + ' draws';
    frames = 0; fpsTime = 0;
  }

  requestAnimationFrame(frame);
}

// --- HUD buttons ------------------------------------------------------------
function layoutButtons() {
  canvas.width = Math.floor(window.innerWidth * Math.min(2, window.devicePixelRatio || 1));
  canvas.height = Math.floor(window.innerHeight * Math.min(2, window.devicePixelRatio || 1));
  canvas.style.width = window.innerWidth + 'px';
  canvas.style.height = window.innerHeight + 'px';

  const w = window.innerWidth, h = window.innerHeight;
  input.registerButton('fire', w - 110, h - 110, 74);
  input.registerButton('jump', w - 236, h - 92, 46);
  input.registerButton('sprint', w - 210, h - 216, 46);

  for (const [name, pos] of Object.entries({
    fire: [w - 110, h - 110, 74], jump: [w - 236, h - 92, 46], sprint: [w - 210, h - 216, 46],
  })) {
    const el = document.getElementById('btn-' + name);
    if (!el) continue;
    el.style.left = (pos[0] - pos[2]) + 'px';
    el.style.top = (pos[1] - pos[2]) + 'px';
    el.style.width = el.style.height = (pos[2] * 2) + 'px';
  }
}
window.addEventListener('resize', layoutButtons);
layoutButtons();

// --- Wi-Fi rooms, via the Android bridge ------------------------------------
function refreshRooms() {
  const bridge = window.BoaLan;
  if (!bridge) { hud.rooms.style.display = 'none'; return; }

  try {
    const rooms = JSON.parse(bridge.rooms() || '[]');
    hud.roomList.innerHTML = rooms.length
      ? rooms.map((r) => `<li><b>${r.roomName}</b><span>${r.hostName} · ${r.players}/${r.maxPlayers}</span></li>`).join('')
      : '<li class="empty">scanning the network…</li>';
  } catch (error) {
    hud.roomList.innerHTML = '<li class="empty">' + error.message + '</li>';
  }
}

if (window.BoaLan) {
  try { window.BoaLan.startScan(); } catch (e) { /* older bridge */ }
  setInterval(refreshRooms, 1500);
  refreshRooms();

  document.getElementById('hostBtn').addEventListener('click', () => {
    const name = 'Squad ' + Math.floor(100 + Math.random() * 900);
    window.BoaLan.hostRoom(name, 'Free-roam city', 8);
    hud.banner.textContent = 'HOSTING · ' + name + ' · ' + window.BoaLan.localIp();
    hud.banner.style.display = 'block';
    setTimeout(() => { hud.banner.style.display = 'none'; }, 4000);
  });
} else {
  hud.rooms.style.display = 'none';
}

requestAnimationFrame(frame);
