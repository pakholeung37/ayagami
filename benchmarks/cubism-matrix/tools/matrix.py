#!/usr/bin/env python3
"""Build and run the four Cubism/Ayagami benchmark combinations."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


MATRIX_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = MATRIX_ROOT.parents[1]
MATRIX_PATH = MATRIX_ROOT / "config" / "matrix.json"
WORKLOAD_PATH = MATRIX_ROOT / "config" / "mao-20.json"
BUILD_ROOT = REPO_ROOT / "target/cubism-matrix/build"


def read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def load_configuration() -> tuple[dict, dict]:
    matrix = read_json(MATRIX_PATH)
    workload = read_json(WORKLOAD_PATH)
    expected = {
        ("cubism", "cubism-framework-native"),
        ("ayagami", "cubism-framework-native"),
        ("cubism", "ayagami-godot"),
        ("ayagami", "ayagami-godot"),
    }
    cases = matrix.get("cases", [])
    actual = {(case.get("core"), case.get("host")) for case in cases}
    ids = [case.get("id") for case in cases]
    if actual != expected or len(ids) != 4 or len(set(ids)) != 4:
        raise ValueError("matrix.json must contain each Core/host combination exactly once")
    if workload.get("instances") != workload["layout"]["columns"] * workload["layout"]["rows"]:
        raise ValueError("workload layout must have exactly one grid cell per instance")
    if len(workload.get("viewport", [])) != 2:
        raise ValueError("workload viewport must contain width and height")
    return matrix, workload


def find_case(case_id: str) -> tuple[dict, dict]:
    matrix, workload = load_configuration()
    for case in matrix["cases"]:
        if case["id"] == case_id:
            return case, workload
    choices = ", ".join(case["id"] for case in matrix["cases"])
    raise ValueError(f"unknown case {case_id!r}; choose one of: {choices}")


def run(command: list[str], *, cwd: Path = REPO_ROOT, env: dict | None = None) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=cwd, env=env, check=True)


def replace_tree(source: Path, destination: Path) -> None:
    if not source.is_dir():
        raise FileNotFoundError(f"required directory does not exist: {source}")
    if destination.exists():
        shutil.rmtree(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination)


def prepare_model(model_source: Path | None = None) -> Path:
    model_source = model_source or REPO_ROOT / "demos/godot/assets/live2d/mao"
    replace_tree(model_source, MATRIX_ROOT / "assets/live2d/mao")
    return MATRIX_ROOT / "assets/live2d/mao/runtime/mao_pro.model3.json"


def prepare_godot(addon_source: Path | None = None, model_source: Path | None = None) -> None:
    addon_source = addon_source or REPO_ROOT / "crates/ayagami-godot/addons/ayagami_godot"
    replace_tree(addon_source, MATRIX_ROOT / "addons/ayagami_godot")
    prepare_model(model_source)
    extension_cache = MATRIX_ROOT / ".godot/extension_list.cfg"
    extension_cache.parent.mkdir(parents=True, exist_ok=True)
    extension_cache.write_text(
        "res://addons/ayagami_godot/ayagami_godot.gdextension\n",
        encoding="utf-8",
    )
    print(f"prepared isolated Godot project at {MATRIX_ROOT}")


def build_shim() -> Path:
    run(["cargo", "build", "--release", "-p", "ayagami-cubism-core"])
    archive = REPO_ROOT / "target/release/libayagami_cubism_core.a"
    if not archive.is_file():
        raise FileNotFoundError(f"Cargo did not produce {archive}")
    return archive


def cmake_workload_arguments(workload: dict, model_hash: str) -> list[str]:
    width, height = workload["viewport"]
    timing = workload["timing"]
    layout = workload["layout"]
    return [
        f"-DBENCHMARK_MODEL_COUNT={workload['instances']}",
        f"-DBENCHMARK_WORKLOAD_ID={workload['id']}",
        f"-DBENCHMARK_MODEL_NAME={workload['model']}",
        f"-DBENCHMARK_MODEL_HASH={model_hash}",
        f"-DBENCHMARK_COLUMNS={layout['columns']}",
        f"-DBENCHMARK_ROWS={layout['rows']}",
        f"-DBENCHMARK_WIDTH={width}",
        f"-DBENCHMARK_HEIGHT={height}",
        f"-DBENCHMARK_WARMUP_SECONDS={timing['warmup_seconds']}",
        f"-DBENCHMARK_SAMPLE_SECONDS={timing['sample_seconds']}",
    ]


def build_native(case_id: str, jobs: int) -> Path:
    case, workload = find_case(case_id)
    if case["host"] != "cubism-framework-native":
        raise ValueError(f"{case_id} is not a Native case")
    third_party = (
        REPO_ROOT
        / "crates/ayagami-godot/thirdparty/CubismSdkForNative-5-r.5/Samples/OpenGL/thirdParty"
    )
    missing = [path for path in (third_party / "glew/build/cmake", third_party / "glfw") if not path.is_dir()]
    if missing:
        setup = third_party / "scripts/setup_glew_glfw"
        raise FileNotFoundError(
            "Native OpenGL dependencies are not prepared; run:\n"
            f"cd {setup.parent} && ./setup_glew_glfw"
        )
    if case["core"] == "ayagami":
        build_shim()
    model_path = prepare_model()
    model_hash = hashlib.sha256(model_path.read_bytes()).hexdigest()
    build_dir = BUILD_ROOT / case_id / "native"
    source_dir = MATRIX_ROOT / "runners/native"
    command = [
        "cmake", "-S", str(source_dir), "-B", str(build_dir),
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
        "-DCSM_MINIMUM_DEMO=OFF",
        f"-DCORE_PROVIDER={case['core']}",
        f"-DBENCHMARK_CASE_ID={case_id}",
        *cmake_workload_arguments(workload, model_hash),
    ]
    run(command)
    run(["cmake", "--build", str(build_dir), f"-j{jobs}"])
    executable = build_dir / "bin/Demo/Demo"
    if not executable.is_file():
        raise FileNotFoundError(f"Native build did not produce {executable}")
    return executable


def build_godot(case_id: str, jobs: int, platform: str, arch: str) -> Path:
    case, _ = find_case(case_id)
    if case["host"] != "ayagami-godot":
        raise ValueError(f"{case_id} is not a Godot case")
    extension_root = REPO_ROOT / "crates/ayagami-godot"
    scons = extension_root / ".venv/bin/scons"
    if not scons.is_file():
        raise FileNotFoundError(f"SCons environment does not exist: {scons}")
    environment = os.environ.copy()
    if case["core"] == "ayagami":
        environment["CUBISM_CORE_LIBRARY"] = str(build_shim())
    else:
        environment.pop("CUBISM_CORE_LIBRARY", None)
    run(
        [
            str(scons), f"platform={platform}", f"arch={arch}",
            "target=template_release", f"-j{jobs}",
        ],
        cwd=extension_root,
        env=environment,
    )
    addon_source = extension_root / "addons/ayagami_godot"
    artifact = BUILD_ROOT / case_id / "addons/ayagami_godot"
    replace_tree(addon_source, artifact)
    prepare_godot(artifact)
    return artifact


def run_case(case_id: str, godot_bin: str) -> None:
    case, _ = find_case(case_id)
    if case["host"] == "cubism-framework-native":
        executable = BUILD_ROOT / case_id / "native/bin/Demo/Demo"
        if not executable.is_file():
            raise FileNotFoundError(f"build {case_id} before running it")
        run([str(executable)], cwd=executable.parent)
        return
    addon_artifact = BUILD_ROOT / case_id / "addons/ayagami_godot"
    if not addon_artifact.is_dir():
        raise FileNotFoundError(f"build {case_id} before running it")
    prepare_godot(addon_artifact)
    run(
        [
            godot_bin, "--path", str(MATRIX_ROOT),
            "res://runners/godot/benchmark.tscn", "--",
            f"--case={case_id}", f"--core={case['core']}", "--profile=release",
        ]
    )


def validate(local: bool) -> None:
    matrix, workload = load_configuration()
    print(f"configuration valid: {len(matrix['cases'])} cases, workload={workload['id']}")
    if local:
        required = [
            REPO_ROOT / "crates/ayagami-godot/thirdparty/CubismSdkForNative-5-r.5",
            REPO_ROOT / "demos/godot/assets/live2d/mao/runtime/mao_pro.model3.json",
            REPO_ROOT / "crates/ayagami-godot/thirdparty/CubismSdkForNative-5-r.5/Samples/OpenGL/thirdParty/glew/build/cmake",
            REPO_ROOT / "crates/ayagami-godot/thirdparty/CubismSdkForNative-5-r.5/Samples/OpenGL/thirdParty/glfw",
        ]
        missing = [path for path in required if not path.exists()]
        if missing:
            raise FileNotFoundError("missing local prerequisites:\n" + "\n".join(map(str, missing)))
        print("local SDK and Mao fixture found")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--local", action="store_true")
    prepare_parser = subparsers.add_parser("prepare-godot")
    prepare_parser.add_argument("--addon-source", type=Path)
    prepare_parser.add_argument("--model-source", type=Path)
    for name in ("build-native", "build-godot"):
        build_parser = subparsers.add_parser(name)
        build_parser.add_argument("case")
        build_parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
        if name == "build-godot":
            build_parser.add_argument("--platform", default="macos")
            build_parser.add_argument("--arch", default="arm64")
    run_parser = subparsers.add_parser("run")
    run_parser.add_argument("case")
    run_parser.add_argument(
        "--godot-bin",
        default=os.environ.get("GODOT_BIN", "/Applications/Godot_mono.app/Contents/MacOS/Godot"),
    )
    args = parser.parse_args()
    try:
        if args.command == "validate":
            validate(args.local)
        elif args.command == "prepare-godot":
            prepare_godot(args.addon_source, args.model_source)
        elif args.command == "build-native":
            build_native(args.case, args.jobs)
        elif args.command == "build-godot":
            build_godot(args.case, args.jobs, args.platform, args.arch)
        elif args.command == "run":
            run_case(args.case, args.godot_bin)
    except (FileNotFoundError, ValueError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
