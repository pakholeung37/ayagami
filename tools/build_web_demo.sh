#!/usr/bin/env bash
set -eu
tools_dir=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$tools_dir/.."

crate_name=demos/ayagami-demo
build_flags=(--config Trunk.release.toml)

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "build_web_demo.sh [--release]"
      echo ""
      echo "  --release: Build with --release, and then run wasm-opt."
      exit 0
      ;;

    --release)
      shift
      build_flags+=(--release)
      ;;

    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Building with trunk…"

(cd "$crate_name" &&
  trunk build "${build_flags[@]}" &&
  touch dist/.nojekyll
)
