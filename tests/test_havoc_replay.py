"""test: additive executable checks for independent SimC replay evidence."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from hypothesis import given, settings, strategies as st


ROOT = Path(__file__).resolve().parents[1]
LUA = Path(r"C:\Program Files (x86)\Lua\5.1\lua.exe")
SCRIPT = ROOT / "scripts" / "replay_havoc.lua"


def row(spell_id, name, *, fury=50, cooldowns=None, target="Dummy", targets=None):
    return {
        "time": 8.0,
        "id": spell_id,
        "name": name,
        "target": target,
        "queue_failed": False,
        "resources": {"fury": fury},
        "resources_max": {"fury": 170},
        "buffs": [],
        "cooldowns": cooldowns or [],
        "targets": targets or [{"name": "Dummy", "debuffs": []}],
    }


class HavocReplayTests(unittest.TestCase):
    def replay(self, rows=None, raw=None):
        with tempfile.TemporaryDirectory() as folder:
            trace_path = Path(folder) / "trace.json"
            report_path = Path(folder) / "report.json"
            if raw is not None:
                trace_path.write_text(raw, encoding="utf-8")
            else:
                trace = {
                    "sim": {
                        "options": {"desired_targets": 1},
                        "players": [{"collected_data": {"action_sequence": rows}}],
                    }
                }
                trace_path.write_text(json.dumps(trace), encoding="utf-8")
            process = subprocess.run(
                [str(LUA), str(SCRIPT), str(trace_path), str(report_path)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else None
            return process, report

    def test_bad_json_is_rejected_without_report(self):
        process, report = self.replay(raw='{"sim": [')
        self.assertNotEqual(process.returncode, 0)
        self.assertIsNone(report)

    def test_override_actions_remain_in_comparison_after_key_expansion(self):
        process, report = self.replay([
            row(210152, "death_sweep"), row(201427, "annihilation"),
            row(188499, "blade_dance"), row(162794, "chaos_strike"),
        ])
        self.assertEqual(process.returncode, 0, process.stderr)
        for profile in report["profileResults"]:
            self.assertEqual(4, profile["mappedActionRows"])
            self.assertEqual([210152, 201427, 188499, 162794],
                             [r["observedSpellID"] for r in profile["comparisons"]])

    def test_only_unique_same_name_cooldown_alias_is_used(self):
        eye_beam = row(
            198013,
            "eye_beam",
            cooldowns=[{"id": 452497, "name": "eye_beam", "stacks": 1, "remains": 5}],
        )
        process, report = self.replay([eye_beam])
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual([(452497, 198013)], [
            (alias["cooldownID"], alias["actionID"]) for alias in report["cooldownAliases"]
        ])

        eye_beam["cooldowns"][0]["name"] = "unrelated_cooldown"
        process, report = self.replay([eye_beam])
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual([], report["cooldownAliases"])

    def test_cooldown_stacks_are_never_available_charges(self):
        trace_row = row(
            258920,
            "immolation_aura",
            fury=50,
            cooldowns=[{"id": 258920, "name": "immolation_aura", "stacks": 99, "remains": 10}],
        )
        process, report = self.replay([trace_row])
        self.assertEqual(process.returncode, 0, process.stderr)
        comparison = report["profileResults"][0]["comparisons"][0]
        self.assertNotEqual(258920, comparison["predictedSpellID"])
        self.assertIn("currentCharges", comparison["missing"])

    def test_same_row_low_resource_does_not_emit_declared_spender(self):
        process, report = self.replay([row(162794, "chaos_strike", fury=0)])
        self.assertEqual(process.returncode, 0, process.stderr)
        comparison = report["profileResults"][0]["comparisons"][0]
        self.assertEqual(0, comparison["fury"])
        self.assertNotEqual(162794, comparison["predictedSpellID"])
        self.assertEqual([], report["profileResults"][0]["impossibleActionEvidence"])

    @settings(max_examples=12, deadline=None)
    @given(st.integers(min_value=0, max_value=29))
    def test_low_fury_property_rejects_all_declared_high_cost_spenders(self, fury):
        process, report = self.replay([row(162794, "chaos_strike", fury=fury)])
        self.assertEqual(process.returncode, 0, process.stderr)
        for profile in report["profileResults"]:
            predicted = profile["comparisons"][0]["predictedSpellID"]
            self.assertNotIn(predicted, [162794, 201427, 188499, 210152, 198013])

    def test_essence_break_window_uses_only_the_action_target(self):
        targets = [
            {"name": "A", "debuffs": []},
            {"name": "B", "debuffs": [
                {"id": 320338, "name": "essence_break", "stack": 1, "remains": 2.0}
            ]},
        ]
        wrong_target = row(162794, "chaos_strike", target="A", targets=targets)
        right_target = row(162794, "chaos_strike", target="B", targets=targets)
        process, report = self.replay([wrong_target, right_target])
        self.assertEqual(process.returncode, 0, process.stderr)
        comparisons = report["profileResults"][0]["comparisons"]
        self.assertFalse(comparisons[0]["contextEvidence"]["essenceBreakOnActionTarget"])
        self.assertTrue(comparisons[1]["contextEvidence"]["essenceBreakOnActionTarget"])
        self.assertIn("essenceBreakWindow", comparisons[0]["missing"])
        self.assertNotIn("essenceBreakWindow", comparisons[1]["missing"])

    def test_active_meta_aura_is_true_without_claiming_demonic_window(self):
        trace_row = row(162794, "chaos_strike")
        trace_row["buffs"] = [
            {"id": 162264, "name": "metamorphosis", "stacks": 1, "remains": 8.0}
        ]
        process, report = self.replay([trace_row])
        self.assertEqual(process.returncode, 0, process.stderr)
        comparison = report["profileResults"][0]["comparisons"][0]
        self.assertTrue(comparison["contextEvidence"]["metamorphosisAura"])
        self.assertNotIn("metaState", comparison["missing"])
        self.assertIn("demonicWindow", comparison["missing"])


if __name__ == "__main__":
    unittest.main()
