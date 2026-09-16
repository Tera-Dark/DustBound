# 0.5 开发说明

## 17 个源码文件

| 文件 | 责任 |
|---|---|
| Boot.client.lua | 独立 ReplicatedFirst 启动页；无 require、DataStore 或服务器就绪依赖。 |
| Config.lua | 数值、教学、云存档/分析开关、图集和音频 ID。 |
| Tech.lua / Catalog.lua | 48 节点、前置/成本；武器/补给/怪物共享参数与图鉴。 |
| Rules.lua | schema 5 清洗/旧档迁移、科技原子扣费、属性、材料、记录。 |
| Core.lua | 纯权威模拟：波次、弹丸、机器人、操作校验、一次结算、快照。 |
| Guide.lua | 只读情报、投资变化/理由、预计运回、研究缺口、教学提示。 |
| Server.server.lua | 每玩家独立会话、网络、节流、快照、读档/保存/访客/分析入口。 |
| ProfileStore.lua | 云读写、锁、失败保护、稳定待写快照/重试；不自动合并访客。 |
| Telemetry.lua | 服务端事件白名单、本地有界记录、可选平台 API。 |
| UI.lua | 原生 UI 构造、按钮、滚动面板。 |
| Client.client.lua | 安全区、自适应布局、请求确认、页面优先级、启动就绪。 |
| Panels.lua | 研究/配装/预设/图鉴/设置/暂停/存档/补给/经营/结算。 |
| Motion.lua | 关节步态、炮塔后坐、弹丸插值、钻探/返航、特效池。 |
| Art.lua / ArtData.lua | 单张共享内嵌图集、上传图集或 GUI 兼容绘制。 |
| Audio.lua | 限频事件声音、音量/暂停、可选钻探音与环境循环。 |

入口将 `Tech` / `Catalog` 注入 Config，Core / Rules / Guide 不 require Roblox 实例。纯模块示例：

```lua
local C = require('../src/Config')
C.Tech = require('../src/Tech')
C.Catalog = require('../src/Catalog')
local R = require('../src/Rules')
local G = require('../src/Core')
local state = G.new(C, R, R.cleanProfile(nil))
G.start(state, C, R, 'tutorial') -- 或 standard
G.step(state, C, R, 0.1)
```

## 状态与时间

```text
menu -> start(tutorial|standard) -> running / combat
combat -> 28 秒生成结束 -> clearing
clearing -> 敌人与弹丸均清空 -> mining + supply
supply -> 接收有效 token/id -> 完整 30 秒 mining
mining -> 下一波 combat
教学第 3 波 mining 完成 -> ended（固定首通材料 / 重温零材料）
标准第 10 波 mining 完成 -> decision（撤离 / 追加两波）
标准第 12 波 mining 完成 -> ended
失守 -> ended；abandon(confirm) -> menu（零结算）
```

`paused` 与 `supply` 是独立阻塞。任一存在都不推进战斗/机器人/增益/整备有效时间；统计仍分别记录停留时长。`pause` 接受明确 boolean 而非 toggle。关闭设置回暂停菜单；关闭经营台不自动解除原有暂停。无中途战斗存档。

- 固定 0.1 秒模拟、0.15 秒快照，掉帧有限追赶，不承诺墙钟时长等于模拟时长。
- 机器人完成钻探锁定本趟 cargo，运回同时增加 ore / totalMined；之后投资不追改已有货物。
- 末刻没有返回的货物默认不计；industry_8 仅回收已装好的货物，不凭空补钻探产量。
- Guide 估算当前配置下的返航，不发材料，不包含未来投资或末刻远程卸载。
- 实体弹丸飞行结束才伤害；电弧/喷焰是瞬时类。动画不决定伤害、经济或研究。

## GUI 与手机

四层：Background(1,None)、HUD(10,CoreUISafeInsets)、Shade(20,None)、Panels(21,CoreUISafeInsets)。背景/拦截遮罩全屏，交互只在安全区域。

优先使用 canvas.AbsoluteSize，未布局时参考视口与 GuiService inset；零尺寸先等待。桌面逻辑 1440×810；紧凑高度 540，宽度按安全区比例扩大且至少 960，维持等比尺度。尺寸变化可重建布局。横屏操作为目标，设置 LandscapeSensor；不宣称完整竖屏支持。

手机投资只有一张分页卡；研究只显示当前分支 8 个节点和详情。长内容仍使用原生 ScrollingFrame。按钮 Activated，不把鼠标专属事件作为唯一入口。当前 844×390 / 模拟 36px 顶部 inset 主要购买按钮约 47px 高；**实际更大安全边距或更小窗口可能降低命中尺寸，需要设备验收，不保证所有屏幕达到 44px。**

兼容绘制最多显示 12 只敌人，其余继续服务器模拟，并显示额外数量提示；完整图集路径敌人模拟上限 20。不把 GUI 实例数或离线帧率当作低端性能证明。

## 请求、存档与分析

客户端提交意图，不能指定伤害、收入、科技价格。服务器验证类型/阶段/资源/解锁/补给令牌；令牌桶 24、恢复 12/s，业务操作间隔至少 0.12s。

请求整数 ID 单调递增，服务器确认最高 ID，重复请求不会重复扣费。客户端业务等待约 3 秒后重新请求快照；元数据 view/ui_ready 不占业务等待位。面板等待层拦截重复点击，不代替服务端校验。

`runSerial / settledSerial` 与阶段检查约束单局结算；教程完成标记控制固定一次材料。不在云更新回调累加奖励。

ProfileStore 的生产调用使用 `flush`：先处理待重试快照，再写新修订，最后释放锁。不要将带旧 pending 的 record 直接 `save(release=true)` 作为最终关服路径。详见 STORAGE_MIGRATION.md。

Telemetry 为独立服务端模块；快照只有摘要，最多保留 48 条本地事件；平台上报默认关闭。详见 ANALYTICS.md。

## 重建与测试

本轮工具：Luau 0.738、Rojo 7.7.0。依赖见 tests/requirements.txt。

```bash
pip install -r tests/requirements.txt
python tools/export_reference.py
python tools/build_place.py --rojo /path/to/rojo
pytest -q tests
/path/to/luau tests/native.luau
python tests/pilot.py
for f in src/*.lua; do luau-compile "$f" >/dev/null || exit; done
luau-analyze src/Config.lua src/Rules.lua src/Core.lua src/Tech.lua src/Catalog.lua src/Guide.lua
```

修改 src 后先重建 Place 再测试；测试会比较导出的 17 个 Source，拒绝源码与 Place 不一致。

可选素材 / 离线预览：

```bash
python tools/build_art.py
python tools/build_audio.py
# build_art 改变源码/裁切后必须重建 Place
pip install -r tools/preview-requirements.txt
python -m playwright install chromium
python tools/preview_layout.py --capture
python tools/preview_motion.py
```

预览工具执行 Lua GUI，再把 mock 变换序列转浏览器排版；HTML 写入 `.cache/previews`，非游戏实现。字体、渲染、复制、输入和性能不等价于 Roblox。截图包含示例状态；结果页经过完整离线教学模拟，和 tests/pilot.py 的投资策略不同，时长/投资次数不必相同。

## 扩展约定

新增字段同步 schema/清洗/迁移/测试；新增效果同时修改 Tech/Catalog 与 Core/Rules 的消费者；网络不得直接透传任意事件/实例/资源修改。保持角色无依赖启动、未发布本地入口、失败档保护和模拟/表现分离。
