using System.Collections.Generic;
using BattleOfAgents.Core;
using BattleOfAgents.Net;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>The waiting room: two team columns, a ready toggle, chat, and (for the
    /// host) the deploy button that unlocks once everyone is ready.</summary>
    public class RoomLobbyScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.RoomLobby; } }

        readonly List<string> _chat = new List<string>();
        RectTransform _chatList;
        InputField _chatField;

        protected override void Build()
        {
            Backdrop();

            var lobby = LobbyService.Instance;
            var state = lobby.State;
            var roomName = string.IsNullOrEmpty(state.roomName) ? "Connecting …" : state.roomName;

            Header(roomName, ModeLabel(state) + "  ·  " + (state.mapName ?? "—") +
                "  ·  " + LanUtility.LocalIPv4());

            // --- team columns --------------------------------------------------
            var teams = UIKit.Row(Root, 20f, null, "Teams");
            var trt = (RectTransform)teams.transform;
            trt.anchorMin = new Vector2(0.04f, 0.30f);
            trt.anchorMax = new Vector2(0.66f, 0.86f);
            trt.offsetMin = Vector2.zero;
            trt.offsetMax = Vector2.zero;

            TeamColumn(teams.transform, Team.Alpha, "TEAM ALPHA", Theme.TeamAlpha);
            TeamColumn(teams.transform, Team.Bravo, "TEAM BRAVO", Theme.TeamBravo);

            // --- chat -----------------------------------------------------------
            var chatPanel = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "Chat");
            var crt = (RectTransform)chatPanel.transform;
            crt.anchorMin = new Vector2(0.68f, 0.10f);
            crt.anchorMax = new Vector2(0.96f, 0.86f);
            crt.offsetMin = Vector2.zero;
            crt.offsetMax = Vector2.zero;
            var edge = chatPanel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var chatCol = UIKit.Column(chatPanel.transform, 8f, new RectOffset(22, 22, 20, 20), "ChatBody");
            UIKit.Fill((RectTransform)chatCol.transform);
            UIKit.Label(chatCol.transform, "SQUAD COMMS", 20, Theme.TextLow, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;
            UIKit.Divider(chatCol.transform);

            var msgs = UIKit.Column(chatCol.transform, 6f, null, "Messages");
            msgs.gameObject.AddComponent<LayoutElement>().flexibleHeight = 1f;
            _chatList = (RectTransform)msgs.transform;
            RenderChat();

            _chatField = UIKit.TextField(chatCol.transform, "Message the squad …", "", 60f);
            _chatField.onEndEdit.AddListener(text =>
            {
                if (string.IsNullOrEmpty(text)) return;
                LobbyService.Instance.SendChat(text);
                _chatField.text = string.Empty;
            });

            // --- action bar ------------------------------------------------------
            var bar = UIKit.Row(Root, 16f, null, "Actions");
            var brt = (RectTransform)bar.transform;
            brt.anchorMin = new Vector2(0.04f, 0.10f);
            brt.anchorMax = new Vector2(0.66f, 0.26f);
            brt.offsetMin = Vector2.zero;
            brt.offsetMax = Vector2.zero;

            UIKit.GhostButton(bar.transform, "Leave", () =>
            {
                LobbyService.Instance.Leave();
                Router.Go(ScreenId.MainMenu, false);
            }, 84f);

            UIKit.GhostButton(bar.transform, "Swap team", () =>
            {
                var next = Session.Local.Team == Team.Alpha ? Team.Bravo : Team.Alpha;
                LobbyService.Instance.SetTeam(next);
            }, 84f);

            UIKit.GhostButton(bar.transform, "Agent: " +
                AgentCatalog.Get(Session.Local.AgentId).Name,
                () => Router.Go(ScreenId.AgentSelect), 84f);

            if (lobby.IsHost)
            {
                var canStart = lobby.CanStart();
                var deploy = UIKit.PrimaryButton(bar.transform,
                    canStart ? "Deploy" : "Waiting for squad",
                    canStart ? (System.Action)(() => lobby.StartMatch()) : null,
                    84f, canStart ? Theme.Success : Theme.TextLow);
                deploy.interactable = canStart;
            }
            else
            {
                var ready = Session.Local.IsReady;
                UIKit.PrimaryButton(bar.transform, ready ? "Ready ✓" : "Ready up",
                    () => LobbyService.Instance.SetReady(!ready), 84f,
                    ready ? Theme.Success : Theme.Amber);
            }
        }

        void TeamColumn(Transform parent, Team team, string title, Color accent)
        {
            var panel = UIKit.Panel(parent, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "Team_" + team);
            var edge = panel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.WithAlpha(accent, 0.45f);
            edge.effectDistance = new Vector2(1.5f, -1.5f);

            var col = UIKit.Column(panel.transform, 10f, new RectOffset(24, 24, 20, 20), "TeamBody");
            UIKit.Fill((RectTransform)col.transform);

            var members = Session.RoomPlayers.FindAll(p => p.Team == team);

            var head = UIKit.Row(col.transform, 8f, null, "TeamHead");
            head.gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;
            UIKit.Label(head.transform, title, 24, accent, FontStyle.Bold);
            UIKit.Label(head.transform, members.Count + " / " + (GameConfig.MaxPlayers / 2),
                22, Theme.TextLow, FontStyle.Normal, TextAnchor.MiddleRight);
            UIKit.Divider(col.transform, 1f, Theme.WithAlpha(accent, 0.3f));

            for (int i = 0; i < members.Count; i++) PlayerRow(col.transform, members[i], accent);

            int emptySlots = (GameConfig.MaxPlayers / 2) - members.Count;
            for (int i = 0; i < emptySlots; i++)
            {
                var slot = UIKit.Label(col.transform, "· open slot ·", 22, Theme.TextLow,
                    FontStyle.Italic, TextAnchor.MiddleCenter);
                slot.gameObject.AddComponent<LayoutElement>().preferredHeight = 54f;
            }
            UIKit.Flex(col.transform);
        }

        void PlayerRow(Transform parent, PlayerProfile p, Color accent)
        {
            var rowRt = UIKit.Rect("P_" + p.PlayerId, parent);
            rowRt.gameObject.AddComponent<LayoutElement>().preferredHeight = 62f;
            var bg = rowRt.gameObject.AddComponent<Image>();
            bg.color = Theme.WithAlpha(Theme.Void, 0.6f);
            bg.raycastTarget = false;

            var row = UIKit.Row(rowRt, 10f, new RectOffset(16, 16, 0, 0), "Cells");
            UIKit.Fill((RectTransform)row.transform);

            var isMe = p.PlayerId == Session.Local.PlayerId;
            var nameText = p.DisplayName + (p.IsHost ? "  ·  HOST" : "") + (isMe ? "  (you)" : "");
            UIKit.Label(row.transform, nameText, 24, isMe ? accent : Theme.TextHi,
                isMe ? FontStyle.Bold : FontStyle.Normal);

            UIKit.Label(row.transform, AgentCatalog.Get(p.AgentId).Name, 22, Theme.TextMid);
            UIKit.Label(row.transform, p.IsReady ? "READY" : "…", 22,
                p.IsReady ? Theme.Success : Theme.TextLow, FontStyle.Bold, TextAnchor.MiddleRight);
        }

        void RenderChat()
        {
            if (_chatList == null) return;
            for (int i = _chatList.childCount - 1; i >= 0; i--) Destroy(_chatList.GetChild(i).gameObject);

            int start = Mathf.Max(0, _chat.Count - 12);
            for (int i = start; i < _chat.Count; i++)
            {
                var line = UIKit.Label(_chatList, _chat[i], 21, Theme.TextMid);
                line.gameObject.AddComponent<LayoutElement>().preferredHeight = 28f;
            }
        }

        public override void OnShow()
        {
            var lobby = LobbyService.Instance;
            lobby.RoomStateChanged += OnRoomState;
            lobby.ChatReceived += OnChat;
            lobby.Disconnected += OnDisconnected;
            lobby.MatchStarting += OnMatchStarting;
        }

        public override void OnHide()
        {
            var lobby = LobbyService.Instance;
            if (lobby == null) return;
            lobby.RoomStateChanged -= OnRoomState;
            lobby.ChatReceived -= OnChat;
            lobby.Disconnected -= OnDisconnected;
            lobby.MatchStarting -= OnMatchStarting;
        }

        void OnRoomState() { Rebuild(); }

        void OnChat(string from, string text)
        {
            _chat.Add(from + ":  " + text);
            RenderChat();
        }

        void OnDisconnected(string reason)
        {
            _chat.Add("· " + reason + " ·");
            Router.Go(ScreenId.MainMenu, false);
        }

        void OnMatchStarting(StartMsg msg)
        {
            Session.SelectedMap = msg.mapName;
            Session.SelectedMode = (MatchMode)msg.mode;
            Router.Go(ScreenId.Hud, false);
        }

        static string ModeLabel(RoomStateMsg s)
        {
            switch ((MatchMode)s.mode)
            {
                case MatchMode.FreeForAll: return "Free for all";
                case MatchMode.Domination: return "Domination";
                default: return "Team deathmatch";
            }
        }
    }
}
