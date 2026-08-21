#!/usr/bin/env python3
"""Renders one HTML page per game screen, pixel-matched to the runtime UI code in
Assets/Scripts/UI/Screens. These pages exist purely so every screen can be reviewed
(and screenshotted) without a Unity editor in the loop."""
import os

OUT = os.path.dirname(os.path.abspath(__file__))

SHELL = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>{title}</title><link rel="stylesheet" href="theme.css"></head>
<body><div class="page">{body}</div></body></html>"""


def header(title, sub, back=True):
    b = '<div class="btn ghost" style="width:220px">Back</div>' if back else ''
    return f"""<div class="header">
  <div class="t"><div class="h1">{title}</div><div class="sub">{sub}</div></div>{b}
</div>"""


def bar(pct, color, h=10):
    return (f'<div class="bar" style="height:{h}px">'
            f'<i style="width:{pct}%;background:{color}"></i></div>')


SCREENS = {}

# ---------------------------------------------------------------- 01 splash
SCREENS["01-splash"] = ("Splash", f"""
<div style="height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px">
  <div class="mark">// B O A</div>
  <div style="font-size:96px;font-weight:700;letter-spacing:.10em;text-shadow:0 0 60px rgba(59,232,255,.35)">BATTLE OF AGENTS</div>
  <div class="sub" style="letter-spacing:.5em">TACTICAL SKIRMISH</div>
  <div style="width:900px;margin-top:36px">{bar(62,'var(--cyan)',6)}</div>
  <div class="low" style="font-size:22px;letter-spacing:.3em;margin-top:6px">SCANNING WI-FI ADAPTER</div>
</div>
<div class="low" style="position:absolute;left:48px;bottom:40px;font-size:20px">build 0.1.0 &nbsp;·&nbsp; proto BOA1</div>
<div class="low" style="position:absolute;right:48px;bottom:40px;font-size:20px">LAN ONLY · NO ACCOUNT NEEDED</div>
""")

# ---------------------------------------------------------------- 02 main menu
SCREENS["02-main-menu"] = ("Main menu", f"""
<div style="display:flex;gap:40px;height:100%">
  <div class="col" style="width:44%;gap:16px">
    <div class="mark">// B O A</div>
    <div class="h2">BATTLE<br>OF AGENTS</div>
    <div class="sub">Wi-Fi squad combat &nbsp;·&nbsp; 2–8 agents</div>
    <div style="height:26px"></div>
    <div class="btn clip">Host a squad</div>
    <div class="btn amber clip">Join over Wi-Fi</div>
    <div class="btn ghost clip">Agents &amp; loadout</div>
    <div class="btn ghost clip">Solo drill</div>
    <div class="btn ghost clip">Settings</div>
    <div class="grow"></div>
    <div class="low" style="font-size:20px">v0.1.0 &nbsp;·&nbsp; no internet required</div>
  </div>

  <div class="panel clip glow grow" style="padding:36px;display:flex;flex-direction:column;gap:14px">
    <div class="cap">Operator</div>
    <div style="font-size:54px;font-weight:700;letter-spacing:.04em">Agent-317</div>
    <div class="cy" style="font-size:26px;letter-spacing:.14em">VANGUARD &nbsp;·&nbsp; ASSAULT</div>
    <div style="height:10px"></div><div class="divider"></div><div style="height:10px"></div>
    {''.join(f'''<div class="row" style="height:40px"><div class="cap">{k}</div><div class="grow"></div>
      <div style="font-size:24px;color:{c}">{v}</div></div>''' for k, v, c in [
        ("LEVEL", "7", "var(--text-hi)"),
        ("XP", "840 / 1200", "var(--amber)"),
        ("NETWORK", "WI-FI CONNECTED", "var(--success)"),
        ("LOCAL IP", "192.168.1.24", "var(--text-mid)")])}
    <div style="height:14px"></div>
    <div class="mid" style="font-size:22px;line-height:1.5">Front-line breacher. Trades range for raw
      pressure and a shield dash that closes the last ten metres for the squad.</div>
    <div class="grow"></div>
    <div class="btn ghost clip">Change agent</div>
  </div>
</div>
""")

# ---------------------------------------------------------------- 03 create room
SCREENS["03-create-room"] = ("Host a squad", header("Host a squad",
    "Everyone on this Wi-Fi will see your room") + f"""
<div style="display:flex;gap:32px;height:calc(100% - 130px)">
  <div class="panel clip" style="width:56%;padding:34px;display:flex;flex-direction:column;gap:14px">
    <div class="cap">Room name</div>
    <div class="field"><span>Kabul Night Ops</span></div>
    <div style="height:8px"></div>
    <div class="cap">Mode</div>
    <div class="stepper"><span>Team deathmatch</span><span class="chev">&gt;</span></div>
    <div class="cap">Map</div>
    <div class="stepper"><span>Kandahar Rooftops</span><span class="chev">&gt;</span></div>
    <div class="cap">Squad size</div>
    <div class="stepper"><span>8 players</span><span class="chev">&gt;</span></div>
    <div class="grow"></div>
    <div class="btn clip">Open the room</div>
  </div>

  <div class="col grow" style="gap:12px">
    <div class="cap">Broadcast preview</div>
    <div class="panel clip" style="background:rgba(17,26,37,.9);padding:24px;display:flex;flex-direction:column;gap:8px">
      <div class="ok" style="font-size:20px;letter-spacing:.28em">● LIVE · LAN</div>
      <div style="font-size:30px;font-weight:700">Kabul Night Ops</div>
      <div class="mid" style="font-size:22px">1/8 &nbsp;·&nbsp; Kandahar Rooftops &nbsp;·&nbsp; TDM</div>
      <div class="cy" style="font-size:22px">192.168.1.24:47778</div>
    </div>
    <div style="height:12px"></div>
    <div class="low" style="font-size:21px;line-height:1.6">Players join without typing an address —
      the host beacons on UDP 47777 and every phone on the same router picks it up automatically.</div>
    <div class="grow"></div>
    <div class="panel" style="padding:20px 24px">
      <div class="cap" style="margin-bottom:8px">Wire format</div>
      <div class="low" style="font-size:19px;font-family:monospace;line-height:1.7">
        UDP 47777 → beacon (room, host, players)<br>TCP 47778 → lobby control channel</div>
    </div>
  </div>
</div>
""")

# ---------------------------------------------------------------- 04 lan browser
rooms = [
    ("Kabul Night Ops", "Agent-317", "192.168.1.24", "TDM", "Kandahar Rooftops", "5/8", False),
    ("Rooftop Rumble", "Zaman", "192.168.1.31", "FFA", "Signal Tower", "3/6", False),
    ("Cargo Yard Clash", "Nawid", "192.168.1.47", "DOM", "Cargo Yard 09", "8/8", True),
    ("Late Night Duel", "Sahar", "192.168.1.52", "TDM", "Frozen Depot", "2/4", False),
]
rows = ""
for name, host, ip, mode, mp, count, full in rooms:
    btn = ('<div class="btn dead" style="width:180px;height:60px;font-size:24px">Full</div>' if full
           else '<div class="btn clip" style="width:180px;height:60px;font-size:24px">Join</div>')
    rows += f"""<div class="panel clip row" style="height:84px;padding:0 20px;background:rgba(17,26,37,.85)">
      <div class="col" style="width:520px">
        <div style="font-size:28px;font-weight:700">{name}</div>
        <div class="low" style="font-size:20px">host {host} &nbsp;·&nbsp; {ip}</div>
      </div>
      <div class="cy" style="width:150px;font-size:24px;letter-spacing:.14em">{mode}</div>
      <div class="mid grow" style="font-size:24px">{mp}</div>
      <div style="width:140px;text-align:right;font-size:26px;font-weight:700;
        color:{'var(--danger)' if full else 'var(--success)'}">{count}</div>
      {btn}</div>"""

SCREENS["04-lan-browser"] = ("Join over Wi-Fi", header("Join over Wi-Fi",
    "Rooms on your network appear automatically") + f"""
<div class="panel clip" style="height:calc(100% - 210px);padding:28px;display:flex;flex-direction:column;gap:10px">
  <div class="row" style="height:34px">
    <div class="cap" style="width:520px">Room</div><div class="cap" style="width:150px">Mode</div>
    <div class="cap grow">Map</div><div class="cap" style="width:140px;text-align:right">Players</div>
    <div style="width:180px"></div>
  </div>
  <div class="divider"></div>
  <div class="col" style="gap:10px">{rows}</div>
  <div class="grow"></div>
  <div class="mid" style="font-size:22px">4 squads on this network &nbsp;·&nbsp; scanning udp/47777 on 192.168.1.24 …</div>
</div>
<div class="row" style="margin-top:20px;gap:16px">
  <div class="btn ghost clip grow">Rescan</div>
  <div class="btn ghost clip grow">Host instead</div>
</div>
""")

# ---------------------------------------------------------------- 05 room lobby
def member(name, agent, ready, me=False, host=False, color="var(--team-a)"):
    tag = ("&nbsp;·&nbsp; HOST" if host else "") + ("&nbsp;&nbsp;(you)" if me else "")
    return f"""<div class="row" style="height:62px;padding:0 16px;background:rgba(5,7,12,.6)">
      <div style="font-size:24px;white-space:nowrap;color:{color if me else 'var(--text-hi)'};
        font-weight:{700 if me else 400}">{name}{tag}</div>
      <div class="grow"></div>
      <div class="mid" style="font-size:22px;margin-right:24px">{agent}</div>
      <div style="font-size:22px;font-weight:700;color:{'var(--success)' if ready else 'var(--text-low)'}">
        {'READY' if ready else '…'}</div></div>"""

alpha = member("Agent-317", "Vanguard", True, me=True, host=True) + \
    member("Zaman", "Spectre", True) + member("Sahar", "Halo", False) + \
    '<div class="low" style="height:54px;display:flex;align-items:center;justify-content:center;font-style:italic">· open slot ·</div>'
bravo = member("Nawid", "Reaper", True, color="var(--team-b)") + \
    member("Bilal", "Forge", True, color="var(--team-b)") + \
    member("Omid", "Havoc", False, color="var(--team-b)") + \
    '<div class="low" style="height:54px;display:flex;align-items:center;justify-content:center;font-style:italic">· open slot ·</div>'

chat = "".join(f'<div class="mid" style="font-size:21px;height:28px">{m}</div>' for m in [
    "Zaman:&nbsp; take the east stair",
    "Nawid:&nbsp; we push mid on the timer",
    "Sahar:&nbsp; swapping to Halo, need heals",
    "Agent-317:&nbsp; ready when you are",
    "· Omid joined the room ·"])

SCREENS["05-room-lobby"] = ("Room lobby", header("Kabul Night Ops",
    "Team deathmatch &nbsp;·&nbsp; Kandahar Rooftops &nbsp;·&nbsp; 192.168.1.24", back=False) + f"""
<div style="display:flex;gap:20px;height:calc(100% - 230px)">
  <div class="panel clip" style="width:32%;padding:24px;border-color:rgba(59,232,255,.45)">
    <div class="row" style="height:34px"><div style="font-size:24px;font-weight:700;letter-spacing:.2em;color:var(--team-a)">TEAM ALPHA</div>
      <div class="grow"></div><div class="low" style="font-size:22px">3 / 4</div></div>
    <div class="divider" style="background:rgba(59,232,255,.3);margin:10px 0"></div>
    <div class="col" style="gap:10px">{alpha}</div>
  </div>
  <div class="panel clip" style="width:32%;padding:24px;border-color:rgba(255,122,59,.45)">
    <div class="row" style="height:34px"><div style="font-size:24px;font-weight:700;letter-spacing:.2em;color:var(--team-b)">TEAM BRAVO</div>
      <div class="grow"></div><div class="low" style="font-size:22px">3 / 4</div></div>
    <div class="divider" style="background:rgba(255,122,59,.3);margin:10px 0"></div>
    <div class="col" style="gap:10px">{bravo}</div>
  </div>
  <div class="panel clip grow" style="padding:22px;display:flex;flex-direction:column;gap:8px">
    <div class="cap">Squad comms</div><div class="divider"></div>
    <div class="col grow" style="gap:6px;padding-top:8px">{chat}</div>
    <div class="field" style="height:60px"><span class="ph">Message the squad …</span></div>
  </div>
</div>
<div class="row" style="margin-top:22px;gap:16px;width:64.5%">
  <div class="btn ghost clip grow" style="height:84px">Leave</div>
  <div class="btn ghost clip grow" style="height:84px">Swap team</div>
  <div class="btn ghost clip grow" style="height:84px;font-size:22px">Agent: Vanguard</div>
  <div class="btn green clip grow" style="height:84px">Deploy</div>
</div>
""")

# ---------------------------------------------------------------- 06 agent select
AGENTS = [
    ("Vanguard", "Assault", "Bulwark Dash", "#3BE8FF", True),
    ("Spectre", "Recon", "Thermal Sweep", "#B58CFF", False),
    ("Forge", "Engineer", "Deploy Barricade", "#FFB23B", False),
    ("Reaper", "Marksman", "Steady Aim", "#FF4D5E", False),
    ("Halo", "Support", "Nano Field", "#4DFFA6", False),
    ("Havoc", "Demolition", "Cluster Volley", "#FF7A3B", False),
]
cards = ""
for name, role, ability, color, sel in AGENTS:
    cards += f"""<div class="panel clip" style="height:150px;padding:16px 18px;display:flex;flex-direction:column;
      background:{'rgba(59,232,255,.16)' if sel else 'rgba(17,26,37,.85)'};
      border-color:{color if sel else 'var(--line)'}">
      <div class="cap" style="font-size:18px">{role}</div>
      <div style="font-size:34px;font-weight:700;letter-spacing:.08em;
        color:{color if sel else 'var(--text-hi)'}">{name.upper()}</div>
      <div class="grow"></div>
      <div style="font-size:19px;color:{'var(--success)' if sel else 'var(--text-mid)'}">
        {'EQUIPPED' if sel else ability}</div></div>"""


def stat(label, pct, value, color="var(--cyan)"):
    return f"""<div class="row" style="height:34px">
      <div class="cap" style="width:150px">{label}</div>
      <div class="grow">{bar(pct, color, 8)}</div>
      <div style="width:110px;text-align:right;font-size:20px">{value}</div></div>"""


SCREENS["06-agent-select"] = ("Agents", header("Agents", "Pick the operator you deploy with") + f"""
<div style="display:flex;gap:36px;height:calc(100% - 130px)">
  <div style="width:52%;display:grid;grid-template-columns:repeat(3,1fr);gap:16px;align-content:start">{cards}</div>
  <div class="panel clip grow" style="padding:34px;border-color:rgba(59,232,255,.5);display:flex;flex-direction:column;gap:10px">
    <div class="cy cap" style="color:var(--cyan)">Assault</div>
    <div style="font-size:62px;font-weight:700;letter-spacing:.06em">VANGUARD</div>
    <div class="mid" style="font-size:23px;line-height:1.5">Front-line breacher. Trades range for raw
      pressure and a shield dash.</div>
    <div style="height:10px"></div><div class="divider"></div><div style="height:10px"></div>
    {stat("HEALTH", 92, "120")}{stat("SPEED", 77, "6.2")}{stat("FIRE RATE", 75, "9.0/s")}{stat("DAMAGE", 16, "11")}
    <div style="height:14px"></div>
    <div class="cap">Signature ability</div>
    <div class="cy" style="font-size:30px;font-weight:700">Bulwark Dash</div>
    <div class="mid" style="font-size:22px">Dash forward behind a hard-light shield for 2s.</div>
    <div class="grow"></div>
    <div class="btn green clip">Deployed agent</div>
  </div>
</div>
""")

# ---------------------------------------------------------------- 07 hud
feed = "".join(f'<div style="font-size:21px;text-align:right;color:{c}">{t}</div>' for t, c in [
    ("Zaman &nbsp;⟶&nbsp; Omid &nbsp;&nbsp;rifle", "var(--text-mid)"),
    ("<b>Agent-317</b> &nbsp;⟶&nbsp; Bilal &nbsp;&nbsp;headshot", "var(--cyan)"),
    ("Nawid &nbsp;⟶&nbsp; Sahar &nbsp;&nbsp;marksman", "var(--team-b)"),
])

SCREENS["07-hud"] = ("In-match HUD", f"""
<div style="position:absolute;inset:0;background:
  linear-gradient(160deg,#0a1524 0%,#0d1c2b 42%,#1a1410 100%)"></div>
<div style="position:absolute;inset:0;background:
  radial-gradient(700px 420px at 68% 38%, rgba(255,178,59,.16), transparent 70%),
  radial-gradient(900px 520px at 20% 78%, rgba(59,232,255,.10), transparent 70%)"></div>
<!-- blocked-out skyline so the HUD reads against real scene contrast -->
<div style="position:absolute;left:0;right:0;bottom:0;height:44%;background:
  linear-gradient(180deg, rgba(3,6,10,.1), rgba(3,6,10,.92))"></div>
<div style="position:absolute;left:6%;bottom:22%;width:220px;height:300px;background:rgba(4,8,14,.85)"></div>
<div style="position:absolute;left:22%;bottom:22%;width:160px;height:420px;background:rgba(6,11,18,.8)"></div>
<div style="position:absolute;right:14%;bottom:22%;width:280px;height:360px;background:rgba(5,9,15,.85)"></div>

<div class="hud">
  <!-- objective bar -->
  <div style="position:absolute;left:50%;transform:translateX(-50%);top:20px;width:680px;height:104px;
    background:rgba(5,7,12,.55);display:flex;align-items:center;padding:0 28px;gap:24px" class="clip">
    <div style="width:120px;text-align:center;font-size:54px;font-weight:700;color:var(--team-a)">14</div>
    <div class="col grow" style="align-items:center">
      <div style="font-size:46px;font-weight:700;letter-spacing:.06em">03:12</div>
      <div class="cap" style="font-size:18px">Team deathmatch</div>
    </div>
    <div style="width:120px;text-align:center;font-size:54px;font-weight:700;color:var(--team-b)">11</div>
  </div>

  <!-- kill feed -->
  <div class="col" style="position:absolute;right:140px;top:40px;width:520px;gap:8px;align-items:flex-end">{feed}</div>

  <!-- pause -->
  <div class="btn ghost" style="position:absolute;right:24px;top:24px;width:96px;height:64px">II</div>

  <!-- crosshair -->
  <div style="position:absolute;left:50%;top:50%;transform:translate(-50%,-50%)">
    <div style="width:6px;height:6px;background:rgba(59,232,255,.9);margin:auto"></div>
    <div style="position:absolute;left:2px;top:-35px;width:2px;height:18px;background:rgba(59,232,255,.7)"></div>
    <div style="position:absolute;left:2px;top:23px;width:2px;height:18px;background:rgba(59,232,255,.7)"></div>
    <div style="position:absolute;top:2px;left:-35px;height:2px;width:18px;background:rgba(59,232,255,.7)"></div>
    <div style="position:absolute;top:2px;left:23px;height:2px;width:18px;background:rgba(59,232,255,.7)"></div>
  </div>

  <!-- vitals -->
  <div class="col" style="position:absolute;left:36px;bottom:56px;width:520px;gap:8px">
    <div class="row" style="height:34px"><div class="cy" style="font-size:26px;font-weight:700;letter-spacing:.16em">VANGUARD</div>
      <div class="grow"></div><div class="am" style="font-size:22px;font-weight:700">3x STREAK</div></div>
    <div style="font-size:44px;font-weight:700">86</div>
    {bar(86,'var(--success)',10)}{bar(52,'var(--cyan)',6)}
    <div style="height:6px"></div>
    <div class="cap" style="font-size:19px">Bulwark dash</div>
    {bar(64,'var(--amber)',6)}
  </div>

  <!-- ammo -->
  <div style="position:absolute;right:560px;bottom:44px;text-align:right">
    <div style="font-size:52px;font-weight:700">24<span class="low" style="font-size:30px"> / 120</span></div>
    <div class="cap" style="font-size:19px">MK-7 CARBINE</div>
  </div>

  <!-- touch controls -->
  <div style="position:absolute;left:96px;bottom:136px;width:230px;height:230px;border-radius:50%;
    background:rgba(85,103,125,.10);border:1px solid rgba(85,103,125,.25)"></div>
  <div style="position:absolute;left:163px;bottom:203px;width:96px;height:96px;border-radius:50%;
    background:rgba(59,232,255,.35)"></div>
  <div style="position:absolute;right:80px;bottom:90px;width:200px;height:200px;border-radius:50%;
    background:rgba(255,77,94,.16);border:2px solid rgba(255,77,94,.7);display:flex;align-items:center;
    justify-content:center;font-size:26px;font-weight:700;letter-spacing:.2em;color:var(--danger)">FIRE</div>
  <div style="position:absolute;right:335px;bottom:235px;width:130px;height:130px;border-radius:50%;
    background:rgba(255,178,59,.16);border:2px solid rgba(255,178,59,.7);display:flex;align-items:center;
    justify-content:center;font-size:20px;font-weight:700;letter-spacing:.14em;color:var(--amber)">ABILITY</div>
  <div style="position:absolute;right:335px;bottom:75px;width:130px;height:130px;border-radius:50%;
    background:rgba(59,232,255,.16);border:2px solid rgba(59,232,255,.7);display:flex;align-items:center;
    justify-content:center;font-size:20px;font-weight:700;letter-spacing:.14em;color:var(--cyan)">JUMP</div>
</div>
""")

# ---------------------------------------------------------------- 08 pause
SCREENS["08-pause"] = ("Paused", f"""
<div style="position:absolute;inset:0;background:linear-gradient(160deg,#0a1524,#0d1c2b 45%,#1a1410)"></div>
<div style="position:absolute;inset:0;background:rgba(5,7,12,.86)"></div>
<div class="panel clip" style="position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);
  width:720px;height:620px;padding:44px;display:flex;flex-direction:column;gap:14px;background:rgba(11,17,25,.95)">
  <div style="font-size:52px;font-weight:700;letter-spacing:.24em;text-align:center">PAUSED</div>
  <div class="mid" style="font-size:22px;text-align:center">The match keeps running — your squad still needs you.</div>
  <div style="height:16px"></div><div class="divider"></div><div style="height:16px"></div>
  {''.join(f'''<div class="row" style="height:38px"><div class="cap">{k}</div><div class="grow"></div>
    <div style="font-size:23px">{v}</div></div>''' for k, v in [
      ("MAP", "Kandahar Rooftops"), ("TIME LEFT", "03:12"),
      ("HOST", "Agent-317"), ("PING", "12 ms · LAN")])}
  <div class="grow"></div>
  <div class="btn clip">Resume</div>
  <div class="btn ghost clip" style="height:68px">Settings</div>
  <div class="btn red clip" style="height:68px">Leave match</div>
</div>
""")

# ---------------------------------------------------------------- 09 results
BOARD = [
    ("Vanguard", "Agent-317", 18, 7, 5, 2140, "a", True),
    ("Spectre", "Zaman", 15, 9, 3, 1780, "a", False),
    ("Reaper", "Nawid", 14, 11, 2, 1650, "b", False),
    ("Forge", "Bilal", 9, 12, 7, 1290, "b", False),
    ("Halo", "Sahar", 4, 10, 14, 1120, "a", False),
    ("Havoc", "Omid", 7, 15, 4, 940, "b", False),
]
board_rows = ""
for agent, name, k, d, a, sc, team, me in BOARD:
    tc = "var(--team-a)" if team == "a" else "var(--team-b)"
    bg = f"rgba(59,232,255,.12)" if me else "rgba(5,7,12,.45)"
    board_rows += f"""<div class="row" style="height:58px;padding:0 18px;background:{bg}">
      <div style="width:240px;font-size:23px;font-weight:700;color:{tc}">{agent}</div>
      <div style="width:320px;font-size:23px">{name}{'&nbsp;&nbsp;(you)' if me else ''}</div>
      <div style="width:90px;text-align:right;font-size:23px">{k}</div>
      <div style="width:90px;text-align:right;font-size:23px" class="mid">{d}</div>
      <div style="width:90px;text-align:right;font-size:23px" class="mid">{a}</div>
      <div class="grow"></div>
      <div style="width:140px;text-align:right;font-size:23px;font-weight:700;color:var(--amber)">{sc}</div></div>"""

SCREENS["09-results"] = ("Match results", f"""
<div style="position:absolute;left:0;right:0;top:0;height:19%;background:rgba(77,255,166,.14);
  display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px">
  <div class="ok" style="font-size:68px;font-weight:700;letter-spacing:.24em">VICTORY</div>
  <div class="mid" style="font-size:26px;letter-spacing:.16em">ALPHA 25 &nbsp;—&nbsp; 21 BRAVO</div>
</div>
<div class="panel clip" style="position:absolute;left:6%;right:6%;top:24%;bottom:16%;padding:30px;
  display:flex;flex-direction:column;gap:8px">
  <div class="row" style="height:32px">
    <div class="cap" style="width:240px">Agent</div><div class="cap" style="width:320px">Operator</div>
    <div class="cap" style="width:90px;text-align:right">K</div>
    <div class="cap" style="width:90px;text-align:right">D</div>
    <div class="cap" style="width:90px;text-align:right">A</div>
    <div class="grow"></div><div class="cap" style="width:140px;text-align:right">Score</div>
  </div>
  <div class="divider"></div>
  <div class="col" style="gap:8px">{board_rows}</div>
</div>
<div class="row" style="position:absolute;left:6%;right:6%;bottom:4%;height:82px;gap:16px">
  <div class="btn clip grow" style="height:82px">Rematch</div>
  <div class="btn ghost clip grow" style="height:82px">Back to lobby</div>
  <div class="btn ghost clip grow" style="height:82px">Leave squad</div>
</div>
""")

# ---------------------------------------------------------------- 10 settings
SCREENS["10-settings"] = ("Settings", header("Settings", "Tune identity, visuals and performance") + f"""
<div style="display:flex;gap:32px;height:calc(100% - 130px)">
  <div class="panel clip" style="width:56%;padding:36px;display:flex;flex-direction:column;gap:12px">
    <div class="cap">Callsign</div>
    <div class="field"><span>Agent-317</span></div>
    <div style="height:10px"></div>
    <div class="cap">Graphics tier</div>
    <div class="stepper" style="height:70px"><span>Cinematic</span><span class="chev">&gt;</span></div>
    <div class="cap">Frame rate</div>
    <div class="stepper" style="height:70px"><span>60 fps</span><span class="chev">&gt;</span></div>
    <div class="cap">Cinematic post-processing</div>
    <div class="stepper" style="height:70px"><span>On</span><span class="chev">&gt;</span></div>
    <div class="cap">Haptics</div>
    <div class="stepper" style="height:70px"><span>On</span><span class="chev">&gt;</span></div>
    <div class="grow"></div>
    <div class="btn clip">Save and go back</div>
  </div>
  <div class="col grow" style="gap:10px">
    <div class="cap">Device</div>
    {''.join(f'''<div class="row" style="height:36px"><div class="cap">{k}</div><div class="grow"></div>
      <div class="mid" style="font-size:21px">{v}</div></div>''' for k, v in [
      ("MODEL", "Samsung SM-A546E"), ("GPU", "Mali-G68 MC4"),
      ("MEMORY", "6144 MB"), ("LOCAL IP", "192.168.1.24"), ("BUILD", "0.1.0 (BOA1)")])}
    <div style="height:20px"></div>
    <div class="panel" style="padding:22px">
      <div class="cap" style="margin-bottom:10px">Rendering stack</div>
      <div class="low" style="font-size:19px;line-height:1.8;font-family:monospace">
        URP · Forward+<br>ACES tonemapping<br>Bloom 1.25 / thr 1.05<br>
        Split toning: cool shadows<br>Film grain 0.22 · Vignette 0.32</div>
    </div>
  </div>
</div>
""")

# ---------------------------------------------------------------------------
for slug, (title, body) in SCREENS.items():
    path = os.path.join(OUT, slug + ".html")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(SHELL.format(title="Battle of Agents — " + title, body=body))
    print("wrote", os.path.basename(path))
