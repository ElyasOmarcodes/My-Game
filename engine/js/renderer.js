// Scene renderer with a small post chain: bloom, ACES tonemap, vignette, grain.
//
// This is the same look the Unity side gets from URP's volume stack, rebuilt on
// WebGL 1 so it runs in a WebView and in headless Chromium. The post pass is what
// turns flat-shaded boxes into something that reads as a lit city at dusk.
import { createProgram, mat4, hex, sub, norm } from './gl.js';
import { ENVIRONMENT } from './palette.js';

const QUAD_VERT = `
attribute vec2 aPos;
varying vec2 vUv;
void main() { vUv = aPos * 0.5 + 0.5; gl_Position = vec4(aPos, 0.0, 1.0); }`;

const BRIGHT_FRAG = `
precision mediump float;
varying vec2 vUv;
uniform sampler2D uScene;
uniform float uThreshold;
void main() {
  vec3 c = texture2D(uScene, vUv).rgb;
  float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
  float keep = max(luma - uThreshold, 0.0) / max(luma, 0.0001);
  gl_FragColor = vec4(c * keep, 1.0);
}`;

const BLUR_FRAG = `
precision mediump float;
varying vec2 vUv;
uniform sampler2D uSource;
uniform vec2 uDirection;
void main() {
  // 9-tap gaussian, separable — two passes cost what one 2D kernel would.
  vec3 sum = texture2D(uSource, vUv).rgb * 0.227;
  sum += (texture2D(uSource, vUv + uDirection * 1.385).rgb
        + texture2D(uSource, vUv - uDirection * 1.385).rgb) * 0.316;
  sum += (texture2D(uSource, vUv + uDirection * 3.231).rgb
        + texture2D(uSource, vUv - uDirection * 3.231).rgb) * 0.070;
  gl_FragColor = vec4(sum, 1.0);
}`;

const COMPOSITE_FRAG = `
precision mediump float;
varying vec2 vUv;
uniform sampler2D uScene;
uniform sampler2D uBloom;
uniform float uBloomIntensity;
uniform float uVignette;
uniform float uGrain;
uniform float uTime;

// ACES filmic curve: the highlight roll-off that stops neon clipping to white.
vec3 aces(vec3 x) {
  return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

float noise(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233)) + uTime) * 43758.5453);
}

void main() {
  vec3 scene = texture2D(uScene, vUv).rgb;
  vec3 bloom = texture2D(uBloom, vUv).rgb;
  vec3 color = scene + bloom * uBloomIntensity;

  color *= 1.05;                       // post exposure
  color = aces(color);
  color = mix(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), color, 1.06);  // saturation

  // cool shadows / warm highlights, the split-toning from the Unity stack
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color += mix(vec3(-0.012, 0.004, 0.030), vec3(0.028, 0.010, -0.020), luma);

  vec2 centred = vUv - 0.5;
  float vig = 1.0 - dot(centred, centred) * uVignette;
  color *= clamp(vig, 0.0, 1.0);

  color += (noise(vUv * 900.0) - 0.5) * uGrain;

  gl_FragColor = vec4(pow(max(color, 0.0), vec3(1.0 / 2.2)), 1.0);
}`;

function compile(gl, vert, frag, uniformNames) {
  const shader = (type, src) => {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
    return s;
  };
  const program = gl.createProgram();
  gl.attachShader(program, shader(gl.VERTEX_SHADER, vert));
  gl.attachShader(program, shader(gl.FRAGMENT_SHADER, frag));
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));

  const uniforms = {};
  for (const name of uniformNames) uniforms[name] = gl.getUniformLocation(program, name);
  return { program, uniforms, aPos: gl.getAttribLocation(program, 'aPos') };
}

function createTarget(gl, width, height) {
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

  const framebuffer = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);

  const depth = gl.createRenderbuffer();
  gl.bindRenderbuffer(gl.RENDERBUFFER, depth);
  gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, width, height);
  gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depth);

  gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  return { texture, framebuffer, depth, width, height };
}

export class Renderer {
  constructor(canvas, options = {}) {
    const gl = canvas.getContext('webgl', {
      antialias: true, alpha: false, depth: true, powerPreference: 'high-performance',
      // Headless screenshots read the canvas back after the frame, so the buffer
      // has to survive compositing. On the phone this stays off.
      preserveDrawingBuffer: options.preserveDrawingBuffer === true,
    });
    if (!gl) throw new Error('WebGL is not available');

    this.gl = gl;
    this.canvas = canvas;
    this.env = { ...ENVIRONMENT, ...(options.environment || {}) };
    this.bloomIntensity = options.bloomIntensity ?? 1.15;
    this.postEnabled = options.post !== false;

    gl.getExtension('OES_element_index_uint');

    this.scene = createProgram(gl);
    this.bright = compile(gl, QUAD_VERT, BRIGHT_FRAG, ['uScene', 'uThreshold']);
    this.blur = compile(gl, QUAD_VERT, BLUR_FRAG, ['uSource', 'uDirection']);
    this.composite = compile(gl, QUAD_VERT, COMPOSITE_FRAG,
      ['uScene', 'uBloom', 'uBloomIntensity', 'uVignette', 'uGrain', 'uTime']);

    this.quad = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quad);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);

    this.resize();
  }

  resize() {
    const { gl, canvas } = this;
    const width = canvas.width, height = canvas.height;
    if (this.sceneTarget && this.sceneTarget.width === width && this.sceneTarget.height === height)
      return;

    this.sceneTarget = createTarget(gl, width, height);
    const bw = Math.max(1, width >> 2), bh = Math.max(1, height >> 2);
    this.bloomA = createTarget(gl, bw, bh);
    this.bloomB = createTarget(gl, bw, bh);
  }

  /// Uploads every material group once; call after generating geometry.
  upload(groups) {
    for (const group of groups) if (!group.gpu) group.upload(this.gl);
  }

  drawQuad(pass) {
    const { gl } = this;
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quad);
    gl.enableVertexAttribArray(pass.aPos);
    gl.vertexAttribPointer(pass.aPos, 2, gl.FLOAT, false, 0, 0);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  render(groups, camera) {
    const { gl } = this;
    this.resize();

    const aspect = this.canvas.width / this.canvas.height;
    const projection = mat4.perspective(camera.fov || 62, aspect, 0.1, 1400);
    const view = mat4.lookAt(camera.position, camera.target, [0, 1, 0]);
    const viewProj = mat4.multiply(projection, view);
    const sun = norm(this.env.sunDir);

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.postEnabled ? this.sceneTarget.framebuffer : null);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    gl.clearColor(...this.env.clear, 1);
    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    const p = this.scene;
    gl.useProgram(p.program);
    gl.uniformMatrix4fv(p.uniforms.uViewProj, false, viewProj);
    gl.uniform3fv(p.uniforms.uSunDir, sun);
    gl.uniform3fv(p.uniforms.uSunColor, this.env.sunColor);
    gl.uniform3fv(p.uniforms.uSkyColor, this.env.skyColor);
    gl.uniform3fv(p.uniforms.uGroundColor, this.env.groundColor);
    gl.uniform3fv(p.uniforms.uFogColor, this.env.fogColor);
    gl.uniform3fv(p.uniforms.uCamPos, camera.position);
    gl.uniform1f(p.uniforms.uFogDensity, this.env.fogDensity);

    let drawCalls = 0;
    for (const group of groups) {
      if (!group.gpu) continue;
      gl.uniform3fv(p.uniforms.uColor, group.color);
      gl.uniform3fv(p.uniforms.uEmissive, group.emissive);
      gl.uniform1f(p.uniforms.uSpecular, group.specular);

      gl.bindBuffer(gl.ARRAY_BUFFER, group.gpu.vbo);
      gl.enableVertexAttribArray(p.aPos);
      gl.vertexAttribPointer(p.aPos, 3, gl.FLOAT, false, 24, 0);
      gl.enableVertexAttribArray(p.aNormal);
      gl.vertexAttribPointer(p.aNormal, 3, gl.FLOAT, false, 24, 12);

      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, group.gpu.ibo);
      gl.drawElements(gl.TRIANGLES, group.gpu.indexCount, group.gpu.indexType, 0);
      drawCalls++;
    }
    this.drawCalls = drawCalls;

    if (this.postEnabled) this.post();
  }

  post() {
    const { gl } = this;
    gl.disable(gl.DEPTH_TEST);
    gl.disable(gl.CULL_FACE);

    // bright pass into the quarter-res target
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomA.framebuffer);
    gl.viewport(0, 0, this.bloomA.width, this.bloomA.height);
    gl.useProgram(this.bright.program);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.sceneTarget.texture);
    gl.uniform1i(this.bright.uniforms.uScene, 0);
    gl.uniform1f(this.bright.uniforms.uThreshold, 0.62);
    this.drawQuad(this.bright);

    // two separable blur passes
    const blurPass = (from, to, direction) => {
      gl.bindFramebuffer(gl.FRAMEBUFFER, to.framebuffer);
      gl.viewport(0, 0, to.width, to.height);
      gl.useProgram(this.blur.program);
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, from.texture);
      gl.uniform1i(this.blur.uniforms.uSource, 0);
      gl.uniform2fv(this.blur.uniforms.uDirection, direction);
      this.drawQuad(this.blur);
    };
    blurPass(this.bloomA, this.bloomB, [1 / this.bloomA.width, 0]);
    blurPass(this.bloomB, this.bloomA, [0, 1 / this.bloomA.height]);

    // composite to the screen
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    gl.useProgram(this.composite.program);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.sceneTarget.texture);
    gl.uniform1i(this.composite.uniforms.uScene, 0);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.bloomA.texture);
    gl.uniform1i(this.composite.uniforms.uBloom, 1);
    gl.uniform1f(this.composite.uniforms.uBloomIntensity, this.bloomIntensity);
    gl.uniform1f(this.composite.uniforms.uVignette, 0.85);
    gl.uniform1f(this.composite.uniforms.uGrain, 0.030);
    gl.uniform1f(this.composite.uniforms.uTime, performance.now() * 0.001);
    this.drawQuad(this.composite);
  }
}
