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
temporary_dir=$(mktemp -d /tmp/ayagami-cubism-core-demo.XXXXXX)

restore_binaries() {
  if [[ -f ${temporary_dir}/ayagami_godot ]]; then
    cp ${temporary_dir}/ayagami_godot ${ayagami_godot_dir}/${gd_binary_rel}
  fi
  if [[ -f ${temporary_dir}/demo ]]; then
    cp ${temporary_dir}/demo ${demo_binary}
  fi
  rm -rf ${temporary_dir}
}
trap restore_binaries EXIT INT TERM

if [[ -f ${ayagami_godot_dir}/${gd_binary_rel} ]]; then
  cp ${ayagami_godot_dir}/${gd_binary_rel} ${temporary_dir}/ayagami_godot
fi
if [[ -f ${demo_binary} ]]; then
  cp ${demo_binary} ${temporary_dir}/demo
fi

cd ${repo_dir}
cargo build -p ayagami-cubism-core

cd ${ayagami_godot_dir}
rm -f ${ayagami_godot_dir}/${gd_binary_rel}
CUBISM_CORE_LIBRARY=${shim_archive} \
  .venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
cp ${ayagami_godot_dir}/${gd_binary_rel} ${demo_binary}

${godot_bin} --headless --editor --path ${demo_dir} --quit

cd ${demo_dir}
${godot_bin} --path ${demo_dir} res://main.tscn
