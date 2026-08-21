using System.Collections.Generic;
using BattleOfAgents.UI;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.Core
{
    /// <summary>Owns the canvas, instantiates every screen and switches between them.
    /// One instance lives for the whole session (DontDestroyOnLoad).</summary>
    public class AppRouter : MonoBehaviour
    {
        public SessionState Session { get; private set; }
        public Canvas Canvas { get; private set; }
        public ScreenId Current { get; private set; }

        readonly Dictionary<ScreenId, ScreenBase> _screens = new Dictionary<ScreenId, ScreenBase>();
        readonly Stack<ScreenId> _history = new Stack<ScreenId>();

        public static AppRouter Instance { get; private set; }

        public void Boot(SessionState session)
        {
            Instance = this;
            Session = session;
            BuildCanvas();
            UIKit.EnsureEventSystem();

            Register<Screens.SplashScreen>();
            Register<Screens.MainMenuScreen>();
            Register<Screens.CreateRoomScreen>();
            Register<Screens.LanBrowserScreen>();
            Register<Screens.RoomLobbyScreen>();
            Register<Screens.AgentSelectScreen>();
            Register<Screens.HudScreen>();
            Register<Screens.PauseScreen>();
            Register<Screens.ResultsScreen>();
            Register<Screens.SettingsScreen>();

            Go(ScreenId.Splash);
        }

        void BuildCanvas()
        {
            var go = new GameObject("UICanvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            go.transform.SetParent(transform, false);
            Canvas = go.GetComponent<Canvas>();
            Canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            Canvas.pixelPerfect = false;

            var scaler = go.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = Theme.ReferenceResolution;
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0.5f;
        }

        void Register<T>() where T : ScreenBase
        {
            var host = new GameObject(typeof(T).Name, typeof(RectTransform));
            var rt = (RectTransform)host.transform;
            rt.SetParent(Canvas.transform, false);
            UIKit.Fill(rt);

            var screen = host.AddComponent<T>();
            screen.Init(this, rt);
            _screens[screen.Id] = screen;
        }

        public T Screen<T>(ScreenId id) where T : ScreenBase
        {
            ScreenBase s;
            return _screens.TryGetValue(id, out s) ? s as T : null;
        }

        public void Go(ScreenId id, bool remember = true)
        {
            ScreenBase next;
            if (!_screens.TryGetValue(id, out next))
            {
                Debug.LogError("[Router] unknown screen " + id);
                return;
            }

            ScreenBase current;
            if (_screens.TryGetValue(Current, out current) && current != next)
            {
                current.Hide();
                if (remember) _history.Push(Current);
            }

            Current = id;
            next.Show();
        }

        public void Back()
        {
            if (_history.Count == 0) { Go(ScreenId.MainMenu, false); return; }
            Go(_history.Pop(), false);
        }

        /// <summary>Rebuilds a screen if it is the one on display — used by network
        /// callbacks that mutate the session state.</summary>
        public void RefreshIfVisible(ScreenId id)
        {
            ScreenBase s;
            if (Current == id && _screens.TryGetValue(id, out s)) s.Rebuild();
        }
    }
}
