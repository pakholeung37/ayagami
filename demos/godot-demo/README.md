# Ayagami Godot integration demo

A minimal end-to-end Godot 4 demo with two runtime paths:

- `main.tscn` uses the `ayagami-godot` GDExtension and Cubism Native
  Framework.
- `ayagami_demo.tscn` uses the separate Rust-based Ayagami GDExtension.

Both scenes use the same local Nijiiro Mao sample model, allowing their meshes
and rendered output to be compared.

## Local prerequisites

The model and the proprietary Cubism Native SDK cannot be redistributed in
this repository. Place them at these paths from the monorepo root:

```text
demos/godot-demo/assets/live2d/mao/
crates/ayagami-godot/thirdparty/CubismSdkForNative-5-r.5/
```

Initialize `godot-cpp` and prepare SCons once:

```sh
git submodule update --init --recursive
python3 -m venv crates/ayagami-godot/.venv
crates/ayagami-godot/.venv/bin/python -m pip install scons==4.7.0
```

## Run

Open `demos/godot-demo/project.godot` with Godot 4.7 or newer, or launch
either scene from the monorepo root:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --path demos/godot-demo

/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --path demos/godot-demo \
  res://ayagami_demo.tscn
```

Run the integration smoke tests with:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --headless --path demos/godot-demo \
  --script res://tests/smoke_test.gd

/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --headless --path demos/godot-demo \
  --script res://tests/ayagami_smoke_test.gd
```

## Ayagami through the Cubism Core ABI

The temporary shim in `crates/cubism-core-shim/` exposes Ayagami through the
Cubism Core C ABI expected by the native framework. Run its complete
build/copy/test/restore cycle from the monorepo root:

```sh
crates/cubism-core-shim/run_experiment.sh
```

To launch the interactive demo with the shim installed temporarily:

```sh
crates/cubism-core-shim/run_demo.sh
```

Both scripts restore any pre-existing extension binaries when they exit.

## Rebuild the `ayagami-godot` addon

```sh
cd crates/ayagami-godot
.venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
cd ../..
rsync -a --delete crates/ayagami-godot/demo/addons/gd_cubism/ \
  demos/godot-demo/addons/gd_cubism/
```

The extension currently targets the Godot 4.3 ABI and has been exercised with
Godot 4.7.2 Mono on macOS arm64. Distribution remains subject to the licenses
of `ayagami-godot`, the Cubism Native SDK, and the sample model.

## Layout

- `addons/gd_cubism/` — built native extension and shaders used at runtime.
- `addons/ayagami/` — comparison Ayagami extension fixture.
- `assets/live2d/` — ignored local model assets.
- `tests/` — smoke, mesh-comparison, ordering, mask, and render tests.
- `benchmarks/` — Godot and native stress-test scenes.
