# 0.5 声音接入

## 默认状态

`Config.SoundIds = {}`。Audio 模块使用 `rbxasset://sounds/electronicpingshort.wav` 做基础兼容反馈，设置可试听、调音量。**这个内置路径在本制作环境不能原生验证，不承诺所有客户端都能播放。** 默认没有音乐；不会伪造可用资产 ID。

`assets/audio/` 中是 `tools/build_audio.py` 以振荡器/噪声/包络生成的 13 个原创单声道 WAV，没有引用第三方采样。它们不是旁边放着就会自动在 Roblox 播放的文件。

## 上传

1. 用体验所有者或所属群组上传 WAV，按平台要求处理音频审核与体验使用权限。
2. 等待可用，取得音频资产 ID。
3. Studio → ReplicatedStorage → FrontierShared → Config，填**实际数字 ID**：

```lua
C.SoundIds = {
    cannon = 你的主炮音频ID,
    machine = 你的机枪音频ID,
    arc = 你的电弧音频ID,
    impact = 你的命中音频ID,
    warning = 你的警报音频ID,
    upgrade = 你的升级音频ID,
    deposit = 你的运回音频ID,
    supply = 你的补给音频ID,
    victory = 你的胜利音频ID,
    defeat = 你的失败音频ID,
    click = 你的确认音频ID,
    drill = 你的钻探音频ID,
    music = 你的环境底音ID,
}
```

上面中文占位符必须替换，不可原样粘贴运行。也可先只配置已上传的一部分。磁轨/迫击炮当前共用主炮反馈；喷焰共用能量反馈，不是每把武器独立完整声音设计。

4. 在测试体验 Play / 发布客户端检验：试听、炮击、补给、机器人运回、胜败、暂停停止/恢复、音量为零及重进偏好。
5. `drill.wav` 配置后在机器人钻探阶段限频播放；未配置时不会用内置滴声不断刷钻探。
6. `music.wav` 只是 8 秒可循环的环境底音，不是完整配乐。配置后受音乐音量和暂停控制；可替换为自行制作并有权限的配乐。

**“已配置”不是“已经下载/审核/可听”的证明。** 若无声先核对资产权限、ID、主音量和 Output；本包离线测试只证明 Sound 调用和状态逻辑，不证明平台原生播放成功。

## 重建

```bash
python tools/build_audio.py
```

输出 22050 Hz / 16-bit / mono WAV。包内离线 MP4 是无声动画检查，不能用来验收音效。
