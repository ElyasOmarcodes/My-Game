// Minimal WebGL layer: one shader, one buffer per material, nothing else.
//
// This runs in two places — headless Chromium (to render the review screenshots)
// and an Android WebView (the installable preview APK) — so it targets WebGL 1
// and keeps every feature inside the ES 2.0 baseline that every phone supports.

export const VERT = `
attribute vec3 aPos;
attribute vec3 aNormal;
uniform mat4 uViewProj;
uniform mat4 uModel;
varying vec3 vNormal;
varying vec3 vWorld;
void main() {
  // Static geometry passes identity; characters pass their bone matrix. Model
  // matrices here are rotation plus translation only, so the upper 3x3 is a
  // valid normal matrix without inverting anything.
  vec4 world = uModel * vec4(aPos, 1.0);
  vNormal = mat3(uModel) * aNormal;
  vWorld = world.xyz;
  gl_Position = uViewProj * world;
}`;

export const FRAG = `
precision mediump float;
varying vec3 vNormal;
varying vec3 vWorld;

uniform vec3 uColor;
uniform vec3 uEmissive;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uSkyColor;
uniform vec3 uGroundColor;
uniform vec3 uFogColor;
uniform vec3 uCamPos;
uniform float uFogDensity;
uniform float uSpecular;

void main() {
  vec3 n = normalize(vNormal);

  // Hemisphere ambient: sky above, bounce below. Cheap stand-in for GI and the
  // main reason flat-shaded boxes still read as a lit scene.
  float hemi = n.y * 0.5 + 0.5;
  vec3 ambient = mix(uGroundColor, uSkyColor, hemi);

  float ndl = max(dot(n, uSunDir), 0.0);
  vec3 diffuse = uSunColor * ndl;

  vec3 viewDir = normalize(uCamPos - vWorld);
  vec3 halfDir = normalize(uSunDir + viewDir);
  float spec = pow(max(dot(n, halfDir), 0.0), 48.0) * uSpecular;

  // Contact darkening: surfaces close to the street lose ambient, which fakes
  // the occlusion you would otherwise need a whole pass to get.
  float ao = clamp(vWorld.y * 0.14 + 0.32, 0.0, 1.0);

  vec3 color = uColor * (ambient * ao + diffuse) + uSunColor * spec + uEmissive;

  float dist = length(uCamPos - vWorld);
  float fog = 1.0 - exp(-pow(dist * uFogDensity, 2.0));
  color = mix(color, uFogColor, clamp(fog, 0.0, 1.0));

  gl_FragColor = vec4(color, 1.0);
}`;

export function createProgram(gl) {
  const compile = (type, src) => {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS))
      throw new Error(gl.getShaderInfoLog(shader));
    return shader;
  };

  const program = gl.createProgram();
  gl.attachShader(program, compile(gl.VERTEX_SHADER, VERT));
  gl.attachShader(program, compile(gl.FRAGMENT_SHADER, FRAG));
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS))
    throw new Error(gl.getProgramInfoLog(program));

  const uniforms = {};
  for (const name of ['uViewProj', 'uModel', 'uColor', 'uEmissive', 'uSunDir', 'uSunColor',
    'uSkyColor', 'uGroundColor', 'uFogColor', 'uCamPos', 'uFogDensity', 'uSpecular'])
    uniforms[name] = gl.getUniformLocation(program, name);

  return {
    program,
    uniforms,
    aPos: gl.getAttribLocation(program, 'aPos'),
    aNormal: gl.getAttribLocation(program, 'aNormal'),
  };
}

// --- 4x4 matrices (column-major, same layout WebGL expects) -----------------

export const mat4 = {
  perspective(fovyDeg, aspect, near, far) {
    const f = 1 / Math.tan(fovyDeg * Math.PI / 360);
    const nf = 1 / (near - far);
    return new Float32Array([
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far + near) * nf, -1,
      0, 0, 2 * far * near * nf, 0,
    ]);
  },

  lookAt(eye, target, up = [0, 1, 0]) {
    const z = norm(sub(eye, target));
    const x = norm(cross(up, z));
    const y = cross(z, x);
    return new Float32Array([
      x[0], y[0], z[0], 0,
      x[1], y[1], z[1], 0,
      x[2], y[2], z[2], 0,
      -dot(x, eye), -dot(y, eye), -dot(z, eye), 1,
    ]);
  },

  identity() {
    return new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
  },

  /// Translate, then yaw, then pitch — the order a limb joint needs.
  compose(position, yawDeg, pitchDeg = 0) {
    const ry = yawDeg * Math.PI / 180, rx = pitchDeg * Math.PI / 180;
    const cy = Math.cos(ry), sy = Math.sin(ry);
    const cx = Math.cos(rx), sx = Math.sin(rx);
    // R = Ry * Rx
    return new Float32Array([
      cy, 0, -sy, 0,
      sy * sx, cx, cy * sx, 0,
      sy * cx, -sx, cy * cx, 0,
      position[0], position[1], position[2], 1,
    ]);
  },

  multiply(a, b) {
    const out = new Float32Array(16);
    for (let c = 0; c < 4; c++)
      for (let r = 0; r < 4; r++) {
        let sum = 0;
        for (let k = 0; k < 4; k++) sum += a[k * 4 + r] * b[c * 4 + k];
        out[c * 4 + r] = sum;
      }
    return out;
  },
};

export const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
export const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
export const scale = (a, s) => [a[0] * s, a[1] * s, a[2] * s];
export const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
export const cross = (a, b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
export const norm = (a) => {
  const len = Math.hypot(a[0], a[1], a[2]) || 1;
  return [a[0] / len, a[1] / len, a[2] / len];
};

export const hex = (value) => [
  parseInt(value.slice(1, 3), 16) / 255,
  parseInt(value.slice(3, 5), 16) / 255,
  parseInt(value.slice(5, 7), 16) / 255,
];

/// Deterministic RNG so one seed always produces the same city.
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
