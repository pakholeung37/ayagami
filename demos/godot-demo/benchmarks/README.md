# 20-character Cubism stress test

The renderer has since been refactored. See [REFACTOR_RESULTS.md](REFACTOR_RESULTS.md)
for the final 84.31 FPS Metal run and validation. The table below preserves the
original measurements before the refactor.

This benchmark renders the same `mao_pro` model and looping Idle motion in a
5x4 grid at 1280x720. It disables VSync, warms up for 5 seconds, then records
15 seconds of frame times.

## Results on Apple M4

| Runtime | Models | Average FPS | P50 | P95 | Draw calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| gd_cubism / Godot Metal | 1 | 120.00 | 8.34 ms | 8.73 ms | 178 |
| gd_cubism / Godot Metal | 5 | 47.57 | 20.99 ms | 24.50 ms | 886 |
| gd_cubism / Godot Metal | 10 | 22.42 | 45.93 ms | 48.87 ms | 1,771 |
| gd_cubism / Godot Metal | 20 | 5.92 | 175.27 ms | 259.55 ms | 3,541 |
| Cubism Native / OpenGL | 20 | 120.01 | 8.36 ms | 8.58 ms | n/a |

The Native result is refresh-rate limited, so 120 FPS is a lower bound on its
uncapped throughput. Native uses the official macOS OpenGL sample because the
test machine only has Apple Command Line Tools, not the full Xcode required by
the SDK's Metal sample. Both paths use Cubism SDK 5-r.5 / Core 6.0.1 and the
same model, animation, render resolution, and timing window.

The detailed machine-readable output is in `results-2026-09-16.json`.

## Run the Godot benchmark

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --path demos/godot-demo \
  res://benchmarks/gd_cubism_20.tscn
```

Pass `-- --models=1`, `-- --models=5`, or `-- --models=10` to collect a scaling
point other than the default 20.

## Build and run the Native benchmark

The CMake project expects the SDK at
`crates/ayagami-godot/thirdparty/CubismSdkForNative-5-r.5` and copies the Mao model
from this Godot project into the build output.

```bash
cd crates/ayagami-godot/thirdparty/CubismSdkForNative-5-r.5/Samples/OpenGL/thirdParty/scripts
./setup_glew_glfw

cd demos/godot-demo/benchmarks/native_cubism_20
cmake -S . -B build \
  -D CMAKE_BUILD_TYPE=Release \
  -D CSM_MINIMUM_DEMO=OFF \
  -D CMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build build -j10
./build/bin/Demo/Demo
```
