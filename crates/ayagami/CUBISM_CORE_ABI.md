# Ayagami Cubism Core ABI compatibility

This optional Ayagami module keeps ayagami-godot's compatible `GDCubism*` API
and the official open-source Cubism Native Framework intact, but replaces the
proprietary `libLive2DCubismCore` static library with a Rust library backed by
Ayagami.

It intentionally targets the Core ABI used by the local Cubism SDK 5-r.5 and
the Mao test model. Parameters, parts, drawables, masks, render order, vertex
deformation, colors, and the classic blend modes are implemented. Cubism 5.3
offscreen parts currently report a count of zero.

Build the ABI provider and the alternate GDExtension from the monorepo:

```sh
cd /path/to/ayagami
cargo build -p ayagami --features cubism-core-abi

cd crates/ayagami-godot
rm -f addons/ayagami_godot/bin/libayagami_godot.macos.debug.framework/libayagami_godot.macos.debug
CUBISM_CORE_LIBRARY=../../target/debug/libayagami.a \
  .venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
cd ../..
python3 tools/stage_godot_addon.py demos/godot
```

For the complete build/copy/test/restore cycle, run
`tools/run_cubism_core_experiment.sh` from the repository root. It
temporarily installs the alternate extension into the demo,
runs the ABI-specific and ordinary ayagami-godot smoke tests, and restores the
canonical addon and any pre-existing extension binary even if a command fails.

To inspect the interactive ayagami-godot demo while it is backed by Ayagami, run
`tools/run_cubism_core_demo.sh`. The alternate extension remains
installed while the Godot window is open and is restored when the window
closes.

The ABI provider stores Rust-owned state behind the caller-provided in-place Core
buffers. Since the Cubism Core ABI has no model/moc destruction callback,
those allocations cannot be reclaimed by a drop-in implementation. This is
acceptable for compatibility testing, but a future native integration should
add an owned backend abstraction inside ayagami-godot instead of emulating the
closed ABI.

## Result

The Mao model successfully loads through `GDCubismUserModel` with 128
parameters, 260 drawables, clipping masks, 7 motions, and 8 expressions. This
proves that Ayagami's Core ABI provider can reuse the compatible `GDCubism*`
API exposed by ayagami-godot. It does not mean Ayagami is already a drop-in
Core replacement: the compatibility layer leaks per-model state due to the
Core ABI's in-place ownership contract, and Cubism 5.3 offscreen parts are not
implemented.
