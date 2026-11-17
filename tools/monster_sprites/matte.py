"""AI 생성 몬스터 시안(체크무늬 배경이 그림에 박혀 있는 불투명 PNG)에서 배경을 지운다.

체크무늬는 칸 크기와 시작 위치가 일정하다(GRID). 칸마다 두 가지 회색 중 하나가 깔린다고 보고
'배경판(plate)'을 다시 그린 뒤, 배경판과 거의 같은 색이면서 그림 바깥과 이어진 픽셀을 지운다.
- 칸 색은 칸 가운데의 중앙값으로 잡고, 캐릭터에 가려진 칸은 주변의 같은 색 칸에서 가져온다.
- 칸 경계(흐림 때문에 두 색이 섞인 띠)에서는 두 색 모두 배경으로 인정한다.
- 이펙트의 은은한 빛은 배경판을 빼는 color-to-alpha로 반투명으로 남긴다.
- 검은 칸 위에서 함께 지워진 캐릭터 외곽선은 마지막에 1px 되살린다.
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

K8 = np.ones((3, 3), bool)
# 시트별 체크무늬: (칸 크기, x 시작, y 시작). tools/monster_sprites/grid 측정값
GRID = {
    'normal_a': (45.86, 45.25, 39.0),
    'normal_b': (22.93, 22.25, 16.0),
    'boss_a': (45.86, 45.0, 39.25),
    'boss_b': (22.93, 22.0, 16.25),
}


def plate_for(px, grid):
    s, phx, phy = grid
    h, w, _ = px.shape
    xs = np.arange(w); ys = np.arange(h)
    cx = np.floor((xs - phx) / s).astype(int) + 2
    cy = np.floor((ys - phy) / s).astype(int) + 2
    ncx, ncy = cx.max() + 1, cy.max() + 1
    CX, CY = np.meshgrid(cx, cy)
    parity = (CX + CY) & 1
    lum = px.mean(-1)
    # 칸별 가운데 색
    med = np.full((ncy, ncx, 3), np.nan, np.float32)
    clean = np.zeros((ncy, ncx), bool)
    inset = max(2, int(s * 0.18))
    for j in range(ncy):
        y0 = int(np.ceil(phy + (j - 2) * s)) + inset; y1 = int(np.floor(phy + (j - 1) * s)) - inset
        y0 = max(y0, 0); y1 = min(y1, h)
        if y1 - y0 < 3: continue
        for i in range(ncx):
            x0 = int(np.ceil(phx + (i - 2) * s)) + inset; x1 = int(np.floor(phx + (i - 1) * s)) - inset
            x0 = max(x0, 0); x1 = min(x1, w)
            if x1 - x0 < 3: continue
            c = px[y0:y1, x0:x1].reshape(-1, 3)
            m = np.median(c, 0)
            sd = np.abs(c - m).max(1)
            sat = m.max() - m.min()
            if (sd < 9).mean() > 0.92 and sat < 16 and m.mean() < 80:
                med[j, i] = m; clean[j, i] = True
    # 같은 색 칸끼리 전역 대표색
    par = (np.add.outer(np.arange(ncy), np.arange(ncx))) & 1
    tone = [np.median(med[clean & (par == k)], 0) for k in (0, 1)]
    # 가려진 칸: 반경 안 같은 색 깨끗한 칸 평균, 없으면 전역색
    filled = med.copy()
    for j in range(ncy):
        for i in range(ncx):
            if clean[j, i]: continue
            k = par[j, i]; acc = []
            for r in (2, 4, 8):
                jj0, jj1 = max(0, j - r), min(ncy, j + r + 1); ii0, ii1 = max(0, i - r), min(ncx, i + r + 1)
                sub = clean[jj0:jj1, ii0:ii1] & (par[jj0:jj1, ii0:ii1] == k)
                if sub.sum() >= 2:
                    acc = med[jj0:jj1, ii0:ii1][sub]; break
            filled[j, i] = np.median(acc, 0) if len(acc) else tone[k]
    P = filled[CY, CX]
    # 칸 경계 거리
    fx = ((xs - phx) / s) % 1.0; fy = ((ys - phy) / s) % 1.0
    dx = np.minimum(fx, 1 - fx) * s; dy = np.minimum(fy, 1 - fy) * s
    DX, DY = np.meshgrid(dx, dy)
    edge = np.minimum(DX, DY) < 2.2
    # 경계 띠에서는 이웃 칸 색(반대 색)도 후보
    P2 = filled[CY, np.clip(CX + np.where(np.meshgrid(fx, fy)[0] < 0.5, -1, 1), 0, ncx - 1)]
    P3 = filled[np.clip(CY + np.where(np.meshgrid(fx, fy)[1] < 0.5, -1, 1), 0, ncy - 1), CX]
    return P, P2, P3, edge, tone


def sheet_maps(px, grid, tol=12.0):
    """시트 전체의 배경 차이(D), 배경 후보(cand), 주변 배경 비율(cellfrac), 배경판(P).
    AI가 그린 체크무늬는 칸 위치가 조금씩 어긋나므로, 칸의 짝/홀을 믿지 않고
    '그 근처의 두 가지 체크 색 중 가까운 쪽'과의 차이를 배경 차이로 쓴다."""
    s, phx, phy = grid
    P, P2, P3, edge, tone = plate_for(px, grid)
    # 근처 두 색: 이 칸 색(P)과 옆 칸 색(P2 또는 P3 중 P와 더 다른 쪽)
    alt = np.where((np.abs(P2 - P).sum(-1) >= np.abs(P3 - P).sum(-1))[..., None], P2, P3)
    d1 = np.abs(px - P).max(-1)
    d2 = np.abs(px - alt).max(-1)
    # 두 색 사이 섞인 값(칸 경계 흐림)
    lo = np.minimum(P, alt) - tol; hi = np.maximum(P, alt) + tol
    between = np.all((px >= lo) & (px <= hi), -1) & ((px.max(-1) - px.min(-1)) < 16)
    D = np.minimum(d1, d2)
    D = np.where(between & edge, np.minimum(D, tol * 0.5), D)
    cand = D < tol
    win = int(round(s))
    cellfrac = ndi.uniform_filter(cand.astype(np.float32), size=win)
    Pn = np.where((d1 <= d2)[..., None], P, alt)
    # 어두운 칸 색에 가까운지 (체크 두 색이 함께 있는 덩어리 = 진짜 배경 판별용)
    mid = (P.mean(-1) + alt.mean(-1)) * 0.5
    is_dark = px.mean(-1) < mid
    return {'D': D, 'cand': cand, 'cellfrac': cellfrac, 'P': Pn, 'is_dark': is_dark, 'tone_dark': float(min(t.mean() for t in tone)), 'tol': tol, 's': s}


def frame_matte(px, M, rb, keep_frac=0.02, soft_fx=True):
    """한 프레임 잘라 낸 부분의 배경 제거.
    px: HxWx3, M: sheet_maps를 같은 범위로 자른 dict, rb: 같은 범위 rembg 마스크(0~1).
    반환: RGBA float (0~255 색, 0~1 알파)"""
    D, cand, cellfrac, P = M['D'], M['cand'], M['cellfrac'], M['P']
    tol, s = M['tol'], M['s']
    # 1) 배경판과 같은 색이면서 바깥과 이어진(또는 넓은) 부분 = 배경
    lab, n = ndi.label(cand, K8)
    sizes = ndi.sum(cand, lab, range(1, n + 1))
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    keep_bg = np.zeros(n + 1, bool)
    for i, sz in enumerate(sizes, 1):
        if i in border or sz >= s * s * 0.35:
            keep_bg[i] = True
    bg_plate = keep_bg[lab]
    # 체크 두 색이 모두 들어 있는 넓은 덩어리는 이펙트 안쪽에 갇혀 있어도 배경이다
    forced = np.zeros(n + 1, bool)
    if n:
        nd = ndi.sum(M['is_dark'] & cand, lab, range(1, n + 1))
        for i, sz in enumerate(sizes, 1):
            if sz >= s * s * 0.3:
                fd = nd[i - 1] / sz
                if min(fd, 1 - fd) >= 0.15:
                    forced[i] = True
    forced_bg = forced[lab]
    # 2) 칸이 통째로 배경판인 곳은 무조건 배경
    full_cell = cand & (cellfrac > 0.88)
    # 3) rembg가 캐릭터라고 보는 곳은 배경판 색이어도 살린다(머리카락 등).
    #    rembg가 배경이라 보고 배경판과 크게 다르지 않으면 지운다(남은 체크 칸).
    fg = (~bg_plate | (rb > 0.6)) & ~full_cell & ~forced_bg
    big_cand = np.zeros(n + 1, bool)
    big_cand[1:] = sizes >= s * s * 0.15
    fg &= (rb > 0.12) | ~(cand & big_cand[lab])
    # 남은 체크 칸 조각: 배경과 맞닿아 있고, 배경색에 조금 덜 가깝지만(느슨한 기준) rembg도 배경이라 보는 곳
    loose = (D < tol * 2.2) & (rb < 0.5) & fg
    ll, ln = ndi.label(loose, K8)
    if ln:
        touch = np.unique(ll[ndi.binary_dilation(~fg, K8) & loose])
        fg &= ~np.isin(ll, touch[touch > 0])
    # 캐릭터 안쪽 구멍(옷 그림자가 배경색과 비슷한 곳)은 메운다. 체크 두 색이 다 보이는 구멍(다리 사이 등)은 둔다
    holes = ndi.binary_fill_holes(fg) & ~fg
    hl, hn = ndi.label(holes, K8)
    if hn:
        hs = ndi.sum(holes, hl, range(1, hn + 1))
        hf = ndi.sum(holes & (forced_bg | full_cell), hl, range(1, hn + 1))
        fill = [i + 1 for i in range(hn) if hs[i] < s * s * 0.12 or (hs[i] < s * s * 2 and hf[i] < hs[i] * 0.3)]
        fg |= np.isin(hl, fill)
    # 작은 조각 제거
    lab2, n2 = ndi.label(fg, K8)
    if n2:
        sz2 = ndi.sum(fg, lab2, range(1, n2 + 1))
        mx = sz2.max()
        fg = np.isin(lab2, [i + 1 for i, v in enumerate(sz2) if v >= max(40, mx * keep_frac)])
    # 4) 부드러운 가장자리: 바깥 띠에서는 배경판 대비 차이와 rembg 값으로 투명도
    dist = ndi.distance_transform_edt(fg)
    band = fg & (dist <= 4)
    soft = np.clip((D - tol * 0.5) / 36.0, 0, 1)
    alpha = fg.astype(np.float32)
    a_band = np.maximum(soft, np.clip(rb * 1.2 - 0.1, 0, 1) * (D > tol * 0.5))
    alpha = np.where(band, np.clip(np.maximum(a_band, (dist >= 3) * 0.9), 0, 1), alpha)
    # 5) 외곽선 되살리기 (검은 칸 위에서 함께 지워진 1px 외곽선)
    lum = px.mean(-1)
    ring = ndi.binary_dilation(fg, K8) & ~fg
    outl = ring & (lum < max(M['tone_dark'] - 5, 9)) & (rb > 0.3)
    alpha = np.where(outl, 1.0, alpha)
    a3 = np.maximum(alpha, 1e-3)[..., None]
    col = np.clip((px - (1 - alpha[..., None]) * P) / a3, 0, 255)
    col = np.where((alpha >= 0.999)[..., None], px, col)
    return col, alpha
