#!/usr/bin/env python3

"""Install a Python package from a git repository into the current environment."""

import argparse
import logging
import shutil
import subprocess
import sys
import tempfile
from importlib import metadata
from pathlib import Path


repo_url = "https://github.com/pathogenwatch-oss/vista.git"
default_package_name = "vista"

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")


def run_command(command, *, cwd=None, dry_run=False):
    """Run a command, capture output, and raise on failure."""

    logging.info("Running: %s", " ".join(map(str, command)))

    if dry_run:
        logging.info("Dry-run mode: not executing command")
        return None

    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        cwd=str(cwd) if cwd is not None else None,
    )

    if completed.stdout:
        logging.info("stdout: %s", completed.stdout.strip())

    if completed.stderr:
        logging.info("stderr: %s", completed.stderr.strip())

    if completed.returncode != 0:
        raise subprocess.CalledProcessError(
            completed.returncode,
            command,
            output=completed.stdout,
            stderr=completed.stderr,
        )

    return completed


def is_package_installed(package_name: str) -> bool:
    """Return True when the package is already installed in this environment."""

    try:
        metadata.version(package_name)
    except metadata.PackageNotFoundError:
        return False

    return True


def find_container_builder():
    if shutil.which("apptainer"):
        return "apptainer"

    if shutil.which("singularity"):
        return "singularity"

    raise RuntimeError("Neither apptainer nor singularity found")


def patch_dockerfile_for_https(dockerfile_path: Path):
    """Rewrite FTP URLs in a Dockerfile to HTTPS when possible."""

    if not dockerfile_path.exists():
        return False

    original_text = dockerfile_path.read_text(encoding="utf-8")
    updated_text = original_text.replace("ftp://", "https://")

    if updated_text != original_text:
        dockerfile_path.write_text(updated_text, encoding="utf-8")
        logging.info("Updated Dockerfile URLs to HTTPS: %s", dockerfile_path)
        return True

    return False


def build_from_definition(source_dir: Path, build_file: Path, image_path: Path, builder: str, dry_run: bool):
    """Build a container image from either a Dockerfile or a Singularity definition file."""

    build_path = build_file if build_file.is_absolute() else source_dir / build_file

    if not build_path.exists():
        raise FileNotFoundError(f"Build definition not found: {build_path}")

    if build_path.name.lower().startswith("dockerfile") or build_path.suffix.lower() in {".dockerfile"}:
        patch_dockerfile_for_https(build_path)
        build_context = build_path.parent
        logging.info("Building container image %s from Dockerfile %s using %s", image_path, build_path, builder)
        run_command([builder, "build", str(image_path), f"buildkit://{build_context}"], dry_run=dry_run)
        return

    logging.info("Building container image %s from definition file %s using %s", image_path, build_path, builder)
    run_command([builder, "build", str(image_path), str(build_path)], dry_run=dry_run)


def main():
    parser = argparse.ArgumentParser(description="Clone a repo and install it with pip or build a container")
    parser.add_argument("--repo", default=repo_url, help="Git repository to clone")
    parser.add_argument(
        "--package-name",
        default=default_package_name,
        help="Package name to check for before installing",
    )
    parser.add_argument(
        "--build-file",
        default=None,
        help="Optional Dockerfile or Singularity definition file path relative to the cloned repo",
    )
    parser.add_argument("--image-name", default="vista.sif", help="Output image file name for container builds")
    parser.add_argument("--out-dir", default="containers", help="Directory to place the built image")
    parser.add_argument("--dry-run", action="store_true", help="Show commands without executing them")

    args = parser.parse_args()

    if args.build_file is None and is_package_installed(args.package_name):
        logging.info("Package already installed: %s", args.package_name)
        return

    if not shutil.which("git"):
        raise RuntimeError("git is required but not found in PATH")

    with tempfile.TemporaryDirectory(prefix="vista-install-", dir=str(Path.cwd())) as tmp_dir:
        source_dir = Path(tmp_dir) / "repo"

        logging.info("Cloning repository %s -> %s", args.repo, source_dir)
        run_command(["git", "clone", args.repo, str(source_dir)], dry_run=args.dry_run)

        if args.build_file:
            out_dir = Path(args.out_dir)
            if not out_dir.is_absolute():
                out_dir = Path.cwd() / out_dir
            out_dir.mkdir(parents=True, exist_ok=True)

            image_path = out_dir / args.image_name
            if image_path.exists():
                logging.info("Container already exists: %s", image_path)
                return

            builder = find_container_builder()
            build_from_definition(source_dir, Path(args.build_file), image_path, builder, args.dry_run)
            if not image_path.exists() and not args.dry_run:
                raise RuntimeError("Container build failed")
            return

        logging.info("Installing package from %s", source_dir)
        run_command(
            [sys.executable, "-m", "pip", "install", "."],
            cwd=source_dir,
            dry_run=args.dry_run,
        )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        logging.exception(error)
        sys.exit(1)