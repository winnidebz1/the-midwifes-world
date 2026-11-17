# Phase 1 technical review

Verification of the adult-character foundation, followed by the Phase 1.1 correction pass. Both were done on 17 November 2026 with Godot 4.7.2 stable on the Intel Core i7-7600U, Intel HD Graphics 620, 16 GB machine. The project renderer remained `gl_compatibility`. No Phase 2 work was started.

The first pass recorded the defects below and changed no character code. The correction pass then fixed those defects, added `tests/phase1_1_regressions.gd`, and measured the yard again. The temporary measurement script was removed afterwards. No meshes were deleted to improve a frame rate.

## Defects corrected

The review found six clothing and save defects. Each one is corrected in the current code.

1. **One accessory slot.** Accessories now use exclusive sockets. The shipped sockets are `chest` (`placeholder_name_badge`) and `wrist` (`placeholder_wrist_band`). A request may use the legacy string key `accessory` or the array key `accessories`. Each requested id is kept. Save and load restore both ids, and both meshes are shown when the sockets differ.
2. **`covers` was stored and never applied.** A garment now hides another equipped surface only when that surface's slot is listed in `covers` and its region is listed in `covered_regions`. The covering garment does not hide itself. Regions that are not listed stay visible.
3. **A dress without `occupies` was treated as a wearable garment.** A dress record that omits `occupies` is invalid catalogue content. The shipped dress still lists `uniform_upper` and `uniform_lower`, so it still blocks scrub trousers.
4. **A reversed size range was reported as a body mismatch.** A range whose minimum is not below its maximum is invalid catalogue content. The reason says the range is reversed or empty and that this is catalogue content, distinct from a body-fit result.
5. **A record with no content id was accepted as a garment.** A missing content id fails catalogue validation.
6. **A clothing string or a proportions array crashed the loader.** `AppearanceProfile.from_save_dictionary` checks the whole record before it builds a profile. A malformed record returns `ok: false`, an error code, and a diagnostic, and the current appearance stays in place.

Compatibility levels are `compatible`, `compatible_with_limitations`, `incompatible`, and `invalid_content`. The same request produces the same results. Accessory ids are sorted before socket assignment, so the earlier id in that order keeps an exclusive socket. The other id stays in the request, with the reason `Socket chest already holds placeholder_name_badge, so placeholder_second_badge stays off. It was not replaced with a different accessory.`

A missing catalogue id stays `incompatible`, with `missing_content: <id> is not in the installed catalogue and was not replaced.` That is a missing installed garment. `invalid_content` is a garment record that is present and malformed. Neither path substitutes another garment.

The base layer is five regional meshes: torso, both sleeves, and both legs. The shipped dress covers the base torso and both base legs. Both sleeves stay visible. The apron covers the dress torso and the scrub-top torso. The dress skirt region and the scrub trousers stay visible. Scrub top and scrub trousers also cover the matching base regions, and the sleeves stay visible under that outfit.

Catalogue content version is `phase1.adult.1.1`. An older save still loads. The loader records `content_version_differs` and does not rewrite the unknown ids.

## Regression tests and results

Headless, `Godot_v4.7.2-stable_win64_console.exe --path <project> --script res://tests/phase1_1_regressions.gd`.

Result: `PHASE11_OK`, exit code 0.

| Case | Result |
| --- | --- |
| Apron over dress, with base and requested trousers | Dress and apron `compatible`. Trousers `incompatible` because the dress occupies `uniform_lower`. Base torso and left leg hidden. Both sleeves visible. Dress torso hidden. Dress skirt visible. Apron visible. Trousers hidden |
| Apron over scrubs, with base | Apron, scrub top, and scrub trousers `compatible`. Scrub torso hidden. Trousers visible. Left sleeve visible. Base torso hidden |
| Two accessories | `placeholder_name_badge` and `placeholder_wrist_band` both `compatible` and both visible |
| Two accessories, one exclusive socket | Sorted ids. `placeholder_name_badge` stays `compatible`. `placeholder_second_badge` is `incompatible` with a `Socket chest` reason. A second resolve returns the same results |
| Dress with no `occupies` | Catalogue classification invalid, diagnostic contains `missing occupies`. Resolver level `invalid_content`. The reason does not say the body is outside a range. The valid trousers in the same request stay `compatible` |
| Reversed stature ranges | Catalogue classification invalid. Resolver level `invalid_content`. The reason contains `reversed` |
| Record with no content id | Diagnostic contains `missing content id`. Resolver level `invalid_content`. The valid footwear in the same request stays `compatible` |
| Clothing supplied as a string | `malformed_clothing`. Diagnostic contains `clothing must be an object`. Identity and dress unchanged |
| Proportions supplied as an array | `malformed_proportions`. Identity unchanged |
| `stature_m` supplied as the string `tall` | `invalid_proportion_type`. Diagnostic names `stature_m`. Identity unchanged |
| Clothing slot value `12` | `malformed_clothing`. Identity unchanged |
| Proportions object containing only `stature_m` 1.81 | Load succeeds. Stature stays 1.81. Missing shoulder scale uses the documented default 1.0 and records `proportion_key_missing:shoulder_scale`. Footwear equips. The previous dress is not kept |
| Unknown identity, skin, hair, and apron ids | Those ids stay. The known dress equips. `placeholder_apron` is not substituted. `retired_apron` is listed in `missing_ids`. Unknown skin uses the neutral grey fallback |
| Accessory array save and load | Both accessory ids and both meshes come back |

The original suite was run again after its apron assertion was updated to the covers rule: the apron and the scrub top stay compatible, the scrub torso is hidden, and the scrub trousers stay visible.

Headless, `--script res://tests/phase1_adult.gd`.

Result: `PHASE1_OK`, exit code 0. Boot, yard flow, capsule collision, walk, run, jump, and camera were unchanged. The default outfit reported 32 meshes, 24 visible, and 8 visible materials.

## Rig verification

No photorealistic mesh was created. The scene file is still a `Node3D` plus `adult_rig.gd`. At runtime the script builds a `Skeleton3D` of 16 bones and an `AnimationPlayer` with `Idle`, `Walk`, `Run`, and `Jump`.

These are separate mechanisms.

| Mechanism | What the project actually has |
| --- | --- |
| Skeleton and animation | Sixteen bones and four generated clips. Each clip writes quaternion keys at the start, the middle, and the end. Walk, run, and idle loop. Jump does not. The tracks are `UpperLegL`, `UpperLegR`, `LowerLegL`, `LowerLegR`, `UpperArmL`, `UpperArmR`, and `Spine` |
| Bone-attached primitive components | Every body, face, hair, and garment mesh is a `BoxMesh` or, for the head, a `SphereMesh`, parented to a `BoneAttachment3D`. The attachment follows the named bone |
| Skinned mesh and vertex weights | Not implemented. `MeshInstance3D.skin` is null on the measured upper leg and upper arm. There is no skin resource and no blend shape. The boxes do not deform |
| Interchangeable character meshes | Catalogue ids show and hide separate meshes, and face ids move the brow, jaw, and nose on the head attachment. Replacing the visual means replacing the scene under `Visual/Model`. That replacement mesh does not exist yet |

The headless regression sought `Walk` at 0.4 s and compared a point on each mesh, 0.16 m up and 0.04 m forward of the mesh origin, with the idle pose at 0.0 s.

| Part | Parent | Movement at the sampled point |
| --- | --- | --- |
| `UpperLegL` | `BoneAttachment3D` on `UpperLegL` | 0.0615 m |
| `LowerLegL` | `BoneAttachment3D` on `LowerLegL` | 0.1273 m |
| `UpperArmL` | `BoneAttachment3D` on `UpperArmL` | 0.0237 m |
| `ChestBody` | `BoneAttachment3D` on `Chest` | 0.0270 m from the spine track |

`Jump` at 0.17 s moved the upper-leg sample more than 0.02 m from the idle pose. Seeking `Idle` at 0.0 s returned that sample to 0.0020 m from the idle pose, and more than 0.02 m away from the walk pose.

A mesh origin that sits on the bone pivot does not translate when that bone only rotates. The first measurement of `UpperLegL.global_position` stayed at 0.000 m while the lower-leg origin, which is offset from the rotating thigh, moved. The offset-point measurement above is the one that shows the thigh, arm, and chest boxes turning with their bones.

Parts that are not driven by a bone:

- `Player` (`CharacterBody3D`) and its capsule `CollisionShape3D` follow the movement script.
- `CameraPivot`, `PitchPivot`, `SpringArm`, and `Camera3D` follow the camera script. They are siblings of `Visual`, not children of the skeleton.
- `CharacterAnimation` is a logic node. It plays the named clip. It is not a mesh.
- `Root`, `Neck`, `ShoulderL`, and `ShoulderR` have no mesh of their own. `Spine` has no mesh of its own. The chest attachment is a child bone of the spine, so the spine track moves the chest box.

Face brow, jaw, and nose are children of the head attachment and carry a local offset. They follow the head bone. Hair meshes are also on the head attachment and are shown or hidden by hair id.

## Performance measurements

No visual feature was removed. The corrected rig has more meshes than the rig that produced the earlier numbers: the base layer is five regions, and the wrist band adds one hidden mesh on the default outfit. The default outfit now has 32 meshes and 24 visible. The earlier inventory was 27 meshes and 23 visible. Draw calls were expected to change, and they did.

### Earlier readings

Both earlier readings used `Godot_v4.7.2-stable_win64_console.exe` with `--script`, the Compatibility renderer, VSync disabled in that process, and the same yard: procedural sky, one shadow-casting directional light named Sun, a floor, and two marker blocks, plus the player. `project.godot` was not edited. The mouse was not captured. The character code was the same for both, so the gap between them is not an optimisation.

| Reading | Window | Warm-up | Capture | One character | Four characters |
| --- | --- | --- | --- | --- | --- |
| Phase 1 report | Engine default, size not recorded | 20 frames | 60 frames, last-frame draw counter | 54.52 fps, 18.342 ms, 66 draws, texture 6,874,731 bytes, video 13,393,979 bytes | 28.28 fps, 35.354 ms, 237 draws, texture 6,874,731 bytes, video 13,713,683 bytes |
| Technical review, before this correction | 1280×720 | 30 frames | 120 frames, draw count constant | 249.50 fps and 251.78 fps, about 4.0 ms, 64 draws, texture 8,275,563 bytes, video 14,794,811 bytes | 186.68 fps and 194.36 fps, 5.357 ms and 5.145 ms, 149 draws, texture 8,275,563 bytes, video 15,114,515 bytes |

Godot printed the same driver path for the windowed review: installed OpenGL 3.3 is in the low-quality list, so the process used ANGLE 2.1.1, OpenGL ES 3.0, over Direct3D 11 `D3D11-27.20.100.8854` on Intel HD Graphics 620. `OS.get_video_adapter_driver_info()` was empty. The `d3d12` project setting stays unused under Compatibility.

The review also measured the pre-correction frame with garments hidden (45 draws), every mesh forced visible (75 draws), and the yard sun shadow turned off (25 draws, 2.678 ms). Hidden meshes were not drawn. The shadow pass accounted for most of the 64 draws. That shadow-off sample was not repeated in this correction pass.

### Reconciled readings

One windowed process, after these corrections, ran both historical protocols. A shared warm-up of 90 frames ran first, so neither protocol was the cold start of the process. VSync mode was `0` (`VSYNC_DISABLED`). The scene was the same yard and player, then three extra `humanoid_adult_1` instances. Mouse mode stayed `0`.

The process reported `OS.is_debug_build() == true` and the `editor` feature. That is the official console binary running a script. It is not an exported release player. Both earlier readings used that same invocation. None of the three sessions is a release export.

Startup line:

`OpenGL API OpenGL ES 3.0 (ANGLE 2.1.1 git hash: aaebda1c5a40) - Compatibility - Using Device: Google Inc. (Intel) - ANGLE (Intel, Intel(R) HD Graphics 620 (0x00005916) Direct3D11 vs_5_0 ps_5_0, D3D11-27.20.100.8854)`

| Protocol | Window measured | Warm-up | Capture | One character | Four characters |
| --- | --- | --- | --- | --- | --- |
| A, the Phase 1 method | 1152×648, the engine default on this run | 20 frames after the shared 90 | 60 frames | 191.24 fps, 5.229 ms, 69 draws on every frame, texture 6,874,731 bytes, video 13,397,699 bytes | 99.19 fps, 10.082 ms, 249 draws on every frame, texture 6,874,731 bytes, video 13,728,563 bytes |
| B, the review method | 1280×720 | 30 frames | 120 frames | 187.85 fps, 5.323 ms, 69 draws on every frame, texture 8,275,563 bytes, video 14,798,531 bytes | 103.42 fps, 9.669 ms, 249 draws on every frame, texture 8,275,563 bytes, video 15,129,395 bytes |

Frame time is the average of `Time.get_ticks_usec()` around each `process_frame`. Draw calls were read on every captured frame. Minimum, maximum, and last frame were the same number.

What the comparison shows:

- Window size does not explain 54 fps versus 250 fps. After the shared warm-up, 1152×648 and 1280×720 differ by about 3 fps for one character. The smaller window was slightly faster. Texture memory still matches the historical split exactly: 6,874,731 bytes at 1152×648 and 8,275,563 bytes at 1280×720.
- Renderer, driver, VSync, scene, and binary class are the same across the original report, the review, and this pass. Debug versus release does not differ between them, because none of them was an exported release build.
- Capture length does not explain the gap. The 60-frame sample and the 120-frame sample in this process agree.
- The original 18.3 ms frame and the review's 4.0 ms frame were two sessions of the pre-correction rig. This pass does not reproduce either extreme. The warmed one-character cost of the corrected rig is about 5.2 ms, near 190 fps, at both window sizes.
- One-character draw calls rose from 64 to 69. The default outfit shows one more mesh than before (24 visible, was 23) because the base layer now draws both sleeves while the covered torso and leg regions stay hidden. The wrist band is hidden on that outfit and is not in the 69.
- Four-character draw calls in this pass are 249 at both window sizes. The original report recorded 237 and the review recorded 149, before this mesh change and in different sessions. The 149-draw figure does not repeat. This pass kept every regional mesh.

## Remaining limitations

- There is still no skinned mesh, no vertex weight, and no blend shape. Bone attachments move whole boxes. They do not deform a surface.
- The clips are generated placeholder keys. They are not an authored walk, run, or jump.
- Face records move three boxes on the head attachment.
- Garment fit still tests stature, shoulder scale, and hip scale. Leg scale and torso scale are saved and posed.
- Exclusive sockets in the shipped catalogue are `chest` and `wrist` only.
- `covers` hides a listed region of another equipped garment. It does not clip or deform cloth.
- Every garment mesh is still created with the rig. Hidden meshes remain in the scene and are omitted from the draw.
- `body_state` is stored as `none` and does not change the skeleton.
- The wrist band is a labelled placeholder. It is not an official badge or a national uniform.
- There is no character-creator screen, no child or infant rig, no additional country, and no clinical system. Phase 2 has not been started.

## Git status

No commit was made for this correction pass. Nothing was reset, discarded, or deleted from the existing baseline.

Commands inspected after the correction and the documentation update:

`git status --short --branch` after this document was saved:

```
## main...origin/main
 M characters/rig/adult/adult_rig.gd
 M characters/rig/adult/appearance_catalogue.gd
 M characters/rig/adult/clothing_resolver.gd
 M data/appearance/catalogue.json
 M documentation/PHASE1_IMPLEMENTATION_REPORT.md
 M documentation/SYSTEM_ARCHITECTURE.md
 M scripts/resources/appearance_profile.gd
 M scripts/resources/garment_definition.gd
 M tests/phase1_adult.gd
?? documentation/PHASE1_TECHNICAL_REVIEW.md
?? tests/phase1_1_regressions.gd
```

`main` tracks `origin/main` with no ahead or behind count, so the pushed Phase 1 commits are the remote tip. Those commits are `32b0964` (“Add the Godot foundation and the Phase 1 adult character.”) and `bc64690` (“Remove leftover UIDs for deleted one-shot scripts.”). The correction above is uncommitted.

`.gitignore` contains only:

```
# Godot 4+ specific ignores
.godot/
/android/
```

`.godot/` is present and ignored. It holds the editor cache and should stay untracked. User saves under `user://` are outside the repository. `tests/phase1_1_perf.gd` was the one-shot measurement script and was deleted after the numbers above were captured. It is not part of the baseline.

This review document is part of the intended baseline. It was untracked after the verification pass, and the correction pass updates it in place. It should be included with the correction if a later commit is requested.

`git ls-files` lists the pushed Phase 1 source: `project.godot`, `icon.svg`, `icon.svg.import`, scenes, scripts, the adult rig, `data/appearance/catalogue.json`, the audio bus layout, `.uid` files beside the existing scripts, `README.md`, the architecture notes, the roadmap, the Phase 1 implementation report, `tests/phase1_adult.gd`, `tests/phase1_bench.gd`, and `.gitkeep` files in empty folders.

Files this correction would add or change, and only these, if a commit is requested later:

- `characters/rig/adult/adult_rig.gd`
- `characters/rig/adult/appearance_catalogue.gd`
- `characters/rig/adult/clothing_resolver.gd`
- `data/appearance/catalogue.json`
- `scripts/resources/appearance_profile.gd`
- `scripts/resources/garment_definition.gd`
- `tests/phase1_adult.gd`
- `tests/phase1_1_regressions.gd`
- `documentation/PHASE1_IMPLEMENTATION_REPORT.md`
- `documentation/PHASE1_TECHNICAL_REVIEW.md`
- `documentation/SYSTEM_ARCHITECTURE.md`

A Godot `.uid` beside `tests/phase1_1_regressions.gd` belongs in that set if the editor writes one. `.godot/`, `user://` saves, and the deleted measurement script do not.
