# DUSTBOUND / 荒星前哨

<div align="center">

![Version](https://img.shields.io/badge/version-0.9.0--FIRST%20CONTACT-blue.svg)
![Roblox](https://img.shields.io/badge/engine-Roblox%20%2F%20Luau-00A2FF.svg)
![Rojo](https://img.shields.io/badge/sync-Rojo%207.x-red.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Mobile%20%7C%20Browser-orange.svg)

**Roblox · Luau · 原生 2D 自动防御与机器人采矿**

</div>

### 🌟 当前试玩版本：0.9 FIRST CONTACT

用 Roblox Studio 打开根目录 **`Dustbound-0.9.0-FIRST-CONTACT.rbxlx`**。本轮玩法改动、对比数据、测试边界与运行方式详见 [0.9 更新说明](docs/UPGRADE_0.9.md)。当前为可试玩开发版，非正式发行验收。

# DUSTBOUND / 荒星前哨

## 0.8.0 · FRONTIER EDITION

**Roblox / Luau 原生 2D 自动防御与机器人采矿 · 界面、战场与矿运体验升级版**

> 请打开 **`Dustbound-0.8.0-FRONTIER.rbxlx`**，不要误开保留的旧版 0.7 Place。  
> 这是可运行的升级集成版，**尚未完成 Roblox Studio / 真机上线验收**。云存档默认关闭。  
> 本轮现行规则专项 **84 项通过**；完整历史测试 **195 通过 / 129 失败**，与原仓库比较没有新增失败测试 ID。遗留失败尚未全部解决，详见 [升级与验证报告](docs/UPGRADE_0.8.md)。

![浏览器界面评审：并非 Roblox Studio 截图](docs/preview-08/home.png)

## 开始游戏

1. 在 Roblox Studio 打开根目录 **`Dustbound-0.8.0-FRONTIER.rbxlx`**。
2. 点击 **Play / F5**（不是仅服务端 Run）。
3. **前哨总览 → 开始游戏 → 远征航图 → 部署前哨**。
4. 主炮自动防守；清场后免费选择补给，机器人进入 30 秒采矿整备。
5. 通过矿运入库获得局内金矿；结算后用合金 / 数据 / 核心研究永久科技。

## 这次升级了什么

- **游戏入口**：主菜单不再默认铺满 24 个关卡。建立主菜单、远征、研究、图鉴、设置的独立层次。
- **视觉体系**：深青灰控制台、暖沙主按钮、薄荷绿信息；顶部状态分组、耐久条、五个装备卡位、任务简报和插画式免费选择。
- **新场景**：重新生成峡谷背景并打入运行时图集；删除覆盖战场的大型圆角半透明面板。
- **空地分流**：爬行与重甲虫只从左右地面通道前进；掠翼虫第 3 波起从上方进入，使用独立躯干和扑翼图层。
- **双侧采矿**：矿脉实体化，机器人履带、钻头、矿屑、进度、载货返航和入库反馈组成完整循环。
- **逻辑保留**：服务端掌控金币、伤害、关卡和研究；保持旧科技 ID、存档迁移和现有经济约束。
- **评审工具**：浏览器交互预览通过 Lupa 运行同一份 Lua Core，而不是一套虚假的前端规则。

## 浏览器交互预览

浏览器版是单独的 HTML / Canvas 展示层，方便评审界面、美术和逻辑；**不是 Roblox 模拟器，不与原生 GUI 像素级一致**。

```bash
python -m pip install -r preview/requirements.txt
python preview/server.py --port 8080
```

在本机浏览器访问 `http://localhost:8080`。浏览器使用临时内存会话，不连接 Roblox 云档。请勿把这个本地评审服务器作为正式线上后端。

## 源码与构建

需要 Python 3 和 Rojo 7.x：

```bash
python tools/build_place.py --rojo /path/to/rojo --output Dustbound-0.8.0-FRONTIER.rbxlx
```

开发同步：

```bash
rojo serve default.project.json
```

新模块 `src/Frontier.lua` 已加入项目映射。修改 `src/` 后须重新构建 `.rbxlx`。

美术重新生成：

```bash
python -m pip install Pillow==12.3.0
python tools/build_art.py
```

`flyerBody.svg` 和 `flyerWing.svg` 对应的 PNG 已包含。改动 SVG 后用 CairoSVG 导出 PNG，再重新生成图集。新图集仍支持 EditableImage 与 GUI fallback；如果配置自有 `AtlasImageId`，必须上传本轮的新图集，不能继续使用旧图集的 ID。

## 验证

```bash
python -m pip install -r tests/requirements.txt
PYTHONPATH=tests pytest -q tests/test_frontier_08.py tests/test_audit_07.py tests/test_integration_07.py
PYTHONPATH=tests python tests/campaign_pilot.py
luau tests/audit_native.luau
luau-compile src/*.lua
```

- 现行规则专项：**84 / 84 通过**。
- 原生 Luau 审计：**343,535 次断言通过**，不是相同数量的独立测试用例。
- 普通属性自动策略：**24 / 24 关完成**，不等于难度曲线已完成人类玩家验证。
- Chromium 实测：主流程、设置和 390px 布局通过，无未捕获 JS 错误；不是 Roblox 实机或 FPS 测试。
- 全量旧测试：原仓库 **168 / 129** → 本轮 **195 / 129**（通过 / 失败），剩余项不可全部忽略。

浏览器测试需单独安装 Playwright，并先启动预览服务器：

```bash
python -m pip install playwright
python -m playwright install --with-deps chromium
python tests/browser_08.py
python tests/browser_gameplay_08.py  # 真实时间首波与矿运验证
```

## 文件索引

- [完整升级、验证与未完成项](docs/UPGRADE_0.8.md)
- [专项测试输出](docs/test-08-focused.txt)
- [原仓库基线测试输出](docs/test-07-baseline.txt)
- [当前全量测试输出](docs/test-08-full.txt)
- [失败 ID 比较](docs/regression-comparison.json)
- [24 关规则试跑结果](docs/campaign-08-results.json)
- [0.7 原始说明存档](docs/README_0.7_ARCHIVE.md)
- [音频配置](docs/AUDIO_SETUP.md)
- [原有许可](LICENSE)

本轮背景为 AI 生成新素材；飞行虫为新编写 SVG 分层素材；基地、机器人等沿用原项目美术。没有替用户发布 Roblox 体验、上传音频，或推送 GitHub 分支。
