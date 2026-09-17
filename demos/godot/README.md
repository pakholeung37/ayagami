# Ayagami Godot integration demo

A minimal end-to-end Godot 4 demo using the `ayagami-godot` GDExtension and
Cubism Native Framework with the local Nijiiro Mao sample model.

## Local prerequisites

The model and the proprietary Cubism Native SDK cannot be redistributed in
this repository. Place them at these paths from the monorepo root:

```text
demos/godot/assets/live2d/mao/
third_party/CubismSdkForNative-5-r.5/
```

Initialize `godot-cpp` and prepare SCons once:

```sh
git submodule update --init --recursive
python3 -m venv crates/ayagami-godot/.venv
crates/ayagami-godot/.venv/bin/python -m pip install scons==4.7.0
```

## Run

Open `demos/godot/project.godot` with Godot 4.7 or newer, or launch it from
the monorepo root:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --path demos/godot

/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --headless --path demos/godot \
  --script res://tests/smoke_test.gd
```

## Ayagami through the Cubism Core ABI

The optional `cubism-core-abi` feature in `crates/ayagami` exposes Ayagami
through the Cubism Core C ABI expected by the native framework. Run its complete
build/copy/test/restore cycle from the monorepo root:

```sh
tools/run_cubism_core_experiment.sh
```

To launch the interactive demo with the Ayagami ABI provider installed
temporarily:

```sh
tools/run_cubism_core_demo.sh
```

Both scripts restore any pre-existing extension binaries when they exit. See
`crates/ayagami/CUBISM_CORE_ABI.md` for the manual build and compatibility
details.

## Rebuild the `ayagami-godot` addon

```sh
cd crates/ayagami-godot
.venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
cd ../..
python3 tools/stage_godot_addon.py demos/godot
```

The extension currently targets the Godot 4.3 ABI and has been exercised with
Godot 4.7.2 Mono on macOS arm64. Distribution remains subject to the licenses
of `ayagami-godot`, the Cubism Native SDK, and the sample model.

## Layout

- `addons/ayagami_godot/` — generated local copy of the addon used at runtime.
- `assets/live2d/` — ignored local model assets.
- `tests/` — smoke, ordering, mask, and render tests.

Performance benchmarks are intentionally kept out of this interactive project.
See `benchmarks/cubism-matrix/` for the four Core/runtime combinations.
