using System;
using System.Collections.Generic;
using UnityEngine;

namespace BattleOfAgents.Net
{
    /// <summary>Sockets run on worker threads; Unity objects may only be touched on
    /// the main thread. Everything crossing that line goes through this queue.</summary>
    public class MainThreadDispatcher : MonoBehaviour
    {
        static MainThreadDispatcher _instance;
        static readonly Queue<Action> Pending = new Queue<Action>();

        public static MainThreadDispatcher Instance
        {
            get
            {
                if (_instance == null)
                {
                    var go = new GameObject("[MainThreadDispatcher]");
                    DontDestroyOnLoad(go);
                    _instance = go.AddComponent<MainThreadDispatcher>();
                }
                return _instance;
            }
        }

        public static void Enqueue(Action action)
        {
            if (action == null) return;
            lock (Pending) Pending.Enqueue(action);
        }

        void Update()
        {
            while (true)
            {
                Action next;
                lock (Pending)
                {
                    if (Pending.Count == 0) return;
                    next = Pending.Dequeue();
                }
                try { next(); }
                catch (Exception e) { Debug.LogException(e); }
            }
        }
    }
}
