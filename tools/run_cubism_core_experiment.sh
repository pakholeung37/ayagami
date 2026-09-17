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
cargo test --locked -p ayagami --features cubism-core-abi
cargo build --locked -p ayagami --features cubism-core-abi

cd ${gd_cubism_dir}
CUBISM_CORE_PROVIDER=ayagami \
CUBISM_CORE_LIBRARY=${core_archive} \
  .venv/bin/python -m SCons platform=macos arch=arm64 target=template_debug -j8
python3 ${stage_tool} --core-provider ayagami ${demo_dir}

# A fresh Godot checkout has no extension/class cache yet. Populate it before
# asking Godot to parse test scripts that refer to native extension classes.
${godot_bin} --headless --editor --path ${demo_dir} --quit

run_test() {
  local script=$1
  local success_marker=$2
  local output
  output=$(${godot_bin} --headless --path ${demo_dir} --script ${script} 2>&1)
  print -r -- ${output}
  print -r -- ${output} | grep -q ${success_marker}
}

run_test res://tests/ayagami_core_abi_test.gd AYAGAMI_CORE_ABI_TEST_OK
run_test res://tests/smoke_test.gd SMOKE_TEST_OK
