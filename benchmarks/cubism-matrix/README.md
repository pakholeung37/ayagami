# Cubism compatibility and performance matrix

This project renders 20 independent instances of Nijiiro Mao to compare three
Cubism Core ABI providers across two host/rendering stacks. Compatibility must
be established before performance numbers are treated as valid.

| Case | Core provider | Host/rendering stack | Purpose |
| --- | --- | --- | --- |
| `cubism-native` | Official Cubism Core | Cubism Framework Native | Baseline |
| `ayagami-native` | Ayagami Core ABI | Cubism Framework Native | Isolate Ayagami Core |
| `purism-native` | Purism Core v6 ABI | Cubism Framework Native | Isolate Purism Core |
| `cubism-godot` | Official Cubism Core | gd_cubism | Isolate Godot integration |
| `ayagami-godot` | Ayagami Core ABI | gd_cubism | Ayagami Core through the Godot stack |
| `purism-godot` | Purism Core v6 ABI | gd_cubism | Purism Core with the Godot stack |

The Core implementation is selected at link time. The matrix therefore creates
six separate artifacts; it never switches Core implementations inside a
running process. All Native cases share one C++ runner, and all Godot cases
share one scene and script.

## Layout

- `config/matrix.json` defines the six permitted combinations.
- `config/mao-20.json` is the shared workload definition.
- `runners/native/` is the Cubism Framework OpenGL runner.
- `runners/godot/` is the gd_cubism runner.
- `tools/matrix.py` validates, prepares, builds, and runs individual cases.
- `results/historical/` preserves measurements from before this restructure.
- `artifacts/results/`, `addons/`, and `assets/` are generated/local and ignored.
- `target/cubism-matrix/build/` holds isolated build artifacts outside the
  Godot project, so Godot cannot discover and load multiple GDExtensions.

## Prerequisites

The proprietary SDK and Mao model are not tracked. Put them at:

```text
third_party/CubismSdkForNative-5-r.5/
demos/godot/assets/live2d/mao/
```

PurismCore is pinned at `modules/purism-core` as a Git submodule. Initialize
submodules after cloning, or set `PURISM_CORE_ROOT` to use another checkout.
The matrix configures its Purism build with CTest enabled; run it with:

```sh
ctest --test-dir target/cubism-matrix/core/purism-v6 --output-on-failure
```

Validate the matrix alone, or include local prerequisites:

```sh
python3 benchmarks/cubism-matrix/tools/matrix.py validate
python3 benchmarks/cubism-matrix/tools/matrix.py validate --local
```

For Native OpenGL builds, prepare the SDK's vendored GLEW and GLFW once:

```sh
cd third_party/CubismSdkForNative-5-r.5/Samples/OpenGL/thirdParty/scripts
./setup_glew_glfw
```

## Native cases

The tool maps `config/mao-20.json` into CMake definitions so the C++ runner
uses the same instance count, grid, viewport, warmup, and sampling interval as
Godot.

```sh
python3 benchmarks/cubism-matrix/tools/matrix.py build-native cubism-native
python3 benchmarks/cubism-matrix/tools/matrix.py run cubism-native

python3 benchmarks/cubism-matrix/tools/matrix.py build-native ayagami-native
python3 benchmarks/cubism-matrix/tools/matrix.py run ayagami-native

python3 benchmarks/cubism-matrix/tools/matrix.py build-native purism-native
python3 benchmarks/cubism-matrix/tools/matrix.py run purism-native
```

The current Native runner uses OpenGL. A future Metal runner should report a
different `graphics_api` and must not be merged into the OpenGL baseline.

## Godot cases

Initialize the extension build environment as described in `demos/godot/README.md`.
Building a case copies its complete addon into a case-specific artifact and
rewrites the editor/debug GDExtension entry to select the freshly built release
library. It then stages that addon plus the local Mao fixture into this isolated
project. This rewrite is required because the Godot editor executable normally
selects the debug entry even when benchmarking a `template_release` extension.

Each Core provider has a stable filename in the canonical addon `bin/`
directory, so builds coexist and remain available for incremental reuse:

```text
libgd_cubism.cubism.<platform>.<profile>...
libgd_cubism.ayagami.<platform>.<profile>...
libgd_cubism.purism.<platform>.<profile>...
```

Building one provider no longer overwrites either of the other two. The
case-specific descriptor only selects the matching existing binary.

```sh
python3 benchmarks/cubism-matrix/tools/matrix.py build-godot cubism-godot
python3 benchmarks/cubism-matrix/tools/matrix.py run cubism-godot

python3 benchmarks/cubism-matrix/tools/matrix.py build-godot ayagami-godot
python3 benchmarks/cubism-matrix/tools/matrix.py run ayagami-godot

python3 benchmarks/cubism-matrix/tools/matrix.py build-godot purism-godot
python3 benchmarks/cubism-matrix/tools/matrix.py run purism-godot
```

Use `GODOT_BIN` or `--godot-bin` when Godot is installed elsewhere.

Each runner prints one `BENCHMARK_RESULT` JSON object. Godot also writes the
latest JSON and screenshot under `artifacts/results/`. Results identify the
case, Core, host, graphics API, build profile, workload, FPS, and frame-time
percentiles.

## Measurement rules

- Use Release builds, VSync off, the same model fixture and viewport.
- Run compatibility checks before collecting performance results.
- Execute every case multiple times in an interleaved order.
- Compare medians and spread, not a single best run.
- Treat Native-vs-Godot FPS as end-to-end stack measurements; it includes
  engine overhead and is not a direct Core-only measurement.
