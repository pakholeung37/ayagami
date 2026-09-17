#!/usr/bin/env python3
"""Build and run the Cubism Core provider/host benchmark matrix."""

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
sys.path.insert(0, str(REPO_ROOT / "tools"))

from stage_godot_addon import stage_addon


MATRIX_PATH = MATRIX_ROOT / "config" / "matrix.json"
WORKLOAD_PATH = MATRIX_ROOT / "config" / "mao-20.json"
BUILD_ROOT = REPO_ROOT / "target/cubism-matrix/build"
SDK_ROOT = REPO_ROOT / "third_party/CubismSdkForNative-5-r.5"
PURISM_ROOT = Path(
    os.environ.get("PURISM_CORE_ROOT", REPO_ROOT / "modules/purism-core")
).expanduser().resolve()
PURISM_BUILD_ROOT = REPO_ROOT / "target/cubism-matrix/core/purism-v6"


def read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def load_configuration() -> tuple[dict, dict]:
    matrix = read_json(MATRIX_PATH)
    workload = read_json(WORKLOAD_PATH)
    providers = {"cubism", "ayagami", "purism"}
    hosts = {"cubism-framework-native", "gd-cubism"}
    expected = {(provider, host) for provider in providers for host in hosts}
    cases = matrix.get("cases", [])
    actual = {(case.get("core"), case.get("host")) for case in cases}
    ids = [case.get("id") for case in cases]
    if actual != expected or len(ids) != len(expected) or len(set(ids)) != len(expected):
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


def select_release_extension_for_editor(
    addon_root: Path, platform: str, arch: str
) -> None:
    """Point the editor/debug key at the freshly built release library.

    The benchmark runs through the Godot editor executable, which selects the
    debug GDExtension entry even when the native extension was built with
    target=template_release. Without this rewrite an old debug binary in the
    addon can silently defeat Core-provider isolation.
    """
    descriptor = addon_root / "gd_cubism.gdextension"
    text = descriptor.read_text(encoding="utf-8")
    suffix = "" if platform == "macos" else f".{arch}"
    debug_key = f"{platform}.debug{suffix}"
    release_key = f"{platform}.release{suffix}"
    lines = text.splitlines()
    release_value = next(
        (
            line.split("=", 1)[1].strip()
            for line in lines
            if line.split("=", 1)[0].strip() == release_key
        ),
        None,
    )
    if release_value is None:
        raise ValueError(f"missing {release_key} in {descriptor}")
    replaced = False
    for index, line in enumerate(lines):
        if line.split("=", 1)[0].strip() == debug_key:
            lines[index] = f"{debug_key} = {release_value}"
            replaced = True
            break
    if not replaced:
        raise ValueError(f"missing {debug_key} in {descriptor}")
    descriptor.write_text("\n".join(lines) + "\n", encoding="utf-8")


def prepare_model(model_source: Path | None = None) -> Path:
    model_source = model_source or REPO_ROOT / "demos/godot/assets/live2d/mao"
    replace_tree(model_source, MATRIX_ROOT / "assets/live2d/mao")
    return MATRIX_ROOT / "assets/live2d/mao/runtime/mao_pro.model3.json"


def prepare_godot(addon_source: Path | None = None, model_source: Path | None = None) -> None:
    addon_source = addon_source or REPO_ROOT / "modules/gd-cubism/addons/gd_cubism"
    stage_addon(MATRIX_ROOT, addon_source)
    prepare_model(model_source)
    print(f"prepared isolated Godot project at {MATRIX_ROOT}")


def build_ayagami_core() -> Path:
    run(
        [
            "cargo",
            "build",
            "--release",
            "--locked",
            "-p",
            "ayagami",
            "--features",
            "cubism-core-abi",
        ]
    )
    archive = REPO_ROOT / "target/release/libayagami.a"
    if not archive.is_file():
        raise FileNotFoundError(f"Cargo did not produce {archive}")
    return archive


def build_purism_core(jobs: int) -> Path:
    if not (PURISM_ROOT / "CMakeLists.txt").is_file():
        raise FileNotFoundError(
            f"PurismCore checkout not found at {PURISM_ROOT}; set PURISM_CORE_ROOT"
        )
    run(
        [
            "cmake",
            "-S",
            str(PURISM_ROOT),
            "-B",
            str(PURISM_BUILD_ROOT),
            "-DCMAKE_BUILD_TYPE=Release",
            "-DBUILD_SHARED_LIBS=OFF",
            "-DPURISM_CORE_ABI=v6",
        ]
    )
    run(["cmake", "--build", str(PURISM_BUILD_ROOT), f"-j{jobs}"])
    archive = PURISM_BUILD_ROOT / "libPurismCore.a"
    if not archive.is_file():
        raise FileNotFoundError(f"CMake did not produce {archive}")
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
    third_party = SDK_ROOT / "Samples/OpenGL/thirdParty"
    missing = [path for path in (third_party / "glew/build/cmake", third_party / "glfw") if not path.is_dir()]
    if missing:
        setup = third_party / "scripts/setup_glew_glfw"
        raise FileNotFoundError(
            "Native OpenGL dependencies are not prepared; run:\n"
            f"cd {setup.parent} && ./setup_glew_glfw"
        )
    if case["core"] == "ayagami":
        build_ayagami_core()
    elif case["core"] == "purism":
        build_purism_core(jobs)
    model_path = prepare_model()
    model_hash = hashlib.sha256(model_path.read_bytes()).hexdigest()
    build_dir = BUILD_ROOT / case_id / "native"
    source_dir = MATRIX_ROOT / "runners/native"
    command = [
        "cmake", "-S", str(source_dir), "-B", str(build_dir),
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
        "-DCSM_MINIMUM_DEMO=OFF",
        f"-DSDK_ROOT_PATH={SDK_ROOT}",
        f"-DCORE_PROVIDER={case['core']}",
        f"-DPURISM_CORE_LIBRARY={PURISM_BUILD_ROOT / 'libPurismCore.a'}",
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
    if case["host"] != "gd-cubism":
        raise ValueError(f"{case_id} is not a Godot case")
    extension_root = REPO_ROOT / "modules/gd-cubism"
    scons_python = extension_root / ".venv/bin/python"
    if not scons_python.is_file():
        raise FileNotFoundError(
            f"SCons environment does not exist: {scons_python.parent}"
        )
    environment = os.environ.copy()
    environment["CUBISM_SDK_ROOT"] = str(SDK_ROOT)
    if case["core"] == "ayagami":
        environment["CUBISM_CORE_LIBRARY"] = str(build_ayagami_core())
    elif case["core"] == "purism":
        environment["CUBISM_CORE_LIBRARY"] = str(build_purism_core(jobs))
    else:
        environment.pop("CUBISM_CORE_LIBRARY", None)
    run(
        [
            str(scons_python), "-m", "SCons",
            f"platform={platform}", f"arch={arch}",
            "target=template_release", f"-j{jobs}",
        ],
        cwd=extension_root,
        env=environment,
    )
    addon_source = extension_root / "addons/gd_cubism"
    artifact = BUILD_ROOT / case_id / "addons/gd_cubism"
    replace_tree(addon_source, artifact)
    select_release_extension_for_editor(artifact, platform, arch)
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
    addon_artifact = BUILD_ROOT / case_id / "addons/gd_cubism"
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
            SDK_ROOT,
            PURISM_ROOT / "CMakeLists.txt",
            REPO_ROOT / "demos/godot/assets/live2d/mao/runtime/mao_pro.model3.json",
            SDK_ROOT / "Samples/OpenGL/thirdParty/glew/build/cmake",
            SDK_ROOT / "Samples/OpenGL/thirdParty/glfw",
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
