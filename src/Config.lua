local C = {}
C.Version = "0.5.0"
C.EnableCloudSave = false -- Set true ONLY in your published test/production experience.
C.EnableAnalytics = false -- Opt-in server AnalyticsService; local diagnostics always work.
C.TutorialWaves = 3
C.TutorialReward = {alloy=180,research=35}
C.SoundIds = {} -- Optional uploaded original WAV asset IDs; see docs/AUDIO_SETUP.md.
C.SaveName = "Dustbound2D_Profile_v1"
-- Optional: upload assets/dustbound-atlas.png as an IMAGE, then paste its image ID.
-- 0 uses a runtime EditableImage with embedded pixels; failure falls back to GUI art.
C.AtlasImageId = 0
C.Tick = 0.1
C.SnapshotInterval = 0.15
C.WaveDuration = 28
C.TotalWaves = 10
C.EnemyCap = 20
C.InitialOre = 120
C.InitialHull = 900
C.MiningDuration = 30
C.Robots = 2
C.RobotCycle = 6
C.RobotCargo = 28
C.Categories = {
    base = {"armor", "repair", "regen"},
    mining = {"drill", "salvage", "refinery"},
    weapons = {"damage", "rate", "barrel"},
}
C.Upgrades = {
    armor = {name="装甲扩容",description="提高耐久上限并修复相同耐久",cost=130,growth=1.65,cap=4,icon="shield",color="mint"},
    repair = {name="紧急维修",description="立即恢复 180 点耐久",cost=90,growth=1.25,cap=30,icon="repair",color="mint"},
    regen = {name="维修纳米网",description="每秒自动修复耐久",cost=180,growth=1.8,cap=3,icon="repair",color="mint"},
    drill = {name="机器人钻头",description="增加机器人每趟运回的矿料",cost=100,growth=1.7,cap=5,icon="drill",color="orange"},
    salvage = {name="残骸回收",description="提高击杀虫群的矿料收入",cost=110,growth=1.7,cap=4,icon="ore",color="orange"},
    refinery = {name="晶体精炼",description="提高最终结算的研究数据",cost=140,growth=1.8,cap=3,icon="crystal",color="mint"},
    damage = {name="火炮伤害",description="提高主炮与副武器伤害",cost=110,growth=1.7,cap=5,icon="turret",color="orange"},
    rate = {name="射击速度",description="提高主炮与副武器射速",cost=160,growth=1.65,cap=5,icon="ammo",color="orange"},
    barrel = {name="联装炮管",description="主炮每轮多发射 1 枚炮弹",cost=460,growth=2,cap=2,icon="turret",color="orange"},
}
-- Catalog and Tech are injected by entry points; Core stays engine-independent.
return C
