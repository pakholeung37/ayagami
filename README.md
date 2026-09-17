# Ayagami

Ayagami (彩紙) is an experimental, open-source runtime for loading, deforming,
and rendering 2D puppet models. It is written primarily in Rust and focuses on
interoperability with models created for the Live2D Cubism ecosystem.

This monorepo brings together the Ayagami model runtime, a reference `wgpu`
renderer and demo, a Godot GDExtension, an optional Cubism Core ABI
compatibility layer, and a reproducible native/Godot compatibility and
performance matrix.

## Acknowledgements

This project builds on the work of two upstream open-source projects:

- [Ayagami](https://github.com/AyagamiDev/ayagami), which provides the original
  Rust model parser, deformation runtime, renderer, and demo. Copyright remains
  with the Ayagami Project Contributors; this repository uses that work under
  its MIT license option.
- [GDCubism](https://github.com/MizunagiKB/gd_cubism) by MizunagiKB, which
  provides the foundation of the Godot integration. GDCubism-derived portions
  remain Copyright (c) 2023 MizunagiKB and are used under the MIT License.

The maintainers and contributors of those projects are not responsible for,
and do not necessarily endorse, the changes made in this repository.

## License and third-party rights

Original code and modifications in this repository are available under the
[MIT License](LICENSE), except where a file, directory, dependency, or
submodule carries a different notice. Existing third-party copyright and
license notices remain in force. In particular, the `godot-cpp` submodule and
Live2D-derived benchmark sources are governed by their respective licenses;
the repository MIT License does not relicense them. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the applicable scopes and
notices.

Live2D, Cubism, the Live2D Cubism SDK, Cubism Core, Cubism Native Framework,
and associated sample data are owned by or licensed through Live2D Inc. and/or
their respective rightsholders. This project is independent and is not
affiliated with, authorized by, endorsed by, or sponsored by Live2D Inc. The
names “Live2D” and “Cubism” are used only to describe interoperability; no
affiliation or endorsement is implied.

This repository does not distribute the proprietary Cubism Core binary, a
Cubism SDK package, or Live2D sample model assets. Users who obtain, build,
link, publish, or distribute software using Live2D materials are responsible
for complying with all applicable terms, including the
[Live2D Proprietary Software License Agreement](https://www.live2d.com/eula/live2d-proprietary-software-license-agreement_en.html),
[Live2D Open Software License Agreement](https://www.live2d.com/eula/live2d-open-software-license-agreement_en.html),
and any applicable [sample data terms](https://www.live2d.com/eula/live2d-sample-model-terms_en.html).
The MIT License for this repository grants no rights to third-party software,
models, artwork, trademarks, or other materials.
