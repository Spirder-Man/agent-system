# -*- coding: utf-8 -*-
"""Pack CPU / GPU / Docker source archives from git HEAD. No GGUF."""
from __future__ import annotations

import io
import os
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

VERSION = sys.argv[1] if len(sys.argv) > 1 else "v0.1.0"
ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
DIST = ROOT / "dist"
DIST.mkdir(exist_ok=True)

status = subprocess.check_output(["git", "status", "--porcelain"], text=True, encoding="utf-8")
if status.strip():
    print("Warning: working tree is not clean. git archive uses HEAD.")

EDITIONS = (
    ("cpu", ROOT / "scripts" / "packaging" / "START-cpu.md"),
    ("gpu", ROOT / "scripts" / "packaging" / "START-gpu.md"),
    ("docker", ROOT / "scripts" / "packaging" / "START-docker.md"),
)


def git_tar(prefix: str) -> bytes:
    return subprocess.check_output(
        ["git", "archive", "--format=tar", f"--prefix={prefix}/", "HEAD"]
    )


def add_start(tar_bytes: bytes, prefix: str, start_path: Path) -> bytes:
    start_name = f"{prefix}/START.md"
    start_data = start_path.read_bytes()
    buf = io.BytesIO()
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as src:
        with tarfile.open(fileobj=buf, mode="w:") as dst:
            for m in src.getmembers():
                if m.isfile():
                    dst.addfile(m, src.extractfile(m))
                else:
                    dst.addfile(m)
            info = tarfile.TarInfo(name=start_name)
            info.size = len(start_data)
            info.mtime = int(__import__("time").time())
            dst.addfile(info, io.BytesIO(start_data))
    return buf.getvalue()


def write_zip(tar_bytes: bytes, zip_path: Path) -> None:
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as src:
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for m in src.getmembers():
                if m.isdir():
                    zf.writestr(m.name.rstrip("/") + "/", b"")
                    continue
                f = src.extractfile(m)
                data = f.read() if f else b""
                zf.writestr(m.name, data)


def write_tgz(tar_bytes: bytes, tgz_path: Path) -> None:
    import gzip

    with gzip.open(tgz_path, "wb") as gz:
        gz.write(tar_bytes)


for name, start in EDITIONS:
    folder = f"cangwei-{name}-{VERSION}"
    packed = add_start(git_tar(folder), folder, start)
    zip_path = DIST / f"{folder}.zip"
    tgz_path = DIST / f"{folder}.tar.gz"
    write_zip(packed, zip_path)
    write_tgz(packed, tgz_path)
    print(f"Wrote {zip_path} ({zip_path.stat().st_size} bytes)")
    print(f"Wrote {tgz_path} ({tgz_path.stat().st_size} bytes)")

print("Done.", DIST)
