#!/bin/zsh
set -euo pipefail

experiment_dir=${0:A:h}
repo_dir=${experiment_dir:h:h}
demo_dir=${repo_dir}/demos/godot
ayagami_godot_dir=${repo_dir}/crates/ayagami-godot
godot_bin=${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
shim_archive=${repo_dir}/target/debug/libayagami_cubism_core.a
gd_binary_rel=addons/ayagami_godot/bin/libayagami_godot.macos.debug.framework/libayagami_godot.macos.debug
demo_binary=${demo_dir}/addons/ayagami_godot/bin/libayagami_godot.macos.debug.framework/libayagami_godot.macos.debug
temporary_dir=$(mktemp -d /tmp/ayagami-cubism-core.XXXXXX)

restore_binaries() {
  if [[ -f ${temporary_dir}/ayagami_godot ]]; then
    cp ${temporary_dir}/ayagami_godot ${ayagami_godot_dir}/${gd_binary_rel}
  fi
  if [[ -f ${temporary_dir}/demo ]]; then
    cp ${temporary_dir}/demo ${demo_binary}
  fi
  rm -rf ${temporary_dir}
}
trap restore_binaries EXIT

if [[ -f ${ayagami_godot_dir}/${gd_binary_rel} ]]; then
  cp ${ayagami_godot_dir}/${gd_binary_rel} ${temporary_dir}/ayagami_godot
fi
if [[ -f ${demo_binary} ]]; then
  cp ${demo_binary} ${temporary_dir}/demo
fi

cd ${repo_dir}
cargo test -p ayagami-cubism-core
cargo build -p ayagami-cubism-core

cd ${ayagami_godot_dir}
rm -f ${ayagami_godot_dir}/${gd_binary_rel}
CUBISM_CORE_LIBRARY=${shim_archive} \
  .venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
cp ${ayagami_godot_dir}/${gd_binary_rel} ${demo_binary}

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

run_test res://tests/ayagami_core_shim_test.gd AYAGAMI_CORE_SHIM_TEST_OK
run_test res://tests/smoke_test.gd SMOKE_TEST_OK
