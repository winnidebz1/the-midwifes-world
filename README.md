# The Midwife's World

A Godot 4 game in early foundation. Gameplay is not implemented yet. This repository currently holds the project configuration, the folder layout, and the technical plans for how the game will be built.

## Requirements

- Godot 4.7, matching `config/features` in `project.godot`
- GDScript
- Compatibility renderer (OpenGL)

No plugins, downloaded asset packs, or paid dependencies are part of this setup.

## Open the project

1. Install Godot 4.7.
2. In the Project Manager, import this folder.
3. Confirm the renderer shown for the project is **Compatibility**.
4. Open the project and press Play. The window title is **The Midwife's World**, and the boot scene opens.
5. Press Enter to enter the test yard. WASD walks, Shift runs, the mouse looks, and Space jumps. Escape releases the cursor, and Escape again returns to the boot scene. Click the yard to capture the mouse again. Leaving the yard writes the adult appearance to `user://the_midwifes_world/adult_appearance.json`.

Change `project.godot` from the editor when a milestone needs a setting. Read the current value first.

## Layout

| Path | Owns |
| --- | --- |
| `characters/` | Playable character scenes, the movement script, and `characters/rig/adult/` |
| `npcs/` | Non-player character scenes and their scripts |
| `environments/` | Locations, blockouts, and environment scripts |
| `scenes/` | Flow scenes that compose the other modules (boot, menus, gameplay shell) |
| `scripts/autoload/` | Global services. `GameState`, `GameFlow`, and `AudioService` are registered |
| `scripts/components/` | Reusable nodes shared by characters, NPCs, and other scenes |
| `scripts/resources/` | Custom `Resource` class scripts |
| `ui/` | Interface scenes and scripts |
| `audio/music/`, `audio/sfx/`, `audio/ambience/` | Sound files, grouped by bus |
| `assets/characters/`, `assets/npcs/`, `assets/environments/`, `assets/ui/` | Imported art for that domain |
| `assets/shared/` | Fonts, shaders, and other art used by more than one domain |
| `data/` | Authored content. `data/appearance/catalogue.json` is the Phase 1 adult catalogue |
| `documentation/` | Design and engineering documents. Godot ignores this folder |

Empty directories contain `.gitkeep` so they survive in Git. `.gitignore` is the Godot 4 template and ignores `.godot/` and `/android/`.

Domain scenes stay beside their scripts (`characters/scenes` with `characters/scripts`). Shared code stays in `scripts/`. Imported files stay in `assets/` or `audio/`, separate from the scenes that use them.

## Documents

- [Development roadmap](documentation/DEVELOPMENT_ROADMAP.md) — initial milestones and exit criteria
- [System architecture](documentation/SYSTEM_ARCHITECTURE.md) — module boundaries for the first playable slice
- [Phase 1 implementation report](documentation/PHASE1_IMPLEMENTATION_REPORT.md) — adult rig, clothing resolution, save/load, and measured performance

## Configuration

- Application name: `The Midwife's World`
- Main scene: `res://scenes/boot.tscn`. Enter opens `res://scenes/prototype.tscn`
- Autoloads: `GameState`, `GameFlow`, `AudioService` (unchanged)
- Input actions: `advance`, `back`, `move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `jump`
- First slice: 3D. The player body is a `CharacterBody3D` capsule. The visible adult is `humanoid_adult_1` under `Visual`, and the yard uses Jolt
- Adult catalogue: `data/appearance/catalogue.json`. Its garments are cosmetic placeholders, including a scrub set and a dress with an apron
- Audio buses: Master, Music, SFX, Ambience (`audio/default_bus_layout.tres`)
- Features: Godot 4.7, GL Compatibility
- Renderer: `gl_compatibility` for desktop and mobile. This was not changed for the 3D prototype
- 3D physics: Jolt Physics
- 3D collision layers: 1 `world`, 2 `actors`
- Window stretch: `canvas_items` / `expand`, engine default viewport. Kept, because the yard uses a screen-space hint and the 3D view already fills the window
- Icon: the default `icon.svg`

`rendering/rendering_device/driver.windows` remains `d3d12`. That driver applies to Forward+ and Mobile. The Compatibility renderer uses OpenGL, so the setting stays idle.

## Working agreement

- Extend an existing module before adding a new top-level folder.
- Keep content that can change without code in `data/` once resource types exist.
- Keep Forward+-only rendering features out of scenes. The limits are listed in the architecture document.
- Add a plugin only after the engine API is insufficient, and only if it is free of paid dependencies.
