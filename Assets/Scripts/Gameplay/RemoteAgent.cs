using BattleOfAgents.Core;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>Another player's agent, driven by 20 Hz snapshots.
    ///
    /// Snapshots arrive every 50 ms, which would look like a slideshow if drawn
    /// directly, so the body is interpolated towards the newest state each frame. The
    /// capsule collider is what the local weapon raycasts against.</summary>
    public class RemoteAgent : MonoBehaviour
    {
        public string PlayerId { get; private set; }
        public Team Team { get; private set; }
        public float Yaw { get; private set; }
        public bool IsAlive { get; private set; }

        AgentAvatar _avatar;
        Vector3 _targetPosition;
        float _targetYaw;

        const float PositionSmoothing = 14f;
        const float RotationSmoothing = 18f;

        public static RemoteAgent Create(Transform parent, PlayerProfile profile)
        {
            var go = new GameObject("Remote_" + profile.DisplayName);
            go.transform.SetParent(parent, false);

            var capsule = go.AddComponent<CapsuleCollider>();
            capsule.height = 1.9f;
            capsule.radius = 0.42f;
            capsule.center = new Vector3(0f, 0.95f, 0f);

            var agent = go.AddComponent<RemoteAgent>();
            agent.PlayerId = profile.PlayerId;
            agent.Team = profile.Team;
            agent.IsAlive = true;
            agent._avatar = AgentAvatar.Create(go.transform,
                AgentCatalog.Get(profile.AgentId), profile.Team, profile.DisplayName);
            return agent;
        }

        public void ReceiveState(Vector3 position, float yaw)
        {
            _targetPosition = position;
            _targetYaw = yaw;
        }

        public void SetAlive(bool alive)
        {
            if (IsAlive == alive) return;
            IsAlive = alive;
            _avatar.SetVisible(alive);
            GetComponent<CapsuleCollider>().enabled = alive;
        }

        /// <summary>Immediate local feedback on a hit — the host still has the final
        /// say on whether it counted, but the shooter sees it right away.</summary>
        public void PlayHitFeedback()
        {
            _avatar.FlashHit();
        }

        void Update()
        {
            transform.position = Vector3.Lerp(transform.position, _targetPosition,
                1f - Mathf.Exp(-PositionSmoothing * Time.deltaTime));

            Yaw = Mathf.LerpAngle(Yaw, _targetYaw, 1f - Mathf.Exp(-RotationSmoothing * Time.deltaTime));
            transform.rotation = Quaternion.Euler(0f, Yaw, 0f);
        }
    }
}
