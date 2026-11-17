# Development roadmap

Initial milestones for The Midwife's World. Each milestone ends with something that runs in Godot 4.7 on the Compatibility renderer, or with a written decision that later milestones depend on.

Gameplay systems, narrative content, and art production start only after the milestone that introduces them. Milestone 0 is the current state of the repository.

## How to use this document

- Finish the exit criteria before widening the next milestone.
- Keep new work inside the folders described in [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md).
- Change `project.godot` from the editor when a milestone requires it, after reading the current value.
- Stay on engine features. Plugins, downloaded packs, and paid assets are out of scope until a later decision says otherwise.

## Milestone 0 — Project foundation

**Status:** Done

**Goal:** A documented Godot 4.7 project with a place for every major module.

**Exit criteria:**

- `project.godot` inspected and left intact
- Folder layout for characters, NPCs, environments, scenes, scripts, UI, audio, assets, data, and documentation
- `README.md`, this roadmap, and `SYSTEM_ARCHITECTURE.md` in place
- No gameplay scenes or scripts added

## Milestone 1 — Runtime skeleton

**Status:** Done

**Goal:** The game boots into an empty shell, and global services have names and homes before gameplay code appears.

**Done:**

- Window title is `The Midwife's World`
- `scenes/boot.tscn` is the main scene. Enter (`advance`) opens the 3D prototype. Escape (`back`) returns
- Autoloads `GameState`, `GameFlow`, and `AudioService` are registered from `scripts/autoload/`
- Buses Master, Music, SFX, and Ambience exist in `audio/default_bus_layout.tres`
- Presentation for the first slice is a 3D world with a 2D hint overlay
- Stretch stays `canvas_items` / `expand`. The hint is screen-space, and the 3D view already fills the window, so the engine default viewport was left in place
- Movement actions are in the Input Map

**Exit criteria:**

- Play opens the boot scene on the Compatibility renderer
- The shell can change to another scene and return
- The presentation decision is written down

## Milestone 2 — Playable character

**Status:** Done for the first prototype

**Goal:** One character moves through an otherwise empty space.

**Done:**

- `characters/scenes/player.tscn` is a `CharacterBody3D` on collision layer `actors`. Phase 1 kept the collision capsule and replaced the visible capsule with the adult rig
- `characters/scripts/player.gd` moves from the Input Map, camera-relative, and jumps
- `scripts/components/third_person_camera.gd` yaws and pitches a spring arm behind the capsule
- The player script does not call `GameFlow` or read NPC or UI nodes

## Milestone 3 — First environment

**Status:** Done for the test blockout

**Goal:** One location the character can occupy, built as its own scene.

**Done:**

- `environments/scenes/test_yard.tscn` is a primitive floor, two marker blocks, a procedural sky, and one shadow-casting directional light
- `scenes/prototype.tscn` instances the yard and the player. Enter from boot opens it through `GameFlow`
- The shell sets `GameState.location_id` to `test_yard` and sends Escape back to boot
- Headless Godot 4.7.2 kept the player on the floor, moved about 2.25 m forward in half a second, jumped, turned the camera pivot, and returned to boot
- A windowed run on this machine used the Compatibility renderer. Captured mouse motion reached the camera script and changed yaw and pitch

**Still later:** a designed location, NPCs, and final art. The yard is a blockout.

## Phase 1 — Modular adult character

**Status:** Done

**Goal:** One versioned adult visual, with interchangeable appearance and clothing data, on the existing movement body and camera.

**Done:**

- `characters/rig/adult/humanoid_adult_1.tscn` is rig family `humanoid_adult_1`, skeleton version `1.0.0`
- The rig is a child of `Visual/Model`. `player.gd` and `third_person_camera.gd` were left in place
- `data/appearance/catalogue.json` holds identity, skin, hair, face, proportion, component, and garment records
- The clothing resolver returns `compatible`, `compatible_with_limitations`, or `incompatible` with a reason
- The placeholder set includes a base layer, scrub top, scrub trousers, dress, apron, belt, footwear, and a name badge. These records are cosmetic placeholders
- Idle, Walk, Run, and Jump clips play from the rig's `AnimationPlayer` when the existing movement state changes
- Appearance saves and loads through `user://the_midwifes_world/adult_appearance.json`, including schema, content, and skeleton versions
- Headless `tests/phase1_adult.gd` passed. Windowed measurements are in [PHASE1_IMPLEMENTATION_REPORT.md](PHASE1_IMPLEMENTATION_REPORT.md)

**Exit criteria:**

- Play still opens the boot scene, and Enter still opens the yard
- Walk, run, jump, mouse look, and the two-step Escape behaviour still work
- The collision capsule remains the physics body
- Identity, skin, hair, face, proportions, and clothing can be changed independently
- A missing or newer schema does not swap in an unrelated garment
- The renderer is still Compatibility

## Milestone 4 — NPC and interaction

**Status:** Not started

**Goal:** One NPC can be approached, and the character can start an interaction without either scene depending on the other's script.

**Work:**

- One NPC scene under `npcs/`
- A reusable interaction component under `scripts/components/`
- The character and the NPC communicate through signals on that component

**Exit criteria:**

- Interacting raises a signal the shell can observe
- Removing the NPC scene leaves the character playable

## Milestone 5 — UI shell

**Status:** Not started

**Goal:** A menu and a gameplay HUD exist as their own scenes, drawn above the world.

**Work:**

- Menu and HUD scenes under `ui/scenes/`, scripts under `ui/scripts/`
- The menu starts the gameplay shell through the scene-flow autoload
- The HUD listens to signals. It does not reach into character or NPC nodes to pull state

**Exit criteria:**

- The menu can start and leave gameplay
- The HUD updates from a signal emitted during the Milestone 4 interaction
- UI uses the project theme path only after a theme file is added under `ui/`

## Milestone 6 — Audio playback

**Status:** Not started

**Goal:** Music, effects, and ambience have one playback path.

**Work:**

- An audio autoload in `scripts/autoload/` that plays a `AudioStream` on the Music, SFX, or Ambience bus
- Call sites in the shell, character, NPC, and UI use that autoload
- Sound files, when they are produced, go in `audio/music/`, `audio/sfx/`, or `audio/ambience/`

**Exit criteria:**

- A stream assigned in the editor is audible on the correct bus
- Volume for each bus can be changed in one place
- No external audio is downloaded as part of the milestone

## Milestone 7 — Data-driven content

**Status:** Partly started. Phase 1 put the adult catalogue in `data/appearance/catalogue.json` and the matching resource scripts in `scripts/resources/`. A general editor `.tres` workflow for other content is still open.

**Goal:** The first piece of authored content lives in a resource, not in a script constant.

**Work:**

- Choose the first definition type once the game design names it (for example a character profile or a location entry)
- The class script goes in `scripts/resources/`
- One instance goes in `data/`
- The matching scene reads that resource on ready

**Exit criteria:**

- Editing the resource changes what the scene shows, without editing the scene script
- The resource loads in a scene run with F6

## Milestone 8 — Save and load

**Status:** Partly started. Phase 1 saves and loads the adult appearance. Scene id, character transform, and a menu save action are still open.

**Goal:** The small amount of session state from the slice survives a restart.

**Work:**

- A save autoload that writes and reads one save file under Godot's user data path
- Persist only state the slice already has (scene id, character transform, and fields stored on resources)
- Route the action through the menu from Milestone 5

**Exit criteria:**

- Save, quit, and load restore the shell to the saved scene and transform
- A missing save file starts a new session cleanly

## Milestone 9 — Compatibility pass

**Status:** Not started

**Goal:** The slice is honest about the Compatibility renderer and can be exported once.

**Work:**

- Play the slice and confirm it does not depend on Forward+-only features listed in the architecture document
- Check shadow cost in the first environment
- Create a local export preset for one desktop target and produce a test build

**Exit criteria:**

- The exported build reaches the menu, starts the slice, moves the character, and completes one interaction
- `project.godot` still selects `gl_compatibility`

## After the slice

Later milestones — dialogue content, additional locations, more characters, animation, and narrative structure — get their own sections when the first slice is playable. They should extend `data/` and the existing modules.

## Explicitly deferred

- Full game feature list and story structure
- Final art direction, animation sets, and a custom application icon
- Localization
- Controller glyphs and input remapping UI
- Cloud saves, analytics, and store integration
- Plugins and third-party assets
