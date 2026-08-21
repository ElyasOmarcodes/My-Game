using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.Gameplay
{
    /// <summary>A world-space name plate that always faces the camera.</summary>
    public class NameTag : MonoBehaviour
    {
        Transform _camera;

        public static NameTag Attach(Transform parent, string label, Color color, float height = 2.15f)
        {
            var go = new GameObject("NameTag", typeof(Canvas));
            go.transform.SetParent(parent, false);
            go.transform.localPosition = new Vector3(0f, height, 0f);

            var canvas = go.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.WorldSpace;
            var rt = (RectTransform)go.transform;
            rt.sizeDelta = new Vector2(300f, 60f);
            rt.localScale = Vector3.one * 0.01f;

            var text = UI.UIKit.Label(go.transform, label, 34, color,
                FontStyle.Bold, TextAnchor.MiddleCenter);
            UI.UIKit.Fill((RectTransform)text.transform);

            var tag = go.AddComponent<NameTag>();
            return tag;
        }

        void LateUpdate()
        {
            if (_camera == null)
            {
                var cam = Camera.main;
                if (cam == null) return;
                _camera = cam.transform;
            }
            transform.rotation = Quaternion.LookRotation(transform.position - _camera.position);
        }
    }
}
