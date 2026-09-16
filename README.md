# DUSTBOUND / 荒星前哨

<div align="center">

![Version](https://img.shields.io/badge/version-0.5.0-blue.svg)
![Roblox](https://img.shields.io/badge/engine-Roblox%20%2F%20Luau-00A2FF.svg)
![Rojo](https://img.shields.io/badge/sync-Rojo%207.x-red.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Mobile-orange.svg)

**一款基于 Roblox 平台的轻量科幻 2D 自动化基地防御与经营放置增量游戏**

[快速开始](#-快速开始与运行指南) • [核心玩法](#-核心玩法与操作指南) • [架构与技术栈](#-项目架构与技术栈) • [开发与测试](#-离线测试与构建工具) • [文档索引](#-完整文档导航)

</div>

---

## 📖 项目简介

**《荒星前哨》(DustBound)** 采用独特的 2D 卡通画面表现，融合了基地自动防御、机器人整备采矿、科技树演进与局外构筑配装。

在游戏中，玩家**不直接操纵火炮瞄准、不手动采矿**，而是扮演前哨基地指挥官，负责：
- 🎯 **战术投资**：动态强化主炮杀伤、射程与装甲耐久
- ⛏️ **整备调度**：在波次间隙调度采矿机器人钻探、运输高能矿料
- ⚡ **能源与补给**：统筹能量分配，选择战术补给被动增益
- 🔬 **前哨科技树**：6 大科技系 × 8 阶 = 48 个科技节点，解锁全新副武器与生产机制

---

## 🚀 快速开始与运行指南

### 方式一：Roblox Studio 直接体验（推荐）

1. 使用 **Roblox Studio** 打开根目录下的 [`Dustbound-0.5.0.rbxlx`](./Dustbound-0.5.0.rbxlx)。
2. 点击 Studio 顶部的 **Play (F5)** 进入游戏。
   > ⚠️ **提示**：场景采用客户端程序化构建，编辑视图未运行为空是正常现象；请勿使用仅服务端模式（Run），必须使用客户端 **Play**。
3. 在主菜单选择 **“3 波教学 · 推荐”**，体验完整的“战斗 - 采矿 - 补给 - 研发 - 配装”成长闭环。

### 方式二：Rojo 实时工程同步

本项目采用行业标准的 [Rojo](https://rojo.space/) 管理代码资产映射：

```powershell
# 启动 Rojo 同步服务
rojo serve default.project.json
```
在 Studio 中打开工程并点击 Rojo 插件中的 **Connect** 即可双向实时热重载。

---

## 🎮 核心玩法与操作指南

### 试玩推进路线

1. **迎战虫潮**：第一波自动战斗开始，主炮自动追踪防御；战斗期间矿区休眠。
2. **整备采矿**：波次结束后进入 30 秒整备时间，采矿机器人出库钻探，安全运回基地才计入矿料。
3. **补给抉择**：三选一战术补给，可暂看投资面板后再确认，不消耗整备倒计时。
4. **基地研发**：教学通关获取固定合金与数据，在局外进入【研究】解锁副武器蓝图（如“电弧蓝图”）。
5. **工坊换装**：在【配装】面板装配已研发的副武器，开启多重火力标准远征。

### 常用快捷键与操作

| 操作 | PC 键位 | 移动端 / 触控适配 |
|---|---|---|
| 切换投资分支 | `1` (基地) / `2` (采矿) / `3` (武器) | 左右翻卡滑块（自适应单卡布局） |
| 模拟暂停 / 继续 | `P` 或面板 `Ⅱ` 按钮 | 顶部暂停按钮（支持长时冻结） |
| 经营台 / 战况情报 | 快捷面板呼出 | 侧边抽屉式信息流面板 |
| 安全区自适应 | 全屏自适应 | 严格遵循 `GuiService.CoreUISafeInsets` 规避刘海遮挡 |

---

## 🏗️ 项目架构与技术栈

### 目录结构树

```
DustBound/
├── default.project.json      # Rojo 映射与工程定义
├── Dustbound-0.5.0.rbxlx     # Studio Place 工程文件（含预挂载脚本）
├── README.md                 # 仓库主说明文档
├── LICENSE                   # MIT 开源许可证
├── .gitignore                # 增强版 Git 忽略配置
├── .gitattributes           # 换行符 LF 规范与二进制媒体声明
├── src/                      # Luau 游戏核心业务源码
│   ├── Boot.client.lua       # 客户端启动自检与视口守卫
│   ├── Client.client.lua     # 客户端表现层、响应式 UI 与控制器
│   ├── Server.server.lua     # 服务端仲裁、状态机循环与防重放
│   ├── Core.lua              # 战斗与整备核心数值逻辑
│   ├── ProfileStore.lua      # 强一致性 Session-Locking 存档核心
│   ├── Tech.lua              # 48 节点科技树依赖关系网
│   ├── Catalog.lua           # 武器、补给、怪物图鉴静态库
│   ├── Motion.lua            # 2D 物理运动学、关节腿足程序动画
│   ├── Panels.lua            # 响应式布局面板组件
│   ├── UI.lua                # 通用 UI 原子组件与安全区处理
│   ├── Art.lua / ArtData.lua # 图集加载器与回退渲染策略
│   ├── Audio.lua             # 声音总线与音量控制
│   ├── Config.lua            # 全局配置参数
│   ├── Rules.lua             # 校验与数据清洗规则
│   └── Telemetry.lua         # 离线埋点与数据分析接线
├── assets/                   # 美术与音频素材
│   ├── dustbound-atlas.png   # 卡通纹理图集
│   ├── source-sprites.png    # 原始精灵合集
│   └── audio/                # 13 轨原创音效与 BGM (WAV)
├── docs/                     # 详尽设计规格与测试报告
│   ├── DEVELOPER.md          # 开发者架构规格与状态机定义
│   ├── STUDIO_CHECKLIST.md   # 人工验收清单与排查项
│   ├── STORAGE_MIGRATION.md  # DataStore 云存档配置与发布迁移
│   ├── TECH_REFERENCE.md     # 48 科技节点全量数值手册
│   ├── TEST_REPORT.md        # 离线与单元测试报告
│   └── CHANGELOG.md          # 版本发布日志
├── tests/                    # 离线仿真与单元测试
│   ├── mock_engine.lua       # Roblox 运行时轻量级模拟桩
│   ├── test_core.py          # 核心数值与战斗逻辑 pytest
│   ├── test_v05.py           # 存档事务与重试幂等性测试
│   └── test_ui.py            # UI 状态树与响应式布局断言
└── tools/                    # 自动化与资源生成工具链
    ├── build_place.py        # 基于 Rojo 的编译构建脚本
    ├── build_art.py          # 图集自动化切片与代码导出
    └── preview_layout.py     # 离线多分辨率布局快照渲染
```

### 核心设计特性

1. **高可靠性存档机制**：
   - 采用服务端驱动的 Session-Locking 机制，杜绝跨服多写覆盖与脏写。
   - 提供访客隔离与明确保存状态标识，云端读写失败绝不静默覆盖。
2. **离线高保真渲染兼容**：
   - 支持 `EditableImage` 动态像素渲染，同时内建轻量级原生 GUI 备用通道，即使在低配设备或旧引擎环境下也能稳定运行。
3. **全端响应式界面**：
   - 彻底摆脱粗暴等比缩放，手机端智能重排为全宽横屏多标签抽屉卡片，完美规避操作盲区。

---

## 🧪 离线测试与构建工具

无需启动 Roblox Studio 即可在终端运行完整的离线回归测试套件：

```powershell
# 运行全部核心业务与架构单元测试
pytest tests/

# 运行自动化地点构建 (需本地安装 rojo)
python tools/build_place.py
```

---

## 📚 完整文档导航

- 📘 [开发者架构指南 (DEVELOPER.md)](./docs/DEVELOPER.md)
- 📋 [Studio 人工验收清单 (STUDIO_CHECKLIST.md)](./docs/STUDIO_CHECKLIST.md)
- 💾 [云存档配置与迁移指南 (STORAGE_MIGRATION.md)](./docs/STORAGE_MIGRATION.md)
- 🔬 [科技树节点全量手册 (TECH_REFERENCE.md)](./docs/TECH_REFERENCE.md)
- 🎨 [美术图集配置 (ART_SETUP.md)](./docs/ART_SETUP.md) 与 🎵 [音频配置 (AUDIO_SETUP.md)](./docs/AUDIO_SETUP.md)
- 📊 [事件埋点与分析规格 (ANALYTICS.md)](./docs/ANALYTICS.md)
- 📝 [版本更新日志 (CHANGELOG.md)](./docs/CHANGELOG.md)

---

## 📄 开源许可证

本项目遵循 [MIT License](./LICENSE) 开源协议。
