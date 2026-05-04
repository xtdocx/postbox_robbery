# postbox_robbery

Immersive postbox robbery system for FiveM, built for the **Qbox** framework.

Players can pry open any `prop_postbox_01a` in the world using a crowbar. A bl_ui slider skill check decides the outcome — succeed and walk away with cash plus loot, fail and your hand gets stuck in the postbox while a police alert may fire.

## Features

- Works on every `prop_postbox_01a` map prop in the world — no manual placements needed
- Third-eye interaction via **ox_target**, gated on the player having **weapon_crowbar** equipped
- bl_ui `Progress` skill check (configurable rounds + difficulty)
- Skillcheck pops up immediately while the pry animation plays in parallel
- Failure plays the looping `pull_tooth_loop_weak_player` "stuck" animation and locks the player in place
- Server-validated cooldowns, weapon checks, and reward distribution
- Guaranteed cash + at least one item drop on every success
- Configurable police alert with job-filtered blip on failure
- Clean module structure following the Qbox / ox_lib `require` pattern

## Dependencies

| Resource | Purpose |
|---|---|
| [ox_lib](https://github.com/overextended/ox_lib) | `lib.callback`, `lib.notify`, `lib.class`, `require` |
| [qbx_core](https://github.com/Qbox-project/qbx_core) | Player object, money handling |
| [ox_target](https://github.com/overextended/ox_target) | Third-eye interaction |
| [ox_inventory](https://github.com/overextended/ox_inventory) | Item rewards, weapon detection |
| [bl_ui](https://docs.byte-labs.net/bl_ui) | Skill check minigame |

## Installation

1. Drop the `postbox_robbery` folder into your `resources/` directory (typically under `[illusion]` or any other category).
2. Make sure all listed dependencies are already installed and started before this resource.
3. Add to your `server.cfg`:
   ```cfg
   ensure postbox_robbery
   ```
4. Restart the server (or `refresh; ensure postbox_robbery` from the console).

## Configuration

All tunables live in [`shared/config.lua`](shared/config.lua). Highlights:

| Key | Description |
|---|---|
| `PROP_MODEL` | Postbox model hash. Default `prop_postbox_01a`. |
| `REQUIRED_WEAPON` | Weapon that must be equipped to start a robbery. Default `weapon_crowbar`. |
| `SKILLCHECK.iterations` | Number of bl_ui `Progress` rounds. |
| `SKILLCHECK.difficulty` | 1–100. Higher = faster slider, smaller target. |
| `STUCK.chance` | % chance of the stuck-hand penalty after a failed skill check. |
| `STUCK.durationMs` | How long the stuck animation locks the player (ms). |
| `REWARDS.cash` | Min/max cash payout on success. |
| `REWARDS.guaranteed` | Items that always drop on success. |
| `REWARDS.bonus` | Chance-rolled extras on top of the guaranteed pool. |
| `COOLDOWN.perPlayerMs` | Per-player cooldown between robbery attempts. |
| `POLICE_ALERT.chanceOnFail` | % chance to dispatch a police blip on failure. |

Item names must match real entries in your `ox_inventory/data/items.lua`.

## Project Structure

```
postbox_robbery/
├── fxmanifest.lua
├── shared/
│   ├── config.lua              # All tunables
│   ├── classes/
│   │   └── robbery.lua         # Robbery state OOP class
│   └── utils/
│       ├── random.lua          # Range / chance helpers
│       └── logger.lua          # Centralised logging
├── client/
│   ├── main.lua                # ox_target setup + entry point
│   ├── robbery.lua             # Robbery sequence / skill check / animations
│   └── dispatch.lua            # Police-alert blip handler
├── server/
│   └── main.lua                # lib.callback endpoints + validation
└── modules/
    ├── cooldowns.lua           # Per-player cooldown tracking
    └── rewards.lua             # Loot generation + payout distribution
```

## Customisation Tips

- **Different bl_ui minigame**: swap `Progress` for `CircleProgress`, `KeySpam`, `NumberSlide`, etc. in [`client/robbery.lua`](client/robbery.lua) — the call signature is identical.
- **Custom dispatch**: replace the implementation in [`client/dispatch.lua`](client/dispatch.lua) and `dispatchPoliceAlert` in [`server/main.lua`](server/main.lua) with your dispatch system of choice (ps-dispatch, cd_dispatch, etc.).
- **Different police jobs**: edit the `isPolice()` helper in [`client/dispatch.lua`](client/dispatch.lua).

## Author

See [AUTHORS.md](AUTHORS.md).

## License

Released under the MIT License — see [LICENSE](LICENSE) for details.
