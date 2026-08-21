using BattleOfAgents.Core;
using BattleOfAgents.Visual;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>The locally-driven agent: movement, aim, jump, ability and the
    /// third-person camera boom. Everything the player physically controls lives here;
    /// damage and scoring are decided by the host (see <see cref="GameSync"/>).</summary>
    [RequireComponent(typeof(CharacterController))]
    public class PlayerController : MonoBehaviour
    {
        public AgentDef Agent { get; private set; }
        public Team Team { get; private set; }
        public bool IsAlive { get; private set; }
        public float Yaw { get; private set; }
        public float Pitch { get; private set; }
        public AgentAvatar Avatar { get; private set; }
        public WeaponSystem Weapon { get; private set; }

        CharacterController _controller;
        Vector3 _velocity;
        float _abilityCooldown;
        float _abilityActiveUntil;
        float _respawnAt;

        const float Gravity = -22f;
        const float JumpSpeed = 7.4f;
        const float LookSensitivity = 0.14f;
        const float CameraDistance = 5.2f;
        const float CameraHeight = 2.1f;
        const float RespawnDelay = 4f;

        public static PlayerController Spawn(AgentDef agent, Team team, Transform spawnPoint, string label)
        {
            var go = new GameObject("LocalPlayer");
            go.transform.position = spawnPoint.position;

            var controller = go.AddComponent<CharacterController>();
            controller.height = 1.8f;
            controller.radius = 0.35f;
            controller.center = new Vector3(0f, 0.9f, 0f);
            controller.slopeLimit = 50f;
            controller.stepOffset = 0.45f;

            var player = go.AddComponent<PlayerController>();
            player.Initialise(agent, team, spawnPoint, label);
            return player;
        }

        void Initialise(AgentDef agent, Team team, Transform spawnPoint, string label)
        {
            Agent = agent;
            Team = team;
            IsAlive = true;
            Yaw = spawnPoint.eulerAngles.y;

            _controller = GetComponent<CharacterController>();
            Avatar = AgentAvatar.Create(transform, agent, team, label);
            Weapon = gameObject.AddComponent<WeaponSystem>();
            Weapon.Configure(agent, Avatar.MuzzlePoint, this);
        }

        void Update()
        {
            if (!IsAlive)
            {
                if (Time.time >= _respawnAt) Respawn();
                return;
            }

            var input = TouchInput.Instance;
            if (input == null) return;

            Aim(input.Look);
            Drive(input.Move);
            if (input.JumpPressed) Jump();
            if (input.AbilityPressed) UseAbility();
            if (input.Firing) Weapon.PullTrigger();

            DriveCamera();
            TickAbility();
        }

        void Aim(Vector2 lookDelta)
        {
            Yaw += lookDelta.x * LookSensitivity;
            Pitch = Mathf.Clamp(Pitch - lookDelta.y * LookSensitivity, -35f, 55f);
            transform.rotation = Quaternion.Euler(0f, Yaw, 0f);
        }

        void Drive(Vector2 move)
        {
            var speed = Agent.MoveSpeed * (IsAbilityActive && Agent.Id == "vanguard" ? 1.85f : 1f);
            var wish = transform.right * move.x + transform.forward * move.y;
            if (wish.sqrMagnitude > 1f) wish.Normalize();

            var horizontal = wish * speed;
            _velocity.x = horizontal.x;
            _velocity.z = horizontal.z;

            if (_controller.isGrounded && _velocity.y < 0f) _velocity.y = -2f;
            _velocity.y += Gravity * Time.deltaTime;

            _controller.Move(_velocity * Time.deltaTime);
        }

        void Jump()
        {
            if (!_controller.isGrounded) return;
            _velocity.y = JumpSpeed;
        }

        /// <summary>Third-person boom that pulls in when a wall is behind the player,
        /// so the camera never clips through cover.</summary>
        void DriveCamera()
        {
            var rig = CinematicRig.Instance;
            if (rig == null || rig.MainCamera == null) return;

            var pivot = transform.position + Vector3.up * CameraHeight;
            var rotation = Quaternion.Euler(Pitch, Yaw, 0f);
            var wanted = pivot - rotation * Vector3.forward * CameraDistance;

            RaycastHit hit;
            if (Physics.Linecast(pivot, wanted, out hit))
                wanted = hit.point + hit.normal * 0.2f;

            var cam = rig.MainCamera.transform;
            cam.position = Vector3.Lerp(cam.position, wanted, 1f - Mathf.Exp(-18f * Time.deltaTime));
            cam.rotation = Quaternion.Slerp(cam.rotation, rotation, 1f - Mathf.Exp(-22f * Time.deltaTime));
        }

        // --- abilities ---------------------------------------------------------

        public bool IsAbilityActive { get { return Time.time < _abilityActiveUntil; } }

        public float AbilityCharge01
        {
            get { return _abilityCooldown <= 0f ? 1f : Mathf.Clamp01(1f - _abilityCooldown / AbilityCooldownFor(Agent)); }
        }

        static float AbilityCooldownFor(AgentDef agent)
        {
            switch (agent.Id)
            {
                case "reaper": return 18f;
                case "medic": return 14f;
                case "havoc": return 16f;
                default: return 12f;
            }
        }

        void UseAbility()
        {
            if (_abilityCooldown > 0f) return;

            _abilityCooldown = AbilityCooldownFor(Agent);
            _abilityActiveUntil = Time.time + AbilityDuration();
            CinematicRig.Instance.Shake(0.25f);

            switch (Agent.Id)
            {
                case "medic":
                    MatchState.Instance.Health = Mathf.Min(MatchState.Instance.MaxHealth,
                        MatchState.Instance.Health + 45f);
                    break;
                case "reaper":
                    Time.timeScale = 0.55f;   // local slow-motion, restored in TickAbility
                    break;
            }
        }

        float AbilityDuration()
        {
            switch (Agent.Id)
            {
                case "reaper": return 3f;
                case "medic": return 5f;
                case "spectre": return 4f;
                default: return 2f;
            }
        }

        void TickAbility()
        {
            if (_abilityCooldown > 0f) _abilityCooldown -= Time.deltaTime;

            if (Agent.Id == "reaper" && !IsAbilityActive && Time.timeScale < 1f)
                Time.timeScale = 1f;

            var match = MatchState.Instance;
            if (match != null) match.AbilityCharge01 = AbilityCharge01;
        }

        // --- damage ------------------------------------------------------------

        public void TakeDamage(float amount, string attackerId)
        {
            if (!IsAlive) return;

            var match = MatchState.Instance;
            var shielded = IsAbilityActive && Agent.Id == "vanguard";
            var applied = shielded ? amount * 0.25f : amount;

            if (match.Shield > 0f)
            {
                var absorbed = Mathf.Min(match.Shield, applied);
                match.Shield -= absorbed;
                applied -= absorbed;
            }
            match.Health -= applied;

            Avatar.FlashHit();
            CinematicRig.Instance.Shake(0.18f);
            CinematicRig.Instance.SetDamageState(1f - Mathf.Clamp01(match.Health / match.MaxHealth));

            if (match.Health <= 0f) Die(attackerId);
        }

        void Die(string killerId)
        {
            IsAlive = false;
            _respawnAt = Time.time + RespawnDelay;
            Avatar.SetVisible(false);

            var match = MatchState.Instance;
            match.Health = 0f;
            match.KillStreak = 0;
            match.RegisterKill(killerId, GameBootstrap.Session.Local.PlayerId, "eliminated");
            Time.timeScale = 1f;
        }

        void Respawn()
        {
            var match = MatchState.Instance;
            match.Health = match.MaxHealth;
            match.Shield = 50f;

            var arena = FindObjectOfType<ArenaBuilder>();
            if (arena != null)
            {
                var spawn = arena.PickSpawn(Team, Random.Range(0, 4));
                _controller.enabled = false;
                transform.position = spawn.position;
                transform.rotation = spawn.rotation;
                Yaw = spawn.eulerAngles.y;
                _controller.enabled = true;
            }

            _velocity = Vector3.zero;
            IsAlive = true;
            Avatar.SetVisible(true);
            CinematicRig.Instance.SetDamageState(0f);
        }
    }
}
