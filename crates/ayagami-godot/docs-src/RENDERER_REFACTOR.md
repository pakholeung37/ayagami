# Batched 2D renderer

The 2D renderer now uploads model positions and drawable parameters into two
floating-point textures per model. Static meshes contain vertex IDs; the vertex
shader resolves these IDs to the current deformed positions. Geometry is merged
only across adjacent drawables using the same shader and main texture. Render
order changes rebuild batches; opacity changes update parameters without
rebuilding geometry. Invisible drawables remain in their batches with zero alpha.

Each model has one mask atlas rather than one SubViewport per clipping group.
Each clipping group occupies a padded tile with explicit sample bounds, including
inverted masks. Tiles are sized in screen pixels, grow in blocks, and shrink only
after substantial zoom-out. The atlas is bounded to 4096 pixels per axis. An
off-screen model suspends atlas drawing. Position meshes are shared with mask
draws, so deformation is uploaded once.

The default remains the project's chosen Godot rendering backend. The renderer
does not switch Metal to OpenGL or reduce animation/physics update frequency.

## Compatibility

This is a renderer ABI change: ship the rebuilt GDExtension and the updated ten
`2d_cubism_*.gdshader` files together. Older extension binaries and these shaders
are incompatible. Custom replacement shaders must adopt the new vertex-ID and
parameter-texture contract from the corresponding bundled shader. In particular,
the initial vertex X coordinate is a vertex ID, not a model-space position.
Per-drawable colors and atlas transforms are now fetched in the vertex shader,
not supplied as per-material uniforms. Core animation, expression and model APIs
are unchanged. Cubism 5.3 extended blend modes retain the pre-existing fallback;
this refactor does not add support for those modes.

For diagnostics, set `gd_cubism/rendering/batching=false` in ProjectSettings
before loading a model to draw each Drawable separately with the same textures
and atlas. This is the visual regression reference, not the old renderer.

## Build

From this checkout:

```sh
.venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
```

The paired runtime shaders are under `demo/addons/gd_cubism/res/shader/`.
The monorepo's `benchmarks/cubism-matrix` project contains the shared stress
workload. Godot regression and image-comparison tests remain in `demos/godot`.
