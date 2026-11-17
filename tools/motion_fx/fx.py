"""마스터 시안에서 초식 이펙트 12장을 x 범위로 골라 잘라 낸다 (알파 40 미만 배경 안개 제거)."""
import sys, os
from PIL import Image
import numpy as np
from scipy import ndimage
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
a = np.array(Image.open(src).convert('RGBA')).astype(np.float32)
core = a[..., 3] > 90
lab, n = ndimage.label(core); objs = ndimage.find_objects(lab)
# (파일 이름, 시안 행, x0, x1)
PICK = [
 ("plum_blossom_sword_t1", 1, 905, 1000), ("plum_blossom_sword_t2", 1, 1130, 1230),
 ("plum_blossom_sword_t3", 1, 1005, 1125), ("plum_blossom_sword_t4", 1, 1420, 1530),
 ("arhat_fist_t1", 7, 905, 1002), ("arhat_fist_t2", 7, 1195, 1295),
 ("arhat_fist_t3", 7, 1010, 1190), ("arhat_fist_t4", 7, 1300, 1530),
 ("yin_yang_five_elements_t1", 3, 1402, 1530), ("yin_yang_five_elements_t2", 3, 975, 1104),
 ("yin_yang_five_elements_t3", 3, 1105, 1226), ("yin_yang_five_elements_t4", 3, 1228, 1401),
]
for name, r, x0, x1 in PICK:
    mask = np.zeros(core.shape, bool)
    for i, s in enumerate(objs):
        m = lab[s] == i + 1
        if m.sum() < 25: continue
        ys, xs = np.nonzero(m); cy = ys.mean() + s[0].start; cx = xs.mean() + s[1].start
        if int((cy - 8) // 102.4) != r or not (x0 <= cx < x1): continue
        mask[s] |= m
    mask = ndimage.binary_dilation(mask, iterations=8)
    mask[:, :x0] = False; mask[:, x1:] = False
    ys, xs = np.nonzero(mask)
    yy0, yy1, xx0, xx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    sub = a[yy0:yy1, xx0:xx1].copy()
    al = sub[..., 3] * mask[yy0:yy1, xx0:xx1]
    sub[..., 3] = np.clip((al - 40) / 190, 0, 1) * 255
    Image.fromarray(sub.astype(np.uint8)).save(f'{out}/{name}.png')
    print(name, xx1 - xx0, yy1 - yy0)
