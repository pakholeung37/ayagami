#!/bin/zsh
set -euo pipefail

tools_dir=${0:A:h}
repo_dir=${tools_dir:h}
demo_dir=${repo_dir}/demos/godot
ayagami_godot_dir=${repo_dir}/crates/ayagami-godot
godot_bin=${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
core_archive=${repo_dir}/target/debug/libayagami.a
stage_tool=${repo_dir}/tools/stage_godot_addon.py
binary_rel=addons/ayagami_godot/bin/libayagami_godot.macos.debug.framework/libayagami_godot.macos.debug
source_binary=${ayagami_godot_dir}/${binary_rel}
temporary_dir=$(mktemp -d /tmp/ayagami-cubism-core-demo.XXXXXX)
had_source_binary=0

restore_addon() {
  if (( had_source_binary )); then
    cp ${temporary_dir}/ayagami_godot ${source_binary}
  else
    rm -f ${source_binary}
  fi
  python3 ${stage_tool} ${demo_dir}
  rm -rf ${temporary_dir}
}
trap restore_addon EXIT INT TERM

if [[ -f ${source_binary} ]]; then
  cp ${source_binary} ${temporary_dir}/ayagami_godot
  had_source_binary=1
fi

cd ${repo_dir}
cargo build --locked -p ayagami --features cubism-core-abi

cd ${ayagami_godot_dir}
rm -f ${source_binary}
CUBISM_CORE_LIBRARY=${core_archive} \
  .venv/bin/scons platform=macos arch=arm64 target=template_debug -j8
python3 ${stage_tool} ${demo_dir}

${godot_bin} --headless --editor --path ${demo_dir} --quit

cd ${demo_dir}
${godot_bin} --path ${demo_dir} res://main.tscn
