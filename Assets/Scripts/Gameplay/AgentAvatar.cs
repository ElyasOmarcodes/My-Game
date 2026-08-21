using BattleOfAgents.Core;
using BattleOfAgents.Gameplay.Models;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>An agent's physical presence: the body model, its weapon, the walk
    /// cycle and the name plate. Wraps <see cref="CharacterRig"/> so callers never
    /// have to know how the model is put together.</summary>
    public class AgentAvatar : MonoBehaviour
    {
        public Transform MuzzlePoint { get; private set; }
        public Transform Head { get { return _rig != null ? _rig.Head : transform; } }
        public CharacterRig Rig { get { return _rig; } }
        public CharacterAnimator Animator { get; private set; }
        public WeaponDef Weapon { get; private set; }

        CharacterRig _rig;
        Material _accent;
        Color _accentColor;

        public static AgentAvatar Create(Transform parent, AgentDef def, Team team, string label,
            string weaponId = null)
        {
            var root = new GameObject("Avatar_" + def.Id);
            root.transform.SetParent(parent, false);

            var avatar = root.AddComponent<AgentAvatar>();
            avatar.Assemble(def, team, label, weaponId ?? WeaponModelLibrary.DefaultFor(def.Id));
            return avatar;
        }

        void Assemble(AgentDef def, Team team, string label, string weaponId)
        {
            _accentColor = def.Accent;
            var teamColor = team == Team.Bravo ? UI.Theme.TeamBravo : UI.Theme.TeamAlpha;

            _rig = AgentModelLibrary.Build(transform, AgentModelLibrary.ArchetypeFor(def.Id),
                _accentColor, teamColor);
            _accent = _rig.AccentMaterial;

            Weapon = WeaponModelLibrary.Get(weaponId);
            MuzzlePoint = WeaponModelLibrary.Build(_rig.WeaponMount, Weapon.Id, _accentColor);

            Animator = gameObject.AddComponent<CharacterAnimator>();
            Animator.Bind(_rig);

            NameTag.Attach(transform, label, teamColor, _rig.Height + 0.35f);
        }

        public void SetAimPitch(float degrees)
        {
            if (Animator != null) Animator.SetAimPitch(degrees);
        }

        public void PlayRecoil(float degrees)
        {
            if (Animator != null) Animator.Kick(degrees);
        }

        /// <summary>Blow out the accent trim for a couple of frames on a hit — the
        /// cheapest possible hit confirmation, and it reads even at distance.</summary>
        public void FlashHit()
        {
            CancelInvoke("ClearFlash");
            SetEmission(9f);
            Invoke("ClearFlash", 0.09f);
        }

        void ClearFlash() { SetEmission(2.8f); }

        void SetEmission(float intensity)
        {
            if (_accent == null || !_accent.HasProperty("_EmissionColor")) return;
            _accent.SetColor("_EmissionColor", _accentColor * intensity);
        }

        public void SetVisible(bool visible)
        {
            if (_rig != null) _rig.SetVisible(visible);
        }
    }
}
