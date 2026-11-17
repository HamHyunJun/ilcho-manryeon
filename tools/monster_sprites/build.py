"""몬스터 시안 4장 → 게임용 스프라이트 스트립 + 프레임 정보 JSON.

실행: python3 tools/monster_sprites/build.py [출력 폴더]
  기본 출력: assets/sprites/monsters  (<id>.png, monster_sprites.json)
필요: numpy, pillow, scipy, rembg (isnet-general-use 모델; 처음 실행 때 내려받는다)

순서
1. matte.sheet_maps: 시트마다 체크무늬 배경판을 다시 그려 픽셀별 배경 차이를 구한다.
2. 프레임마다 rembg(isnet-general-use) 마스크를 함께 써서 배경을 지운다 (matte.frame_matte).
   배경판과 색이 같은 머리카락은 rembg로 살리고, rembg가 남긴 체크 칸은 배경판 비교로 지운다.
3. 시안은 모두 오른쪽을 보고 있으므로 좌우 반전해 왼쪽(주인공 쪽)을 보게 한다.
4. 몸 프레임은 발 기준점(anchor)을, 이펙트 프레임은 가운데를 기준점으로 기록한다.
   발 기준점이 이펙트에 끌려가는 프레임은 ANCHOR_FIX로 바로잡는다.
"""
import json
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from matte import GRID, sheet_maps, frame_matte, K8  # noqa: E402
from spec import SPRITES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'assets', 'sprites', 'monsters')
PAD = 24
# 시트 오른쪽 아래 생성 도구 로고(반투명 흰 ✦)의 (가운데 x, 가운데 y, 반지름, 불투명도)
WATERMARK = {'normal_b': [(2640, 1424, 48, 0.45)], 'boss_a': [(2640, 1424, 48, 0.45)]}


def unstar(px, cx, cy, r, op):
    """반투명 흰 별 로고를 걷어 낸다: 관측 = (1-a)·원래 + a·255 를 거꾸로 푼다."""
    y0, y1, x0, x1 = cy - r - 3, cy + r + 4, cx - r - 3, cx + r + 4
    ys, xs = np.mgrid[y0:y1, x0:x1]
    u = np.abs(xs - cx) / r; v = np.abs(ys - cy) / r
    f = u ** 0.72 + v ** 0.72  # 변이 살짝 오목한 네 꼭짓점 별
    # 가장자리 1.5px 정도 부드럽게
    a = op * np.clip((1.0 - f) * r / 2.0 + 0.5, 0, 1)
    O = px[y0:y1, x0:x1]
    px[y0:y1, x0:x1] = np.clip((O - a[..., None] * 255.0) / np.maximum(1 - a[..., None], 1e-3), 0, 255)
FX_ANIMS = ('fx', 'skill_fx')
# (스프라이트, 동작, 칸 번호) → 반전 전 원본 좌표 기준 발 x (시트 좌표). 자동 추정이 이펙트에 끌려갈 때 쓴다.
ANCHOR_FIX = {}
try:
    from anchors import ANCHOR_FIX  # noqa: F401,E402
except ImportError:
    pass

_session = None


def rembg_mask(rgb):
    global _session
    from rembg import new_session, remove
    if _session is None:
        _session = new_session('isnet-general-use')
    m = remove(Image.fromarray(rgb.astype(np.uint8)), session=_session, only_mask=True)
    return np.asarray(m).astype(np.float32) / 255.0


def cut(sheet, maps, box):
    x0, y0, x1, y1 = box
    H, W, _ = sheet.shape
    X0, Y0, X1, Y1 = max(0, x0 - PAD), max(0, y0 - PAD), min(W, x1 + PAD), min(H, y1 + PAD)
    px = sheet[Y0:Y1, X0:X1]
    M = {k: (v[Y0:Y1, X0:X1] if isinstance(v, np.ndarray) else v) for k, v in maps.items()}
    rb = rembg_mask(px)
    col, a = frame_matte(px, M, rb)
    # 상자 바깥(여유분)은 버린다
    keep = np.zeros_like(a, bool)
    keep[y0 - Y0:y1 - Y0, x0 - X0:x1 - X0] = True
    a = np.where(keep, a, 0)
    # 상자 안에서 다시 작은 조각 정리 (이웃 칸에서 넘어온 끄트머리)
    solid = a > 0.35
    lab, n = ndi.label(solid, K8)
    if n:
        sz = ndi.sum(solid, lab, range(1, n + 1))
        lum = np.asarray(col).mean(-1)
        big = int(np.argmax(sz)) + 1
        cell = maps['s'] ** 2
        ok = []
        for i, v in enumerate(sz, 1):
            if v < max(40, sz.max() * 0.02):
                continue
            # 떨어져 있는 작고 새까만 덩어리 = 남은 체크 칸 조각
            if i != big and v < cell * 1.5 and np.median(lum[lab == i]) < 60:
                continue
            ok.append(i)
        good = np.isin(lab, ok)
        near = ndi.binary_dilation(good, iterations=3)
        a = np.where(near, a, 0)
    rgba = np.dstack([col, a * 255]).clip(0, 255).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    bb = im.getbbox()
    return im.crop(bb), (X0 + bb[0], Y0 + bb[1])


def body_anchor(im):
    """발 기준점 (이미지 좌표, 반전 전)."""
    a = np.asarray(im)[..., 3] > 128
    rows = np.where(a.sum(1) >= 4)[0]
    fy = int(rows.max()) if len(rows) else im.height - 1
    band = max(6, int(im.height * 0.12))
    ys, xs = np.nonzero(a[max(0, fy - band):fy + 1])
    fx = float(np.median(xs)) if len(xs) else im.width / 2
    return fx, fy + 1


def main():
    os.makedirs(OUT, exist_ok=True)
    sheets, maps = {}, {}
    meta = {}
    preview_rows = []
    for sid, sp in SPRITES.items():
        g = sp['sheet']
        if g not in sheets:
            sheets[g] = np.asarray(Image.open(os.path.join(HERE, 'sheets', g + '.png')).convert('RGB')).astype(np.float32)
            for wm in WATERMARK.get(g, []):
                unstar(sheets[g], *wm)
            maps[g] = sheet_maps(sheets[g], GRID[g])
            print('sheet', g, 'ready')
        frames, anims = [], {}
        for anim, boxes in sp['anims'].items():
            anims[anim] = []
            for k, box in enumerate(boxes):
                im, (ox, oy) = cut(sheets[g], maps[g], box)
                if anim in FX_ANIMS:
                    ax, ay = im.width / 2, im.height / 2
                else:
                    ax, ay = body_anchor(im)
                    fix = ANCHOR_FIX.get((sid, anim, k))
                    if fix is not None:
                        ax = fix - ox
                # 좌우 반전: 왼쪽(주인공 쪽)을 보게
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
                ax = im.width - ax
                anims[anim].append(len(frames))
                frames.append((im, ax, ay, anim))
        # 가로 한 줄로 붙인다
        H = max(f[0].height for f in frames)
        W = sum(f[0].width for f in frames) + 2 * (len(frames) - 1)
        strip = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        x = 0
        recs = []
        for im, ax, ay, anim in frames:
            strip.paste(im, (x, 0))
            recs.append({'rect': [x, 0, im.width, im.height], 'anchor': [round(ax, 1), round(ay, 1)]})
            x += im.width + 2
        # 256색 팔레트로 줄여 저장한다 (도트 그림이라 눈에 띄는 차이 없이 용량이 약 1/4)
        strip.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(os.path.join(OUT, sid + '.png'), optimize=True)
        # 피격 순간 하얀 실루엣 (같은 배치, 알파만 유지)
        flash = Image.new('RGBA', strip.size, (255, 255, 255, 0))
        flash.putalpha(strip.getchannel('A'))
        flash.save(os.path.join(OUT, sid + '_flash.png'), optimize=True)
        # 몸 높이: 대기 첫 칸에서 발 기준점~맨 위
        i0 = anims.get('idle', [0])[0]
        body_h = frames[i0][2]
        meta[sid] = {'frames': recs, 'anims': anims, 'body_px': round(body_h, 1)}
        preview_rows.append((sid, frames))
        print(sid, len(frames), 'frames', strip.size)
    with open(os.path.join(OUT, 'monster_sprites.json'), 'w') as f:
        json.dump({'_comment': 'tools/monster_sprites/build.py가 만든 파일. 직접 고치지 말 것. rect=[x,y,w,h], anchor=칸 안의 기준점(몸: 발, 이펙트: 가운데). 그림은 왼쪽을 본다.', 'sprites': meta}, f, ensure_ascii=False, indent=1)
    # 미리보기: 발 기준점을 같은 선에 맞춰 늘어놓는다 (확인용, 저장소에는 넣지 않음)
    prev = os.environ.get('PREVIEW')
    if prev:
        from PIL import ImageDraw
        rows = []
        for sid, frames in preview_rows:
            up = max(f[2] for f in frames); dn = max(f[0].height - f[2] for f in frames) + 4
            cw = [max(f[0].width, 60) + 20 for f in frames]
            row = Image.new('RGB', (sum(cw), int(up + dn) + 18), (90, 120, 90))
            d = ImageDraw.Draw(row)
            x = 0
            for (im, ax, ay, anim), w in zip(frames, cw):
                ox = x + 10 + (w - 20 - im.width) // 2
                row.paste(im, (int(ox), int(up - ay) + 14), im)
                d.line([(ox + ax, 14), (ox + ax, row.height)], fill=(255, 255, 0))
                d.text((x + 2, 1), anim, fill=(255, 255, 255))
                x += w
            d.line([(0, up + 14), (row.width, up + 14)], fill=(255, 0, 0))
            d.text((2, row.height - 12), sid, fill=(255, 255, 255))
            rows.append(row)
        os.makedirs(prev, exist_ok=True)
        for sid_row, row in zip(preview_rows, rows):
            row.save(os.path.join(prev, sid_row[0] + '.png'))


if __name__ == '__main__':
    main()
