using UnityEngine;

namespace BattleOfAgents.Gameplay.Models
{
    /// <summary>A procedural walk cycle driven by how fast the body is actually moving.
    ///
    /// There is no animation clip in the project: legs and arms swing on a sine wave
    /// whose phase advances with distance travelled, so the feet never skate no matter
    /// what speed the agent runs at, and a remote agent moving under interpolation
    /// animates from the same signal.</summary>
    public class CharacterAnimator : MonoBehaviour
    {
        public float StrideLength = 1.9f;
        public float SwingDegrees = 42f;
        public float BobHeight = 0.055f;

        CharacterRig _rig;
        Vector3 _lastPosition;
        float _phase;
        float _speed;
        float _aimPitch;
        Vector3 _hipsRest;

        public void Bind(CharacterRig rig)
        {
            _rig = rig;
            _lastPosition = transform.position;
            if (_rig != null && _rig.Hips != null) _hipsRest = _rig.Hips.localPosition;
        }

        /// <summary>Torso pitch, so a marksman looking up actually leans back.</summary>
        public void SetAimPitch(float degrees) { _aimPitch = Mathf.Clamp(degrees, -35f, 45f); }

        void LateUpdate()
        {
            if (_rig == null || _rig.Hips == null) return;

            var delta = transform.position - _lastPosition;
            delta.y = 0f;
            _lastPosition = transform.position;

            var instantSpeed = Time.deltaTime > 0f ? delta.magnitude / Time.deltaTime : 0f;
            _speed = Mathf.Lerp(_speed, instantSpeed, 1f - Mathf.Exp(-12f * Time.deltaTime));

            // Phase advances with distance, not time: the stride stays locked to the ground.
            _phase += delta.magnitude / StrideLength * Mathf.PI * 2f;

            var moving = _speed > 0.35f;
            var blend = Mathf.Clamp01(_speed / 6f);
            var swing = Mathf.Sin(_phase) * SwingDegrees * blend;

            if (!moving)
            {
                // idle: settle the limbs and add a slow breathing bob
                swing = 0f;
                _phase = 0f;
                var breath = Mathf.Sin(Time.time * 1.6f) * 0.012f;
                _rig.Hips.localPosition = _hipsRest + new Vector3(0f, breath, 0f);
            }
            else
            {
                var bob = Mathf.Abs(Mathf.Sin(_phase)) * BobHeight * blend;
                _rig.Hips.localPosition = _hipsRest + new Vector3(0f, bob, 0f);
            }

            _rig.LegLeft.localRotation = Quaternion.Euler(swing, 0f, 0f);
            _rig.LegRight.localRotation = Quaternion.Euler(-swing, 0f, 0f);

            // The weapon arm stays forward on aim; the free arm counter-swings.
            _rig.ArmLeft.localRotation = Quaternion.Euler(-swing * 0.7f, 0f, 0f);
            _rig.ArmRight.localRotation = Quaternion.Euler(-72f + swing * 0.15f, 0f, 0f);

            _rig.Torso.localRotation = Quaternion.Euler(
                Mathf.LerpAngle(_rig.Torso.localEulerAngles.x, -_aimPitch * 0.35f, 0.25f), 0f,
                Mathf.Sin(_phase) * 2.2f * blend);
        }

        /// <summary>Recoil kick on the weapon arm, called by the weapon on each shot.</summary>
        public void Kick(float degrees)
        {
            if (_rig == null || _rig.ArmRight == null) return;
            _rig.ArmRight.localRotation *= Quaternion.Euler(-degrees, 0f, 0f);
        }
    }
}
