using System.Collections.Generic;
using BattleOfAgents.Core;
using BattleOfAgents.Net;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>The Wi-Fi room browser. Rooms appear here on their own — no IP typing,
    /// no codes — because the host is beaconing on the local subnet.</summary>
    public class LanBrowserScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.LanBrowser; } }

        RectTransform _list;
        Text _status;
        readonly List<RoomInfo> _rooms = new List<RoomInfo>();

        protected override void Build()
        {
            Backdrop();
            Header("Join over Wi-Fi", "Rooms on your network appear automatically", ScreenId.MainMenu);

            var panel = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "ListPanel");
            var prt = (RectTransform)panel.transform;
            prt.anchorMin = new Vector2(0.06f, 0.08f);
            prt.anchorMax = new Vector2(0.94f, 0.80f);
            prt.offsetMin = Vector2.zero;
            prt.offsetMax = Vector2.zero;
            var edge = panel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var col = UIKit.Column(panel.transform, 10f, new RectOffset(28, 28, 24, 24), "ListBody");
            UIKit.Fill((RectTransform)col.transform);

            var head = UIKit.Row(col.transform, 12f, null, "ListHead");
            head.gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;
            UIKit.Label(head.transform, "ROOM", 20, Theme.TextLow, FontStyle.Bold);
            UIKit.Label(head.transform, "MODE", 20, Theme.TextLow, FontStyle.Bold);
            UIKit.Label(head.transform, "MAP", 20, Theme.TextLow, FontStyle.Bold);
            UIKit.Label(head.transform, "PLAYERS", 20, Theme.TextLow, FontStyle.Bold, TextAnchor.MiddleRight);
            UIKit.Divider(col.transform);

            var listCol = UIKit.Column(col.transform, 10f, null, "Rooms");
            listCol.gameObject.AddComponent<LayoutElement>().flexibleHeight = 1f;
            _list = (RectTransform)listCol.transform;

            _status = UIKit.Label(col.transform, "Scanning …", 22, Theme.TextMid);
            _status.gameObject.AddComponent<LayoutElement>().preferredHeight = 30f;

            var footer = UIKit.Row(Root, 16f, null, "Footer");
            var frt = (RectTransform)footer.transform;
            frt.anchorMin = new Vector2(0.06f, 0.02f);
            frt.anchorMax = new Vector2(0.94f, 0.075f);
            frt.offsetMin = Vector2.zero;
            frt.offsetMax = Vector2.zero;
            UIKit.GhostButton(footer.transform, "Rescan", Rescan, 60f);
            UIKit.GhostButton(footer.transform, "Host instead", () => Router.Go(ScreenId.CreateRoom), 60f);

            RenderRooms();
        }

        public override void OnShow()
        {
            var discovery = LobbyService.Instance.Discovery;
            discovery.RoomsChanged += OnRoomsChanged;
            discovery.StartScanning();
            LobbyService.Instance.Disconnected += OnDisconnected;
        }

        public override void OnHide()
        {
            var lobby = LobbyService.Instance;
            if (lobby == null) return;
            lobby.Discovery.RoomsChanged -= OnRoomsChanged;
            lobby.Discovery.StopScanning();
            lobby.Disconnected -= OnDisconnected;
        }

        void OnDisconnected(string reason)
        {
            if (_status != null) _status.text = reason;
        }

        void Rescan()
        {
            var d = LobbyService.Instance.Discovery;
            d.StopScanning();
            d.StartScanning();
            _rooms.Clear();
            RenderRooms();
        }

        void OnRoomsChanged(List<RoomInfo> rooms)
        {
            _rooms.Clear();
            _rooms.AddRange(rooms);
            RenderRooms();
        }

        void RenderRooms()
        {
            if (_list == null) return;
            for (int i = _list.childCount - 1; i >= 0; i--) Destroy(_list.GetChild(i).gameObject);

            if (_rooms.Count == 0)
            {
                _status.text = LanUtility.IsOnWifi()
                    ? "Scanning udp/" + GameConfig.DiscoveryPort + " on " + LanUtility.LocalIPv4() + " …"
                    : "Not on Wi-Fi. Connect to the same network as the host.";

                var empty = UIKit.Label(_list, "No squads found yet — ask the host to open their room.",
                    24, Theme.TextLow, FontStyle.Italic, TextAnchor.MiddleCenter);
                empty.gameObject.AddComponent<LayoutElement>().preferredHeight = 120f;
                return;
            }

            _status.text = _rooms.Count + " squad" + (_rooms.Count == 1 ? "" : "s") + " on this network";
            for (int i = 0; i < _rooms.Count; i++) RoomRow(_rooms[i]);
        }

        void RoomRow(RoomInfo room)
        {
            var rowRt = UIKit.Rect("Room_" + room.RoomId, _list);
            rowRt.gameObject.AddComponent<LayoutElement>().preferredHeight = 84f;

            var bg = rowRt.gameObject.AddComponent<Image>();
            bg.color = Theme.WithAlpha(Theme.SurfaceAlt, 0.85f);
            var edge = rowRt.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var row = UIKit.Row(rowRt, 12f, new RectOffset(20, 20, 0, 0), "RoomCells");
            UIKit.Fill((RectTransform)row.transform);

            var full = room.PlayerCount >= room.MaxPlayers;

            var nameCol = UIKit.Column(row.transform, 2f, null, "NameCell");
            UIKit.Label(nameCol.transform, room.RoomName, 28, Theme.TextHi, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;
            UIKit.Label(nameCol.transform, "host " + room.HostName + "  ·  " + room.HostAddress,
                20, Theme.TextLow).gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;

            UIKit.Label(row.transform, ModeShort(room.Mode), 24, Theme.Cyan);
            UIKit.Label(row.transform, room.MapName, 24, Theme.TextMid);
            UIKit.Label(row.transform, room.PlayerCount + "/" + room.MaxPlayers, 26,
                full ? Theme.Danger : Theme.Success, FontStyle.Bold, TextAnchor.MiddleRight);

            var joinHolder = UIKit.Rect("JoinHolder", row.transform);
            joinHolder.gameObject.AddComponent<LayoutElement>().preferredWidth = 180f;
            var join = UIKit.PrimaryButton(joinHolder, full ? "Full" : "Join",
                full ? (System.Action)null : () => Join(room), 60f, full ? Theme.TextLow : Theme.Cyan);
            UIKit.Fill((RectTransform)join.transform);
            join.interactable = !full;
        }

        void Join(RoomInfo room)
        {
            _status.text = "Connecting to " + room.HostAddress + " …";
            Session.CurrentRoom = room;
            LobbyService.Instance.JoinRoom(room);
            Router.Go(ScreenId.RoomLobby);
        }

        static string ModeShort(MatchMode m)
        {
            switch (m)
            {
                case MatchMode.FreeForAll: return "FFA";
                case MatchMode.Domination: return "DOM";
                default: return "TDM";
            }
        }
    }
}
