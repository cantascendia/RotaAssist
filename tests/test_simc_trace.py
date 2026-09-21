"""Additive SimC trace validation tests (Test-Lock scenario ③)."""

import copy

import pytest
from hypothesis import given, strategies as st

from scripts import simc_trace as trace


def raw_trace():
    row = {
        "time": 2.796, "id": 198013, "name": "eye_beam", "target": "Fluffy_Pillow",
        "spell_name": "Eye Beam", "queue_failed": False,
        "buffs": [{"id": 391215, "name": "initiative", "stacks": 1, "remains": 2.204}],
        "cooldowns": [{"id": 232893, "name": "felblade", "stacks": 1, "remains": 5.051}],
        "targets": [{"name": "Fluffy_Pillow", "debuffs": []}],
        "resources": {"fury": 81.0}, "resources_max": {"fury": 170.0},
    }
    return {
        "version": "1210-01", "git_revision": "774babd", "report_version": "2.0.0",
        "logs": [],
        "sim": {
            "options": {
                "desired_targets": 1, "max_time": 30.0, "seed": 20260922,
                "threads": 1, "iterations": 1, "fixed_time": True, "log": True,
                "vary_combat_length": 0.0,
                "dbc": {
                    "version_used": "Live",
                    "Live": {"wow_version": "12.1.0.69875", "build_level": 69875},
                },
            },
            "players": [{
                "name": "MID2_Demon_Hunter_Havoc_Fel-Scarred",
                "specialization": "Havoc Demon Hunter", "talents": "pinned-talent-string",
                "profile_source": "custom",
                "collected_data": {
                    "action_sequence_precombat": [], "action_sequence": [row],
                },
            }],
        },
    }


def validated(raw):
    return trace.validated_trace(raw, targets=1, duration=30, seed=20260922)


def test_export_keeps_real_action_snapshot_without_charge_invention():
    raw = raw_trace()
    output = validated(raw)
    action = output["sim"]["players"][0]["collected_data"]["action_sequence"][0]
    assert action == raw["sim"]["players"][0]["collected_data"]["action_sequence"][0]
    assert action["cooldowns"][0]["stacks"] == 1
    assert "current_available_charges" in output["coverage"]["not_captured_per_action"]


def test_real_wait_row_has_state_but_no_invented_action_label():
    raw = raw_trace()
    wait = copy.deepcopy(raw["sim"]["players"][0]["collected_data"]["action_sequence"][0])
    wait["time"] = 3.0
    for key in ("id", "name", "target", "spell_name", "queue_failed"):
        wait.pop(key)
    wait["wait"] = 0.42
    raw["sim"]["players"][0]["collected_data"]["action_sequence"].append(wait)
    output = validated(raw)
    assert output["coverage"]["wait_rows"] == 1
    assert output["sim"]["players"][0]["collected_data"]["action_sequence"][-1] == wait


@pytest.mark.parametrize("change", [
    lambda d: d.update(report_version="3.0.0-alpha1"),
    lambda d: d["sim"]["options"].update(desired_targets=5),
    lambda d: d["sim"]["options"].update(threads=4),
    lambda d: d["sim"]["options"]["dbc"]["Live"].update(build_level=69848),
    lambda d: d["sim"]["players"][0]["collected_data"]["action_sequence"][0].pop("resources"),
    lambda d: d["sim"]["players"][0]["collected_data"]["action_sequence"][0].pop("cooldowns"),
    lambda d: d["logs"].append({"level": "warning", "message": "unexpected"}),
])
def test_trace_rejects_mismatched_or_incomplete_source(change):
    raw = copy.deepcopy(raw_trace())
    change(raw)
    with pytest.raises(ValueError):
        validated(raw)


@given(st.floats(allow_nan=True, allow_infinity=True, width=64))
def test_invalid_action_timestamps_never_pass(value):
    raw = raw_trace()
    raw["sim"]["players"][0]["collected_data"]["action_sequence"][0]["time"] = value
    if not (0 <= value <= 30):
        with pytest.raises(ValueError):
            validated(raw)
    else:
        assert validated(raw)["coverage"]["combat_rows"] == 1
