#!/usr/bin/env python3
"""Create and validate envbat backup manifest schema v2."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tarfile
from pathlib import Path, PurePosixPath

SCHEMA_VERSION = 2
VALID_STATUS = {"ok", "warn", "skip", "fail"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_module_path(backup_dir: Path, value: str) -> Path:
    relative = PurePosixPath(value)
    if relative.is_absolute() or ".." in relative.parts or value in {"", "."}:
        raise ValueError(f"unsafe module path: {value}")
    candidate = (backup_dir / Path(*relative.parts)).resolve()
    if os.path.commonpath([backup_dir.resolve(), candidate]) != str(backup_dir.resolve()):
        raise ValueError(f"module path escapes backup: {value}")
    return candidate


def create_manifest(args: argparse.Namespace) -> int:
    backup_dir = Path(args.backup_dir).resolve()
    install_base = Path(args.install_base).resolve()
    if not os.path.isabs(args.install_base) or install_base == Path(install_base.anchor):
        raise ValueError("install_base must be a non-root absolute path")
    modules: dict[str, dict[str, object]] = {}
    for name, requirement, status, path_value, sensitivity in args.module:
        if name in modules:
            raise ValueError(f"duplicate module: {name}")
        if requirement not in {"required", "optional"}:
            raise ValueError(f"invalid requirement for {name}: {requirement}")
        if status not in VALID_STATUS:
            raise ValueError(f"invalid status for {name}: {status}")
        path = None if path_value == "-" else path_value
        checksum = None
        if status == "ok":
            if path is None:
                raise ValueError(f"ok module requires a path: {name}")
            artifact = safe_module_path(backup_dir, path)
            if not artifact.is_file():
                raise ValueError(f"module artifact missing: {name}: {path}")
            checksum = sha256(artifact)
        modules[name] = {
            "required": requirement == "required",
            "status": status,
            "path": path,
            "sha256": checksum,
            "sensitive": sensitivity == "sensitive",
        }

    manifest = {
        "schema_version": SCHEMA_VERSION,
        "created_at": args.created_at,
        "host": args.host,
        "user": args.user,
        "os": args.os,
        "install_base": args.install_base,
        "overall_status": args.overall_status,
        "modules": modules,
    }
    target = backup_dir / "manifest.json"
    temporary = backup_dir / ".manifest.json.tmp"
    temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.chmod(temporary, 0o600)
    os.replace(temporary, target)
    return 0


def load_and_validate(backup_dir_value: str) -> tuple[Path, dict[str, object]]:
    backup_dir = Path(backup_dir_value).resolve()
    manifest_path = backup_dir / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"manifest unreadable: {error}") from error

    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise ValueError(f"unsupported manifest schema: {manifest.get('schema_version')!r}; expected 2")
    for field in ("created_at", "host", "user", "os", "install_base", "overall_status", "modules"):
        if field not in manifest:
            raise ValueError(f"manifest field missing: {field}")
    for field in ("created_at", "host", "user", "os", "install_base"):
        if not isinstance(manifest[field], str) or not manifest[field]:
            raise ValueError(f"manifest field must be a non-empty string: {field}")
    install_base = Path(manifest["install_base"]).resolve()
    if not os.path.isabs(manifest["install_base"]) or install_base == Path(install_base.anchor):
        raise ValueError("install_base must be a non-root absolute path")
    if manifest["overall_status"] not in {"complete", "complete_with_warnings"}:
        raise ValueError("invalid overall_status")
    if not isinstance(manifest["modules"], dict):
        raise ValueError("modules must be an object")

    for name, module in manifest["modules"].items():
        if not isinstance(module, dict):
            raise ValueError(f"invalid module object: {name}")
        if not isinstance(module.get("required"), bool):
            raise ValueError(f"module required must be boolean: {name}")
        if not isinstance(module.get("sensitive"), bool):
            raise ValueError(f"module sensitive must be boolean: {name}")
        status = module.get("status")
        if status not in VALID_STATUS:
            raise ValueError(f"invalid module status: {name}: {status}")
        if module.get("required") and status != "ok":
            raise ValueError(f"required module is not usable: {name}: {status}")
        path = module.get("path")
        checksum = module.get("sha256")
        if status == "ok":
            if not isinstance(path, str) or not isinstance(checksum, str):
                raise ValueError(f"module metadata incomplete: {name}")
            artifact = safe_module_path(backup_dir, path)
            if not artifact.is_file():
                raise ValueError(f"module artifact missing: {name}: {path}")
            if sha256(artifact) != checksum:
                raise ValueError(f"checksum mismatch: {name}: {path}")
        elif path is not None or checksum is not None:
            raise ValueError(f"non-ok module must not reference an artifact: {name}")
    return backup_dir, manifest


def command_validate(args: argparse.Namespace) -> int:
    _, manifest = load_and_validate(args.backup_dir)
    print(f"manifest v2 valid: {manifest['overall_status']}")
    return 0


def command_modules(args: argparse.Namespace) -> int:
    _, manifest = load_and_validate(args.backup_dir)
    for name, module in manifest["modules"].items():
        print(
            "\t".join(
                [
                    name,
                    str(module["status"]),
                    str(module["path"] or "-"),
                    "required" if module["required"] else "optional",
                    "sensitive" if module.get("sensitive") else "normal",
                ]
            )
        )
    return 0


def command_get(args: argparse.Namespace) -> int:
    _, manifest = load_and_validate(args.backup_dir)
    if args.field not in {"created_at", "host", "user", "os", "install_base", "overall_status"}:
        raise ValueError(f"unsupported field: {args.field}")
    print(manifest[args.field])
    return 0


def command_repos_create(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    output = Path(args.output)
    repos: list[dict[str, str]] = []
    if root.is_dir():
        for current, dirs, _ in os.walk(root):
            if ".git" not in dirs:
                continue
            repo = Path(current)
            result = subprocess.run(
                ["git", "-C", str(repo), "remote", "get-url", "origin"],
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode == 0 and result.stdout.strip():
                repos.append({"relative_path": repo.relative_to(root.parent).as_posix(), "remote_url": result.stdout.strip()})
            dirs[:] = []
    output.write_text(json.dumps(repos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.chmod(output, 0o600)
    return 0


def command_repos_list(args: argparse.Namespace) -> int:
    data = json.loads(Path(args.file).read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("git repository list must be an array")
    for entry in data:
        if not isinstance(entry, dict):
            raise ValueError("invalid git repository entry")
        path = entry.get("relative_path")
        url = entry.get("remote_url")
        if not isinstance(path, str) or not isinstance(url, str):
            raise ValueError("git repository entry is incomplete")
        if "\t" in path or "\n" in path or "\t" in url or "\n" in url:
            raise ValueError("git repository entry contains unsupported control characters")
        relative = PurePosixPath(path)
        if path in {"", "."} or relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"unsafe repository path: {path}")
        print(f"{path}\t{url}")
    return 0


def command_tree_list(args: argparse.Namespace) -> int:
    base = Path(args.install_base).resolve()
    for line_number, raw in enumerate(Path(args.file).read_text(encoding="utf-8").splitlines(), start=1):
        if not raw:
            continue
        candidate = Path(raw)
        if not os.path.isabs(raw) or ".." in candidate.parts:
            raise ValueError(f"unsafe directory tree path at line {line_number}: {raw}")
        resolved = candidate.resolve()
        if os.path.commonpath([base, resolved]) != str(base):
            raise ValueError(f"directory tree path escapes install_base at line {line_number}: {raw}")
        print(raw)
    return 0


def command_extract_tar(args: argparse.Namespace) -> int:
    destination = Path(args.destination)
    destination.mkdir(parents=True, exist_ok=True)
    try:
        with tarfile.open(args.archive, "r:gz") as archive:
            archive.extractall(destination, filter="data")
    except (OSError, tarfile.TarError, ValueError) as error:
        raise ValueError(f"unsafe or unreadable archive: {error}") from error
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    create = subparsers.add_parser("create")
    create.add_argument("--backup-dir", required=True)
    create.add_argument("--created-at", required=True)
    create.add_argument("--host", required=True)
    create.add_argument("--user", required=True)
    create.add_argument("--os", required=True)
    create.add_argument("--install-base", required=True)
    create.add_argument("--overall-status", choices=["complete", "complete_with_warnings"], required=True)
    create.add_argument("--module", action="append", nargs=5, required=True)
    create.set_defaults(handler=create_manifest)

    validate = subparsers.add_parser("validate")
    validate.add_argument("backup_dir")
    validate.set_defaults(handler=command_validate)

    modules = subparsers.add_parser("modules")
    modules.add_argument("backup_dir")
    modules.set_defaults(handler=command_modules)

    get = subparsers.add_parser("get")
    get.add_argument("backup_dir")
    get.add_argument("field")
    get.set_defaults(handler=command_get)

    repos_create = subparsers.add_parser("repos-create")
    repos_create.add_argument("root")
    repos_create.add_argument("output")
    repos_create.set_defaults(handler=command_repos_create)

    repos_list = subparsers.add_parser("repos-list")
    repos_list.add_argument("file")
    repos_list.set_defaults(handler=command_repos_list)

    tree_list = subparsers.add_parser("tree-list")
    tree_list.add_argument("install_base")
    tree_list.add_argument("file")
    tree_list.set_defaults(handler=command_tree_list)

    extract_tar = subparsers.add_parser("extract-tar")
    extract_tar.add_argument("archive")
    extract_tar.add_argument("destination")
    extract_tar.set_defaults(handler=command_extract_tar)
    return parser


def main() -> int:
    try:
        args = build_parser().parse_args()
        return args.handler(args)
    except ValueError as error:
        print(f"manifest error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
