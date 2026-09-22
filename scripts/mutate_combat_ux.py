"""Exercise deliberate binding/UI regressions in isolated copies, never the checkout."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MUTATIONS = [
    ("ignore_active_page", "UI/KeybindResolver.lua", 'slot = current', 'slot = button.action'),
    ("disable_positive_cache", "UI/KeybindResolver.lua", 'if cache[spellID] ~= nil then', 'if false then'),
    ("drop_override_match", "UI/KeybindResolver.lua", 'return current', 'return id'),
    ("accept_macros", "UI/KeybindResolver.lua", 'kind == "spell"', '(kind == "spell" or kind == "macro")'),
    ("ignore_override_bar", "UI/KeybindResolver.lua", 'descriptor.main and suppressMain', 'false'),
    ("retain_stale_cache", "UI/KeybindResolver.lua", 'wipe(cache)', '-- wipe(cache)'),
    ("delay_reduced_motion", "UI/Widgets/IconWidget.lua", 'if self.reducedMotion then\n        self.icon:SetTexture(texture)', 'if false then\n        self.icon:SetTexture(texture)'),
    ("stale_pending_texture", "UI/Widgets/IconWidget.lua", 'if self.currentTexture then self.icon:SetTexture(self.currentTexture) end', '-- no texture update'),
    ("pulse_reduced_range", "UI/Widgets/IconWidget.lua", 'not self.reducedMotion and not self.oorAnim:IsPlaying()', 'not self.oorAnim:IsPlaying()'),
    ("invent_confidence", "UI/MainDisplay.lua", 'widget:SetConfidence(predData.confidence)', 'widget:SetConfidence(predData.confidence or 1.0)'),
    ("ignore_glow_setting", "UI/MainDisplay.lua", 'elements.mainIcon:SetGlow(showProcGlow and hasProc)', 'elements.mainIcon:SetGlow(true)'),
    ("preserve_stale_queue", "UI/MainDisplay.lua", 'local data = (smartQ and smartQ:GetFinalQueue()) or emptyQueue', 'local data = smartQ and smartQ:GetFinalQueue(); if not data then return end'),
    ("ignore_capture_opt_in", "Engine/CombatAudit.lua", 'if not active or not record then return end', 'if not record then return end'),
    ("unbounded_capture_rows", "Engine/CombatAudit.lua", 'record.nextIndex = index % LIMIT + 1', 'record.nextIndex = index + 1'),
    ("skip_capture_cadence", "Engine/CombatAudit.lua", 'now - lastSample < INTERVAL', 'now - lastSample < 0'),
    ("serialize_secret_values", "Engine/CombatAudit.lua", 'row.queueSpellID, row.source = number(main.spellID), text(main.source)', 'row.queueSpellID, row.source = main.spellID, main.source'),
    ("record_other_players", "Engine/CombatAudit.lua", 'public(unit) and unit == "player"', 'public(unit)'),
    ("unbounded_capture_builds", "Engine/CombatAudit.lua", '#record.builds < 16', 'true'),
    ("show_partial_key", "UI/Widgets/IconWidget.lua", 'if self.keybind.GetStringWidth then', 'if false then'),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--lua', default=r'C:\Program Files (x86)\Lua\5.1\lua.exe')
    args = parser.parse_args(); args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for name, file, before, after in MUTATIONS:
        isolated = Path(tempfile.mkdtemp(prefix=name + '-', dir=args.output.resolve()))
        for part in ('addon', 'tests', 'scripts'):
            shutil.copytree(ROOT / part, isolated / part, ignore=shutil.ignore_patterns('__pycache__'))
        path = isolated / 'addon' / file
        source = path.read_text(encoding='utf-8')
        if source.count(before) != 1:
            raise ValueError('Mutation anchor drift: ' + name)
        path.write_text(source.replace(before, after, 1), encoding='utf-8')
        run = subprocess.run([args.lua, 'scripts/run_tests.lua', 'keybind_resolver', 'icon_accessibility', 'combat_ux', 'combat_audit'],
                             cwd=isolated, capture_output=True, text=True, encoding='utf-8', errors='replace')
        (isolated / 'result.txt').write_text(run.stdout + run.stderr, encoding='utf-8')
        results.append({'name': name, 'killed': run.returncode != 0 and 'FAIL ' in run.stdout})
    (args.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(results, indent=2))
    if not all(row['killed'] for row in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
