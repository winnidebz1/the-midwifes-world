# Phase 1 implementation report

Modular adult character foundation for The Midwife's World. Godot 4.7.2, Compatibility renderer. Measured on 17 November 2026.

Phase 1.1 later corrected clothing covers, accessory sockets, catalogue validation, and malformed save handling. Those corrections and a second reading of this yard are in [PHASE1_TECHNICAL_REVIEW.md](PHASE1_TECHNICAL_REVIEW.md). The frame times below, and the single accessory slot named in the limitations, are the original Phase 1 readings.

The long-term art target remains cinematic photorealism. Every mesh in this phase is a placeholder box or sphere. The numbers below describe that placeholder, together with the existing test yard.

## Git checkpoint

The repository is on `main` and has no commits. Every project file was untracked when this phase started, so the working tree was not a clean committed snapshot. No checkpoint commit was created. Existing scenes, scripts, autoloads, input actions, and `project.godot` were left in place and edited only where this phase required it.

## Files created

| Path | Role |
| --- | --- |
| `characters/rig/adult/humanoid_adult_1.tscn` | Versioned adult visual scene |
| `characters/rig/adult/adult_rig.gd` | Skeleton, components, clips, and appearance application |
| `characters/rig/adult/appearance_catalogue.gd` | Loads the JSON catalogue into resources |
| `characters/rig/adult/clothing_resolver.gd` | Compatibility resolution |
| `characters/rig/adult/appearance_persistence.gd` | Read and write the appearance file |
| `scripts/resources/appearance_profile.gd` | Saveable selection and version fields |
| `scripts/resources/garment_definition.gd` | One garment record and its fit test |
| `data/appearance/catalogue.json` | Identity, skin, hair, face, proportion, component, and garment records |
| `tests/phase1_adult.gd` | Headless boot, movement, clothing, and save test |
| `tests/phase1_bench.gd` | Windowed frame measurement |

## Files modified

| Path | Change |
| --- | --- |
| `characters/scenes/player.tscn` | The visible capsule and nose mesh were removed. `HumanoidAdult1` is instanced under `Visual/Model`. Collision, camera, and `CharacterAnimation` stay |
| `scenes/prototype.gd` | Leaving the yard saves the current appearance |
| `README.md` | Points at the adult visual, the save file, and this report |
| `documentation/DEVELOPMENT_ROADMAP.md` | Records Phase 1 as done |
| `documentation/SYSTEM_ARCHITECTURE.md` | Records the rig, resolver, and appearance file |

`characters/scripts/player.gd`, `characters/scripts/character_animation.gd`, `scripts/components/third_person_camera.gd`, the three autoloads, the input map, and `project.godot` were not rewritten. The renderer is still `gl_compatibility`.

## Architecture implemented

The physics body remains the player `CharacterBody3D` and its capsule. The adult visual is a child of `Visual`. `player.gd` still yaws `Visual` toward camera-relative movement. The rig script does not move the body and does not rotate the camera pivot.

`humanoid_adult_1` builds a `Skeleton3D` named for a later skinned mesh: root, pelvis, spine, chest, neck, head, shoulders, arms, and legs. Skeleton version `1.0.0`. Placeholder body, hair, face, and garment meshes are parented to `BoneAttachment3D` nodes. Proportion values change bone pose position and scale. The reference stature is 1.72 m.

Appearance is data, selected by id:

- Identity: `adult_a`, `adult_b`
- Skin: `skin_warm`, `skin_deep`, each with roughness plus empty albedo, normal, and roughness texture paths
- Hair: `hair_short`, `hair_tied`, separate meshes
- Face: `face_narrow`, `face_broad`, which move the brow, jaw, and nose meshes
- Proportions: stature, shoulder, hip, leg, and torso, stored as numbers
- Components: body, hair, and face ids derived from the current selection
- Clothing slots: base, uniform upper, uniform lower, dress, outer, belt, footwear, accessory

The default selection is a placeholder base layer, scrub top, scrub trousers, belt, footwear, and name badge. A second combination is a placeholder dress with a placeholder apron. The same apron also resolves over the scrub top and trousers. Catalogue `evidence_status` is `placeholder`. These records are not a national or professional uniform standard.

`ClothingResolver` returns `compatible`, `compatible_with_limitations`, or `incompatible`. An incompatible result includes the garment id and the reason: missing catalogue id, wrong slot, body outside the tested stature, shoulder, or hip range, or another garment occupying the slot. A full dress occupies the upper and lower uniform slots, so requested scrub trousers stay in the selection and stay hidden. They are not replaced with a different garment. An apron without a scrub top or a dress stays equipped and is marked `compatible_with_limitations`.

`body_state` is stored and left at `none`. The rig does not change shape from any other value.

The save file is `user://the_midwifes_world/adult_appearance.json`. It stores schema version `1`, content version `phase1.adult.1`, rig family, skeleton version, identity, appearance ids, proportion numbers, requested clothing, compatibility results, missing ids, and warnings. A missing file uses the catalogue default. A file whose schema is not `1`, or whose rig family is not `humanoid_adult_1`, is rejected and the current appearance stays. An unknown hair, skin, face, proportion, or garment id is kept in the profile. Skin with an unknown id uses a neutral grey material that is not `skin_warm` or `skin_deep`.

The rig's `AnimationPlayer` has `Idle`, `Walk`, `Run`, and `Jump`. The existing `CharacterAnimation` node plays those clips from the movement state. The clips rotate leg bones. They do not drive the capsule.

## Tests

Headless command:

`Godot_v4.7.2-stable_win64_console.exe --headless --path <project> --script res://tests/phase1_adult.gd`

Result: `PHASE1_OK`, exit code 0. The run confirmed:

1. Boot opens, Enter opens the yard, and the second Escape returns to boot. The first Escape only releases the cursor.
2. The collision shape is still a capsule.
3. Walk speed reached the exported 2.6 m/s band, run reached the 5.2 m/s band, jump entered the jump state, and the clips followed the states.
4. `apply_look` changed camera yaw and pitch. Camera distance remained 4.5.
5. Identity, skin, hair, face, and stature changed independently of the other selections.
6. Apron over the dress is compatible, and the requested trousers are incompatible because the dress occupies that slot.
7. Scrub top and trousers are compatible together, and the apron is compatible over that pair.
8. Stature 1.55 m is `compatible_with_limitations` for the scrub top. Stature 2.20 m is `incompatible`, and that mesh is hidden.
9. A round trip restored identity, skin, hair, face, stature, dress, and apron.
10. Schema 99 was rejected. A partial file kept `retired_hair` and `retired_proportion` and equipped the dress that was actually listed.

No new script error was printed in that passing run.

## Performance

Machine: Intel Core i7-7600U, Intel HD Graphics 620, 16 GB RAM. Godot 4.7.2 stable. Project renderer `gl_compatibility`.

The windowed bench instantiated the test yard and one player, sampled 60 frames, then added three more adult rigs and sampled 60 frames. VSync was disabled for that process only. `project.godot` was not changed. The bench does not capture the mouse.

Startup line from Godot:

`OpenGL API OpenGL ES 3.0 (ANGLE 2.1.1) - Compatibility - Using Device: Google Inc. (Intel) - ANGLE (Intel, Intel(R) HD Graphics 620 Direct3D11 vs_5_0 ps_5_0, D3D11-27.20.100.8854)`

The engine reported that the installed OpenGL 3.3 driver is in its low-quality list, so it used ANGLE over Direct3D 11. `OS.get_video_adapter_driver_info()` returned an empty list in the same run. The driver version above is the version Godot printed on that ANGLE line. `rendering/rendering_device/driver.windows` remains `d3d12` and is unused while Compatibility is selected.

| Case | Frames per second | Frame time | Draw calls | Texture memory | Video memory |
| --- | --- | --- | --- | --- | --- |
| Yard plus one player | 54.52 | 18.342 ms | 66 | 6,874,731 bytes (6.56 MiB) | 13,393,979 bytes (12.77 MiB) |
| Yard plus four adult characters | 28.28 | 35.354 ms | 237 | 6,874,731 bytes (6.56 MiB) | 13,713,683 bytes (13.08 MiB) |

The player rig, on the default outfit, has 27 meshes, 23 visible, and 8 visible materials. A dress-only selection in the headless test had 16 visible meshes and 2 visible materials. Texture memory did not rise when three rigs were added. The catalogue texture paths are empty, so this memory is the frame, the shadow map, and the yard, not authored skin or cloth maps. Video memory rose by about 0.31 MiB for those three extra rigs.

These figures include the yard floor, two marker blocks, the procedural sky, and one shadow-casting directional light. They are not a budget for a photoreal character.

## Known limitations

- Body parts are separate meshes on bone attachments. There is no vertex skin, no blend shape, and no cloth deformation.
- Face records move brow, jaw, and nose meshes. They do not drive a facial rig.
- Garment fit tests stature, shoulder scale, and hip scale. Leg scale and torso scale are saved and posed, and they do not yet have their own garment ranges.
- Every garment mesh is created with the rig. Unequipped meshes are hidden. Hidden meshes are included in the total mesh count and are excluded from the visible count.
- One accessory slot is implemented.
- The animation clips are short leg swings on the placeholder skeleton.
- The appearance file does not store the character transform or the current scene.

## Deviations from the approved architecture

- The visual contract is a real skeleton and real swappable meshes. Binding is `BoneAttachment3D` until an authored skin exists.
- Skin records have texture slots. With those paths empty, the placeholder albedo colour and roughness are what the material shows.
- The catalogue is one JSON file rather than one `.tres` per record, so a missing id can be kept without a resource file to load.
- The appearance writer is not a new autoload. The yard calls it on exit.
- The public method is `select_identity`. Godot 4.7 already defines `Node3D.set_identity()`, and a script method of that name does not compile.
- The windowed bench disabled VSync for its own process so the frame time was not held to the display refresh. The project setting was left alone.

## Remaining work

This authorisation stops at Phase 1. Later work needs its own approval. Still open inside the adult foundation:

- Authored skinned meshes, facial blend shapes, and texture maps for the existing skin and garment slots
- Garment ranges for leg and torso scale
- A character-creator interface
- Scene and transform save, which remains Milestone 8

Pregnancy, child and infant rigs, other country modules, clinical scenarios, hospital and apartment scenes, and multiplayer were not started.
