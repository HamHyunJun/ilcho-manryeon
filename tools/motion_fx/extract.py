"""마스터 시안에서 캐릭터 모션 프레임과 이펙트 조각을 잘라 낸다."""
import sys, json, os
from PIL import Image
import numpy as np
from scipy import ndimage
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
im = Image.open(src).convert('RGBA'); a = np.array(im).astype(np.float32)
al = a[..., 3]
core = al > 90
lab, n = ndimage.label(core)
objs = ndimage.find_objects(lab)
SLOTS = [177, 275, 355, 421, 483, 572, 690, 780, 865]
rows = {r: {'motion': {i: [] for i in range(9)}, 'fx': []} for r in range(10)}
for i, s in enumerate(objs):
    m = lab[s] == i + 1
    sz = m.sum()
    if sz < 30: continue
    ys, xs = np.nonzero(m)
    cy = ys.mean() + s[0].start; cx = xs.mean() + s[1].start
    if cx < 125: continue  # 이름표
    r = int((cy - 8) // 102.4); r = max(0, min(9, r))
    item = (i + 1, s)
    if cx < 905 and s[1].stop < 925:
        k = int(np.argmin([abs(cx - c) for c in SLOTS]))
        rows[r]['motion'][k].append(item)
    else:
        rows[r]['fx'].append(item)
def crop(items, name, pad=6, grow=5):
    mask = np.zeros(core.shape, bool)
    for lid, s in items:
        mask[s] |= lab[s] == lid
    mask = ndimage.binary_dilation(mask, iterations=grow)
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    y0 = max(0, y0 - pad); x0 = max(0, x0 - pad); y1 = min(core.shape[0], y1 + pad); x1 = min(core.shape[1], x1 + pad)
    sub = a[y0:y1, x0:x1].copy()
    alpha = sub[..., 3] * mask[y0:y1, x0:x1]
    # 배경 잔여(알파 40 미만의 옅은 안개) 제거, 나머지는 다시 늘린다
    alpha = np.clip((alpha - 40) / (230 - 40), 0, 1) * 255
    sub[..., 3] = alpha
    Image.fromarray(sub.astype(np.uint8)).save(os.path.join(out, name))
    return [int(x0), int(y0), int(x1), int(y1)]
meta = {}
for r in range(10):
    meta[r] = {'motion': [], 'fx': []}
    for k in range(9):
        items = rows[r]['motion'][k]
        meta[r]['motion'].append(crop(items, f'r{r}_m{k}.png') if items else None)
    # 이펙트: x 간격으로 묶는다
    fx = sorted(rows[r]['fx'], key=lambda it: it[1][1].start)
    groups = []
    for it in fx:
        s = it[1]
        if groups and s[1].start <= groups[-1]['x1'] + 10:
            groups[-1]['items'].append(it); groups[-1]['x1'] = max(groups[-1]['x1'], s[1].stop)
        else:
            groups.append({'items': [it], 'x1': s[1].stop})
    for j, g in enumerate(groups):
        meta[r]['fx'].append(crop(g['items'], f'r{r}_fx{j}.png', grow=8))
json.dump(meta, open(os.path.join(out, 'meta.json'), 'w'), indent=1)
for r in range(10): print(r, len(meta[r]['fx']), [m and (m[2]-m[0], m[3]-m[1]) for m in meta[r]['motion']])
