# Cinderwatch — Godot 4.7.2 (Pure GDScript)

A complete **Godot 4.7.2** GDScript port of **Cinderwatch**: a self-playing 3D isometric tower defense with **zero external art or audio assets**. Every mesh, procedural texture array, shader, animation, and sound effect is generated in code.

## How to Run (Godot 4.7.2)

1. Extract `cinderwatch_godot_4_7_2.zip`.
2. Open **Godot 4.7.2** Project Manager -> **Import** -> select `project.godot`.
3. Press **F5** (Run Project). The AI Commander starts defending immediately; click any pad or press hotkeys to take control at any time.

## Controls

| Input | Action |
| :--- | :--- |
| Hover / Click Pad | Highlight pad & range; open Build / Upgrade / Sell menu |
| `1` – `4` | Build Archer Tower / Bombard / Storm Spire / Guard Post on hovered or selected pad |
| `U` | Upgrade hovered or selected tower |
| `X` | Sell selected tower |
| `Space` | Call next wave early for bonus gold |
| `C` | Toggle between AI Commander and Player Commander |
| `M` | Mute / Unmute procedural audio |
| `Esc` / Right-Click | Close menu |

## Project Structure

- `project.godot` — Godot 4.7.2 (`config_version=5`, Forward Plus) project configuration & InputMap
- `scenes/main.tscn` — Minimal root scene attaching `scripts/main.gd`
- `shaders/lit_world.gdshader` — Procedural `Texture2DArray` PBR shader with screen-space bump, wind sway, biome snow/moss/ash/sand cover, and instanced hit-flash
- `shaders/lit_water.gdshader` — Procedural water, frozen ice, flowing lava, and bog shader
- `shaders/post_process.gdshader` — Sub-texel crisp upscaling, tilt-shift blur, ACES Filmic grading, 8×8 Bayer ordered dithering, vignette, and film grain
- `scripts/util.gd` — Deterministic PRNG (`Mulberry32`), value/periodic noise, and Catmull-Rom spline utilities
- `scripts/biome.gd` — All 5 biomes (Ashen Pass, Frostfall, Mirefen, Emberscar, Duskmesa)
- `scripts/gfx.gd` — 11-layer `64×64` procedural `Texture2DArray` generator and `Soup` (`SurfaceTool`) mesh builder
- `scripts/layout.gd` — Procedural road, stream, and tower pad layout
- `scripts/terrain.gd` — `6×6` chunked terrain with cliff strata, ruined keep + beacon, biome flora/props, and crumble/rise transitions
- `scripts/rig.gd` — `MultiMeshInstance3D` (`PartBatch`) boneless character rigging and shatter debris physics
- `scripts/fx.gd` — Dynamic light pool (Moon, Fill, shadow-casting Beacon, 3 pooled tower SpotLights, 12 tower OmniLights, 4 flash lights), particles, chain lightning, and weather
- `scripts/towers.gd` — 4 tower types × 3 levels, piece-by-piece scaffolding build animation, flaming arrows, mortar shells, chain lightning, and dueling guard footmen
- `scripts/monsters.gd` — 21 monster types + 6 biome bosses with all special abilities (split, frenzy, sapper blast, wraith fade, drummer aura, summon, regen, armor, Frost Jotun tower freeze, Magma Colossus enrage)
- `scripts/game.gd` — Wave director, economy, biome progression, and self-playing AI Commander
- `scripts/audio.gd` — Pure-math procedural `AudioStreamWAV` synthesizer (SFX + looping wind/fire/drone ambience)
- `scripts/ui.gd` — HUD, wave/boss banners, build/upgrade/sell menu, and 3D range rings
- `scripts/main.gd` — Half-resolution `SubViewport` pipeline, texel-snapped orthographic `Camera3D`, input, and simulation loop

## Controls & Gamepad (D3)
- **Mouse / Keyboard**: Click a pad to build/upgrade, `1-4` pick/build tower, `U` upgrade, `X / Delete / Backspace` sell, `Space / Enter` call next wave, `C` toggle AI/Player command, `M` mute, `Esc` close menu.
- **Gamepad**: Left Stick / D-Pad selects pads & menu buttons (`0.22s` repeat), `A` confirm/open, `B` close, `X` upgrade, `Y / Start` call next wave. Moving the mouse immediately hides gamepad focus.

## Reproducible Web Export (E1)
```powershell
.\tools\build_web.ps1
python -m http.server 8080 -d build/web
```
Open `http://localhost:8080` in your browser.
