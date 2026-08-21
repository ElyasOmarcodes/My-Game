# Screens

Rendered at 1920x1080 — the same reference resolution the in-game `CanvasScaler`
uses. Regenerate with `python3 tools/mockups/build_mockups.py && tools/mockups/shoot.sh`.

| # | Screen | Code |
| --- | --- | --- |
| 01 | Splash | `Assets/Scripts/UI/Screens/SplashScreen.cs` |
| 02 | Main menu | `MainMenuScreen.cs` |
| 03 | Host a squad | `CreateRoomScreen.cs` |
| 04 | Wi-Fi browser | `LanBrowserScreen.cs` |
| 05 | Room lobby | `RoomLobbyScreen.cs` |
| 06 | Agents | `AgentSelectScreen.cs` |
| 07 | In-match HUD | `HudScreen.cs` |
| 08 | Pause | `PauseScreen.cs` |
| 09 | Results | `ResultsScreen.cs` |
| 10 | Settings | `SettingsScreen.cs` |

## World, models and the playable build

Rendered by the WebGL engine in `engine/` — the same code the preview APK runs,
so these are what the game actually looks like, not mockups.

| File | What it shows |
| --- | --- |
| `3d-city-aerial.png` | The whole 460 m map and its five districts |
| `3d-city-street.png` | Downtown avenue at dusk, agents in scale |
| `3d-city-park.png` | Park district — pond, paths, tree cover |
| `3d-city-industrial.png` | Warehouse and stacked shipping containers |
| `3d-agents.png` | The four body archetypes |
| `3d-weapons.png` | The five weapon models |
| `3d-gameplay.png` | The playable build with its HUD and touch controls |

Regenerate with `tools/mockups/shoot3d.sh` and `tools/mockups/shootgame.sh`.
