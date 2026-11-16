#!/usr/bin/env python3
"""일초만련 픽셀 스프라이트 생성기.

외부 에셋을 쓰지 않고, 코드로 픽셀을 찍어 캐릭터와 몬스터 스프라이트 시트를 만든다.
- 출력: assets/sprites/characters/*.png, assets/sprites/monsters/*.png (한 줄짜리 시트)
- 프레임 순서(모든 시트 공통): 대기0, 대기1, 공격0(준비), 공격1(타격), 공격2(회수), 피격, 쓰러짐0(무릎), 쓰러짐1(누움)
- 시트와 동작 정보는 data/sprites/sprite_sets.json 이 가리킨다. 나중에 그린 그림으로 바꿀 때는
  같은 크기/같은 프레임 순서의 PNG로 파일만 교체하면 된다.

실행: python3 tools/sprites/generate_sprites.py [--preview 미리보기.png]
필요: Pillow
"""
import argparse
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FRAMES = ["idle0", "idle1", "atk0", "atk1", "atk2", "hit", "down0", "down1"]


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def shade(c, f):
    """색을 f배로 어둡게(f<1) 또는 밝게(f>1)."""
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))), c[3])


class Canvas:
    """픽셀 단위로 찍는 작은 캔버스."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def dot(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if c[3] == 255 or self.px[x, y][3] == 0:
                self.px[x, y] = c
            else:
                # 반투명 색은 아래 색과 섞는다
                b = self.px[x, y]
                a = c[3] / 255.0
                self.px[x, y] = (int(c[0] * a + b[0] * (1 - a)), int(c[1] * a + b[1] * (1 - a)),
                                 int(c[2] * a + b[2] * (1 - a)), max(b[3], c[3]))

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.dot(x, y, c)

    def line(self, x0, y0, x1, y1, c, t=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            k = i / max(n, 1)
            x = x0 + (x1 - x0) * k
            y = y0 + (y1 - y0) * k
            if t <= 1:
                self.dot(x, y, c)
            else:
                for dy in range(t):
                    for dx in range(t):
                        self.dot(x - (t - 1) / 2 + dx, y - (t - 1) / 2 + dy, c)

    def outline(self, c):
        """불투명 픽셀 둘레(상하좌우)에 외곽선을 그린다."""
        src = self.img.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] > 128:
                        self.px[x, y] = c
                        break


def polar(x, y, ang, length):
    r = math.radians(ang)
    return x + math.cos(r) * length, y + math.sin(r) * length


# ---------------------------------------------------------------------------
# 무기 그리기 (오른쪽을 보는 기준, 각도 0 = 앞, 90 = 아래, -90 = 위)
# ---------------------------------------------------------------------------

def draw_weapon(cv, kind, hx, hy, ang, pal, L):
    metal, metal_d = pal["metal"], shade(pal["metal"], 0.65)
    wood = pal.get("wood", hexc("7a4a26"))
    gold = pal.get("gold", hexc("e0b040"))
    if kind == "jian":  # 검: 가늘고 곧은 날, 금빛 코등이
        gx, gy = polar(hx, hy, ang, 1)
        tx, ty = polar(hx, hy, ang, L)
        bx, by = polar(hx, hy, ang + 180, 2)
        cv.line(bx, by, hx, hy, wood, 1)
        cv.line(gx, gy, tx, ty, metal, 1)
        px_, py_ = polar(gx, gy, ang + 90, 1)
        cv.line(px_, py_, *polar(px_, py_, ang, L - 3), metal_d, 1)
        g1 = polar(gx, gy, ang + 90, 2)
        g2 = polar(gx, gy, ang - 90, 2)
        cv.line(*g1, *g2, gold, 1)
        cv.dot(*polar(hx, hy, ang + 180, 3), pal.get("tassel", hexc("d03030")))
    elif kind == "dao":  # 도: 넓고 끝이 휘는 날
        tx, ty = polar(hx, hy, ang, L)
        cv.line(*polar(hx, hy, ang + 180, 2), hx, hy, wood, 2)
        cv.line(*polar(hx, hy, ang, 1), tx, ty, metal, 2)
        ex, ey = polar(hx, hy, ang - 90, 1.5)
        cv.line(*polar(ex, ey, ang, 2), *polar(ex, ey, ang, L - 2), metal_d, 1)
        cv.dot(*polar(tx, ty, ang + 90, 1), metal)
        g1 = polar(hx, hy, ang + 90, 2)
        g2 = polar(hx, hy, ang - 90, 2)
        cv.line(*g1, *g2, gold, 1)
    elif kind == "club":  # 몽둥이: 굵은 나무, 끝에 쇠테
        tx, ty = polar(hx, hy, ang, L)
        cv.line(*polar(hx, hy, ang + 180, 1), tx, ty, wood, 3)
        cv.line(*polar(hx, hy, ang, L - 3), tx, ty, metal, 3)
        cv.line(*polar(*polar(hx, hy, ang, 2), ang + 90, 1), *polar(*polar(hx, hy, ang, L - 4), ang + 90, 1), shade(wood, 1.25), 1)
    elif kind == "daggers":  # 비수 한 쌍
        for off in (0, 3):
            sx, sy = polar(hx, hy, ang + 90, off)
            cv.line(*polar(sx, sy, ang + 180, 1), sx, sy, wood, 1)
            cv.line(*polar(sx, sy, ang, 1), *polar(sx, sy, ang, L), metal, 1)
    elif kind == "spear":  # 창: 긴 자루와 붉은 술
        tx, ty = polar(hx, hy, ang, L)
        cv.line(*polar(hx, hy, ang + 180, 6), tx, ty, wood, 1)
        cv.line(*polar(hx, hy, ang, L - 1), *polar(hx, hy, ang, L + 4), metal, 2)
        cv.dot(*polar(*polar(hx, hy, ang, L - 2), ang + 90, 1), pal.get("tassel", hexc("d03030")))
        cv.dot(*polar(*polar(hx, hy, ang, L - 2), ang - 90, 1), pal.get("tassel", hexc("d03030")))
    elif kind == "guandao":  # 언월도: 긴 자루 끝의 큰 반달 날
        tx, ty = polar(hx, hy, ang, L)
        cv.line(*polar(hx, hy, ang + 180, 10), tx, ty, wood, 2)
        for i in range(9):
            w = 4 - abs(i - 4) * 0.6 + 1
            bx, by = polar(tx, ty, ang, i - 1)
            cv.line(bx, by, *polar(bx, by, ang - 90, w), metal, 1)
            cv.dot(*polar(bx, by, ang - 90, w), metal_d)
        cv.line(*polar(tx, ty, ang + 90, 2), *polar(tx, ty, ang - 90, 2), gold, 2)
        cv.dot(*polar(tx, ty, ang + 90, 3), pal.get("tassel", hexc("d03030")))


def draw_bow(cv, hx, hy, pal, drawn):
    """활: 손 위치에 세로로 선 활. drawn이면 시위를 당긴 상태."""
    wood = pal.get("wood", hexc("7a4a26"))
    pts = []
    for i in range(-7, 8):
        bend = 3 - (i * i) / 16.0
        pts.append((hx + bend, hy + i))
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        cv.line(x0, y0, x1, y1, wood, 1)
    pull = -5 if drawn else -1
    string = hexc("e8e0c8")
    cv.line(pts[0][0], pts[0][1], hx + pull, hy, string, 1)
    cv.line(pts[-1][0], pts[-1][1], hx + pull, hy, string, 1)
    if drawn:
        cv.line(hx + pull, hy, hx + 7, hy, hexc("c8b088"), 1)
        cv.dot(hx + 8, hy, pal["metal"])


# ---------------------------------------------------------------------------
# 사람형 캐릭터
# ---------------------------------------------------------------------------

def humanoid(spec, pose, W, H):
    """spec(생김새)과 pose(자세)로 프레임 하나를 그린다. 오른쪽을 본다."""
    cv = Canvas(W, H)
    pal = spec["pal"]
    d = spec["dims"]
    cx = spec.get("cx", W // 2 - 2)
    ground = H - 1
    bob = pose.get("bob", 0)
    lean = pose.get("lean", 0)
    kneel = pose.get("kneel", False)

    leg_h, skirt_h, torso_h = d["leg"], d["skirt"], d["torso"]
    head_w, head_h, torso_w = d["head_w"], d["head_h"], d["torso_w"]
    sink = (leg_h - 2) if kneel else 0
    up = bob + sink

    # 다리와 신발
    legx_back = cx - torso_w // 4 - 1
    legx_front = cx + torso_w // 4
    leg_top = ground - leg_h + 1
    step = pose.get("step", 0)
    if kneel:
        cv.rect(legx_back - 1, ground - 1, legx_back + 4, ground, pal["boots"])
        cv.rect(legx_front, ground - 2, legx_front + 2, ground, pal["pants"])
        cv.rect(legx_front + 1, ground - 1, legx_front + 4, ground, pal["boots"])
    else:
        lw = d.get("leg_w", 2)
        cv.rect(legx_back - step, leg_top, legx_back - step + lw - 1, ground, shade(pal["pants"], 0.8))
        cv.rect(legx_back - step - 1, ground - 1, legx_back - step + lw - 1, ground, pal["boots"])
        cv.rect(legx_front + step, leg_top, legx_front + step + lw - 1, ground, pal["pants"])
        cv.rect(legx_front + step, ground - 1, legx_front + step + lw, ground, pal["boots"])

    # 몸통 기준점
    ox = cx + lean
    skirt_bot = ground - leg_h + up + (1 if kneel else 0)
    skirt_top = skirt_bot - skirt_h + 1
    torso_bot = skirt_top - 1
    torso_top = torso_bot - torso_h + 1
    tl = ox - torso_w // 2
    tr = tl + torso_w - 1

    # 망토(뒤)
    if spec.get("cape"):
        cc = spec["cape"]
        for y in range(torso_top + 1, skirt_bot + 2):
            k = (y - torso_top) / max(1, (skirt_bot - torso_top))
            cv.rect(tl - 1 - int(k * 3), y, tl + 2, y, shade(cc, 0.85 if y % 3 else 0.7))

    shoulder_b = (tl + 1, torso_top + 2)
    shoulder_f = (tr - 1, torso_top + 2)
    arm_len = d.get("arm", 6)
    sleeve = pal.get("sleeve", pal["robe"])

    # 뒷팔
    bang = pose.get("back_arm", 100)
    bx, by = polar(*shoulder_b, bang, arm_len)
    cv.line(*shoulder_b, bx, by, shade(sleeve, 0.7), d.get("arm_t", 2))
    cv.dot(bx, by, shade(pal["skin"], 0.8))
    if spec.get("bow") and pose.get("bow_pull"):
        pass

    # 치마(도포 아랫단)
    for y in range(skirt_top, skirt_bot + 1):
        k = y - skirt_top
        flare = k // 2
        cv.rect(tl - flare, y, tr + flare, y, pal["robe"])
        cv.dot(tl - flare, y, shade(pal["robe"], 0.7))
        cv.dot(tl - flare + 1, y, shade(pal["robe"], 0.82))
    cv.rect(tl - (skirt_h - 1) // 2, skirt_bot, tr + (skirt_h - 1) // 2, skirt_bot, pal.get("trim", shade(pal["robe"], 0.6)))
    if spec.get("front_panel"):
        cv.rect(ox - 1, skirt_top, ox, skirt_bot, spec["front_panel"])

    # 몸통
    cv.rect(tl, torso_top, tr, torso_bot, pal["robe"])
    cv.rect(tl, torso_top, tl + 1, torso_bot, shade(pal["robe"], 0.75))
    cv.rect(tr, torso_top + 1, tr, torso_bot, shade(pal["robe"], 1.18))
    if spec.get("inner"):
        # 앞섶(교차 깃)
        for i in range(min(4, torso_h - 2)):
            cv.dot(ox + i // 2, torso_top + i, spec["inner"])
            cv.dot(ox + 1 + i // 2, torso_top + i, spec["inner"])
    if spec.get("bare_chest"):
        cv.rect(tl + 2, torso_top, tr - 1, torso_top + torso_h // 2, pal["skin"])
        cv.rect(tl + 2, torso_top, tl + 2, torso_top + torso_h // 2, shade(pal["skin"], 0.8))
    if spec.get("armor"):
        ac = spec["armor"]
        for y in range(torso_top + 1, torso_bot, 2):
            cv.rect(tl + 1, y, tr - 1, y, ac)
            cv.dot(tr - 1, y, shade(ac, 1.3))
    if spec.get("collar"):
        cv.rect(tl - 1, torso_top - 1, tr + 1, torso_top, spec["collar"])
        cv.dot(tl - 1, torso_top, shade(spec["collar"], 0.7))
    sash_y = torso_bot - 1
    cv.rect(tl, sash_y, tr, sash_y + 1, pal["sash"])
    if spec.get("sash_tail"):
        cv.rect(tl - 1, sash_y + 1, tl, sash_y + 4, pal["sash"])

    # 머리
    hx0 = ox - head_w // 2 + 1
    hy1 = torso_top - 1
    hy0 = hy1 - head_h + 1
    cv.rect(hx0, hy0, hx0 + head_w - 1, hy1, pal["skin"])
    cv.rect(hx0, hy0, hx0, hy1, shade(pal["skin"], 0.82))
    # 눈
    ey = hy0 + head_h // 2
    eye_c = pal.get("eye", hexc("1a1420"))
    if pose.get("eyes", "open") == "open":
        for exx in (hx0 + head_w - 2, hx0 + head_w - 4):
            cv.dot(exx, ey, eye_c)
            if spec.get("big_eyes"):
                cv.dot(exx, ey + 1, eye_c)
    else:
        cv.dot(hx0 + head_w - 2, ey + 1, eye_c)
        cv.dot(hx0 + head_w - 3, ey + 1, eye_c)
        cv.dot(hx0 + head_w - 5, ey + 1, eye_c)
        cv.dot(hx0 + head_w - 4, ey + 1, eye_c)
    if spec.get("brow"):
        cv.rect(hx0 + head_w - 5, ey - 1, hx0 + head_w - 1, ey - 1, spec["brow"])
    if spec.get("mask"):
        cv.rect(hx0, ey + 2, hx0 + head_w - 1, hy1, spec["mask"])
    if spec.get("beard"):
        bc = spec["beard"]
        cv.rect(hx0 + 2, ey + 2, hx0 + head_w, hy1 + 2, bc)
        cv.rect(hx0 + 3, hy1 + 3, hx0 + head_w - 1, hy1 + 3, bc)
        cv.rect(hx0 + head_w - 3, ey + 2, hx0 + head_w - 2, ey + 2, shade(pal["skin"], 0.6))  # 입
    if spec.get("blush"):
        cv.dot(hx0 + head_w - 3, ey + 2, spec["blush"])

    # 머리카락 / 모자
    hair = pal.get("hair")
    style = spec.get("hair_style", "topknot")
    if style == "topknot" and hair:
        cv.rect(hx0, hy0 - 1, hx0 + head_w - 1, hy0 + 1, hair)
        cv.rect(hx0, hy0, hx0 + 1, hy0 + head_h // 2 + 1, hair)
        kx = hx0 + head_w // 2 - 1
        cv.rect(kx, hy0 - 3, kx + 2, hy0 - 2, hair)
        if spec.get("ribbon"):
            cv.dot(kx - 1, hy0 - 2, spec["ribbon"])
            cv.dot(kx - 2, hy0 - 1, spec["ribbon"])
            cv.dot(kx - 3, hy0 - 1 + (bob % 2), spec["ribbon"])
    elif style == "long" and hair:
        cv.rect(hx0, hy0 - 1, hx0 + head_w - 1, hy0 + 1, hair)
        cv.rect(hx0 - 1, hy0, hx0 + 1, hy1 + 5, hair)
        cv.rect(hx0 - 2, hy0 + 3, hx0 - 1, hy1 + 6, shade(hair, 0.85))
    elif style == "bald":
        cv.dot(hx0 + 2, hy0 + 1, shade(pal["skin"], 1.2))
        cv.dot(hx0 + 3, hy0 + 1, shade(pal["skin"], 1.2))
    elif style == "wild" and hair:
        cv.rect(hx0 - 1, hy0 - 2, hx0 + head_w, hy0 + 1, hair)
        for i in range(0, head_w + 2, 2):
            cv.dot(hx0 - 1 + i, hy0 - 3, hair)
        cv.rect(hx0 - 2, hy0, hx0 + 1, hy1 + 2, hair)
    if spec.get("headband"):
        cv.rect(hx0, hy0 + 1, hx0 + head_w - 1, hy0 + 1, spec["headband"])
        cv.dot(hx0 - 1, hy0 + 2, spec["headband"])
        cv.dot(hx0 - 2, hy0 + 3, spec["headband"])
    if spec.get("hat") == "bamboo":  # 삿갓
        hc = spec["hat_color"]
        top = hy0 - 4
        for i in range(5):
            cv.rect(ox + 1 - i * 2 - 1, top + i, ox + 1 + i * 2 + 1, top + i, hc if i < 4 else shade(hc, 0.75))
        cv.dot(ox + 1, top - 1, shade(hc, 0.8))
    if spec.get("hat") == "helmet":
        hc = spec["hat_color"]
        cv.rect(hx0 - 1, hy0 - 2, hx0 + head_w, hy0 + 1, hc)
        cv.rect(hx0 - 1, hy0 - 2, hx0 - 1, hy0 + head_h // 2 + 1, shade(hc, 0.7))
        cv.dot(hx0 + head_w // 2, hy0 - 3, spec.get("plume", hexc("c03030")))
        cv.dot(hx0 + head_w // 2 - 1, hy0 - 4, spec.get("plume", hexc("c03030")))
        cv.rect(hx0, hy0 + 1, hx0 + head_w, hy0 + 1, shade(hc, 1.3))
    if spec.get("horns"):
        hc = spec["horns"]
        cv.line(hx0, hy0 - 1, hx0 - 2, hy0 - 4, hc)
        cv.line(hx0 + head_w - 1, hy0 - 1, hx0 + head_w + 1, hy0 - 4, hc)
    if spec.get("glow_eyes") and pose.get("eyes", "open") == "open":
        cv.dot(hx0 + head_w - 2, ey, spec["glow_eyes"])
        cv.dot(hx0 + head_w - 4, ey, spec["glow_eyes"])

    # 앞팔과 무기
    fang = pose.get("arm", 60)
    fx, fy = polar(*shoulder_f, fang, arm_len)
    weapon = spec.get("weapon")
    wang = pose.get("weapon", fang)
    if weapon == "bow":
        cv.line(*shoulder_f, fx, fy, sleeve, d.get("arm_t", 2))
        cv.dot(fx, fy, pal["skin"])
        draw_bow(cv, fx + 1, fy, pal, pose.get("bow_pull", False))
    else:
        cv.line(*shoulder_f, fx, fy, sleeve, d.get("arm_t", 2))
        if spec.get("bare_arms"):
            cv.line(*polar(*shoulder_f, fang, 2), fx, fy, pal["skin"], d.get("arm_t", 2))
        if weapon:
            draw_weapon(cv, weapon, fx, fy, wang, pal, spec.get("weapon_len", 10))
        cv.dot(fx, fy, pal["skin"])
        cv.dot(*polar(fx, fy, fang, 1), pal["skin"])

    # 방패 (가장 앞)
    if spec.get("shield"):
        sc = spec["shield"]
        sx = tr + 1 + pose.get("shield_push", 0)
        sy0 = torso_top - 1
        sy1 = skirt_bot - 1
        cv.rect(sx, sy0, sx + 3, sy1, sc)
        cv.rect(sx + 3, sy0 + 1, sx + 3, sy1 - 1, shade(sc, 1.25))
        cv.rect(sx, sy0, sx, sy1, shade(sc, 0.7))
        cv.dot(sx + 2, (sy0 + sy1) // 2, pal.get("gold", hexc("e0b040")))
        cv.dot(sx + 2, (sy0 + sy1) // 2 - 1, pal.get("gold", hexc("e0b040")))

    # 타격 궤적 (공격 순간만, 반투명)
    if pose.get("swoosh"):
        sw = hexc("fff6d8", 170)
        r = spec.get("weapon_len", 10) + arm_len - 1
        for a in range(-70, 35, 4):
            cv.dot(*polar(*shoulder_f, a, r), sw)
            cv.dot(*polar(*shoulder_f, a, r - 1), hexc("fff6d8", 90))

    cv.outline(pal["outline"])
    return cv.img


def lying(spec, W, H):
    """쓰러짐1: 선 자세(눈 감음)를 그려 90도 돌려 눕힌다. 뒤로(왼쪽으로) 넘어진다."""
    pose = {"eyes": "closed", "arm": 80, "weapon": 95, "back_arm": 95}
    big = humanoid(dict(spec, cape=None, shield=None, weapon=None), pose, W, H)
    rot = big.rotate(90, expand=True, resample=Image.NEAREST)
    bbox = rot.getbbox()
    rot = rot.crop(bbox)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = max(0, (W - rot.width) // 2)
    out.paste(rot, (x, H - rot.height), rot)
    return out


POSES = {
    "idle0": {"bob": 0},
    "idle1": {"bob": 1},
    "atk0": {"lean": -1, "arm": -120, "weapon": -150, "back_arm": 140, "step": 0},
    "atk1": {"lean": 2, "arm": 5, "weapon": 10, "back_arm": 160, "step": 1, "swoosh": True},
    "atk2": {"lean": 1, "arm": 45, "weapon": 60, "back_arm": 120, "step": 1},
    "hit": {"lean": -2, "arm": 140, "weapon": 170, "back_arm": 150, "eyes": "closed"},
    "down0": {"kneel": True, "lean": -1, "arm": 80, "weapon": 100, "eyes": "closed"},
}


def sheet_for(spec, W, H, poses=None, mirror=False):
    poses = dict(POSES, **(poses or {}))
    base_idle = spec.get("idle_pose", {})
    frames = []
    for name in FRAMES:
        if name == "down1":
            img = lying(spec, W, H)
        else:
            p = dict(poses[name])
            if name.startswith("idle"):
                p = dict(base_idle, **p)
            img = humanoid(spec, p, W, H)
        if mirror:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        frames.append(img)
    sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * W, 0), f)
    return sheet


# ---------------------------------------------------------------------------
# 캐릭터와 몬스터 정의
# ---------------------------------------------------------------------------

OUTLINE = hexc("1c1424")
SKIN = hexc("f2c9a0")
STD = {"leg": 6, "skirt": 6, "torso": 9, "head_w": 8, "head_h": 8, "torso_w": 10, "arm": 6}

SPECS = {
    # 주인공: 청의 검객. 흰 속옷 위에 푸른 도포, 상투에 흰 끈, 검(劍)
    "hero_swordsman": {
        "kind": "characters", "size": (40, 40), "mirror": False,
        "dims": dict(STD), "weapon": "jian", "weapon_len": 13, "hair_style": "topknot",
        "ribbon": hexc("f4f4f0"), "inner": hexc("f4f4f0"), "sash_tail": True, "big_eyes": True,
        "idle_pose": {"arm": 70, "weapon": 115, "back_arm": 100},
        "pal": {"skin": SKIN, "hair": hexc("201830"), "robe": hexc("3f7fb8"), "sleeve": hexc("3f7fb8"),
                "trim": hexc("e8e4d8"), "sash": hexc("1f3f6a"), "pants": hexc("e8e4d8"), "boots": hexc("2a2230"),
                "metal": hexc("dfe8f0"), "gold": hexc("e6b84a"), "wood": hexc("5a3a24"), "tassel": hexc("3fb0c8"),
                "outline": OUTLINE},
    },
    # 일반 근접형: 산적. 붉은 머리띠, 갈색 조끼, 도(刀)
    "bandit": {
        "kind": "monsters", "size": (40, 40), "mirror": True,
        "dims": dict(STD), "weapon": "dao", "weapon_len": 10, "hair_style": "topknot",
        "headband": hexc("c83a32"), "bare_chest": True, "brow": hexc("2a1a14"),
        "idle_pose": {"arm": 50, "weapon": -60, "back_arm": 100},
        "pal": {"skin": hexc("d9a37a"), "hair": hexc("2a1a14"), "robe": hexc("8a5a34"), "sleeve": hexc("8a5a34"),
                "trim": hexc("5a3820"), "sash": hexc("c83a32"), "pants": hexc("6a5a48"), "boots": hexc("2a2026"),
                "metal": hexc("c8ccd0"), "outline": OUTLINE},
    },
    # 일반 근접형(무거움): 거한. 대머리, 맨팔, 쇠테 몽둥이
    "brute": {
        "kind": "monsters", "size": (40, 40), "mirror": True,
        "dims": dict(STD, torso_w=14, torso=10, head_w=8, leg=5, skirt=5, arm=7, arm_t=3, leg_w=3),
        "weapon": "club", "weapon_len": 11, "hair_style": "bald", "bare_arms": True, "bare_chest": True,
        "brow": hexc("3a2418"), "beard": hexc("3a2418"),
        "idle_pose": {"arm": 40, "weapon": -70, "back_arm": 100},
        "pal": {"skin": hexc("c98c64"), "robe": hexc("5d4a7a"), "sleeve": hexc("c98c64"),
                "trim": hexc("3a2c50"), "sash": hexc("2a2234"), "pants": hexc("4a3c5c"), "boots": hexc("2a2026"),
                "metal": hexc("9aa0a8"), "wood": hexc("6a4022"), "outline": OUTLINE},
    },
    # 빠른 돌진형: 흑의 자객. 복면, 검은 옷, 비수 한 쌍
    "assassin": {
        "kind": "monsters", "size": (40, 40), "mirror": True,
        "dims": dict(STD, torso_w=8, torso=8), "weapon": "daggers", "weapon_len": 5,
        "hair_style": "topknot", "mask": hexc("24202c"), "sash_tail": True,
        "idle_pose": {"lean": 1, "arm": 20, "weapon": 10, "back_arm": 150},
        "poses": {"atk0": {"lean": -2, "arm": 150, "weapon": 170, "back_arm": 160, "kneel": True},
                  "atk1": {"lean": 5, "arm": 0, "weapon": 0, "back_arm": 175, "step": 2, "swoosh": True},
                  "atk2": {"lean": 3, "arm": 30, "weapon": 20, "back_arm": 150, "step": 1}},
        "pal": {"skin": hexc("e6bc94"), "hair": hexc("141018"), "robe": hexc("36323e"), "sleeve": hexc("36323e"),
                "trim": hexc("5a2430"), "sash": hexc("8a2a34"), "pants": hexc("2c2834"), "boots": hexc("18141c"),
                "metal": hexc("e0e6ee"), "eye": hexc("f0e070"), "outline": hexc("0e0a12")},
    },
    # 원거리형: 삿갓 궁수. 초록 옷, 삿갓, 활
    "archer": {
        "kind": "monsters", "size": (40, 40), "mirror": True,
        "dims": dict(STD, torso_w=9), "weapon": "bow", "hair_style": "topknot",
        "hat": "bamboo", "hat_color": hexc("c8a860"),
        "idle_pose": {"arm": 40, "back_arm": 100},
        "poses": {"atk0": {"lean": -1, "arm": 0, "back_arm": 10, "bow_pull": True},
                  "atk1": {"lean": 0, "arm": 0, "back_arm": 175, "bow_pull": False},
                  "atk2": {"lean": 0, "arm": 20, "back_arm": 120},
                  "hit": {"lean": -2, "arm": 120, "back_arm": 150, "eyes": "closed"}},
        "pal": {"skin": hexc("e8c09a"), "hair": hexc("2a2018"), "robe": hexc("4a7a46"), "sleeve": hexc("4a7a46"),
                "trim": hexc("2e4e2c"), "sash": hexc("a07a3a"), "pants": hexc("5a5040"), "boots": hexc("2a2420"),
                "metal": hexc("c0c4c8"), "wood": hexc("8a5a2a"), "outline": OUTLINE},
    },
    # 방어형: 철갑 수문위사. 투구, 비늘 갑옷, 큰 방패, 창
    "shield_guard": {
        "kind": "monsters", "size": (40, 40), "mirror": True,
        "dims": dict(STD, torso_w=12, torso=10, leg_w=3), "weapon": "spear", "weapon_len": 9,
        "hair_style": "none", "hat": "helmet", "hat_color": hexc("7a8494"), "armor": hexc("9aa4b4"),
        "shield": hexc("8a2a2a"),
        "idle_pose": {"arm": -60, "weapon": -80, "back_arm": 100},
        "poses": {"atk0": {"lean": -1, "arm": -20, "weapon": 0, "back_arm": 100},
                  "atk1": {"lean": 2, "arm": 0, "weapon": 0, "back_arm": 100, "shield_push": 2, "step": 1},
                  "atk2": {"lean": 1, "arm": -10, "weapon": -10, "back_arm": 100, "shield_push": 1},
                  "hit": {"lean": -1, "arm": -70, "weapon": -90, "back_arm": 120, "eyes": "closed"}},
        "pal": {"skin": hexc("e0b48c"), "robe": hexc("5a6474"), "sleeve": hexc("5a6474"),
                "trim": hexc("8a2a2a"), "sash": hexc("8a2a2a"), "pants": hexc("3e4652"), "boots": hexc("22242c"),
                "metal": hexc("d8dee6"), "wood": hexc("6a4a2a"), "gold": hexc("e0b040"), "outline": OUTLINE},
    },
    # 정예: 마교 흑혈대 정예. 흰 장발, 붉은 눈, 검붉은 도포, 망토, 흑검
    "elite_cultist": {
        "kind": "monsters", "size": (40, 40), "mirror": True,
        "dims": dict(STD, torso=10), "weapon": "jian", "weapon_len": 13, "hair_style": "long",
        "glow_eyes": hexc("ff3a3a"), "cape": hexc("8a1a24"), "collar": hexc("2a1a2a"), "horns": None,
        "inner": hexc("c0283a"),
        "idle_pose": {"arm": 60, "weapon": 100, "back_arm": 100},
        "pal": {"skin": hexc("e8d0c0"), "hair": hexc("e8e8f0"), "robe": hexc("3a2440"), "sleeve": hexc("3a2440"),
                "trim": hexc("c0283a"), "sash": hexc("c0283a"), "pants": hexc("2a1c30"), "boots": hexc("140c18"),
                "metal": hexc("6a5a7a"), "gold": hexc("c0283a"), "tassel": hexc("ff3a3a"), "outline": hexc("0e0814")},
    },
    # 보스: 산채 두목. 거대한 체구, 수염, 털 깃, 붉은 갑옷, 언월도
    "bandit_chief": {
        "kind": "monsters", "size": (72, 64), "mirror": True, "cx": 32,
        "dims": {"leg": 8, "skirt": 9, "torso": 15, "head_w": 11, "head_h": 11, "torso_w": 18, "arm": 10,
                 "arm_t": 4, "leg_w": 4},
        "weapon": "guandao", "weapon_len": 18, "hair_style": "wild", "beard": hexc("2a1810"),
        "brow": hexc("2a1810"), "collar": hexc("b89a6a"), "armor": hexc("a8322a"), "headband": hexc("e0b040"),
        "cape": hexc("5a2a1a"), "front_panel": hexc("6a2018"),
        "idle_pose": {"arm": -35, "weapon": -60, "back_arm": 100},
        "poses": {"atk0": {"lean": -2, "arm": -110, "weapon": -135, "back_arm": 140},
                  "atk1": {"lean": 3, "arm": 10, "weapon": 25, "back_arm": 150, "step": 2, "swoosh": True},
                  "atk2": {"lean": 2, "arm": 50, "weapon": 70, "back_arm": 120, "step": 1}},
        "pal": {"skin": hexc("c88e64"), "hair": hexc("2a1810"), "robe": hexc("7a2a22"), "sleeve": hexc("7a2a22"),
                "trim": hexc("e0b040"), "sash": hexc("e0b040"), "pants": hexc("4a2a22"), "boots": hexc("201416"),
                "metal": hexc("d0d6dc"), "wood": hexc("5a3420"), "gold": hexc("e6b84a"), "tassel": hexc("d03030"),
                "outline": hexc("140a0c")},
    },
}


def build_all(out_root=ROOT):
    written = {}
    for sid, spec in SPECS.items():
        W, H = spec["size"]
        sheet = sheet_for(spec, W, H, spec.get("poses"), spec.get("mirror", False))
        path = os.path.join(out_root, "assets", "sprites", spec["kind"], sid + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sheet.save(path)
        written[sid] = (path, sheet)
    return written


NAMES = {
    "hero_swordsman": "청의 검객 (주인공)",
    "bandit": "산적 (일반 근접형)",
    "brute": "거한 (일반 근접형, 무거움)",
    "assassin": "흑의 자객 (빠른 돌진형)",
    "archer": "삿갓 궁수 (원거리형)",
    "shield_guard": "철갑 수문위사 (방어형)",
    "elite_cultist": "흑혈대 정예 (정예)",
    "bandit_chief": "산채 두목 (보스)",
}

ANIMS = {
    "idle": {"frames": [0, 1], "fps": 2.0, "loop": True},
    "attack": {"frames": [2, 3, 4], "fps": 10.0, "loop": False},
    "hit": {"frames": [5], "fps": 6.0, "loop": False},
    "down": {"frames": [6, 7], "fps": 5.0, "loop": False},
}


def write_data(path):
    """data/sprites/sprite_sets.json 을 만든다. 시트 경로, 프레임 크기, 기준점, 동작 프레임."""
    import json
    sets = []
    for sid, spec in SPECS.items():
        W, H = spec["size"]
        cx = spec.get("cx", W // 2 - 2)
        pivot_x = (W - 1 - cx) if spec.get("mirror") else cx
        sets.append({
            "id": sid,
            "name": NAMES.get(sid, sid),
            "sheet": "res://assets/sprites/%s/%s.png" % (spec["kind"], sid),
            "frame_size": [W, H],
            "pivot": [pivot_x, H - 1],
            "scale": spec.get("scale", 3),
            "facing": "left" if spec.get("mirror") else "right",
            "animations": ANIMS,
        })
    data = {
        "_comment": "스프라이트 세트. tools/sprites/generate_sprites.py --write-data 로 만든다. 그림을 바꿀 때는 sheet의 PNG를 같은 프레임 크기/순서로 교체하거나, 이 파일의 sheet/frame_size/pivot/animations를 새 그림에 맞게 고친다. 몬스터 데이터의 sprite 값이 없으면 type_defaults의 유형별 기본 스프라이트를 쓴다.",
        "player_sprite": "hero_swordsman",
        "type_defaults": {
            "melee": "bandit", "charge": "assassin", "ranged": "archer",
            "defense": "shield_guard", "elite": "elite_cultist", "boss": "bandit_chief",
        },
        "sets": sets,
    }
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def make_preview(written, path, scale=4):
    """사람이 보는 확인용 그림: 스프라이트마다 한 줄, 4배 확대, 배경 격자."""
    names = list(written.keys())
    rows = []
    for sid in names:
        sheet = written[sid][1]
        rows.append(sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST))
    W = max(r.width for r in rows) + 20
    H = sum(r.height + 24 for r in rows) + 10
    img = Image.new("RGBA", (W, H), (38, 34, 48, 255))
    dr = ImageDraw.Draw(img)
    y = 6
    for sid, r in zip(names, rows):
        dr.text((10, y), sid + "  (" + ", ".join(FRAMES) + ")", fill=(230, 220, 200, 255))
        y += 16
        fw = SPECS[sid]["size"][0] * scale
        for i in range(len(FRAMES)):
            dr.rectangle([10 + i * fw, y, 10 + (i + 1) * fw - 1, y + r.height - 1],
                         fill=(52, 48, 64, 255) if i % 2 == 0 else (60, 56, 72, 255))
        img.paste(r, (10, y), r)
        y += r.height + 8
    img.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="확인용 미리보기 PNG 경로")
    ap.add_argument("--write-data", action="store_true", help="data/sprites/sprite_sets.json 도 다시 쓴다")
    args = ap.parse_args()
    written = build_all()
    if args.write_data:
        write_data(os.path.join(ROOT, "data", "sprites", "sprite_sets.json"))
        print("data/sprites/sprite_sets.json")
    for sid, (path, sheet) in written.items():
        print("%-16s %s  %dx%d" % (sid, os.path.relpath(path, ROOT), sheet.width, sheet.height))
    if args.preview:
        make_preview(written, args.preview)
        print("preview:", args.preview)


if __name__ == "__main__":
    sys.exit(main())
