# Battle of Agents

A cinematic Wi-Fi (LAN) multiplayer action game for Android — Unity + C#.
No server, no account, no internet: one phone hosts a squad, every other phone on
the same router discovers it automatically and joins.

| | |
| --- | --- |
| Engine | Unity 2022.3 LTS · Universal Render Pipeline |
| Language | C# (no third-party runtime packages) |
| Networking | UDP broadcast discovery + TCP lobby channel, host-authoritative |
| Target | Android 7.0 (API 24) and up · ARM64 · IL2CPP |
| Output | Single debug-signed APK, wrapped in a max-compressed zip by CI |

## Screens

![Main menu](docs/screenshots/02-main-menu.png)

Every page is in [`docs/screenshots/`](docs/screenshots): splash, main menu, host a
squad, Wi-Fi browser, room lobby, agent select, in-match HUD, pause, results, settings.

## How the Wi-Fi multiplayer works

```
HOST                                     CLIENT
 │  udp/47777  ── beacon (1 Hz) ──▶  discovery listener
 │              room, host, players, map, mode
 │
 └─ tcp/47778  ◀── hello ──          join
                ── welcome ──▶
                ── room state ──▶    (full state after every change)
                ◀── ready / team / agent / chat ──
                ── start match ──▶
```

The host owns the roster and re-broadcasts the complete room state after every
change, so clients never merge partial updates. The wire format is newline-delimited
JSON (`Assets/Scripts/Net/NetMessages.cs`) — readable in a packet capture and trivial
to version through `GameConfig.ProtocolId`.

## Repository layout

```
Assets/Scripts/Core        boot, session state, screen router
Assets/Scripts/Net         LAN discovery, lobby service, wire format
Assets/Scripts/UI          theme, widget kit, one file per screen
Assets/Scripts/Gameplay    agent roster, match state
Assets/Scripts/Visual      camera rig + post-processing stack
Assets/Editor              project configurator + CI build entry point
tools/mockups              HTML mirrors of every screen, used for review shots
.github/workflows          Android build pipeline
```

There are no `.prefab` or populated `.unity` files: the whole game builds its
objects at runtime from code (`GameBootstrap` runs on `RuntimeInitializeOnLoadMethod`).
That keeps the repo reviewable in plain diffs and the APK free of serialized assets.

## Building locally

```bash
# Unity 2022.3.62f1 with the Android module installed
Unity -batchmode -quit -projectPath . \
      -executeMethod BattleOfAgents.EditorTools.BuildScript.BuildAndroid
# → build/android/BattleOfAgents.apk
```

## Building in CI

`.github/workflows/android-build.yml` builds on every push to the feature branch, and
on demand from the Actions tab.

**The one thing it needs is a Unity licence.** Unity refuses to start in batch mode
unactivated, so without it the build cannot run at all. Getting one is free and takes
a couple of minutes, once:

1. Actions ▸ **Unity licence request** ▸ *Run workflow*.
2. Download the `Unity_alf` artifact from that run and unzip it.
3. Upload the `.alf` at <https://license.unity3d.com/manual>, choose **Unity Personal**,
   download the `.ulf`.
4. Settings ▸ Secrets and variables ▸ Actions ▸ *New repository secret*:
   `UNITY_LICENSE` = the entire contents of the `.ulf` file.

Until that secret exists, the workflow reports "build skipped" with these steps in its
summary instead of failing with Unity's cryptic `Missing Unity License File` error.

| Secret | Required | What it is |
| --- | --- | --- |
| `UNITY_LICENSE` | yes | Contents of the `.ulf` personal licence file |
| `UNITY_SERIAL` | alternative | Serial number instead, if you have Unity Plus/Pro |
| `UNITY_EMAIL` / `UNITY_PASSWORD` | with serial | Unity account for serial activation |

No keystore secrets: **the APK is signed with Unity's debug key**, so it installs on any
phone with "install unknown apps" enabled. That is the right choice for sideloading and
LAN testing — a Play Store upload would need a release key instead.

## Keeping the download small

Applied in `Assets/Editor/BuildScript.cs`, so a clean clone reproduces them:

- ARM64 only (no fat APK) · IL2CPP · `Master` compiler configuration · size-optimised codegen
- Managed stripping **High** + `stripEngineCode` + unused mesh components stripped
- LZ4HC runtime compression, ASTC textures, no debug symbols
- `.NET Standard 2.0` profile, minimal package manifest (URP + required modules only)
- CI then wraps the APK in a `7z -mx=9 -mfb=258 -mpass=15` zip for download; the APK
  inside is byte-identical and installable — re-deflating the APK itself would
  invalidate its signing block, so we deliberately do not.

## Regenerating the screenshots

```bash
python3 tools/mockups/build_mockups.py   # HTML for every screen
tools/mockups/shoot.sh                   # → docs/screenshots/*.png (1920x1080)
```

---

## په پښتو

دا لوبه د وای‌فای پر مټ ډله‌ایزه اکشن لوبه ده. یو ګډونوال کوربه (host) کیږي، نور
هغه کسان چې په همدې راوټر پورې وصل دي، پرته له دې چې IP یا کوډ ولیکي، کوټه یې
په لیست کې ویني او ورسره یوځای کیږي.

- ژبه: C# ، انجن: Unity 2022.3 LTS ، ګرافیک: URP + سینمایي پوسټ‌پروسیسنګ
- شبکه: UDP بیکن (پیدا کول) + TCP (لابي) — کوربه واکمن دی
- خروجي: یو APK چې د GitHub Actions له لارې جوړېږي او په `7z -mx=9` کې زیپ کیږي

د پرمختګ نقشه په [`docs/PLAN.md`](docs/PLAN.md) کې ده.
