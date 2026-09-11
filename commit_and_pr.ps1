git add addon/UI/MainDisplay.lua
git commit -m "refactor(ui): rewrite MainDisplay as horizontal icon strip"

git add addon/UI/Widgets/IconWidget.lua
git commit -m "feat(ui): add out-of-range detection and red pulse to IconWidget"

git add addon/UI/Widgets/DefensiveAlert.lua addon/UI/Widgets/InterruptAlert.lua addon/RotaAssist.toc
git commit -m "refactor(ui): make DefensiveAlert and InterruptAlert independent floating frames"

git commit --allow-empty -m "feat(ui): hide CD spells from prediction slots and add main icon CD swirl"

git add addon/UI/ConfigPanel.lua
git commit -m "chore(config): update ConfigPanel for new display options"

git add tests/mock_wow_api.lua tests/test_main_display_ui.lua
git commit -m "test: add MainDisplay UI layout and behavior tests"

git add docs/ai-cto/
git commit -m "docs: update ai-cto memory files for Round 15 UI overhaul"

git push origin improve/round15-ui-overhaul

gh pr create --repo Loveil381/RotaAssist --base main --head improve/round15-ui-overhaul --title "refactor: Round 15 UI overhaul — HekiLight-style icon strip" --body "重构 MainDisplay 为水平图标条，新增 out-of-range/proc-glow/CD-swirl 特效，DefensiveAlert 和 InterruptAlert 独立浮动，预测槽位隐藏 CD 技能，更新 ConfigPanel 和测试。"

git log --oneline -n 7
gh pr view improve/round15-ui-overhaul --json url
gh run list --repo Loveil381/RotaAssist --branch improve/round15-ui-overhaul --limit 1 --json url,databaseId
