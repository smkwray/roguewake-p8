# Rogue Wake

A PICO-8 naval tactics roguelite in the spirit of *Sid Meier's Pirates!* — sail
linked ports, manage your crew and coin, fight broadside-to-broadside against
merchants, privateers, and rivals, and chase one of several three-act goals
before your captain's luck runs out.

Runs in your browser via a custom WASM build of the FAKE-08 PICO-8 emulator.

## Play

**[▶ Play in your browser](https://smkwray.github.io/roguewake-p8/)**

Click the canvas first to give it keyboard focus.

## Controls

### Everywhere

| Key | Action |
|---|---|
| Arrows / WASD | Move / select |
| Z or N | ⓞ primary (confirm, fire, enter port) |
| X or M | ⓧ secondary (cancel, command, back) |
| Enter / Escape | Pause menu |

### World map & port menus

Arrows navigate, Z confirms, X goes back. In the market, left/right toggles
buy/sell and up/down picks a cargo.

### Battle

Ship combat uses a chord system. Holding Z or X alone enters **aim mode**
(time slows to 35%). Combining a held button with a direction issues a
command. Firing is automatic whenever a gun has a target in its broadside arc.

**Helm — no modifier held:**

| Key | Action |
|---|---|
| Left / Right | Turn |
| Up | Raise sail → more canvas, faster top speed, looser turns |
| Down | Reef sail → less canvas, lower top speed, tighter turns |

**Hold Z + direction — crew stance:**

| Combo | Stance |
|---|---|
| Z + Left | **Sailing** — faster helm and acceleration |
| Z + Up | **Gunnery** — faster reloads, harder broadsides |
| Z + Right | **Repair** — restore subsystem HP over time |
| Z + Down | **Boarding** stance (or launch boarding if in grapnel range) |

**Hold X + direction — ammo switch** (turning still works while X is held):

| Combo | Ammo |
|---|---|
| X + Up | **Round** — balanced damage |
| X + Down | **Chain** — shreds sails and rigging |
| X + Left | **Grape** — kills crew, drops morale |
| X + Right | **Heavy** — hull + subsystems, higher fire / flood chance |

Swapping ammo triggers a partial reload penalty on all guns.

**Hold Z + X — brace:**

Tapping the second button while the first is held commits a brace (~3.7s of
reduced incoming damage). You can't fire while braced, so pick your moment.

### Boarding mini-game

| Key | Action |
|---|---|
| Up / Down | Pick command |
| Z | Commit command |

## Features

**Three acts, escalating danger.** Each run has a goal (treasure galleon,
admiralty rank, bounty trophy, ...). Act 1 lets new captains find their feet;
by Act 3 privateers hunt you on every crossing and the final port is locked
behind your ship and reputation.

**Ship combat with real wind and momentum.** Six hulls (cutter through
galleon) each with their own acceleration curve, broadside weight, and cargo
room. Point of sail affects speed. Heavy ships spool up slowly; light ships
outmaneuver them. Cold starts take even longer.

**Subsystem damage.** Cannon fire targets hull, rigging, port guns, or
starboard guns. Cripple an enemy's rigging and they can't turn; silence their
starboard guns and close on that side. Fire and flood start probability scales
with heavy-shot hits.

**Ammo types and stances.** Round shot, chain (sails), grape (crew), heavy
(hull + subsystems). Crew stances trade speed for reload, fire rate, or
boarding readiness. Sail modes trade speed for maneuverability.

**Boarding.** Close to grapnel range, hold X to launch grapnels, then play
the boarding micro-game — crew + marines vs. enemy morale, with the option to
capture the ship outright.

**Port economy.** Six port types each with shipyard, market, tavern, and
admiralty options. Upkeep is charged on entry; fail to pay and you sell
belongings or face mutiny. Markets shift. Taverns carry rumors. Shipyards
trade up. Admiralties post contracts.

**Contracts.** Smuggle (contraband risks customs cutters), convoy (clear
hostiles before arrival), bounty (hunt a named rival). Each has distinct
triggers and rewards.

**Officer hiring.** Quartermaster, gunner, storm sailing master, surgeon,
boatswain — each with a specific passive.

**Perk doctrines.** Choose up to four doctrine perks per run. Reach renown
tiers to unlock more slots.

**Background classes.** Ten starting backgrounds (dock rat, disgraced
officer, corsair captain, navy deserter, ...) with thematic ship + gear
loadouts in rich-start mode.

**FX compatibility toggle.** The title menu has an `fx: full | low`
setting that halves ocean FX for weaker handhelds and older browsers.

## Running locally

**Desktop (macOS, native [FAKE-08](https://github.com/jtothebell/fake-08)):**

```bash
# if you have FAKE-08 already:
fake08 cart/rogue_wake.p8
```

**Web (WASM via emscripten):**

```bash
./build/bootstrap.sh   # one-time: installs emsdk + clones + patches fake-08
./build/build_web.sh   # builds docs/web/{index.html,index.js,index.wasm,index.data}
cd docs/web && python3 -m http.server 8765
```

Then open <http://localhost:8765/>.

The web build patches FAKE-08 (see `build/patches/`) to use
`emscripten_set_main_loop` and narrow the SDL init to video/audio/events only
— `SDL_INIT_EVERYTHING` fails on emscripten because haptic isn't supported.
The patched step function includes a 30fps gate to match native FAKE-08's
effective frame rate.

## Deploying

The `docs/` folder is a GitHub Pages deploy target. `docs/index.html`
redirects to `docs/web/`, which contains the compiled WASM bundle (~1.35MB
wasm + ~290KB cart data). Enable Pages on `main` / `/docs` in repo settings.

## Credits

- Engine: [FAKE-08](https://github.com/jtothebell/fake-08) by jtothebell, a
  cross-platform homebrew PICO-8 emulator. This repo includes emscripten
  patches in `build/patches/`; the upstream FAKE-08 repository does not
  officially support web builds.
- Fantasy console: [PICO-8](https://www.lexaloffle.com/pico-8.php) by
  Lexaloffle.
- Game: smkwray.

## License

Game cart (`cart/rogue_wake.p8`) and supporting code in this repository:
all rights reserved by the author, except where individual files carry
their own license notice.

FAKE-08 source (fetched by the bootstrap script, not included in this repo)
is licensed per its own [LICENSE](https://github.com/jtothebell/fake-08/blob/master/LICENSE.MD).
