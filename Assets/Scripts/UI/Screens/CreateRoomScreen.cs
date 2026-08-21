using BattleOfAgents.Core;
using BattleOfAgents.Net;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>Host configuration: name the squad, pick mode/map/size, then open the
    /// room. Opening the room starts the UDP beacon so nearby phones can see it.</summary>
    public class CreateRoomScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.CreateRoom; } }

        static readonly string[] Maps =
        {
            "Kandahar Rooftops", "Cargo Yard 09", "Signal Tower", "Frozen Depot"
        };

        InputField _nameField;
        int _mapIndex;
        int _maxPlayers = 8;
        MatchMode _mode = MatchMode.TeamDeathmatch;
        Text _mapLabel, _sizeLabel, _modeLabel, _error;

        protected override void Build()
        {
            Backdrop();
            Header("Host a squad", "Everyone on this Wi-Fi will see your room", ScreenId.MainMenu);

            var panel = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "Form");
            var prt = (RectTransform)panel.transform;
            prt.anchorMin = new Vector2(0.08f, 0.08f);
            prt.anchorMax = new Vector2(0.62f, 0.82f);
            prt.offsetMin = Vector2.zero;
            prt.offsetMax = Vector2.zero;
            var edge = panel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var form = UIKit.Column(panel.transform, 14f, new RectOffset(36, 36, 32, 32), "FormBody");
            UIKit.Fill((RectTransform)form.transform);

            Caption(form.transform, "ROOM NAME");
            _nameField = UIKit.TextField(form.transform, "e.g. Kabul Night Ops",
                GameBootstrap.Session.Local.DisplayName + "'s squad");

            UIKit.Spacer(form.transform, 8f);
            Caption(form.transform, "MODE");
            _modeLabel = Stepper(form.transform, ModeLabel(_mode), () =>
            {
                _mode = (MatchMode)(((int)_mode + 1) % 3);
                _modeLabel.text = ModeLabel(_mode);
            });

            Caption(form.transform, "MAP");
            _mapLabel = Stepper(form.transform, Maps[_mapIndex], () =>
            {
                _mapIndex = (_mapIndex + 1) % Maps.Length;
                _mapLabel.text = Maps[_mapIndex];
            });

            Caption(form.transform, "SQUAD SIZE");
            _sizeLabel = Stepper(form.transform, _maxPlayers + " players", () =>
            {
                _maxPlayers = _maxPlayers >= GameConfig.MaxPlayers ? GameConfig.MinPlayers : _maxPlayers + 2;
                _sizeLabel.text = _maxPlayers + " players";
            });

            UIKit.Flex(form.transform);
            _error = UIKit.Label(form.transform, "", 22, Theme.Danger);
            _error.gameObject.AddComponent<LayoutElement>().preferredHeight = 28f;

            UIKit.PrimaryButton(form.transform, "Open the room", OpenRoom, 88f, Theme.Cyan);

            // --- right: what the others will see ------------------------------
            var side = UIKit.Column(Root, 12f, new RectOffset(0, 0, 0, 0), "Preview");
            var srt = (RectTransform)side.transform;
            srt.anchorMin = new Vector2(0.66f, 0.08f);
            srt.anchorMax = new Vector2(0.92f, 0.82f);
            srt.offsetMin = Vector2.zero;
            srt.offsetMax = Vector2.zero;

            Caption(side.transform, "BROADCAST PREVIEW");
            var card = UIKit.Panel(side.transform, Theme.WithAlpha(Theme.SurfaceAlt, 0.9f), "PreviewCard");
            card.gameObject.AddComponent<LayoutElement>().preferredHeight = 190f;
            var body = UIKit.Column(card.transform, 8f, new RectOffset(24, 24, 20, 20));
            UIKit.Fill((RectTransform)body.transform);
            UIKit.Label(body.transform, "LIVE  ·  LAN", 20, Theme.Success, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;
            UIKit.Label(body.transform, GameBootstrap.Session.Local.DisplayName + "'s squad", 30,
                Theme.TextHi, FontStyle.Bold).gameObject.AddComponent<LayoutElement>().preferredHeight = 40f;
            UIKit.Label(body.transform, "1/" + _maxPlayers + "  ·  " + Maps[_mapIndex], 22, Theme.TextMid)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 28f;
            UIKit.Label(body.transform, LanUtility.LocalIPv4() + ":" + GameConfig.GamePort, 22, Theme.Cyan)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 28f;

            UIKit.Spacer(side.transform, 12f);
            UIKit.Label(side.transform,
                "Players join without typing an address — the host beacons on UDP " +
                GameConfig.DiscoveryPort + " and phones on the same router pick it up automatically.",
                21, Theme.TextLow).gameObject.AddComponent<LayoutElement>().preferredHeight = 120f;
        }

        void OpenRoom()
        {
            if (!LanUtility.IsOnWifi())
            {
                _error.text = "No Wi-Fi connection detected. Join a network first.";
                return;
            }

            var roomName = _nameField != null && !string.IsNullOrEmpty(_nameField.text)
                ? _nameField.text
                : GameBootstrap.Session.Local.DisplayName + "'s squad";

            Session.SelectedMode = _mode;
            Session.SelectedMap = Maps[_mapIndex];

            if (!LobbyService.Instance.HostRoom(roomName, _mode, Maps[_mapIndex], _maxPlayers))
            {
                _error.text = "Port " + GameConfig.GamePort + " is busy. Close the other match and retry.";
                return;
            }
            Router.Go(ScreenId.RoomLobby);
        }

        static string ModeLabel(MatchMode m)
        {
            switch (m)
            {
                case MatchMode.FreeForAll:  return "Free for all";
                case MatchMode.Domination:  return "Domination";
                default:                    return "Team deathmatch";
            }
        }

        static void Caption(Transform parent, string text)
        {
            UIKit.Label(parent, text, 20, Theme.TextLow, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;
        }

        /// <summary>A tap-to-cycle option row — far friendlier than a dropdown on touch.</summary>
        static Text Stepper(Transform parent, string value, System.Action onNext)
        {
            var row = UIKit.Rect("Stepper", parent);
            var le = row.gameObject.AddComponent<LayoutElement>();
            le.preferredHeight = 72f;

            var bg = row.gameObject.AddComponent<Image>();
            bg.color = Theme.WithAlpha(Theme.Void, 0.85f);
            var outline = row.gameObject.AddComponent<Outline>();
            outline.effectColor = Theme.Line;
            outline.effectDistance = new Vector2(1f, -1f);

            var label = UIKit.Label(row, value, 28, Theme.TextHi);
            var lrt = UIKit.Fill((RectTransform)label.transform, 18f);
            lrt.offsetMax = new Vector2(-70f, lrt.offsetMax.y);

            var chevron = UIKit.Label(row, ">", 30, Theme.Cyan, FontStyle.Bold, TextAnchor.MiddleRight);
            UIKit.Fill((RectTransform)chevron.transform, 18f);

            var btn = row.gameObject.AddComponent<Button>();
            btn.targetGraphic = bg;
            btn.onClick.AddListener(() => onNext());
            return label;
        }
    }
}
