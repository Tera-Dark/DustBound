# DUSTBOUND / 荒星前哨

<div align="center">

![Version](https://img.shields.io/badge/version-0.7.0--AUDIT-blue.svg)
![Roblox](https://img.shields.io/badge/engine-Roblox%20%2F%20Luau-00A2FF.svg)
![Rojo](https://img.shields.io/badge/sync-Rojo%207.x-red.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Mobile-orange.svg)

**Roblox · Luau · 原生 2D 自动防御与机器人采矿**

</div>

当前工程：**0.7 审计修复版（AUDIT）**  
更新日期：2026-09-17

> **请先打开根目录的 `Dustbound-0.7.0-AUDIT.rbxlx`。**
>
> 这是可以用于开发与验证的集成测试工程，**不是正式上线版**。最近一轮全量回归为 **168 通过 / 129 失败**；新规则与审计专项 **57 项通过**。剩余失败既包含旧规则/旧界面测试，也包含尚未恢复的功能保障，不能全部忽略。
>
> 当前状态以本 README 和 [0.7 审计报告](docs/AUDIT_0.7.md) 为准。带旧版本号的文档、截图和测试结果仅作历史参考。

## 1. 快速开始

### 直接在 Roblox Studio 运行

1. 解压完整 ZIP，保留目录结构。
2. 用 Roblox Studio 打开 **`Dustbound-0.7.0-AUDIT.rbxlx`**。
3. 点击 **Play / F5**，不要仅运行服务端的 Run 模式。
4. 等待加载完成，在前哨选择关卡，点击 **出发**。
5. 清场后机器人自动采矿；按波次免费选择遗物或副武器。局外通过 **研究网络** 使用结算材料。

场景与界面由代码创建，编辑模式下看不到完整战场是正常现象。本项目不依赖角色移动，不需要手动瞄准或点击采矿。

**存档默认关闭。** 本地试玩停止后不保存。打开工程并不意味着云存档已连接；请查看游戏内状态提示。

### 从源码重新构建

需要 Python 3 和 Rojo 7.x。Rojo 在 PATH 中时：

```bash
python tools/build_place.py --output Dustbound-0.7.0-AUDIT.rbxlx
```

也可以指定 Rojo 可执行文件：

```bash
python tools/build_place.py --rojo /path/to/rojo --output Dustbound-0.7.0-AUDIT.rbxlx
```

脚本会重新生成 `default.project.json` 并构建 Place。**修改 `src/` 后应重新构建，已有 `.rbxlx` 不会自行更新。**

开发时可运行：

```bash
rojo serve default.project.json
```

然后通过 Roblox Studio 的 Rojo 插件连接，将文件系统中的源码同步到 Studio。当前 2D 工程使用的映射是 **`default.project.json`**。

## 2. 当前玩法规则

### 战斗与成长节奏

- **开局只有固定主炮**，预留四个副武器位。
- 基地位于缩小视野后的战场中心；敌人从四周接近，包括从上方进入的飞行敌人。
- 当前优先实现少量差异化敌人：基础虫、重甲虫和飞行虫。
- 共 **3 个星球 × 8 个关卡**；前四关有数值缓冲，后续逐渐增加，末关达到 **20 波**。

| 事件 | 发生时机 | 费用与限制 |
|---|---|---|
| 副武器三选一 | 完成第 4 / 8 / 12 / 16 波后 | **免费**；安装到下一个副位，独立攻击 |
| 整局遗物三选一 | 完成第 1 / 5 / 9 / 13 / 17 波后 | **免费**；持续本次远征 |
| 机器人采矿 | 非最终波清场后的 30 秒整备 | 实际返航入账，不是连续被动加钱 |
| 重抽 | 存在选择界面时 | 局内有免费次数，之后消耗金矿；付费重抽默认需确认 |

**最终波之后不再安排采矿或三选一。** 选择期间战斗、采矿和投资暂停；选择结束后继续。遗物不是旧版的临时增益或即时空投。

### 局内经济：只花金矿

开局有 120 金矿启动资金；后续赚取的金矿来自机器人采矿，**击杀不掉金矿**。

- 采矿投资：移动速度、挖矿速度、挖矿数量/货舱、机器人数量。
- 战斗投资：伤害、射速、炮管、装甲、维修、自动修复。
- 移动/挖矿/货舱投资各最多 6 级；机器人数量投资最多 4 级，实际机器人总数上限 6 台。永久加成可能使其提前满员。
- 武器和遗物的定时选择不收费；金矿只用于投资和付费重抽。

### 局外经济：合金、数据、核心

| 资源 | 主要用途 | 主要来源 |
|---|---|---|
| 合金 | 基础数值研究，也参与混合费用 | 关卡结算 |
| 数据 | 功能研究，也参与高阶混合费用 | 关卡结算 |
| 核心 | 终极天赋 | 每个星球第 8 关首次通关 |

首次通关材料较多，重玩奖励降低；满足有效战斗条件的失败按进度结算材料。放弃远征没有结算奖励。

研究网络有 **48 个节点**，包含可选分支、合流和跨区替代前置，不是六条必须走完的升级直线。研究在下次出发生效；终极天赋可在局外重置并全额退还当前标准费用。

## 3. 本轮修复与优化

已处理的主要问题包括：

- 放弃远征后的机器人残留、畸形关卡参数、三选一期间的越界投资。
- 重抽支出账本、机器人上限与界面价格不一致。
- 磁轨射程/穿透顺序、迫击炮目标优先级。
- 暂停与三选一遮挡、云档失败恢复入口、天赋退款保存。
- 图鉴引用不存在的图集切片导致崩溃。
- 波次伤害统计、首次采矿指标和加载就绪上报时机。

架构与性能方面：

- 用 `Runtime.lua` 统一服务器/客户端的配置组装。
- 投资价格由服务器快照提供，不再重复推算机器人数量上限。
- 空闲界面不重复写属性；金矿变化只更新保留控件，不重建整页。
- 运行包移除未使用的旧页面/图鉴模块；图鉴每页最多六个条目。
- 保留共享图集、分块解码和兼容绘图，降低同步构造时的卡顿风险。

完整复现、验证和待办见 [审计报告](docs/AUDIT_0.7.md)。

## 4. 项目结构

```text
DustBound/
├─ README.md
├─ LICENSE
├─ PACKAGE_MANIFEST.json          打包文件清单与 SHA-256
├─ Dustbound-0.7.0-AUDIT.rbxlx     当前审计修复构建
├─ default.project.json          当前 2D Rojo 映射
├─ src/
│  ├─ Boot.client.lua            独立加载屏与错误提示
│  ├─ Runtime.lua                统一配置/模块组装
│  ├─ Server.server.lua          请求校验、会话、同步与保存触发
│  ├─ Core.lua                   权威战斗、行为与结算
│  ├─ RunSystems.lua             采矿、局内账本、武器/遗物选择
│  ├─ Economy.lua                三资源经济与研究适配
│  ├─ Rules.lua                  通用规则、研究与 profile 清理
│  ├─ ResearchWeb.lua            分支/合流拓扑
│  ├─ ProfileStore.lua           云档锁、重试与幂等保存
│  ├─ Client.client.lua          原生界面与交互
│  ├─ BattleView.lua             2D 战场表现与对象池
│  ├─ Art.lua / ArtData.lua      图集与绘图降级
│  └─ …                         音效、动画、配置及保留的旧模块
├─ assets/                       图片、图集、音频与素材说明
├─ tests/                        Python/Lupa 测试、mock、Luau 检查
├─ tools/                        构建、资源生成、性能检查工具
├─ docs/
│  ├─ AUDIT_0.7.md               最新审计报告
│  └─ audit-0.7/                 日志、故障清单、性能/构建证据
└─ next/                         早期隔离原型，非当前运行入口
```

`src/` 中保留的 `Panels / Motion / TechMap / Gallery / GalleryData` 是旧实现，**不在当前 Rojo 运行包内**。保留它们是为了迁移和回归对照，请勿误认为当前客户端仍在使用。

ZIP 包含完整开发资料，但不包含 Git 历史、缓存、虚拟环境、外部工具二进制和旧版 Place 构建。需要回退时使用独立保留的 0.6.1 包，不要从当前源码重建旧版本。

## 5. 开发与检查

### Python 测试依赖

建议使用独立虚拟环境，然后安装：

```bash
python -m pip install -r tests/requirements.txt
```

### 当前专项检查

```bash
# 新规则 + 审计修复的回归用例
python -m pytest tests/test_integration_07.py tests/test_audit_07.py -q

# 24 关普通策略，不注入资源/无敌属性
python tests/campaign_pilot.py

# 界面操作计数前后对比；不是 Roblox FPS 测量
python tools/audit_performance.py
```

`audit_performance.py` 使用 `docs/audit-0.7/baseline-sources.zip` 还原比较基线，临时文件写入 `.cache/`。

安装 Luau CLI 后还可以运行：

```bash
luau tests/audit_native.luau
luau-analyze src/Core.lua src/Rules.lua src/RunSystems.lua src/ResearchWeb.lua src/Economy.lua
```

### 全量回归

```bash
python -m pytest tests -q
```

**目前预期并非全绿。** 审计时记录为 168 通过 / 129 失败；不要只跑专项就将其标为正式验收通过。旧 `tests/native.luau` 也仍有旧 schema/规则断言，需要迁移。

部分旧预览、平衡导出和测试工具仍面向历史版本。使用前请检查其入口和假设；HTML/mock 截图不是 Studio 实机截图。

## 6. 验证边界与已知问题

| 检查 | 最新审计记录 |
|---|---|
| 新规则与审计专项 | 57 项通过 |
| 全量 pytest | 168 通过 / 129 失败 |
| Luau 原生审计循环 | 343,535 次断言通过，主要是重复守恒/边界循环 |
| 24 关自动策略 | 全部通关；不等于真人平衡验收 |
| Lua 编译与核心静态分析 | 通过 |
| 构建嵌入源码一致性 | 22 个脚本与工作区一致 |
| Studio、手机、真实云服务 | 尚未完成验证 |

尚需解决：

1. 迁移旧规则/旧 UI 测试，并恢复确实缺失的交互保障，不能批量跳过失败。
2. 部分历史设置字段没有被新界面完整消费，旧 F6 诊断等 QoL 尚未全部恢复。
3. 研究网络的缩放、定位、跨区路线提示和移动端可读性需要实测。
4. GUI 拼图降级路径实例较多，低端设备仍有性能风险。
5. 后期自动策略过于稳健，难度与投资取舍还需对照策略及真人调优。

Place 文件缩小和离线操作次数下降，**不能直接换算成真实加载速度提升或 FPS 增长**。

## 7. 资源与云档配置

配置入口：`src/Config.lua`。

| 配置 | 默认值/用途 |
|---|---|
| `EnableCloudSave` | `false`；默认本地试玩，不保存 |
| `EnableAnalytics` | `false`；默认不调用平台分析接口 |
| `AtlasImageId` | `0`；优先内嵌图集，失败时使用 GUI 绘图降级 |
| `SoundIds` | 空表；可配置已上传并获授权的音频资源 |
| `SaveName` | 云档存储名称，不应在正式迁移中随意更换 |

当前 profile 为 **schema 7**：旧晶体余额按 **1:2 转为数据**，保留研究所有权等进度。迁移代码不等于真实云迁移已验收。

云档只能在独立的已发布测试体验中先行验证。需要测试读取失败、锁占用、重连、保存失败重试与旧 profile 迁移，再考虑生产环境。不要开启后直接覆盖正式线上数据。

素材上传和音频权限参考 [图片配置](docs/ART_SETUP.md) 与 [音频配置](docs/AUDIO_SETUP.md)；其中涉及旧 UI 的说明需结合当前源码使用。

## 8. 文档导航

- **最新检查结论**：[AUDIT_0.7.md](docs/AUDIT_0.7.md)
- **最终检查日志**：[docs/audit-0.7/](docs/audit-0.7/)
- **逐项失败信息**：[failures.csv](docs/audit-0.7/failures.csv)
- **构建与源码校验**：[build.json](docs/audit-0.7/build.json)
- **上一轮集成记录（历史）**：[INTEGRATION_0.7_STATUS.md](docs/INTEGRATION_0.7_STATUS.md)
- **旧版文档**：`docs/` 中标注 0.5.x / 0.6.x 的说明、截图、CHANGELOG 和旧 TEST_REPORT 均保留为历史资料，不作为当前版本通过证明。

## 9. 许可证

项目代码许可证见 [LICENSE](LICENSE)。素材来源、生成方式及授权说明以 `assets/` 内相关文档为准；项目代码许可证不自动替代 Roblox 平台或第三方资源的使用权限。
