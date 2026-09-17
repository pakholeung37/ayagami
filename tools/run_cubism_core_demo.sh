#!/bin/zsh
set -euo pipefail

tools_dir=${0:A:h}
repo_dir=${tools_dir:h}
demo_dir=${repo_dir}/demos/godot
gd_cubism_dir=${repo_dir}/modules/gd-cubism
godot_bin=${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
core_archive=${repo_dir}/target/debug/libayagami.a
stage_tool=${repo_dir}/tools/stage_godot_addon.py
cd ${repo_dir}
cargo build --locked -p ayagami --features cubism-core-abi

cd ${gd_cubism_dir}
CUBISM_CORE_PROVIDER=ayagami \
CUBISM_CORE_LIBRARY=${core_archive} \
  .venv/bin/python -m SCons platform=macos arch=arm64 target=template_debug -j8
python3 ${stage_tool} --core-provider ayagami ${demo_dir}

${godot_bin} --headless --editor --path ${demo_dir} --quit

cd ${demo_dir}
${godot_bin} --path ${demo_dir} res://main.tscn
