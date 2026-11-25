# Cinderwatch (Godot 4.7.2 Port)

A 3D isometric self-playing tower defense built in Godot 4.7.2 (Forward+) with procedural geometry, procedural audio, GPU skeletal batching, and 5 atmospheric biomes.

## Architecture Highlights
- **Scene-driven hierarchy**: `scenes/main.tscn`, `scenes/ui.tscn`, `scenes/tower_node.tscn` wired via `@onready` and native Godot `signal`s.
- **GPU Procedural Rigging**: All 27 monster archetypes and guard footmen are baked once into merged meshes and animated on GPU via `shaders/lit_unit.gdshader` (`1 MultiMesh instance = 1 unit`, dynamic-growing `PackedFloat32Array` buffers).
- **O(1) Crowd Simulation**: Pre-baked `0.2m` road lookup table with linear interpolation, pre-allocated 1D spatial hash grid, strongly-typed `CWMonsterUnit` / `CWFootmanUnit`, and adaptive crowd shadow LOD.
- **Native Engine Systems**: `Path3D` / `Curve3D` road curves, `GPUParticles3D` environmental emitters, `PhysicsDirectSpaceState3D` raycast tower/pad picking, and `AudioServer` (`SFX` / `Ambience`) bus routing.

## Controls
- **Click pad / `1`-`4` / `U` / `X`**: Build, upgrade, or sell towers
- **`Space` / `Enter`**: Call next wave early
- **`C`**: Toggle AI Commander / Player control
- **`P` / `Tab` / `M`**: Pause, cycle speed (1x/2x/3x), mute audio
- **Drag / Wheel / `WASD` / `F`**: Pan, zoom, and reset camera
- **`F1`-`F5` / `B` / `R`**: Switch biomes or reroll map seed
- **`L` / `K`**: Toggle live performance overlay / spawn +100 stress-test units
