using BattleOfAgents.Core;
using BattleOfAgents.Gameplay.Models;
using BattleOfAgents.Net;
using BattleOfAgents.Visual;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>Hit-scan weapon: fire rate, spread, ammo and reload all come from the
    /// <see cref="WeaponDef"/> the agent carries, so the model in their hands and the
    /// way it shoots can never drift apart.
    ///
    /// Shots are resolved locally for instant feedback and simultaneously reported to
    /// the host, which is the only place a hit actually counts. That is the standard
    /// compromise for a LAN shooter: the shooter never waits for a round trip, and the
    /// host still has the last word on damage.</summary>
    public class WeaponSystem : MonoBehaviour
    {
        AgentDef _agent;
        WeaponDef _weapon;
        Transform _muzzle;
        PlayerController _owner;

        float _nextShotAt;
        float _reloadUntil;
        LineRenderer _tracer;
        float _tracerFadeUntil;
        Light _muzzleFlash;

        const float TracerLifetime = 0.05f;

        public WeaponDef Weapon { get { return _weapon; } }

        public void Configure(AgentDef agent, WeaponDef weapon, Transform muzzle, PlayerController owner)
        {
            _agent = agent;
            _weapon = weapon;
            _muzzle = muzzle;
            _owner = owner;
            BuildTracer();
            LoadMagazine();
        }

        /// <summary>Seeds the match's ammo counters from this weapon, so a DMR starts
        /// with six rounds and an SMG with thirty-five.</summary>
        void LoadMagazine()
        {
            var match = MatchState.Instance;
            if (match == null) return;

            match.ClipSize = _weapon.ClipSize;
            match.AmmoInClip = _weapon.ClipSize;
            match.AmmoReserve = _weapon.Reserve;
        }

        void BuildTracer()
        {
            var go = new GameObject("Tracer");
            go.transform.SetParent(transform, false);

            _tracer = go.AddComponent<LineRenderer>();
            _tracer.useWorldSpace = true;
            _tracer.positionCount = 2;
            _tracer.startWidth = 0.045f;
            _tracer.endWidth = 0.012f;
            _tracer.numCapVertices = 2;
            _tracer.enabled = false;

            var shader = Shader.Find("Universal Render Pipeline/Unlit") ?? Shader.Find("Sprites/Default");
            var mat = new Material(shader);
            mat.color = _agent.Accent;
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", _agent.Accent * 4f);
            _tracer.material = mat;

            var flashGo = new GameObject("MuzzleFlash");
            flashGo.transform.SetParent(_muzzle, false);
            _muzzleFlash = flashGo.AddComponent<Light>();
            _muzzleFlash.type = LightType.Point;
            _muzzleFlash.color = _agent.Accent;
            _muzzleFlash.range = 6f;
            _muzzleFlash.intensity = 0f;
        }

        public bool IsReloading { get { return Time.time < _reloadUntil; } }

        public void PullTrigger()
        {
            var match = MatchState.Instance;
            if (match == null || IsReloading || Time.time < _nextShotAt) return;

            if (match.AmmoInClip <= 0)
            {
                Reload();
                return;
            }

            _nextShotAt = Time.time + 1f / Mathf.Max(0.1f, _weapon.FireRate);
            match.AmmoInClip--;
            Fire();
        }

        void Fire()
        {
            var camera = CinematicRig.Instance.MainCamera;
            var origin = camera.transform.position;
            // Steady Aim removes spread entirely; that is the whole point of it.
            var spread = _owner.IsAbilityActive && _agent.Id == "reaper" ? 0f : _weapon.Spread;
            var direction = camera.transform.forward +
                            camera.transform.right * Random.Range(-spread, spread) +
                            camera.transform.up * Random.Range(-spread, spread);

            var endPoint = origin + direction.normalized * _weapon.Range;

            RaycastHit hit;
            if (Physics.Raycast(origin, direction.normalized, out hit, _weapon.Range))
            {
                endPoint = hit.point;
                ReportHit(hit);
            }

            ShowTracer(_muzzle != null ? _muzzle.position : origin, endPoint);
            CinematicRig.Instance.Shake(0.04f * _weapon.RecoilKick);
            if (_owner.Avatar != null) _owner.Avatar.PlayRecoil(_weapon.RecoilKick * 2.4f);
        }

        void ReportHit(RaycastHit hit)
        {
            var target = hit.collider.GetComponentInParent<RemoteAgent>();
            if (target == null) return;

            target.PlayHitFeedback();

            // The host decides whether this actually lands.
            GameSync.Instance.ReportHit(target.PlayerId, _weapon.Damage, hit.point);
        }

        void ShowTracer(Vector3 from, Vector3 to)
        {
            _tracer.SetPosition(0, from);
            _tracer.SetPosition(1, to);
            _tracer.enabled = true;
            _tracerFadeUntil = Time.time + TracerLifetime;
            _muzzleFlash.intensity = 4.5f;
        }

        public void Reload()
        {
            var match = MatchState.Instance;
            if (match.AmmoReserve <= 0 || match.AmmoInClip == match.ClipSize) return;

            _reloadUntil = Time.time + _weapon.ReloadSeconds;
            Invoke("FinishReload", _weapon.ReloadSeconds);
        }

        void FinishReload()
        {
            var match = MatchState.Instance;
            var needed = match.ClipSize - match.AmmoInClip;
            var taken = Mathf.Min(needed, match.AmmoReserve);
            match.AmmoInClip += taken;
            match.AmmoReserve -= taken;
        }

        void Update()
        {
            if (_tracer.enabled && Time.time >= _tracerFadeUntil) _tracer.enabled = false;
            if (_muzzleFlash.intensity > 0f)
                _muzzleFlash.intensity = Mathf.Max(0f, _muzzleFlash.intensity - Time.deltaTime * 45f);
        }
    }
}
