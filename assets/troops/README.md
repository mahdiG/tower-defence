# KayKit Adventurer Troops

Models and weapons are from the local **KayKit Adventurers 2.0 FREE** pack
(downloaded from itch.io).

- `Knight.glb` — Knight model.
- `Ranger.glb` — Ranger model.
- `weapons/sword_1handed.gltf` + `.bin` — Knight sword.
- `weapons/shield_round.gltf` + `.bin` — Knight shield.
- `weapons/bow_withString.gltf` + `.bin` — Ranger bow.
- `weapons/quiver.gltf` + `.bin` — Ranger quiver.
- `weapons/arrow_bow.gltf` + `.bin` — Ranger arrow projectile.
- `weapons/knight_texture.png`, `ranger_texture.png`, `rogue_texture.png` —
  textures referenced by the weapon glTFs (the quiver uses the rogue texture).
- `LICENSE.txt` — the 2.0 pack license (CC0).

## Animation library

The 2.0 FREE character GLBs are **unanimated** (`0` animations), and the 2.0
FREE `Animations/` folder only has 26 basic movement/general clips — no combat
animations. The 1.0 GitHub Adventurer characters contain the full 76-animation
set, including `1H_Melee_Attack_Chop`, `2H_Ranged_Aiming`, `2H_Ranged_Shoot`,
`Idle`, and `Death_A`.

`animations/adventurer_1_0.res` is a generated `AnimationLibrary` made from the
1.0 `Knight.glb` animation set:

- Source GLB: `animations/adventurer_1_0.glb` (1.0 Knight, CC0; see
  `animations/LICENSE_1_0.txt`).
- Source: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- The animation tracks were rewritten from `Rig/Skeleton3D:bone` to
  `Skeleton3D:bone` so they resolve on the 2.0 `Rig_Medium` 23-bone rig.
- The 18 IK/control-bone tracks that do not exist on the 2.0 rig were removed.
- `troop.gd` loads the library and creates the playing `AnimationPlayer` under
  the model's rig root at runtime.

If more 2.0 combat animations become available, they can replace this library
later without changing the troop scenes.
