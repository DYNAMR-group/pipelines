#!/usr/bin/env python3

"""
Container bootstrap script.

Checks for an existing Singularity/Apptainer image.
If missing:
    - clones repository containing a Dockerfile
    - builds an Apptainer/Singularity image directly from that Dockerfile
    - stores the image locally (HPC)
"""


import logging
import shutil
import subprocess
import sys
from pathlib import Path
import tempfile


# Configuration

repo_url = "https://github.com/pathogenwatch-oss/vista.git"

image_name = "vista.sif"

# Default container output directory (can be overridden via CLI)
container_dir = Path("containers")


def _resolve_paths(out_dir: str, image: str):
    out = Path(out_dir)
    return out, out / image

# Logging

logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(message)s"
)

# Helper functions

def run_command(command, dry_run=False):
    """Run a command, capture output, and raise on failure.

    Args:
        command: sequence of command arguments (list/tuple)
        dry_run: if True, only log the command without executing it
    """

    logging.info("Running: %s", " ".join(map(str, command)))

    if dry_run:
        logging.info("Dry-run mode: not executing command")
        return None

    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
    )

    if completed.stdout:
        logging.info("stdout: %s", completed.stdout.strip())

    if completed.stderr:
        logging.info("stderr: %s", completed.stderr.strip())

    if completed.returncode != 0:
        raise subprocess.CalledProcessError(
            completed.returncode, command, output=completed.stdout, stderr=completed.stderr
        )

    return completed

def find_container_builder():

    if shutil.which("apptainer"):
        return "apptainer"

    if shutil.which("singularity"):
        return "singularity"

    raise RuntimeError(
        "Neither apptainer nor singularity found"
    )

# Main

def main():
    parser = __import__("argparse").ArgumentParser(
        description="Bootstrap a Singularity/Apptainer image directly from a repository Dockerfile"
    )

    parser.add_argument("--repo", default=repo_url, help="Git repository to clone")
    parser.add_argument("--image-name", default=image_name, help="Output image file name (e.g. vista.sif)")
    parser.add_argument("--out-dir", default=str(container_dir), help="Directory to place the image")
    parser.add_argument("--docker-tag", default="local_build:latest", help="Optional Docker tag for fallback builds only")
    parser.add_argument("--dry-run", action="store_true", help="Show commands without executing them")

    args = parser.parse_args()

    logging.info("Checking container availability")

    builder = find_container_builder()

    logging.info("Using container builder: %s", builder)

    out_dir, container_image = _resolve_paths(args.out_dir, args.image_name)

    # Existing image check
    if container_image.exists():
        logging.info("Container already exists: %s", container_image)
        return

    logging.info("Container missing. Building new image.")

    out_dir.mkdir(parents=True, exist_ok=True)

    # Ensure git is available
    if not shutil.which("git"):
        raise RuntimeError("git is required but not found in PATH")

    # Temporary build directory
    with tempfile.TemporaryDirectory() as tmp_dir:
        source_dir = Path(tmp_dir) / "source"

        logging.info("Cloning repository %s -> %s", args.repo, source_dir)

        run_command(["git", "clone", args.repo, str(source_dir)], dry_run=args.dry_run)

        dockerfile = source_dir / "Dockerfile"

        if not dockerfile.exists():
            raise FileNotFoundError(f"Dockerfile not found: {dockerfile}")

        logging.info("Dockerfile found: %s", dockerfile)

        logging.info("Building %s directly from Dockerfile using %s", container_image, builder)
        build_spec = f"buildkit://{source_dir}"

        try:
            run_command([builder, "build", str(container_image), build_spec], dry_run=args.dry_run)
        except subprocess.CalledProcessError as exc:
            if shutil.which("docker"):
                logging.warning("Direct build failed; falling back to a Docker daemon build")
                docker_tag = args.docker_tag

                logging.info("Building temporary Docker image: %s", docker_tag)
                run_command(["docker", "build", "-t", docker_tag, str(source_dir)], dry_run=args.dry_run)

                logging.info("Converting Docker image to %s using %s", container_image, builder)
                run_command([builder, "build", str(container_image), f"docker-daemon://{docker_tag}"], dry_run=args.dry_run)
            else:
                raise exc

    # Validate
    if not container_image.exists() and not args.dry_run:
        raise RuntimeError("Container build failed")

    logging.info("Container created successfully: %s", container_image)


if __name__ == "__main__":

    try:
        main()

    except Exception as error:

        logging.exception(error)
        sys.exit(1)