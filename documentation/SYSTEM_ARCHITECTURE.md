# System architecture

Technical structure for The Midwife's World. This describes how modules fit together in Godot 4.7. It does not specify story, mechanics, or content. Those arrive through the milestones in [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md).

The boot flow, the three services, and the first 3D blockout are in place. NPCs and saves are not.

## Engine baseline

Taken from the current `project.godot`:

| Setting | Value | Consequence |
| --- | --- | --- |
| Engine | Godot 4.7 | `config/features` includes `4.7` |
| Language | GDScript | No .NET project is configured |
| Renderer | Compatibility (`gl_compatibility`) on desktop and mobile | OpenGL feature set. See Rendering below |
| Windows RenderingDevice driver | `d3d12` | Used by Forward+ and Mobile. Idle under Compatibility |
| 3D physics | Jolt Physics | Used by the capsule and the yard |
| Stretch | `canvas_items` / `expand` | Kept for the 3D slice. The hint is screen-space, and the 3D view fills the window |
| Audio buses | Master, Music, SFX, Ambience | `audio/default_bus_layout.tres` |
| Main scene | `res://scenes/boot.tscn` | Enter opens `res://scenes/prototype.tscn`. Escape returns |
| Window title | `The Midwife's World` | `application/config/name` |
| First slice | 3D world, 2D hint overlay | `CharacterBody3D` in `characters/scenes/player.tscn` |
| Shell input | `advance`, `back`, move, `jump` | See the roadmap for keys |
| 3D collision | Layer 1 `world`, layer 2 `actors` | Player is layer 2 and collides with layer 1 |

2D physics stays on Godot's 2D physics engine. Jolt covers 3D only.

## Rules

1. **A module owns its scenes and its scripts.** Character code lives under `characters/`. NPC code lives under `npcs/`. A module reads another module through signals, a shared component, or an autoload service.
2. **Flow scenes compose modules.** `scenes/` instances characters, NPCs, environments, and UI. Those modules stay runnable on their own with F6.
3. **Shared behavior is a component.** A node script in `scripts/components/` is added to whatever scene needs it. Character and NPC hierarchies do not inherit from each other.
4. **Autoloads are services.** They handle flow, session state, audio, and saves. They do not represent a person, a place, or a widget. Service scripts live in `scripts/autoload/` and are registered in Project Settings when they are created.
5. **Authored content is a resource.** Class scripts live in `scripts/resources/`. Instances live in `data/`. Scenes receive resources through exports.
6. **Imported files stay out of logic folders.** Art goes to `assets/`. Sound goes to `audio/`. Scenes reference those files; they do not store source art beside scripts.
7. **Input goes through the Input Map.** Scripts check actions.
8. **The Compatibility renderer is the production renderer.** Scenes ship with features that renderer can draw.

```
scenes/                flow: boot, menu handoff, gameplay shell
    | instances
    +-- environments/  location
    +-- characters/    player actor
    +-- npcs/          other actors
    +-- ui/            menus and HUD (CanvasLayer)

scripts/components/    nodes added inside the scenes above
scripts/resources/     data types, instanced under data/
scripts/autoload/      GameFlow, GameState, AudioService, SaveService
```

## Directory ownership

| Path | Responsibility | Does not hold |
| --- | --- | --- |
| `characters/scenes/`, `characters/scripts/` | Playable actors, their cameras if the camera is part of the actor, and player-only behavior | NPC logic, menu layout |
| `npcs/scenes/`, `npcs/scripts/` | Non-player actors and their local behavior | Player input handling |
| `environments/scenes/`, `environments/scripts/` | Locations, collision for the place, local props that are not actors | Character controllers |
| `scenes/` | Root scenes that wire modules together and any temporary slice scenes | Domain logic that belongs to one actor |
| `scripts/autoload/` | Process-wide services | Per-actor state |
| `scripts/components/` | Interaction, locomotion pieces, and other nodes reused across domains | Content tables |
| `scripts/resources/` | `class_name` resource types | Saved `.tres` instances |
| `ui/scenes/`, `ui/scripts/` | Control trees, HUD, menus | World queries that walk actor trees |
| `audio/music/`, `audio/sfx/`, `audio/ambience/` | Streams for the matching bus | Playback code |
| `assets/<domain>/` | Textures, models, and sprites for that domain | Scripts |
| `assets/shared/` | Fonts, shaders, and art used by several domains | Domain-specific meshes |
| `data/` | `.tres` and other authored tables | Class scripts |
| `documentation/` | Roadmap, architecture, and later design notes. `.gdignore` keeps Godot from importing the folder | Game resources |

Add a subfolder inside a module when the first real file needs it. Avoid empty categories beyond this layout.

## Runtime modules

`GameState`, `GameFlow`, and `AudioService` are autoloads. `SaveService` is added in Milestone 8.

### GameFlow

Owns scene changes. Callers pass a scene path or a packed scene. GameFlow performs `change_scene_to_packed` (or the file equivalent) and emits `scene_changed` after the new scene is current. Menus, interaction outcomes, and saves ask GameFlow to move. They do not call `get_tree().change_scene_*` themselves.

### GameState

Holds session facts the shell needs across scene changes: current location id, and later the small set of flags the slice actually uses. Actors push changes with methods or signals. UI reads a snapshot or listens for `state_changed`. GameState does not spawn characters or load levels. GameFlow does the load.

### AudioService

Plays one-shots and looping streams on the Music, SFX, and Ambience buses. Exposes play, stop, and bus volume. Callers pass a stream or a path under `audio/`. They do not create `AudioStreamPlayer` nodes ad hoc in gameplay scripts. The bus layout is Master, with Music, SFX, and Ambience under it, stored in `audio/default_bus_layout.tres`. No sound files are hooked up yet.

### SaveService

Serializes the slice of GameState plus the character transform for the active location. Writes under `user://`. Load asks GameFlow to open the stored scene, then applies the transform once that scene is ready. SaveService stays dormant until Milestone 8.

Per-actor details that are not session facts stay on the actor or on its resource.

## Scene composition

A gameplay shell in `scenes/` looks like this once Milestones 2 through 5 exist:

```
Gameplay (Node)
├── Environment          instance from environments/scenes
├── Actors (Node)
│   ├── Character        instance from characters/scenes
│   └── Npc              instance from npcs/scenes
└── HUD                  CanvasLayer instance from ui/scenes
```

The shell is the only scene that knows all four paths. The character scene exports a spawn transform or reads one the shell sets. The environment scene contains geometry and collision and remains free of actor instances, so it can open alone.

UI sits on a `CanvasLayer` above the world. Menu scenes replace the shell through GameFlow. The HUD stays inside the shell.

### Characters and NPCs

Both are actor scenes with the same shape: a body, a visual, and optional component children. The player scene handles Input Map actions. NPC scenes handle their own local behavior and do not read player input.

Shared actions, such as "this body can be interacted with", are components:

```
Actor (CharacterBody3D, group "actor")
├── CollisionShape3D     capsule. This is the physics body
├── Visual               player.gd yaws this node toward movement
│   └── Model
│       └── HumanoidAdult1   characters/rig/adult/humanoid_adult_1.tscn
├── CameraPivot          scripts/components/third_person_camera.gd
└── CharacterAnimation   plays Idle, Walk, Run, or Jump when those clips exist
```

The player keeps four movement states: idle, walk, run, and jump. Horizontal speed eases between the exported walk and run speeds, and the body turns toward the move direction. `locomotion_blend` moves from 0 to 2 for a future blend space. `CharacterAnimation` finds the `AnimationPlayer` under `Visual` and plays `Idle`, `Walk`, `Run`, and `Jump`.

`HumanoidAdult1` is rig family `humanoid_adult_1`, skeleton version `1.0.0`. It builds a `Skeleton3D` and parents placeholder meshes to `BoneAttachment3D` nodes. It does not call `move_and_slide`, and it does not rotate `CameraPivot`. Replacing the visual means replacing that scene under `Visual/Model`.

Appearance records live in `data/appearance/catalogue.json`. The working selection is an `AppearanceProfile`: identity, skin, hair, face, body proportions, clothing slots, compatibility results, missing ids, and schema, content, and skeleton versions. `body_state` is stored as `none`. Phase 1 does not change the mesh from that field.

Clothing slots are `base`, `uniform_upper`, `uniform_lower`, `dress`, `outer`, `belt`, `footwear`, and `accessory`. `ClothingResolver` returns one of three levels for each requested id:

| Level | Meaning |
| --- | --- |
| `compatible` | The garment passes the tested stature, shoulder, and hip range, and no occupied slot rejects it |
| `compatible_with_limitations` | The garment is inside the limited range, or an outer layer has no uniform or dress under it. The reason text is kept |
| `incompatible` | The body is outside the tested range, the id is missing, the slot does not match, or another garment occupies the slot. The reason names the garment and the range or the occupying id |

A rejected id stays in the saved selection. The resolver does not substitute a different garment. A missing skin id keeps that id and shows a neutral grey material that is not one of the catalogue skin sets. Schema version `1` and rig family `humanoid_adult_1` are required. Any other schema or rig family leaves the current appearance in place.

The yard writes the profile to `user://the_midwifes_world/adult_appearance.json` when `scenes/prototype.gd` leaves the tree. There is no save autoload. The garment records in the catalogue are cosmetic placeholders, with `evidence_status` set to `placeholder`.

Measured frame cost for these placeholders is in [PHASE1_IMPLEMENTATION_REPORT.md](PHASE1_IMPLEMENTATION_REPORT.md).

`Interactable` is still a later component. It will emit `interaction_started` with a reference to itself. The character script does not `get_node` into an NPC scene.

Groups in use: `actor` on the player. Add `interactable` when that component exists.

3D physics layers:

| Bit | Name | Used by |
| --- | --- | --- |
| 1 | `world` | Floor and marker blocks. The camera spring arm collides with this layer only |
| 2 | `actors` | The player body |

### Components

A component is a child node with one job and a signal or a small method API. It may call up to its parent actor through `get_parent()` only when the parent contract is explicit (the parent is the body the component moves). It does not search the tree with `find_child` across module boundaries.

### Resources

A resource describes content. A scene presents it. Phase 1 uses `GarmentDefinition` and `AppearanceProfile` in `scripts/resources/`. The catalogue instance is JSON so the resolver can keep an unknown id without a matching resource file. Example shape for later editor-authored content:

```
# scripts/resources/character_profile.gd
class_name CharacterProfile
extends Resource

@export var display_name: String
@export var portrait: Texture2D
```

The `.tres` file lives in `data/`. The actor script has `@export var profile: CharacterProfile` and reads `profile.display_name`. Swapping the resource swaps the content.

Prefer `Resource` over JSON for data the editor should check. Use a text table only when a milestone needs a format the editor resource system handles poorly.

## Communication

| From | To | Channel |
| --- | --- | --- |
| Menu | Gameplay shell | GameFlow |
| Character | HUD | Signal on the character or on a component, connected by the shell |
| Character | NPC | `Interactable` signal. No direct script reference |
| Any scene | Music, SFX, ambience | AudioService |
| Any scene | Session flags | GameState |
| Menu | Disk | SaveService, which then calls GameFlow. Phase 1 appearance uses its own file and is not this service yet |

Signals cross module borders. Direct method calls stay inside a module or on a service. Cyclic references between `characters/` and `npcs/` are a sign the shared piece belongs in `scripts/components/` or in a signal on the shell.

Autoload access uses the autoload name registered in Project Settings. Domain scripts do not `load()` service scripts to work around that.

## Rendering

Production rendering is Compatibility. OpenGL draws the frame. The `d3d12` project setting does not apply until the renderer changes.

Features the Compatibility renderer can use, from the Godot renderer comparison:

- Depth and height fog, tonemapping, glow, color adjustments
- Screen-space ambient occlusion
- A fullscreen quad for custom post-processing
- LightmapGI display of lightmaps baked in the editor

Features to leave unused while this renderer stays selected:

- Volumetric fog and fog volumes
- Screen-space reflections and screen-space indirect lighting
- SDFGI and VoxelGI
- Decal nodes
- CompositorEffect post-processing
- Particle trails and particle SDF collision
- Depth of field
- HDR output and a 2D HDR viewport
- RenderingDevice / compute access

3D color output is low dynamic range. Shadow-casting lights are drawn in extra passes, and their lighting is blended in sRGB space, so a shadowed light and an unshadowed light do not match. Keep a handful of shadow-casting lights in view, spaced so a surface is covered by one or two of them.

LightmapGI can be shown with this renderer. Baking a lightmap needs the Forward+ or Mobile renderer in the editor. Bake only under an explicit decision, then switch the project back to Compatibility before the work is considered done.

2D work uses `CanvasItem` nodes and is drawn inside the same Compatibility renderer. UI stays on `CanvasLayer` so it is independent of the world camera.

Shaders go in `assets/shared/` and stay on the Compatibility shader types (`canvas_item`, `spatial` under the Compatibility backend). Test a new shader in a scene run with the project renderer before other scenes depend on it.

## Physics

- 3D bodies, areas, and joints use Jolt, as set in `project.godot`.
- 2D bodies use Godot Physics 2D. The boot screen and the yard hint are `Control` nodes and do not use 2D physics.
- The prototype actor is a `CharacterBody3D`. A single actor does not mix 2D and 3D physics bodies.

Movement code lives on the actor or on a locomotion component. It uses `move_and_slide` and the Input Map.

## What is deliberately unset

| Topic | When it is decided |
| --- | --- |
| Movement actions beyond the current set | When a control scheme grows past WASD, arrows, mouse look, and jump |
| Collision layers beyond `world` and `actors` | When an interaction or NPC volume needs its own bit |
| Further resource types beyond adult appearance | Milestone 7, for content other than the Phase 1 catalogue |
| Narrative systems (dialogue trees, tasks, relationships) | After Milestone 8, as new resources and components |
| Custom icon, localization, remapping UI | After the first slice |

Until those decisions exist, avoid speculative managers for inventory, quests, dialogue, or time of day. Add a module when a milestone has a scene that needs it, and give it a folder inside the layout above.
