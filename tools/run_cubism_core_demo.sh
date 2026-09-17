#!/bin/zsh
set -euo pipefail

tools_dir=${0:A:h}
repo_dir=${tools_dir:h}
demo_dir=${repo_dir}/demos/godot
gd_cubism_dir=${repo_dir}/modules/gd-cubism
godot_bin=${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
core_archive=${repo_dir}/target/debug/libayagami.a
stage_tool=${repo_dir}/tools/stage_godot_addon.py
binary_rel=addons/gd_cubism/bin/libgd_cubism.macos.debug.framework/libgd_cubism.macos.debug
source_binary=${gd_cubism_dir}/${binary_rel}
temporary_dir=$(mktemp -d /tmp/ayagami-cubism-core-demo.XXXXXX)
had_source_binary=0

restore_addon() {
  if (( had_source_binary )); then
    cp ${temporary_dir}/gd_cubism ${source_binary}
  else
    rm -f ${source_binary}
  fi
  python3 ${stage_tool} ${demo_dir}
  rm -rf ${temporary_dir}
}
trap restore_addon EXIT INT TERM

if [[ -f ${source_binary} ]]; then
  cp ${source_binary} ${temporary_dir}/gd_cubism
  had_source_binary=1
fi

cd ${repo_dir}
cargo build --locked -p ayagami --features cubism-core-abi

cd ${gd_cubism_dir}
rm -f ${source_binary}
CUBISM_CORE_LIBRARY=${core_archive} \
  .venv/bin/python -m SCons platform=macos arch=arm64 target=template_debug -j8
python3 ${stage_tool} ${demo_dir}

${godot_bin} --headless --editor --path ${demo_dir} --quit

cd ${demo_dir}
${godot_bin} --path ${demo_dir} res://main.tscn
