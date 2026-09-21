"""Additive tests for the pinned SimC benchmark gate (Test-Lock scenario ③)."""

import copy
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest
from hypothesis import given, strategies as st

from scripts import simc_bench as bench


def result_json():
    return {
        "version": bench.EXPECTED_VERSION,
        "git_revision": bench.SOURCE_COMMIT[:7],
        "logs": [],
        "sim": {
            "options": {
                "desired_targets": 5,
                "seed": 20260922,
                "threads": 2,
                "iterations": 5001,
                "max_time": 120.0,
                "fixed_time": True,
                "dbc": {
                    "version_used": "Live",
                    "Live": {"wow_version": "12.1.0.69875", "build_level": 69875},
                },
            },
            "players": [{
                "specialization": "Havoc Demon Hunter",
                "collected_data": {"dps": {"count": 4999, "mean": 540000.0, "mean_std_dev": 200.0}},
            }],
            "statistics": {"elapsed_time_seconds": 4.0, "elapsed_cpu_seconds": 7.0},
        },
    }


def parse(data):
    return bench.parse_result(data, 5, 20260922, 2, 5000)


def test_report_uses_observed_build_and_sample_count():
    report = parse(result_json())
    assert report["build"] == "12.1.0.69875 Live"
    assert report["dps_sample_count"] == 4999
    assert report["dps_95ci_half_width_approx"] == 392.0


@pytest.mark.parametrize("field,value", [
    ("desired_targets", 1), ("seed", 20260923), ("threads", 5),
    ("iterations", 1001),
])
def test_scenario_mismatch_fails_closed(field, value):
    data = result_json()
    data["sim"]["options"][field] = value
    with pytest.raises(ValueError):
        parse(data)


@pytest.mark.parametrize("mutation", [
    lambda d: d["sim"]["options"]["dbc"]["Live"].update(build_level=69848),
    lambda d: d["sim"]["options"]["dbc"].update(version_used="PTR"),
    lambda d: d["sim"]["players"][0]["collected_data"]["dps"].update(count=4997),
    lambda d: d["logs"].append({"level": "warning", "message": "new unknown assumption"}),
    lambda d: d["sim"]["players"][0].update(specialization="Vengeance Demon Hunter"),
])
def test_build_data_and_unknown_warnings_fail_closed(mutation):
    data = copy.deepcopy(result_json())
    mutation(data)
    with pytest.raises(ValueError):
        parse(data)


@given(st.integers(min_value=0, max_value=50))
def test_extra_stock_apl_line_never_passes_exact_hash_gate(extra):
    profile = b"demonhunter=Example\nactions+=/eye_beam\n"
    with tempfile.TemporaryDirectory() as directory, \
            patch.object(bench, "PROFILE_SHA256", bench.sha256(profile)), \
            patch.object(bench, "APL_SHA256", bench.sha256(bench.apl_bytes(profile))):
        path = Path(directory) / "stock.simc"
        path.write_bytes(profile + (b"actions+=/eye_beam\n" * extra))
        if extra:
            with pytest.raises(ValueError, match="SHA-256 mismatch"):
                bench.validated_profile(path, "eye_beam_hold_aoe")
        else:
            modified, _, _ = bench.validated_profile(path, "eye_beam_hold_aoe")
            assert modified.count(b"actions+=/eye_beam,if=active_enemies=1|cooldown.essence_break.remains<3\n") == 1
