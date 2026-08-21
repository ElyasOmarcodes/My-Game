// Box mesh accumulator — the JS twin of Assets/Scripts/Gameplay/World/BoxMeshBuilder.cs.
//
// Everything in this game is boxes, merged per material into one buffer, so a
// whole district or a whole character costs a single draw call.

const FACES = [
  { n: [0, 0, 1],  c: [[-.5,-.5, .5], [ .5,-.5, .5], [ .5, .5, .5], [-.5, .5, .5]] },
  { n: [0, 0, -1], c: [[ .5,-.5,-.5], [-.5,-.5,-.5], [-.5, .5,-.5], [ .5, .5,-.5]] },
  { n: [-1, 0, 0], c: [[-.5,-.5,-.5], [-.5,-.5, .5], [-.5, .5, .5], [-.5, .5,-.5]] },
  { n: [1, 0, 0],  c: [[ .5,-.5, .5], [ .5,-.5,-.5], [ .5, .5,-.5], [ .5, .5, .5]] },
  { n: [0, 1, 0],  c: [[-.5, .5, .5], [ .5, .5, .5], [ .5, .5,-.5], [-.5, .5,-.5]] },
  { n: [0, -1, 0], c: [[-.5,-.5,-.5], [ .5,-.5,-.5], [ .5,-.5, .5], [-.5,-.5, .5]] },
];

export class BoxMesh {
  constructor() {
    this.vertices = [];   // interleaved: px py pz nx ny nz
    this.indices = [];
    this.count = 0;
  }

  get isEmpty() { return this.vertices.length === 0; }

  /// center [x,y,z], size [w,h,d], yaw and pitch in degrees.
  /// Pitch is applied first (limb swing), then yaw (which way the body faces).
  add(center, size, yaw = 0, pitch = 0) {
    const ry = yaw * Math.PI / 180, rx = pitch * Math.PI / 180;
    const cy = Math.cos(ry), sy = Math.sin(ry);
    const cx = Math.cos(rx), sx = Math.sin(rx);

    const rot = ([x, y, z]) => {
      // Rx: swing forward around the joint's left-right axis
      const y1 = y * cx - z * sx;
      const z1 = y * sx + z * cx;
      // Ry: turn the whole body
      return yaw ? [x * cy + z1 * sy, y1, -x * sy + z1 * cy] : [x, y1, z1];
    };

    for (const face of FACES) {
      const base = this.vertices.length / 6;
      const [nx, ny, nz] = rot(face.n);

      for (const corner of face.c) {
        const local = rot([corner[0] * size[0], corner[1] * size[1], corner[2] * size[2]]);
        this.vertices.push(
          center[0] + local[0], center[1] + local[1], center[2] + local[2],
          nx, ny, nz);
      }
      // OpenGL/WebGL treat counter-clockwise as front-facing (Unity uses clockwise,
      // which is why the C# builder emits the opposite order).
      this.indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
    }
    this.count++;
  }

  /// Uploads to the GPU and drops the CPU arrays.
  upload(gl) {
    if (this.isEmpty) return null;

    const vbo = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(this.vertices), gl.STATIC_DRAW);

    // A city block easily exceeds 65k vertices, so use 32-bit indices when the
    // extension is there and fall back to splitting nothing — WebGL2 has it natively.
    const use32 = this.indices.length > 65535 || (this.vertices.length / 6) > 65535;
    if (use32 && !gl.getExtension('OES_element_index_uint') && !gl.RGBA8)
      console.warn('[gl] 32-bit indices unavailable — geometry may wrap');

    const ibo = gl.createBuffer();
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    const data = use32 ? new Uint32Array(this.indices) : new Uint16Array(this.indices);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, data, gl.STATIC_DRAW);

    const mesh = {
      vbo, ibo,
      indexCount: this.indices.length,
      indexType: use32 ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT,
    };
    this.vertices = [];
    this.indices = [];
    return mesh;
  }
}

/// A named bucket of boxes plus the surface response used to shade them.
export class MaterialGroup {
  constructor(name, color, options = {}) {
    this.name = name;
    this.color = color;
    this.emissive = options.emissive || [0, 0, 0];
    this.specular = options.specular ?? 0.15;
    this.mesh = new BoxMesh();
    this.gpu = null;
  }

  add(center, size, yaw = 0, pitch = 0) { this.mesh.add(center, size, yaw, pitch); return this; }
  upload(gl) { this.gpu = this.mesh.upload(gl); return this.gpu; }
}
