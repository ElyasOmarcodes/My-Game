// Twin-stick touch input with a keyboard/mouse fallback for desktop testing.
// Mirrors Assets/Scripts/Gameplay/TouchInput.cs: left half of the screen is a
// floating move stick, right half looks, and the buttons sit on top.

export class Input {
  constructor(element) {
    this.move = [0, 0];
    this.look = [0, 0];
    this.firing = false;
    this.jumpPressed = false;
    this.sprint = false;

    this.stick = { active: false, origin: [0, 0], handle: [0, 0], radius: 110 };
    this.buttons = {};          // name -> {x, y, r}
    this._pressed = new Set();

    this._moveTouch = null;
    this._lookTouch = null;
    this._keys = new Set();

    const opts = { passive: false };
    element.addEventListener('touchstart', (e) => this.onTouchStart(e), opts);
    element.addEventListener('touchmove', (e) => this.onTouchMove(e), opts);
    element.addEventListener('touchend', (e) => this.onTouchEnd(e), opts);
    element.addEventListener('touchcancel', (e) => this.onTouchEnd(e), opts);

    window.addEventListener('keydown', (e) => {
      this._keys.add(e.code);
      if (e.code === 'Space') this.jumpPressed = true;
    });
    window.addEventListener('keyup', (e) => this._keys.delete(e.code));

    element.addEventListener('mousedown', () => { this.firing = true; });
    window.addEventListener('mouseup', () => { this.firing = false; });
    element.addEventListener('mousemove', (e) => {
      if (document.pointerLockElement === element) {
        this.look[0] += e.movementX; this.look[1] += e.movementY;
      }
    });
    element.addEventListener('click', () => {
      if (element.requestPointerLock) element.requestPointerLock();
    });
  }

  /// The HUD registers where it drew the buttons, so what is tapped is exactly
  /// what is seen — no second set of coordinates to drift out of sync.
  registerButton(name, x, y, radius) { this.buttons[name] = { x, y, r: radius }; }

  buttonAt(x, y) {
    for (const [name, b] of Object.entries(this.buttons))
      if ((x - b.x) ** 2 + (y - b.y) ** 2 <= b.r * b.r) return name;
    return null;
  }

  onTouchStart(event) {
    event.preventDefault();
    for (const touch of event.changedTouches) {
      const button = this.buttonAt(touch.clientX, touch.clientY);
      if (button) {
        this._pressed.add(touch.identifier);
        if (button === 'fire') this.firing = true;
        if (button === 'jump') this.jumpPressed = true;
        if (button === 'sprint') this.sprint = !this.sprint;
        this[`_btn_${touch.identifier}`] = button;
        continue;
      }

      if (touch.clientX < window.innerWidth * 0.5 && this._moveTouch === null) {
        this._moveTouch = touch.identifier;
        this.stick.active = true;
        this.stick.origin = [touch.clientX, touch.clientY];
        this.stick.handle = [touch.clientX, touch.clientY];
      } else if (this._lookTouch === null) {
        this._lookTouch = touch.identifier;
        this[`_last_${touch.identifier}`] = [touch.clientX, touch.clientY];
      }
    }
  }

  onTouchMove(event) {
    event.preventDefault();
    for (const touch of event.changedTouches) {
      if (touch.identifier === this._moveTouch) {
        let dx = touch.clientX - this.stick.origin[0];
        let dy = touch.clientY - this.stick.origin[1];
        const len = Math.hypot(dx, dy);
        if (len > this.stick.radius) {
          dx = dx / len * this.stick.radius;
          dy = dy / len * this.stick.radius;
        }
        this.stick.handle = [this.stick.origin[0] + dx, this.stick.origin[1] + dy];
        this.move = [dx / this.stick.radius, -dy / this.stick.radius];
      } else if (touch.identifier === this._lookTouch) {
        const last = this[`_last_${touch.identifier}`] || [touch.clientX, touch.clientY];
        this.look[0] += touch.clientX - last[0];
        this.look[1] += touch.clientY - last[1];
        this[`_last_${touch.identifier}`] = [touch.clientX, touch.clientY];
      }
    }
  }

  onTouchEnd(event) {
    event.preventDefault();
    for (const touch of event.changedTouches) {
      const button = this[`_btn_${touch.identifier}`];
      if (button) {
        if (button === 'fire') this.firing = false;
        delete this[`_btn_${touch.identifier}`];
        this._pressed.delete(touch.identifier);
        continue;
      }
      if (touch.identifier === this._moveTouch) {
        this._moveTouch = null;
        this.stick.active = false;
        this.move = [0, 0];
      } else if (touch.identifier === this._lookTouch) {
        this._lookTouch = null;
        delete this[`_last_${touch.identifier}`];
      }
    }
  }

  /// Call once per frame, after reading. Returns the look delta and clears it.
  consumeLook() {
    const look = this.look;
    this.look = [0, 0];
    return look;
  }

  consumeJump() {
    const jump = this.jumpPressed || this._keys.has('Space');
    this.jumpPressed = false;
    return jump;
  }

  keyboardMove() {
    const x = (this._keys.has('KeyD') ? 1 : 0) - (this._keys.has('KeyA') ? 1 : 0);
    const y = (this._keys.has('KeyW') ? 1 : 0) - (this._keys.has('KeyS') ? 1 : 0);
    return [x, y];
  }

  get moveAxis() {
    const keys = this.keyboardMove();
    return (keys[0] || keys[1]) ? keys : this.move;
  }

  get sprinting() { return this.sprint || this._keys.has('ShiftLeft'); }
}
