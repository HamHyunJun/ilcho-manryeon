"""최종 캐릭터 시안 한 장에서 주인공 스프라이트 20장(큰 일러스트 10 + 전투 포즈 10)을 잘라 낸다.

실행: python3 tools/hero_sprite_cutter.py [시안 PNG] [출력 폴더]
  기본값: tools/hero_design_sheet.png → assets/sprites/heroes
필요: numpy, pillow, scipy

방법
- 큰 일러스트: 굵은 검은 외곽선을 벽으로 삼아 테두리에서 종이색을 채워 나가(flood fill) 배경을 지운다.
  외곽선 바깥의 흰 스티커 테두리와, 머리카락·팔 사이에 갇힌 종이색(둘레 대부분이 외곽선인 덩어리)도 지운다.
- 전투 포즈: 캐릭터는 같은 방법으로 단단하게 남기고, 이펙트의 은은한 빛은 color-to-alpha로
  종이색을 빼 반투명으로 남긴다. 종이보다 밝은 흰 빛은 밝기 차이로 투명도를 정한다.
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hero_sprite_boxes as boxes

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'tools', 'hero_design_sheet.png')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'assets', 'sprites', 'heroes')
SHEET = np.asarray(Image.open(SRC).convert('RGB')).astype(np.float32)
K8 = np.ones((3,3),bool)

def c2a(px, B):
    """GIMP식 color-to-alpha: 배경색 B를 투명으로 빼고 원래 색을 복원한다."""
    a = np.zeros(px.shape[:2], np.float32)
    for ch in range(3):
        p = px[...,ch]; b = B[ch]
        up = np.where(p > b, (p-b)/max(255-b,1e-3), 0)
        dn = np.where(p < b, (b-p)/max(b,1e-3), 0)
        a = np.maximum(a, np.maximum(up, dn))
    a = np.clip(a, 0, 1)
    safe = np.maximum(a, 1e-3)[...,None]
    col = (px - (1-a[...,None])*B) / safe
    return np.clip(col,0,255), a

def segment(box, glow, dark_t=95, sat_t=55, light_t=105, min_frac=0.02):
    x0,y0,x1,y1 = box
    px = SHEET[y0:y1, x0:x1]
    lum = px@np.array([0.299,0.587,0.114],np.float32)
    sat = px.max(-1)-px.min(-1)
    border = np.concatenate([px[0],px[-1],px[:,0],px[:,-1]])
    B = np.median(border,0)
    dark = lum < dark_t
    barrier = ndi.binary_dilation(dark, K8)
    passable = (~barrier) & (sat < sat_t) & (lum >= light_t)
    lab,_ = ndi.label(passable, K8)
    edge = set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]]))) - {0}
    flooded = np.isin(lab, list(edge))
    solid = ~flooded
    # 외곽선 바깥의 흰 테두리(스티커 테두리) 1px 제거
    ring = barrier & ~dark
    light = (lum > 150) & (sat < sat_t)
    solid &= ~(ring & light & ndi.binary_dilation(flooded, K8))
    # 갇힌 배경(머리카락·팔 사이로 막힌 종이색) 제거.
    # 흰 옷과 종이색은 색이 비슷하므로, 둘레가 대부분 검은 외곽선인 덩어리만 구멍으로 본다.
    paperish = (sat < 38) & (lum > 185)
    labh,nh = ndi.label(paperish & solid, K8)
    holes = np.zeros_like(solid)
    for i in range(1, nh+1):
        comp = labh == i
        n = comp.sum()
        if n < 20: continue
        core = comp & (np.linalg.norm(px-B,axis=-1) < 20)
        if core.sum() < n*0.35: continue
        ring = ndi.binary_dilation(comp, K8, iterations=2) & ~comp
        if (dark[ring]).mean() >= 0.55:
            holes |= comp
    solid &= ~holes
    # 바깥 가장자리에 남은 밝은 테두리 픽셀을 두 번 벗겨 낸다
    for _ in range(2):
        edge_px = solid & ndi.binary_dilation(~solid, K8)
        solid &= ~(edge_px & (lum > 175) & (sat < 40))
    # 작은 조각(텍스트·점·잡티) 제거: 가장 큰 덩어리 대비 비율
    lab2,n = ndi.label(solid, K8)
    if n:
        sizes = ndi.sum(solid, lab2, range(1,n+1))
        keep = [i+1 for i,s in enumerate(sizes) if s >= max(sizes)*min_frac]
        solid = np.isin(lab2, keep)
    alpha = solid.astype(np.float32)
    col = px.copy()
    if glow:
        c, a = c2a(px, B)
        a = np.clip((a-0.15)/0.85, 0, 1)
        Blum = float(B@np.array([0.299,0.587,0.114]))
        # 종이 결 잡티 제거: 채도가 낮고 밝기 차이가 작은 픽셀은 버린다
        weak = (np.linalg.norm(px-B,axis=-1) < 15) | ((sat < 20) & (lum < Blum - 3) & (lum > Blum - 30))
        a = np.where(weak, 0, a)
        # 종이보다 밝은 흰 빛(구체·검기의 흰 중심)은 밝기 차이로 투명도를 정한다
        wa = np.clip((lum - Blum - 5) / max(255 - Blum - 5, 1), 0, 1)
        wa = np.clip(wa * 1.6, 0, 1)
        use_w = wa > a
        a = np.where(use_w, wa, a)
        c = np.where(use_w[...,None], np.clip((px - (1-wa[...,None])*B) / np.maximum(wa,1e-3)[...,None], 0, 255), c)
        # 캐릭터 외곽 흰 테두리(스티커 테두리) 제거
        dist = ndi.distance_transform_edt(~solid)
        halo = (dist <= 4) & (sat < 35) & (lum > Blum - 10)
        a = np.where(halo, 0, a)
        # 단단한 덩어리 근처의 은은한 빛만 남긴다 (멀리 떨어진 종이 얼룩 제거)
        near = ndi.binary_dilation(solid, iterations=40)
        a = np.where(near, a, 0)
        # 흐린 빛 중 작은 조각 제거
        g = (a>0) & ~solid
        lab3,n3 = ndi.label(g | solid, K8)
        if n3:
            sizes = ndi.sum(g|solid, lab3, range(1,n3+1))
            keep = [i+1 for i,s in enumerate(sizes) if s >= max(sizes)*0.02]
            a = np.where(np.isin(lab3, keep), a, 0)
        # 종이 위 먹빛 흙먼지는 어두운 배경에서 탁해 보이므로 절반만 남긴다
        clum = c@np.array([0.299,0.587,0.114],np.float32)
        csat = c.max(-1)-c.min(-1)
        a = np.where((~solid) & (clum < 120) & (csat < 70), a*0.5, a)
        col = np.where(solid[...,None], px, c)
        alpha = np.where(solid, 1.0, a)
    rgba = np.dstack([col, alpha*255]).clip(0,255).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    bb = im.getbbox()
    return im.crop(bb), (x0+bb[0], y0+bb[1])

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, big, pose in boxes.boxes():
        a,_ = segment(big, glow=False); a.save(os.path.join(OUT, f'{name}_full.png'))
        b,_ = segment(pose, glow=True); b.save(os.path.join(OUT, f'{name}_battle.png'))
        print(name, a.size, b.size)
