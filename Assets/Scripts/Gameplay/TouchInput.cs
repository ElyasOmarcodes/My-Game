using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>Twin-stick touch input, split down the middle of the screen: the left
    /// half is a floating movement stick, the right half is a look/aim drag with the
    /// action buttons on top. Falls back to keyboard + mouse in the editor.</summary>
    public class TouchInput : MonoBehaviour
    {
        public static TouchInput Instance { get; private set; }

        public Vector2 Move { get; private set; }     // -1..1 on both axes
        public Vector2 Look { get; private set; }     // delta this frame, in pixels
        public bool Firing { get; private set; }
        public bool AbilityPressed { get; private set; }
        public bool JumpPressed { get; private set; }

        /// <summary>Screen-space centre of the movement stick, so the HUD can draw it
        /// where the thumb actually landed.</summary>
        public Vector2 StickOrigin { get; private set; }
        public Vector2 StickHandle { get; private set; }
        public bool StickActive { get; private set; }

        const float StickRadius = 130f;

        int _moveFinger = -1;
        int _lookFinger = -1;

        // Button hit-boxes are registered by the HUD so input and drawing cannot drift.
        Rect _fireRect, _abilityRect, _jumpRect;

        void Awake() { Instance = this; }

        public void RegisterButtons(Rect fire, Rect ability, Rect jump)
        {
            _fireRect = fire;
            _abilityRect = ability;
            _jumpRect = jump;
        }

        void Update()
        {
            AbilityPressed = false;
            JumpPressed = false;
            Look = Vector2.zero;

            if (Input.touchCount > 0) ReadTouches();
            else ReadEditorInput();
        }

        void ReadTouches()
        {
            var firingThisFrame = false;

            for (int i = 0; i < Input.touchCount; i++)
            {
                var touch = Input.GetTouch(i);
                var pos = touch.position;

                switch (touch.phase)
                {
                    case TouchPhase.Began:
                        if (_abilityRect.Contains(pos)) { AbilityPressed = true; break; }
                        if (_jumpRect.Contains(pos)) { JumpPressed = true; break; }
                        if (_fireRect.Contains(pos)) { firingThisFrame = true; break; }

                        if (pos.x < Screen.width * 0.5f && _moveFinger < 0)
                        {
                            _moveFinger = touch.fingerId;
                            StickOrigin = pos;
                            StickHandle = pos;
                            StickActive = true;
                        }
                        else if (_lookFinger < 0)
                        {
                            _lookFinger = touch.fingerId;
                        }
                        break;

                    case TouchPhase.Moved:
                    case TouchPhase.Stationary:
                        if (touch.fingerId == _moveFinger)
                        {
                            var offset = pos - StickOrigin;
                            if (offset.magnitude > StickRadius)
                                offset = offset.normalized * StickRadius;

                            StickHandle = StickOrigin + offset;
                            Move = offset / StickRadius;
                        }
                        else if (touch.fingerId == _lookFinger)
                        {
                            Look += touch.deltaPosition;
                        }
                        else if (_fireRect.Contains(pos))
                        {
                            firingThisFrame = true;
                        }
                        break;

                    case TouchPhase.Ended:
                    case TouchPhase.Canceled:
                        if (touch.fingerId == _moveFinger)
                        {
                            _moveFinger = -1;
                            Move = Vector2.zero;
                            StickActive = false;
                        }
                        else if (touch.fingerId == _lookFinger)
                        {
                            _lookFinger = -1;
                        }
                        break;
                }

                // Holding anywhere inside the fire button keeps the trigger down.
                if (touch.phase != TouchPhase.Ended && touch.phase != TouchPhase.Canceled
                    && _fireRect.Contains(pos))
                    firingThisFrame = true;
            }

            Firing = firingThisFrame;
        }

        void ReadEditorInput()
        {
            Move = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
            StickActive = false;

            Look = new Vector2(Input.GetAxis("Mouse X") * 12f, Input.GetAxis("Mouse Y") * 12f);
            Firing = Input.GetMouseButton(0);
            AbilityPressed = Input.GetKeyDown(KeyCode.Q);
            JumpPressed = Input.GetKeyDown(KeyCode.Space);
        }
    }
}
