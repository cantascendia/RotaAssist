# RotaAssist 安装与首次使用

这是浩劫优先的测试版本。安装不需要 Python、Lua 或其他插件，依赖库已内置。尚未通过真实大米、团本验收，不能保证最高 DPS。

1. 在战网里打开 WoW 正式服的安装目录。退出游戏，将 ZIP 内的整个 `RotaAssist` 文件夹放入 `_retail_/Interface/AddOns/`。
2. 检查最终路径是 `Interface/AddOns/RotaAssist/RotaAssist.toc`，不能多嵌套一层文件夹。升级前可把旧目录备份到 AddOns 之外；无需删除角色设置。
3. 登录角色，在插件列表启用 RotaAssist。输入 `/ra version` 核对版本，再用 `/ra config` 打开设置，选“实战专注”。
4. 大图标是下一步技能；小图标是会变化的预测。按键为空表示没有确认到原生动作按钮绑定，或完整组合键无法放入图标；并不表示技能不可用。
5. `/ra lock` 切换锁定；解锁后可拖动主条，右键主条打开设置。需要更多教练信息时选择“学习视图”。
6. 先在训练假人处检查目标切换、按键翻页、超距、天赋替换。实验独立推荐默认关闭；带“实验”标记的推荐尚未通过伤害性能认证。

## 提交本机验收样本

先选好显示方案，再输入 `/ra capture on`。进行一小段假人或战斗测试，输入 `/ra capture off`，随后 `/reload` 或正常退出游戏。记录位于游戏目录下的 `WTF/Account/<账户>/SavedVariables/RotaAssist.lua`，当前 profile 的 `combatAudit` 字段。开始新采样会覆盖上一份，设置变化会停止采样。

记录最多保存最近 1200 个事件。它不是完整战斗日志，不包含 DPS 测量。不要把整个 WTF 目录发送给别人；本地分析只需要 RotaAssist 自己的采样。界面异常时保留报错和实际发生时间。

## English

Close WoW. Extract the `RotaAssist` folder into the retail client's `Interface/AddOns/` directory. The final path must be `Interface/AddOns/RotaAssist/RotaAssist.toc`. No separate dependencies are needed. Enable the addon, run `/ra version`, then `/ra config` and choose **Combat focus**. `/ra lock` toggles dragging. The large icon is the next action; smaller icons are changing forecasts. Missing key labels mean the binding could not be confirmed.

This Havoc-focused test build has not passed live raid/Mythic+ acceptance and does not guarantee maximum DPS. Experimental recommendations remain opt-in. For local testing, `/ra capture on` starts a new bounded public trace; `/ra capture off` stops it. Reload or log out normally to save. Starting a new capture replaces the previous one.

## 日本語

WoW を終了し、ZIP 内の `RotaAssist` フォルダーを正式版クライアントの `Interface/AddOns/` に配置してください。最終パスは `Interface/AddOns/RotaAssist/RotaAssist.toc` です。追加ライブラリは不要です。

アドオンを有効にし、`/ra version` で確認、`/ra config` から「戦闘に集中」を選択します。`/ra lock` で移動ロックを切り替えます。大きいアイコンは次の行動、小さいアイコンは変化する予測です。キー表示が空の場合は、割り当てを確認できていません。

このテスト版は実際のレイド・ミシック＋で未検証であり、最大 DPS を保証しません。検証記録は `/ra capture on` で開始、`/ra capture off` で停止し、再読込または通常ログアウトで保存します。開始すると前回の記録を置き換えます。
