# Runtime-only backports from erodozer/importer

Reviewed upstream snapshot: `e25bd424040e4c16a1310bcdb88f1e14d556eb60`.

- Adapted model-local scene ordering from `63cc36b` / `41d90b4` to both
  the batched renderer and its unbatched reference path. Internal drawables
  and batches no longer use canvas-wide z-index values. Reorder only when
  the render-order signature changes; retain the public model z-index.
  Sorting is confined to a dedicated `CubismRenderRoot` child, so user
  attachments are not moved relative to model geometry during animation.
- Synchronize model visibility layers to the render container and both
  drawable paths, including already-created batches after runtime layer changes.
- Adapted missing-texture validation from `293aa06`, additionally checking
  image decoding, loaded texture validity, empty slots and drawable indices.
  Invalid assets fail model initialization instead of building invalid meshes.
- Added a model-settings parser validity guard after the negative asset tests
  exposed a null-JSON dereference; malformed settings now fail safely.
- Existing UTF-8 path decoding, shared mask geometry, small initial mask
  allocation and corrected mask texture indices already cover corresponding
  upstream fixes. Retained screen-space atlas allocation and data-texture
  batching instead of upstream's separate mask viewports and instance uniforms.

No importer, editor integration, AnimationPlayer conversion, effect-node API
migration or Godot dependency bump is included. Manual shader color override
is a separate feature, not a performance backport, and is not included.

Regression coverage in the companion demo: `runtime_order_test.gd` checks
canvas sibling ordering in both rendering paths across all expressions;
`batch_render_test.gd` compares the paths' pixels. The asset validation test
checks missing/empty textures and malformed model settings.

`demo/tests/runtime_render_test.gd` checks runtime layer changes, attachment
occlusion and model visibility in both rendering paths. Set `CUBISM_TEST_MODEL`
to a Mao model3.json path and run the script with a graphical Godot process
whose project contains the matching addon shaders and binary.
