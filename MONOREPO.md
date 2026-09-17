# Ayagami monorepo

## Layout

- `crates/ayagami/` — model parser and deformation runtime.
- `crates/ayagami-render/` — reference `wgpu` renderer.
- `apps/ayagami-demo/` — native and web demo built with `egui`.
- `crates/ayagami-godot/` — Godot GDExtension, imported from
  `gd_cubism` and adapted to support an alternate Cubism Core implementation.
- `experiments/cubism-core-shim/` — temporary Cubism Core C ABI shim backed by
  Ayagami. The intended next step is to move this adapter into
  `crates/ayagami`.
- `experiments/godot-demo/` — end-to-end Godot comparison and regression demo.

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
tracked. Put the SDK under `crates/ayagami-godot/thirdparty/` and the model under
`experiments/godot-demo/assets/live2d/`. See the demo and shim READMEs for the
build and test commands.

## Imported sources

- `crates/ayagami-godot/` was imported from `pakholeung37/gd_cubism` at commit
  `36ad060`.
- The Godot demo and ABI experiment were imported from
  `pakholeung37/manosaba-live2d` at commit `b6f8820`.

Those source repositories were imported as files rather than nested Git
repositories. Their commit IDs above provide a stable provenance point.
