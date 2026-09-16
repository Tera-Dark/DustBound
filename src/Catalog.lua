-- Shared mechanics + encyclopaedia data: values shown by the codex come from these definitions.
local D={weapons={},enemies={},supplies={},order={weapons={"cannon","machine","arc","rail","flame","mortar"},enemies={"crawler","runner","tank","spitter","elite","warden"},supplies={"repair","drill","ammo","ore","shield","drones","overclock"}}}
D.weapons={
 cannon={name="联装火炮",role="固定主炮",icon="turret",interval=1.1,multiplier=1,range=700,flight=850,style="shell",desc="实体抛物线炮弹。命中后才扣血，并对邻近敌人造成破片伤害。",tip="火力主轴：伤害、射速和炮管数量均受局内投资影响。"},
 machine={name="速射机枪",role="默认副武器",icon="ammo",interval=.30,multiplier=.25,range=690,flight=1850,style="bullet",desc="快速直线弹丸，稳定对单。弹丸抵达目标后结算伤害。",tip="适合补刀和处理疾行虫。"},
 arc={name="电弧线圈",role="连锁副武器",icon="crystal",interval=1.4,multiplier=.45,range=650,style="arc",tech="energy_2",desc="瞬时电弧连接三个邻近目标，研究可增加连锁数量。",tip="密集虫群效率高；电弧属于瞬时能量武器，没有飞行弹丸。"},
 rail={name="磁轨枪",role="穿透副武器",icon="ammo",interval=2.1,multiplier=1.15,range=760,flight=2100,style="rail",tech="ballistics_4",desc="高速穿透弹命中前方三个目标，无视重甲的常规减伤。",tip="适合重甲与纵向堆叠的敌群。"},
 flame={name="喷焰器",role="持续伤害副武器",icon="drill",interval=.65,multiplier=.45,range=390,style="flame",tech="energy_4",desc="近距离扇形火焰，附加持续三秒燃烧。",tip="射程短，适合已接近前哨的密集虫群。"},
 mortar={name="迫击炮",role="重型范围副武器",icon="turret",interval=3.3,multiplier=1.8,range=780,flight=620,style="mortar",tech="expedition_3",desc="高抛弹道，优先瞄准高耐久目标，命中时造成大范围爆炸。",tip="对大群虫有效；弹速较慢，需要主炮弥补间隙。"},
}
D.enemies={
 crawler={name="穴居虫",body="crawlerBody",color={104,74,112},hp=24,hpWave=5,speed=28,attack=8,attackWave=1,interval=1.5,reward=8,firstWave=1,range=650,desc="基础近战虫，数量较多。",tip="用主炮破片或电弧清理密集队列。"},
 runner={name="疾行虫",body="crawlerBody",color={160,91,74},hp=18,hpWave=4,speed=48,attack=7,attackWave=1,interval=1.0,reward=10,firstWave=2,range=650,scale=.82,desc="耐久较低，移动和攻击更快。",tip="射速与机枪可以减少漏怪。"},
 tank={name="甲壳虫",body="tankBody",color={91,65,101},hp=65,hpWave=8,speed=19,attack=19,attackWave=0,interval=1.8,reward=25,firstWave=3,range=650,armor=.2,desc="行动缓慢，受到普通伤害降低 20%。",tip="磁轨穿透无视它的常规护甲。"},
 spitter={name="酸液虫",body="crawlerBody",color={91,131,96},hp=35,hpWave=6,speed=25,attack=12,attackWave=1,interval=2.4,reward=18,firstWave=4,range=925,desc="在远处停下喷射酸液，弹丸到达基地才造成伤害。",tip="不要只看前排；及时提高远程输出。"},
 elite={name="掘地巨兽",body="tankBody",color={120,66,83},hp=290,hpWave=20,speed=15,attack=42,attackWave=0,interval=2.2,reward=65,firstWave=5,range=650,scale=1.45,crystals=2,desc="第五、十波及追加终波出现的精英。掉落晶体，解锁中阶研究。",tip="提前准备维修或护盾，集中升级主炮。"},
 warden={name="矿巢守卫",body="tankBody",color={63,107,121},hp=125,hpWave=12,speed=17,attack=25,attackWave=1,interval=2.0,reward=36,firstWave=8,range=650,armor=.3,scale=1.15,desc="后期重甲单位，普通伤害降低 30%。",tip="利用范围输出与穿透，避免前线堆积。"},
}
D.supplies={
 repair={name="维修补给",detail="立即修复 240 耐久",icon="repair",desc="维修效果受研究提升，满耐久时仍可选但不会溢出。"},
 drill={name="钻机加速",detail="机器人产量 +60% · 30 秒整备时间",icon="drill",desc="只在机器人采矿阶段消耗持续时间。战斗和暂停不会浪费增益。"},
 ammo={name="强化弹药",detail="射速 +45% · 35 秒战斗时间",icon="ammo",desc="只在开战、清剿阶段消耗持续时间。"},
 ore={name="矿料空投",detail="立即获得 180 矿料",icon="ore",desc="直接用于本局投资，不计入机器人累计采集量。"},
 shield={name="临时护盾",detail="受到伤害 -50% · 35 秒战斗时间",icon="shield",desc="研究可提高减伤与持续时间。"},
 drones={name="机器人支援",detail="本次整备增加 1 台机器人",icon="drill",tech="logistics_4",desc="选取后立即出库，整备结束回收；不增加永久机器人数量。"},
 overclock={name="超载核心",detail="全部武器伤害 +35% · 35 秒战斗时间",icon="crystal",tech="logistics_8",desc="与强化弹药和武器研究叠加，适合后期精英波。"},
}
return D
