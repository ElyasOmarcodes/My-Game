// Axis-aligned collision and ray casts against the city's box list.
//
// The city is thousands of boxes, so both routines first cut the candidate set
// down with a cheap broad-phase over a uniform grid; testing every box every
// frame would cost more than the rest of the game put together.

export class BoxWorld {
  constructor(colliders, cellSize = 24) {
    this.boxes = colliders;
    this.cellSize = cellSize;
    this.cells = new Map();

    colliders.forEach((box, index) => {
      const x0 = Math.floor(box.min[0] / cellSize), x1 = Math.floor(box.max[0] / cellSize);
      const z0 = Math.floor(box.min[2] / cellSize), z1 = Math.floor(box.max[2] / cellSize);
      for (let x = x0; x <= x1; x++)
        for (let z = z0; z <= z1; z++) {
          const key = x + ':' + z;
          let bucket = this.cells.get(key);
          if (!bucket) this.cells.set(key, (bucket = []));
          bucket.push(index);
        }
    });
  }

  near(x, z, radius = 2) {
    const cx = Math.floor(x / this.cellSize), cz = Math.floor(z / this.cellSize);
    const span = Math.ceil(radius / this.cellSize);
    const seen = new Set();
    const out = [];
    for (let ix = cx - span; ix <= cx + span; ix++)
      for (let iz = cz - span; iz <= cz + span; iz++) {
        const bucket = this.cells.get(ix + ':' + iz);
        if (!bucket) continue;
        for (const index of bucket)
          if (!seen.has(index)) { seen.add(index); out.push(this.boxes[index]); }
      }
    return out;
  }

  /// Moves an axis-aligned body one axis at a time, which is what keeps a player
  /// sliding along a wall instead of sticking to it.
  moveBody(position, velocity, half, dt) {
    const result = { position: [...position], grounded: false };
    const axes = [0, 1, 2];

    for (const axis of axes) {
      if (!velocity[axis]) continue;
      result.position[axis] += velocity[axis] * dt;

      for (const box of this.near(result.position[0], result.position[2], 4)) {
        if (!overlaps(result.position, half, box)) continue;

        if (velocity[axis] > 0) result.position[axis] = box.min[axis] - half[axis] - 0.001;
        else result.position[axis] = box.max[axis] + half[axis] + 0.001;

        if (axis === 1) {
          if (velocity[1] < 0) result.grounded = true;
          velocity[1] = 0;
        } else {
          velocity[axis] = 0;
        }
      }
    }

    // the street itself
    if (result.position[1] - half[1] <= 0.16) {
      result.position[1] = 0.16 + half[1];
      if (velocity[1] < 0) velocity[1] = 0;
      result.grounded = true;
    }
    return result;
  }

  /// Slab-method ray cast. Returns { distance, point, box } or null.
  raycast(origin, direction, maxDistance) {
    let best = null;
    const steps = Math.ceil(maxDistance / this.cellSize);

    for (let step = 0; step <= steps; step++) {
      const t = step * this.cellSize;
      const x = origin[0] + direction[0] * t;
      const z = origin[2] + direction[2] * t;

      for (const box of this.near(x, z, this.cellSize)) {
        const hit = rayBox(origin, direction, box, maxDistance);
        if (hit !== null && (best === null || hit < best.distance))
          best = { distance: hit, box };
      }
      if (best && best.distance < t) break;   // nothing closer can appear later
    }

    if (!best) return null;
    best.point = [
      origin[0] + direction[0] * best.distance,
      origin[1] + direction[1] * best.distance,
      origin[2] + direction[2] * best.distance,
    ];
    return best;
  }
}

function overlaps(centre, half, box) {
  return centre[0] + half[0] > box.min[0] && centre[0] - half[0] < box.max[0]
      && centre[1] + half[1] > box.min[1] && centre[1] - half[1] < box.max[1]
      && centre[2] + half[2] > box.min[2] && centre[2] - half[2] < box.max[2];
}

function rayBox(origin, direction, box, maxDistance) {
  let tmin = 0, tmax = maxDistance;
  for (let axis = 0; axis < 3; axis++) {
    const d = direction[axis];
    if (Math.abs(d) < 1e-8) {
      if (origin[axis] < box.min[axis] || origin[axis] > box.max[axis]) return null;
      continue;
    }
    const inv = 1 / d;
    let t0 = (box.min[axis] - origin[axis]) * inv;
    let t1 = (box.max[axis] - origin[axis]) * inv;
    if (t0 > t1) { const swap = t0; t0 = t1; t1 = swap; }
    tmin = Math.max(tmin, t0);
    tmax = Math.min(tmax, t1);
    if (tmin > tmax) return null;
  }
  return tmin;
}
