from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True);t=l.execute((ROOT/'src/Tech.lua').read_text())
lines=['# 科技树数据参考 · 0.5.0','','由 `tools/export_reference.py` 从实际 `src/Tech.lua` 自动导出。所有节点为一次性研究；效果下次开局生效。','','资源顺序：合金 / 研究数据 / 晶体 / 核心。波次条件指完成该波的 30 秒整备。','']
for branch in t.branches.values():
 lines+=['## '+branch.name,'','| 阶 | 节点 | 效果 | 前置 | 最低完成波次 | 消耗 |','|---|---|---|---|---|---|']
 for tier in range(1,9):
  n=t.nodes[f'{branch.id}_{tier}'];pre='、'.join(t.nodes[p].name for p in n.prereqs.values()) or '无';cost=' / '.join(str(n.cost[k]) for k in ['alloy','research','crystals','cores'])
  lines.append(f'| {tier} | {n.name} (`{n.id}`) | {n.detail} | {pre} | {n.minWave} | {cost} |')
 lines.append('')
(ROOT/'docs/TECH_REFERENCE.md').write_text('\n'.join(lines)+'\n')
