"""잘라 낸 프레임(cut/)을 캐릭터별 모션 시트와 초식 이펙트 PNG로 정리한다.
- 모션: 9칸을 같은 몸 높이로 맞추고 발 기준점을 한 곳에 모은다 (시안은 칸마다 크기가 다르다)."""
import sys, os, json
from PIL import Image
import numpy as np
cut, out = sys.argv[1], sys.argv[2]
IDS = ["cheongpung","maehwa","sorim","eumyang","hyeolma","banghwang","mudang","nahan","cheongang","amyeong"]
CELL = (200, 150); FEET = (84, 142); BODY = 104.0
TYPE_K = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.97, 0.97, 0.97]
os.makedirs(out, exist_ok=True)
report = {}
for r, cid in enumerate(IDS):
    sheet = Image.new('RGBA', (CELL[0]*9, CELL[1]), (0,0,0,0))
    rep = []
    for k in range(9):
        im = Image.open(f'{cut}/r{r}_m{k}.png'); a = np.array(im)
        core = a[...,3] > 120
        wide = core.sum(1) >= 7
        ys = np.nonzero(wide)[0]; top, bot = ys.min(), ys.max()
        h = bot - top + 1
        sc = BODY * TYPE_K[k] / h
        feet_rows = core[max(top, bot-10):bot+1]
        fx = np.nonzero(feet_rows)[1].mean()
        nw, nh = max(1, round(im.width*sc)), max(1, round(im.height*sc))
        im2 = im.resize((nw, nh), Image.LANCZOS)
        px = round(FEET[0] - fx*sc); py = round(FEET[1] - (bot+1)*sc)
        cellim = Image.new('RGBA', CELL, (0,0,0,0)); cellim.alpha_composite(im2, (max(px,0), max(py,0)), (max(-px,0), max(-py,0)))
        sheet.alpha_composite(cellim, (k*CELL[0], 0))
        rep.append(round(sc, 2))
    sheet.save(f'{out}/{cid}_motion.png')
    report[cid] = rep
print(json.dumps(report))
