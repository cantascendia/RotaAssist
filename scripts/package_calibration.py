"""Build a deterministic stdlib-only local calibration toolkit ZIP."""
import argparse
import hashlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "README.md": "docs/PERSONAL_CALIBRATION_README.md",
    "START.cmd": "scripts/start_personal_calibration.cmd",
    "policy.json": "research/independent-policy/candidate.json",
    "LICENSE": "LICENSE",
    **{"scripts/" + name: "scripts/" + name for name in (
        "run_personal_calibration.ps1", "personal_calibration.py", "independent_policy.py",
        "search_independent_policy.py", "simc_bench.py")},
}


def build(output: Path):
    payload = {name: (ROOT / source).read_bytes() for name, source in FILES.items()}
    manifest = "".join(hashlib.sha256(data).hexdigest() + "  " + name + "\n" for name, data in sorted(payload.items()))
    payload["SHA256SUMS.txt"] = manifest.encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo("RotaAssist-Calibration/" + name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    with zipfile.ZipFile(output) as archive:
        assert len(archive.namelist()) == len(payload)
        for name, data in payload.items():
            if archive.read("RotaAssist-Calibration/" + name) != data:
                raise ValueError("package payload mismatch: " + name)
    sha = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".zip.sha256").write_text(sha + "  " + output.name + "\n")
    print(f"READY: {output.resolve()}\nSHA256: {sha}\nFILES: {len(payload)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    build(parser.parse_args().output)
