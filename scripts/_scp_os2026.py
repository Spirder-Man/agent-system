# -*- coding: utf-8 -*-
import subprocess
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

root = Path(r"c:/Users/lcy/Desktop/agent-system")
md = root / "docs/platform/os2026-作品介绍.md"
pdf = root / "docs/platform/os2026-作品介绍.pdf"
remote_dir = "D:/桌面/agent/开源大赛提交"
host = "company-pc"

ssh_base = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15", "-o", "IdentitiesOnly=yes", host]


def run(cmd, timeout=40):
    print(">", " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, timeout=timeout)
    out = r.stdout.decode("utf-8", "replace")
    err = r.stderr.decode("utf-8", "replace")
    if out.strip():
        print(out)
    if err.strip():
        print(err)
    print("exit", r.returncode)
    return r.returncode


win_dir = remote_dir.replace("/", "\\")
run(ssh_base + [f'cmd /c mkdir "{win_dir}"'])

# OpenSSH 9+ scp uses SFTP and can hang on this Windows host; -O uses classic scp.
code = run(
    [
        "scp",
        "-O",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=15",
        "-o",
        "IdentitiesOnly=yes",
        str(md),
        str(pdf),
        f"{host}:{remote_dir}/",
    ],
    timeout=60,
)
if code != 0:
    sys.exit(code)

run(
    ssh_base
    + [
        "powershell",
        "-NoProfile",
        "-Command",
        f"Get-ChildItem -LiteralPath '{win_dir}' | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String -Width 220",
    ]
)
