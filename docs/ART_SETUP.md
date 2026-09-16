# 完整卡通素材的接入方式 · 0.5.0

**0.5 沿用 0.4 图集，与 0.4 已上传图集兼容。0.4 图集增加了关节虫体、机器人与钻头部件，布局已改变。若以前填写过 0.3 的 AtlasImageId，请重置为 0，或上传本包新版图集；旧图集 ID 不兼容新裁切表。**

## 为什么有三种显示模式

Roblox 的 ImageLabel 不能直接使用工程旁边的本地 PNG 路径或 HTML data URI。本版没有填写虚假的图片资产 ID。

为了让下载的 Place 尽量直接出现完整图片：

1. 默认从 `ArtData.lua` 读取色板和 RLE 像素数据。
2. 创建一张 1024×1024 EditableImage，写入像素。
3. 用 `Content.fromObject()` 连接 ImageLabel，再根据裁切坐标显示不同素材。
4. 所有基地、敌人、机器人、图标共用这一个图像对象，不逐帧重画图集。

官方说明 EditableImage 支持 WritePixelsBuffer、ImageContent 和 Content.fromObject，最大尺寸为 1024×1024；它也有客户端内存预算和发布权限限制。[2](https://create.roblox.com/docs/reference/engine/classes/EditableImage)

创建失败时会自动用低分辨率 GUI 色块绘制，避免空屏。**兼容绘制不是同等质量模式**：边缘会更粗，UI 实例数量也更多。

## 方式 A：直接本地试玩

保持 `Config.AtlasImageId = 0`。

按 Play，然后打开“设置”：

- 显示“内嵌高清图集”：正在使用完整素材路径。
- 显示“兼容绘制”：本次环境没有成功创建图像对象，请尝试方式 B，或按官方条件配置图像 API。

我们未在你的 Studio 环境验证图像 API 权限，因此不能保证每个账户都自动进入高清模式。

## 方式 B：上传一张图集——推荐正式发布使用

1. 在你自己的 Roblox 账户或体验所属群组下，通过 Studio Asset Manager / Creator Dashboard 的图片上传入口上传：

   **`assets/dustbound-atlas.png`**

2. 保持图片原样：**1024×1024，不裁边、不改尺寸、不重新排版**。
3. 等待审核和处理完成。
4. 取得可用于 ImageLabel 的 **Image ID**。不要误填模型 ID；如果上传结果是 Decal，使用其对应图片内容的 ID。
5. 在 Studio 打开：

   `ReplicatedStorage → FrontierShared → Config`

6. 修改：

   ```lua
   C.AtlasImageId = 你的图片ID
   ```

7. Stop 后重新 Play，设置中应显示“已配置上传图集”。检查背景与所有裁切素材是否正常。

图片必须允许当前体验使用。若个人图片用于群组体验，可能需要明确授权。Roblox 对受限资产有体验权限检查。[3](https://create.roblox.com/docs/projects/assets/privacy)

**上传图集模式不依赖运行时 EditableImage API。** 注意“已配置上传图集”只表示填写了 ID，不代表审核、权限和下载已经由本项目验证成功；若图片不显示，请先核对 ID、审核和体验访问权限，或将 ID 改回 0。

## 方式 C：发布时启用 EditableImage

官方说明公开发布体验使用 EditableImage 默认受限，需要满足平台当前年龄/身份验证条件，并开启 **Enable Mesh / Image APIs**。具体条件以官方文档和你的 Creator Dashboard 为准。[2](https://create.roblox.com/docs/reference/engine/classes/EditableImage)

这与 **DataStore / Studio API 访问**不是同一个开关。不要为了图像显示问题只去打开 DataStore 权限。

## 资源与版权边界

这些卡通素材根据本项目确认的概念方向生成，并经过裁切、去背景与图集处理。没有使用《前哨站4》的原始贴图或资产 ID。DUSTBOUND / 荒星前哨目前是项目暂定名称。

## 重建素材

```bash
python3 tools/build_art.py
```

该命令读取 `source-sprites.png`、`source-landscape.png` 与 `source-motion.png`，输出透明 PNG、图集、裁切坐标及 `ArtData.lua`。

修改图集布局后，必须同步重建数据和 Place；不要只换 PNG 而保留旧裁切坐标。
