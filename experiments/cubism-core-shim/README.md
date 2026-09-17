# Ayagami as a Cubism Core ABI shim

This experiment keeps `gd_cubism` and the official open-source Cubism Native
Framework intact, but replaces the proprietary `libLive2DCubismCore` static
library with a Rust library backed by Ayagami.

It intentionally targets the Core ABI used by the local Cubism SDK 5-r.5 and
the Mao test model. Parameters, parts, drawables, masks, render order, vertex
deformation, colors, and the classic blend modes are implemented. Cubism 5.3
offscreen parts currently report a count of zero.

Build the shim and the alternate GDExtension from the monorepo:

```sh
cd /path/to/ayagami
cargo build -p ayagami-cubism-core

cd crates/ayagami-godot
rm -f demo/addons/gd_cubism/bin/libgd_cubism.macos.debug.framework/libgd_cubism.macos.debug
CUBISM_CORE_LIBRARY=../target/debug/libayagami_cubism_core.a \
  .venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
```

For the complete build/copy/test/restore cycle, run
`experiments/cubism-core-shim/run_experiment.sh` from the repository root. It
temporarily installs the alternate extension into the demo,
runs the ABI-specific and ordinary gd_cubism smoke tests, and restores both
pre-existing binaries even if a command fails.

To inspect the interactive gd_cubism demo while it is backed by Ayagami, run
`./run_demo.sh`. The alternate extension remains installed while the Godot
window is open and is restored when the window closes.

The shim stores Rust-owned state behind the caller-provided in-place Core
buffers. Since the Cubism Core ABI has no model/moc destruction callback,
those allocations cannot be reclaimed by a drop-in implementation. This is
acceptable for the experiment, but a production adapter should add an owned
backend abstraction inside `gd_cubism` instead of emulating the closed ABI.

## Result

The Mao model successfully loads through `GDCubismUserModel` with 128
parameters, 260 drawables, clipping masks, 7 motions, and 8 expressions. A
cross-backend check also verifies that all 260 generated meshes match the
ayagami-gd path in bounds, UVs, indices, and texture assignment. This
proves that an Ayagami-backed Core ABI shim can reuse gd_cubism. It does not
mean Ayagami is already a drop-in Core replacement: the shim is the missing
compatibility layer, it leaks per-model state due to the Core ABI's in-place
ownership contract, and Cubism 5.3 offscreen parts are not implemented.
