# Ayagami monorepo

## Layout

- `crates/ayagami/` — model parser, deformation runtime, and optional Cubism
  Core C ABI provider (`cubism-core-abi`).
- `crates/ayagami-render/` — reference `wgpu` renderer.
- `demos/ayagami-demo/` — native and web demo built with `egui`.
- `crates/ayagami-godot/` — Godot GDExtension, imported from
  `gd_cubism` and adapted to support an alternate Cubism Core implementation.
- `demos/godot/` — interactive Godot comparison and regression demo.
- `benchmarks/cubism-matrix/` — reproducible 2x2 Core/runtime benchmark matrix.
- `third_party/` — local, untracked third-party SDKs shared by crates and apps.
- `tools/` — repository-wide development and staging utilities.

The Rust projects share the root Cargo workspace and lockfile. Run all Rust
checks from the repository root:

```sh
cargo test --workspace
```

The Godot extension keeps `godot-cpp` as a submodule. Initialize it after
cloning:

```sh
git submodule update --init --recursive
```

The proprietary Cubism Native SDK and the demo model are deliberately not
tracked. Put the SDK under `third_party/CubismSdkForNative-5-r.5/` and the model
under `demos/godot/assets/live2d/`. The canonical Godot addon lives under
`crates/ayagami-godot/addons/`; `tools/stage_godot_addon.py` stages it into the
demo and benchmark projects. See the demo, benchmark, and ABI READMEs for build
and test commands.

## Imported sources

- `crates/ayagami-godot/` was imported from `pakholeung37/gd_cubism` at commit
  `36ad060`.
- The Godot demo and ABI experiment were imported from
  `pakholeung37/manosaba-live2d` at commit `b6f8820`.

Those source repositories were imported as files rather than nested Git
repositories. Their commit IDs above provide a stable provenance point.
