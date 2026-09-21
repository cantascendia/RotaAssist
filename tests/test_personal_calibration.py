"""test: additive Test-Lock scenario 3, character isolation and held-out decisions."""
import copy
import sys
from pathlib import Path

import pytest
from hypothesis import given, strategies as st

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import personal_calibration as p


def export():
    return ('demonhunter="Private Name"\nspec=havoc\nlevel=90\nrace=blood_elf\n'
            'talents=ABCDEFGHIJK123456789\nserver=private_server\nregion=us\n'
            + "\n".join(slot + "=,id=" + str(100 + i) + ",bonus_id=1/2,enchant_id=33,gem_id=4/5"
                        for i, slot in enumerate(p.SLOTS)))


def test_normalization_retains_equipment_and_removes_account_identity():
    normalized, identity = p.character_export(export())
    assert b"Private" not in normalized and b"private_server" not in normalized
    assert b"RotaAssistCharacter" in normalized
    assert identity["equipment"]["main_hand"]["enchant_id"] == "33"
    assert len(identity["equipment"]) == 16
    assert p.character_export(normalized.decode())[0] == normalized


@pytest.mark.parametrize("extra", ["input=other.simc", "actions=felblade", "json2=other.json",
                                  "warlock=x", "iterations=100", "head=,id=55", "spec=havoc"])
def test_rejects_extra_actors_directives_and_duplicates(extra):
    with pytest.raises(ValueError):
        p.character_export(export() + "\n" + extra)


@pytest.mark.parametrize("before,after", [("spec=havoc", "spec=vengeance"), ("level=90", "level=80"),
                                         ("off_hand=,id=115", "unknown_slot=,id=115"),
                                         ("bonus_id=1/2", "stats=1000agi")])
def test_incomplete_or_unmodeled_character_fails_closed(before, after):
    with pytest.raises(ValueError):
        p.character_export(export().replace(before, after))


def test_simulated_modifier_change_is_detected():
    _, identity = p.character_export(export())
    player = {"race": "blood_elf", "level": 90, "talents": identity["fields"]["talents"],
              "gear": {slot: {"encoded_item": "name," + ",".join(k + "=" + v for k, v in item.items())}
                       for slot, item in identity["equipment"].items()}}
    raw = {"sim": {"players": [player]}}
    p.verify_character(raw, identity)
    player["gear"]["head"]["encoded_item"] = player["gear"]["head"]["encoded_item"].replace("gem_id=4/5", "gem_id=9")
    with pytest.raises(ValueError, match="equipment mismatch"):
        p.verify_character(raw, identity)


def test_discovery_maximizes_worst_scenario_not_best_single_row():
    reference = [{"dps": 100}, {"dps": 100}]
    candidates = [{"policy": "fragile", "measurements": [{"dps": 200}, {"dps": 80}]},
                  {"policy": "robust", "measurements": [{"dps": 110}, {"dps": 105}]}]
    assert p.select_candidate(candidates, reference)["policy"] == "robust"
    assert p.difference({"dps": 101, "standardError": 1}, {"dps": 100, "standardError": 1})["lowerDelta"] < 0


@given(st.lists(st.integers(1, 1_000_000), min_size=1, max_size=8))
def test_bonus_modifiers_survive_normalization_in_order(bonuses):
    joined = "/".join(map(str, bonuses))
    normalized, identity = p.character_export(export().replace("bonus_id=1/2", "bonus_id=" + joined))
    assert all(item["bonus_id"] == joined for item in identity["equipment"].values())
    assert p.character_export(normalized.decode())[1] == identity


def test_frozen_policy_candidates_change_only_the_generator_threshold():
    import json
    policy = json.loads((Path(__file__).resolve().parents[1] / "research/independent-policy/candidate.json").read_text())
    original = copy.deepcopy(policy)
    candidates = p.candidates(policy)
    assert len(candidates) == 5 and policy == original
    assert len({p.digest(p.canonical(c)) for c in candidates}) == 5


def test_identical_discovery_and_holdout_seed_is_rejected():
    from types import SimpleNamespace
    with pytest.raises(ValueError, match="seeds must differ"):
        p.compare(SimpleNamespace(iterations=100, verify_iterations=200, seed=5, holdout_seed=5))


def test_talents_cannot_silently_change_in_simulator_output():
    _, identity = p.character_export(export())
    raw = {"sim": {"players": [{"race": "blood_elf", "level": 90, "talents": "OTHERBUILD"}]}}
    with pytest.raises(ValueError, match="talents"):
        p.verify_character(raw, identity)


def test_holdout_is_after_frozen_selection_and_does_not_inherit_reference_character(tmp_path, monkeypatch):
    import json
    from types import SimpleNamespace
    profile = tmp_path / "input.simc"
    profile.write_text(export())
    engine = tmp_path / "simc.exe"
    engine.write_bytes(b"test-engine")
    monkeypatch.setattr(p, "ENGINE_SHA256", p.digest(b"test-engine"))
    monkeypatch.setattr(p, "validated_profile", lambda *args: (b"race=orc\nhead=,id=99999\nactions=auto_attack\n", "", ""))
    calls = []

    def fake_run(engine, base, candidate, output, targets, duration, iterations, seed):
        assert b"race=blood_elf" in base and b"head=,bonus_id=1/2" in base
        assert b"race=orc" not in base and b"id=99999" not in base
        if seed == 8:
            assert (output / "selection.json").is_file()
        calls.append(seed)
        raw = output / (str(len(calls)) + ".raw.json")
        _, identity = p.character_export(export())
        player = {"race": "blood_elf", "level": 90, "talents": identity["fields"]["talents"],
                  "gear": {slot: {"encoded_item": "name," + ",".join(k + "=" + v for k, v in item.items())}
                           for slot, item in identity["equipment"].items()}}
        raw.write_text(json.dumps({"sim": {"players": [player]}}))
        return {"dps": 100 if candidate is None else 99, "standardError": 1, "raw": str(raw)}

    monkeypatch.setattr(p, "run", fake_run)
    args = SimpleNamespace(profile=profile, simc=engine, reference=tmp_path / "unused", output=tmp_path / "results",
                           policy=Path(__file__).resolve().parents[1] / "research/independent-policy/candidate.json",
                           seed=7, holdout_seed=8, iterations=100, verify_iterations=200, scenarios="1:120,5:120")
    folder = p.compare(args)
    report = json.loads((folder / "report.json").read_text())
    assert calls == [7] * 12 + [8] * 4
    assert report["candidateClearsEveryReferenceGate"] is False
    assert report["runtimePolicyInstalled"] is False
    assert report["maximumDpsEstablished"] is False
