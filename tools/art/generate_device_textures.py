#!/usr/bin/env python3
"""Процедурная генерация PBR-текстур устройств Abandoned («человеческий слой»).

Текстуры создаются только кодом этого файла: без внешних изображений, шрифтов,
фотографий и генеративных моделей. Результат детерминирован (фиксированные seed)
и распространяется под MIT вместе с проектом.

Формат карт (соглашения Godot 4, ORMMaterial3D):
  *_albedo.png   — базовый цвет, sRGB;
  *_normal.png   — нормали, OpenGL-соглашение (зелёный = +V вверх);
  *_orm.png      — R: ambient occlusion, G: roughness, B: metallic (линейные);
  *_emission.png — маска свечения (оттенки серого). Цвет свечения задаёт материал
                   по семантике ADR-0006: циан — оптика, янтарь — питание,
                   фиолетовый — гравитация.

Запуск из корня репозитория:
  python tools/art/generate_device_textures.py [--out content/textures] [--preview work/textures-preview]
Зависимости инструмента: Python 3.10+, numpy, scipy, Pillow.
"""
from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

SS = 2  # суперсэмплинг масок фигур

PALETTE = {
    "basalt": "#23282B",
    "metal_dark": "#3A4146",
    "amber": "#E8963C",
    "cyan": "#38C8DC",
    "panel_light": "#E8E4DC",
    "marking": "#E06B2D",
    "gravity": "#8B4FC4",
    "hazard": "#7A8B3D",
    "dark": "#0D0F10",
    "rubber": "#1C1E20",
    "steel": "#8E9499",
    "glass": "#14191C",
    "stripe_dark": "#1E2124",
}

EMISSION_SEMANTIC = {
    "cyan": "Игровая оптика (луч, линза, приёмник)",
    "amber": "Питание (каналы, индикаторы, заряд)",
    "gravity": "Гравитационное поле",
    "white": "Нейтральный индикатор состояния (не несёт цветовой семантики)",
}


def rgb(name_or_hex: str) -> np.ndarray:
    value = PALETTE.get(name_or_hex, name_or_hex)
    return np.array([int(value[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255.0


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# --------------------------------------------------------------------------- шум

def value_noise(w: int, h: int, fx: int, fy: int, rng: np.random.Generator) -> np.ndarray:
    """Периодический value noise: целые частоты дают бесшовный результат."""
    grid = rng.random((fy, fx)).astype(np.float32)
    out = ndimage.zoom(grid, (h / fy, w / fx), order=3, mode="grid-wrap", grid_mode=True)
    return out[:h, :w]


def fbm(w: int, h: int, base: int, octaves: int, rng: np.random.Generator,
        persistence: float = 0.5, aspect: tuple[float, float] = (1.0, 1.0)) -> np.ndarray:
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        f = base * (2 ** o)
        fx = max(1, int(round(f * aspect[0])))
        fy = max(1, int(round(f * aspect[1])))
        total += amp * value_noise(w, h, fx, fy, rng)
        norm += amp
        amp *= persistence
    total /= norm
    lo, hi = float(total.min()), float(total.max())
    return (total - lo) / max(hi - lo, 1e-6)


# --------------------------------------------------------------------------- холст

@dataclass
class Canvas:
    w: int
    h: int
    tile_x: bool = False
    tile_y: bool = False
    seed: int = 1
    height: np.ndarray = field(init=False)
    albedo: np.ndarray = field(init=False)
    rough: np.ndarray = field(init=False)
    metal: np.ndarray = field(init=False)
    emis: np.ndarray = field(init=False)
    paint_mask: np.ndarray = field(init=False)
    rng: np.random.Generator = field(init=False)

    def __post_init__(self) -> None:
        shape = (self.h, self.w)
        self.height = np.full(shape, 0.5, np.float32)
        self.albedo = np.zeros((self.h, self.w, 3), np.float32)
        self.rough = np.full(shape, 0.5, np.float32)
        self.metal = np.zeros(shape, np.float32)
        self.emis = np.zeros(shape, np.float32)
        self.paint_mask = np.zeros(shape, np.float32)
        self.rng = np.random.default_rng(self.seed)

    # --- утилиты
    @property
    def tile(self) -> bool:
        return self.tile_x or self.tile_y

    def blur(self, arr: np.ndarray, sigma: float) -> np.ndarray:
        mode = ("wrap" if self.tile_y else "nearest", "wrap" if self.tile_x else "nearest")
        if arr.ndim == 3:
            return np.stack([ndimage.gaussian_filter(arr[..., c], sigma, mode=mode) for c in range(arr.shape[2])], -1)
        return ndimage.gaussian_filter(arr, sigma, mode=mode)

    def noise(self, base: int, octaves: int = 4, persistence: float = 0.5,
              aspect: tuple[float, float] = (1.0, 1.0)) -> np.ndarray:
        return fbm(self.w, self.h, base, octaves, self.rng, persistence, aspect)

    def shape(self, draw: Callable[[ImageDraw.ImageDraw, float, float], None]) -> np.ndarray:
        """Рисует маску фигуры с суперсэмплингом; для бесшовных карт — с повтором по краям."""
        img = Image.new("L", (self.w * SS, self.h * SS), 0)
        d = ImageDraw.Draw(img)
        offs_x = (-self.w, 0, self.w) if self.tile_x else (0,)
        offs_y = (-self.h, 0, self.h) if self.tile_y else (0,)
        for oy in offs_y:
            for ox in offs_x:
                draw(d, float(ox), float(oy))
        img = img.resize((self.w, self.h), Image.LANCZOS)
        return np.asarray(img, np.float32) / 255.0

    # --- нанесение слоёв
    def fill(self, mask: np.ndarray, color: np.ndarray | None = None, *, height: float | None = None,
             height_add: float | None = None, bevel: float = 0.0, rough: float | None = None,
             metal: float | None = None, emis: float | None = None, paint: bool | None = None,
             color_var: float = 0.03, rough_var: float = 0.08) -> None:
        m = np.clip(mask, 0.0, 1.0)
        hm = m
        if bevel > 0.0:
            hm = smoothstep(0.0, 1.0, self.blur(m, bevel) * 2.0 - 0.5) * (m > 0.01)
            hm = np.maximum(hm, m * 0.0)
        if color is not None:
            var = 1.0 + (self.noise(8, 3) - 0.5) * 2.0 * color_var
            col = np.clip(color[None, None, :] * var[..., None], 0, 1)
            self.albedo = self.albedo * (1 - m[..., None]) + col * m[..., None]
        if height is not None:
            self.height = self.height * (1 - hm) + height * hm
        if height_add is not None:
            self.height = self.height + height_add * hm
        if rough is not None:
            r = np.clip(rough + (self.noise(6, 3) - 0.5) * 2.0 * rough_var, 0.05, 1.0)
            self.rough = self.rough * (1 - m) + r * m
        if metal is not None:
            self.metal = self.metal * (1 - m) + metal * m
        if emis is not None:
            self.emis = np.maximum(self.emis, emis * m)
        if paint is not None:
            self.paint_mask = self.paint_mask * (1 - m) + (1.0 if paint else 0.0) * m

    def painted(self, mask: np.ndarray, color: str, *, height: float | None = None, bevel: float = 0.0,
                rough: float = 0.55, height_add: float | None = None) -> None:
        self.fill(mask, rgb(color), height=height, height_add=height_add, bevel=bevel, rough=rough,
                  metal=0.0, paint=True)

    def rubber(self, mask: np.ndarray, *, height: float | None = None, bevel: float = 0.0) -> None:
        self.fill(mask, rgb("rubber"), height=height, bevel=bevel, rough=0.88, metal=0.0, paint=False,
                  color_var=0.06)

    def steel(self, mask: np.ndarray, *, height: float | None = None, bevel: float = 0.0, rough: float = 0.38) -> None:
        self.fill(mask, rgb("steel"), height=height, bevel=bevel, rough=rough, metal=1.0, paint=False)

    def glass(self, mask: np.ndarray, *, height: float | None = None, bevel: float = 0.0) -> None:
        self.fill(mask, rgb("glass"), height=height, bevel=bevel, rough=0.08, metal=0.0, paint=False,
                  color_var=0.02, rough_var=0.02)

    def emissive(self, mask: np.ndarray, strength: float = 1.0) -> None:
        self.emis = np.maximum(self.emis, np.clip(mask, 0, 1) * strength)

    def bolts(self, points: list[tuple[float, float]], r: float, height: float = 0.85) -> None:
        def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
            for x, y in points:
                cx, cy = (x + ox) * SS, (y + oy) * SS
                d.ellipse([cx - r * SS, cy - r * SS, cx + r * SS, cy + r * SS], fill=255)
        m = self.shape(draw)
        self.fill(m, rgb("steel") * 0.8, height=height, bevel=r * 0.5, rough=0.42, metal=1.0, paint=False)
        # шлиц
        def slot(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
            for x, y in points:
                cx, cy = (x + ox) * SS, (y + oy) * SS
                d.line([cx - r * 0.6 * SS, cy - r * 0.6 * SS, cx + r * 0.6 * SS, cy + r * 0.6 * SS],
                       fill=255, width=max(1, int(r * 0.35 * SS)))
        s = self.shape(slot) * m
        self.fill(s, rgb("dark"), height_add=-0.08)

    # --- финальная обработка
    def finish(self, *, wear: float = 0.5, grime: float = 0.5, scratches: int = 60,
               normal_strength: float = 6.0, micro: float = 0.004) -> dict[str, np.ndarray]:
        n_lo = self.noise(4, 4)
        n_hi = self.noise(32, 3)
        h = self.height + (self.noise(64, 3) - 0.5) * micro
        # потёртости рёбер: выпуклые края окрашенных поверхностей обнажают сталь
        convex = np.clip((h - self.blur(h, 3.0)) * 18.0, 0, 1)
        wear_mask = np.clip(convex * 1.6 - (1.0 - wear) - (n_hi - 0.5) * 0.9, 0, 1) * self.paint_mask
        wear_mask = smoothstep(0.25, 0.6, wear_mask)
        # царапины по окрашенным участкам
        if scratches > 0:
            def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
                rr = np.random.default_rng(self.seed + 991)
                for _ in range(scratches):
                    x0, y0 = rr.random() * self.w, rr.random() * self.h
                    ang = rr.random() * math.pi
                    ln = 8 + rr.random() * 60
                    x1, y1 = x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln
                    d.line([(x0 + ox) * SS, (y0 + oy) * SS, (x1 + ox) * SS, (y1 + oy) * SS],
                           fill=int(120 + rr.random() * 135), width=1)
            sc = self.shape(draw) * self.paint_mask * wear
            wear_mask = np.maximum(wear_mask, sc * 0.8)
        steel = rgb("steel")[None, None, :] * (0.85 + 0.25 * n_hi[..., None])
        self.albedo = self.albedo * (1 - wear_mask[..., None]) + steel * wear_mask[..., None]
        self.metal = self.metal * (1 - wear_mask) + 1.0 * wear_mask
        self.rough = self.rough * (1 - wear_mask) + 0.36 * wear_mask
        # грязь в углублениях и общая неравномерность
        cavity = np.clip((self.blur(h, 4.0) - h) * 14.0, 0, 1)
        dirt = cavity * (0.5 + 0.5 * n_lo) * grime
        self.albedo *= (1.0 - 0.45 * dirt[..., None]) * (1.0 - 0.06 * grime * n_lo[..., None])
        self.rough = np.clip(self.rough + 0.25 * dirt, 0, 1)
        # AO из высоты
        occl = np.clip((self.blur(h, 10.0) - h) * 6.0, 0, 1)
        ao = np.clip(1.0 - 0.55 * occl - 0.35 * cavity, 0.25, 1.0)
        # нормали из высоты (OpenGL: +V вверх, ось Y изображения направлена вниз)
        if self.tile_x:
            dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        else:
            dx = np.gradient(h, axis=1)
        if self.tile_y:
            dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
        else:
            dy = np.gradient(h, axis=0)
        k = normal_strength * (self.w / 512.0)
        nx, ny, nz = -dx * k, dy * k, np.ones_like(h)
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        normal = np.stack([nx / ln, ny / ln, nz / ln], -1)
        return {
            "albedo": np.clip(self.albedo, 0, 1),
            "normal": normal * 0.5 + 0.5,
            "orm": np.stack([ao, np.clip(self.rough, 0.04, 1), np.clip(self.metal, 0, 1)], -1),
            "emission": np.clip(self.emis, 0, 1),
            "height": h,
        }


# --------------------------------------------------------------------------- фигуры и пиктограммы

def rect(x0: float, y0: float, x1: float, y1: float, radius: float = 0.0):
    def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
        box = [(x0 + ox) * SS, (y0 + oy) * SS, (x1 + ox) * SS, (y1 + oy) * SS]
        if radius > 0:
            d.rounded_rectangle(box, radius=radius * SS, fill=255)
        else:
            d.rectangle(box, fill=255)
    return draw


def ellipse(cx: float, cy: float, rx: float, ry: float | None = None):
    ry = rx if ry is None else ry
    def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
        d.ellipse([(cx - rx + ox) * SS, (cy - ry + oy) * SS, (cx + rx + ox) * SS, (cy + ry + oy) * SS], fill=255)
    return draw


def poly(points: list[tuple[float, float]]):
    def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
        d.polygon([((x + ox) * SS, (y + oy) * SS) for x, y in points], fill=255)
    return draw


def lines(segments: list[tuple[float, float, float, float]], width: float):
    def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
        for x0, y0, x1, y1 in segments:
            d.line([(x0 + ox) * SS, (y0 + oy) * SS, (x1 + ox) * SS, (y1 + oy) * SS], fill=255, width=int(width * SS))
            for x, y in ((x0, y0), (x1, y1)):
                r = width * 0.5
                d.ellipse([(x - r + ox) * SS, (y - r + oy) * SS, (x + r + ox) * SS, (y + r + oy) * SS], fill=255)
    return draw


def arc(cx: float, cy: float, r: float, a0: float, a1: float, width: float):
    def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
        d.arc([(cx - r + ox) * SS, (cy - r + oy) * SS, (cx + r + ox) * SS, (cy + r + oy) * SS],
              a0, a1, fill=255, width=int(width * SS))
    return draw


def union(*draws):
    def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
        for fn in draws:
            fn(d, ox, oy)
    return draw


def radial(c: Canvas, cx: float, cy: float) -> np.ndarray:
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    return np.sqrt((xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2)


def angle(c: Canvas, cx: float, cy: float) -> np.ndarray:
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    return np.arctan2(yy + 0.5 - cy, xx + 0.5 - cx)


def ring(c: Canvas, cx: float, cy: float, r0: float, r1: float) -> np.ndarray:
    r = radial(c, cx, cy)
    return smoothstep(r0 - 0.8, r0 + 0.8, r) * (1 - smoothstep(r1 - 0.8, r1 + 0.8, r))


def disk(c: Canvas, cx: float, cy: float, r: float) -> np.ndarray:
    return 1 - smoothstep(r - 0.8, r + 0.8, radial(c, cx, cy))


def chevron(cx: float, cy: float, size: float, direction: float, thickness: float):
    """Шеврон-стрелка; direction — угол направления острия в радианах (0 — вправо)."""
    ca, sa = math.cos(direction), math.sin(direction)
    pts_local = [(-0.5, -0.6), (0.25, 0.0), (-0.5, 0.6), (-0.5 + thickness, 0.6),
                 (0.25 + thickness, 0.0), (-0.5 + thickness, -0.6)]
    pts = [(cx + (x * ca - y * sa) * size, cy + (x * sa + y * ca) * size) for x, y in pts_local]
    return poly([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5]])


def lightning(cx: float, cy: float, s: float):
    pts = [(0.15, -0.5), (-0.25, 0.05), (0.0, 0.05), (-0.15, 0.5), (0.3, -0.1), (0.05, -0.1), (0.2, -0.5)]
    return poly([(cx + x * s, cy + y * s) for x, y in pts])


SEGMENTS = {
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
    "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g",
}


def digits(text: str, x: float, y: float, h: float, stroke: float | None = None):
    """Трафаретные семисегментные цифры без шрифтов: только цифры и дефис."""
    w = h * 0.55
    t = stroke if stroke is not None else h * 0.14
    segs: list[tuple[float, float, float, float]] = []
    for i, ch in enumerate(text):
        x0 = x + i * (w + h * 0.25)
        on = SEGMENTS.get(ch, "")
        g = 0.12 * h  # трафаретные разрывы
        pos = {
            "a": (x0 + g, y, x0 + w - g, y), "g": (x0 + g, y + h / 2, x0 + w - g, y + h / 2),
            "d": (x0 + g, y + h, x0 + w - g, y + h), "f": (x0, y + g, x0, y + h / 2 - g),
            "b": (x0 + w, y + g, x0 + w, y + h / 2 - g), "e": (x0, y + h / 2 + g, x0, y + h - g),
            "c": (x0 + w, y + h / 2 + g, x0 + w, y + h - g),
        }
        segs += [pos[s] for s in on]
    return lines(segs, t)


def warning_triangle(cx: float, cy: float, s: float):
    outer = poly([(cx, cy - 0.55 * s), (cx + 0.6 * s, cy + 0.45 * s), (cx - 0.6 * s, cy + 0.45 * s)])
    return outer


# --------------------------------------------------------------------------- тайлящиеся материалы

def mat_panel_light() -> Canvas:
    c = Canvas(1024, 1024, True, True, seed=11)
    full = np.ones((c.h, c.w), np.float32)
    c.painted(full, "panel_light", height=0.5, rough=0.5)
    seams = c.shape(union(rect(-3, 0, 3, 1024), rect(0, -3, 1024, 3), rect(509, 0, 515, 1024)))
    c.fill(seams, rgb("dark"), height=0.32, bevel=1.5, rough=0.8, paint=False)
    pts = [(14, y) for y in range(40, 1024, 96)] + [(498, y) for y in range(88, 1024, 96)] + \
          [(526, y) for y in range(40, 1024, 96)] + [(x, 14) for x in range(64, 1024, 96)]
    c.bolts(pts, 5.5, height=0.62)
    dent = (c.noise(3, 3) - 0.5) * 0.04
    c.height += dent
    return c


def mat_metal_dark() -> Canvas:
    c = Canvas(1024, 1024, True, True, seed=12)
    full = np.ones((c.h, c.w), np.float32)
    c.painted(full, "metal_dark", height=0.5, rough=0.48)
    brushed = c.noise(16, 4, aspect=(0.08, 1.0))
    c.height += (brushed - 0.5) * 0.01
    c.albedo *= (0.94 + 0.12 * brushed[..., None])
    c.height += (c.noise(4, 3) - 0.5) * 0.03
    return c


def mat_hazard_stripes() -> Canvas:
    c = Canvas(1024, 1024, True, True, seed=13)
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    period = 128.0
    phase = np.mod(xx + yy, period) / period
    stripe = smoothstep(0.0, 0.01, phase) * (1 - smoothstep(0.5, 0.51, phase))
    c.painted(np.ones_like(stripe), "stripe_dark", height=0.5, rough=0.6)
    c.painted(stripe, "marking", rough=0.55)
    worn = smoothstep(0.74, 0.86, c.noise(24, 5)) * smoothstep(0.4, 0.7, c.noise(4, 2)) * 0.9
    c.fill(worn, rgb("steel") * 0.75, rough=0.42, metal=1.0, paint=False, height_add=-0.01)
    c.height += (c.noise(5, 3) - 0.5) * 0.02
    return c


def mat_rubber_ribbed() -> Canvas:
    c = Canvas(512, 512, True, True, seed=14)
    yy = np.mgrid[0:c.h, 0:c.w][0].astype(np.float32)
    rib = 0.5 + 0.5 * np.cos(yy / 32.0 * 2 * math.pi)
    c.rubber(np.ones((c.h, c.w), np.float32), height=0.5)
    c.height = 0.4 + 0.2 * smoothstep(0.2, 0.8, rib) + (c.noise(64, 2) - 0.5) * 0.01
    return c


def mat_diamond_plate() -> Canvas:
    c = Canvas(1024, 1024, True, True, seed=15)
    c.steel(np.ones((c.h, c.w), np.float32), height=0.4, rough=0.45)
    cell = 64.0
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    bumps = np.zeros_like(xx)
    for (ox, oy, ang) in ((0.0, 0.0, math.pi / 4), (cell / 2, cell / 2, -math.pi / 4)):
        u = np.mod(xx - ox, cell) - cell / 2
        v = np.mod(yy - oy, cell) - cell / 2
        ru = u * math.cos(ang) + v * math.sin(ang)
        rv = -u * math.sin(ang) + v * math.cos(ang)
        d = (ru / 20.0) ** 2 + (rv / 5.0) ** 2
        bumps = np.maximum(bumps, 1 - smoothstep(0.6, 1.0, d))
    c.height = 0.4 + 0.25 * bumps
    c.albedo *= (0.9 + 0.2 * c.noise(6, 4)[..., None])
    c.rough = np.clip(0.42 + (c.noise(10, 3) - 0.5) * 0.3 - bumps * 0.12, 0.2, 0.8)
    return c


# --------------------------------------------------------------------------- устройства

def dev_cube_face() -> Canvas:
    """Грань утилитарного куба 0,5 м. Одна текстура на все шесть граней (BoxMesh: uv1_scale 3×2)."""
    c = Canvas(512, 512, seed=21)
    S = 512.0
    full = np.ones((c.h, c.w), np.float32)
    c.painted(full, "metal_dark", height=0.8, rough=0.5)
    # фаска края куба
    edge = 1 - c.shape(rect(10, 10, S - 10, S - 10, 14))
    c.fill(edge, None, height=0.55, bevel=4)
    panel = c.shape(rect(58, 58, S - 58, S - 58, 18))
    c.painted(panel, "panel_light", height=0.55, bevel=3, rough=0.52)
    ribs = c.shape(union(lines([(70, 70, S - 70, S - 70), (S - 70, 70, 70, S - 70)], 34)))
    ribs *= panel
    c.painted(ribs, "metal_dark", height=0.72, bevel=2.5)
    # угловые маркеры
    tri = c.shape(union(poly([(70, 70), (150, 70), (70, 150)]), poly([(S - 70, 70), (S - 150, 70), (S - 70, 150)]),
                        poly([(70, S - 70), (150, S - 70), (70, S - 150)]),
                        poly([(S - 70, S - 70), (S - 150, S - 70), (S - 70, S - 150)])))
    c.painted(tri * panel * (1 - ribs), "marking", height_add=0.005)
    # ручки-углубления
    grips = c.shape(union(rect(196, 96, 316, 134, 17), rect(196, S - 134, 316, S - 96, 17)))
    c.rubber(grips, height=0.3, bevel=3)
    # центральный узел с линзой состояния
    hub = c.shape(rect(S / 2 - 76, S / 2 - 76, S / 2 + 76, S / 2 + 76, 14))
    c.painted(hub, "metal_dark", height=0.82, bevel=3)
    c.steel(ring(c, S / 2, S / 2, 48, 58), height=0.9, bevel=1.5)
    lens = disk(c, S / 2, S / 2, 48)
    c.glass(lens, height=0.62, bevel=2)
    c.emissive(disk(c, S / 2, S / 2, 40) * 0.9 + ring(c, S / 2, S / 2, 40, 47) * 0.4)
    c.bolts([(S / 2 - 62, S / 2 - 62), (S / 2 + 62, S / 2 - 62), (S / 2 - 62, S / 2 + 62), (S / 2 + 62, S / 2 + 62)], 5)
    # серийный номер на левом поле панели
    c.painted(c.shape(digits("07", 88, 238, 34, 6)) * panel, "stripe_dark", height_add=0.002)
    c.painted(c.shape(rect(S - 104, 230, S - 86, 282)) * panel, "marking")
    return c


def dev_floor_button_top() -> Canvas:
    """Верхняя плита напольной кнопки (диск, планарная развёртка сверху)."""
    c = Canvas(1024, 1024, seed=22)
    S, C = 1024.0, 512.0
    c.painted(np.ones((c.h, c.w), np.float32), "metal_dark", height=0.4)
    r = radial(c, C, C)
    plate = disk(c, C, C, 496)
    c.painted(plate, "metal_dark", height=0.7, bevel=4)
    band = ring(c, C, C, 400, 480)
    c.painted(band, "marking", height=0.72)
    a = angle(c, C, C)
    for i in range(8):
        ang = i * math.pi / 4 + math.pi / 8
        cx, cy = C + math.cos(ang) * 440, C + math.sin(ang) * 440
        ch = c.shape(chevron(cx, cy, 52, ang + math.pi, 0.32))
        c.painted(ch * band, "stripe_dark", height_add=0.002)
    # канавка и кольцо состояния
    groove = ring(c, C, C, 384, 400)
    c.fill(groove, rgb("dark"), height=0.45, rough=0.8, paint=False)
    c.glass(ring(c, C, C, 386, 398), height=0.5)
    c.emissive(ring(c, C, C, 387, 397))
    # рифлёная середина
    inner = disk(c, C, C, 384)
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    cell = 48.0
    bumps = np.zeros_like(xx)
    for (ox, oy, ang) in ((0.0, 0.0, math.pi / 4), (cell / 2, cell / 2, -math.pi / 4)):
        u = np.mod(xx - ox, cell) - cell / 2
        v = np.mod(yy - oy, cell) - cell / 2
        ru = u * math.cos(ang) + v * math.sin(ang)
        rv = -u * math.sin(ang) + v * math.cos(ang)
        bumps = np.maximum(bumps, 1 - smoothstep(0.6, 1.0, (ru / 15.0) ** 2 + (rv / 4.0) ** 2))
    c.painted(inner, "metal_dark", height=0.68)
    c.height += bumps * 0.1 * inner
    # пиктограмма «груз на плиту»: куб над плитой и стрелки вниз
    icon = c.shape(union(rect(C - 70, C - 150, C + 70, C - 10, 8), rect(C - 150, C + 70, C + 150, C + 100, 6),
                         chevron(C - 90, C + 30, 46, math.pi / 2, 0.3), chevron(C + 90, C + 30, 46, math.pi / 2, 0.3)))
    c.painted(icon * inner, "panel_light", height_add=0.004)
    # сильный износ в центре от нагрузки
    centre_wear = (1 - smoothstep(60, 330, r)) * smoothstep(0.45, 0.75, c.noise(10, 4))
    c.fill(centre_wear * inner, rgb("steel") * 0.85, rough=0.35, metal=1.0, paint=False)
    return c


def dev_wall_button_front() -> Canvas:
    """Лицевая панель настенной кнопки (0,30 × 0,45 м). Решётка — геометрия, не текстура."""
    c = Canvas(512, 768, seed=23)
    W, H = 512.0, 768.0
    c.painted(np.ones((c.h, c.w), np.float32), "panel_light", height=0.6)
    c.fill(1 - c.shape(rect(8, 8, W - 8, H - 8, 22)), None, height=0.4, bevel=4)
    stripes_l = c.shape(rect(20, 120, 64, H - 120, 6))
    stripes_r = c.shape(rect(W - 64, 120, W - 20, H - 120, 6))
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    diag = (np.mod(xx + yy, 48.0) < 24.0).astype(np.float32)
    for m in (stripes_l, stripes_r):
        c.painted(m, "stripe_dark", height=0.62)
        c.painted(m * diag, "marking", height_add=0.002)
    lamp_frame = c.shape(rect(150, 70, W - 150, 150, 16))
    c.painted(lamp_frame, "metal_dark", height=0.7, bevel=3)
    lamp = c.shape(rect(166, 84, W - 166, 136, 10))
    c.glass(lamp, height=0.6, bevel=2)
    c.emissive(c.shape(rect(172, 90, W - 172, 130, 8)))
    well = c.shape(rect(96, 210, W - 96, 600, 24))
    c.painted(well, "metal_dark", height=0.35, bevel=4)
    pad = c.shape(rect(116, 230, W - 116, 580, 18))
    c.painted(pad, "marking", height=0.55, bevel=5, rough=0.7)
    # пиктограмма нажатия: круг-мишень и стрелка внутрь
    cx, cy = W / 2, 405
    # пиктограмма нажатия: «волны» от точки касания — круг и два кольца
    icon = np.maximum(disk(c, cx, cy, 30), ring(c, cx, cy, 56, 72))
    icon = np.maximum(icon, ring(c, cx, cy, 98, 114) * 0.999)
    c.painted(icon * pad, "panel_light", height_add=0.003)
    c.painted(c.shape(digits("12", 200, 650, 54, 9)), "stripe_dark", height_add=0.002)
    c.bolts([(36, 40), (W - 36, 40), (36, H - 40), (W - 36, H - 40)], 9)
    return c


def dev_emitter_body() -> Canvas:
    """Корпус эмиттера: цилиндрическая развёртка, U — по окружности (бесшовно), V — вдоль ствола."""
    c = Canvas(1024, 256, tile_x=True, seed=24)
    c.painted(np.ones((c.h, c.w), np.float32), "metal_dark", height=0.6)
    yy = np.mgrid[0:c.h, 0:c.w][0].astype(np.float32)
    fins = (np.mod(yy, 20.0) < 10.0).astype(np.float32) * (yy > 120) * (yy < 236)
    c.height -= ndimage.gaussian_filter(fins, 1.0) * 0.12
    band = c.shape(rect(0, 28, 1024, 76))
    c.painted(band, "marking", height_add=0.004)
    for i in range(4):
        x = 128 + i * 256
        c.painted(c.shape(lightning(x, 52, 44)) * band, "stripe_dark", height_add=0.002)
    c.fill(c.shape(rect(0, 0, 1024, 14)), rgb("steel"), height=0.7, rough=0.4, metal=1.0, paint=False)
    c.bolts([(64 + i * 128, 100) for i in range(8)], 6)
    return c


def dev_emitter_lens() -> Canvas:
    """Линза эмиттера (диск 256): ирисовая диафрагма и френелевы кольца."""
    c = Canvas(256, 256, seed=25)
    C = 128.0
    c.painted(np.ones((c.h, c.w), np.float32), "metal_dark", height=0.5)
    c.steel(ring(c, C, C, 100, 124), height=0.8, bevel=2)
    a = angle(c, C, C)
    r = radial(c, C, C)
    blades = (np.mod(a + r / 40.0, 2 * math.pi / 6) < 0.9).astype(np.float32) * ring(c, C, C, 70, 100)
    c.painted(ring(c, C, C, 70, 100), "metal_dark", height=0.62)
    c.height += ndimage.gaussian_filter(blades, 1.0) * 0.05
    lens = disk(c, C, C, 70)
    c.glass(lens, height=0.55)
    fres = 0.5 + 0.5 * np.cos(r / 7.0 * 2 * math.pi)
    c.height += fres * 0.015 * lens
    c.emissive(lens * (1 - smoothstep(10, 70, r)) * 0.7 + lens * fres * 0.35 * (1 - r / 80.0))
    c.bolts([(C + math.cos(t) * 112, C + math.sin(t) * 112) for t in np.linspace(0, 2 * math.pi, 6, endpoint=False)], 4)
    return c


def dev_receiver_face() -> Canvas:
    """Лицевая плита приёмника: кольцо-мишень с сегментами попадания."""
    c = Canvas(512, 512, seed=26)
    S, C = 512.0, 256.0
    c.painted(np.ones((c.h, c.w), np.float32), "metal_dark", height=0.55)
    c.fill(1 - c.shape(rect(8, 8, S - 8, S - 8, 20)), None, height=0.4, bevel=4)
    c.painted(ring(c, C, C, 150, 206), "metal_dark", height=0.85, bevel=3)
    c.steel(ring(c, C, C, 140, 150), height=0.8)
    a = angle(c, C, C)
    seg = (np.mod(a, 2 * math.pi / 12) > 0.08).astype(np.float32)
    seg = ndimage.gaussian_filter(seg, 0.8)
    ring_glass = ring(c, C, C, 108, 140)
    c.glass(ring_glass, height=0.5)
    c.emissive(ring(c, C, C, 112, 136) * seg)
    c.glass(disk(c, C, C, 108), height=0.45)
    r = radial(c, C, C)
    c.emissive(disk(c, C, C, 16) + ring(c, C, C, 54, 58) * 0.5)
    for i in range(12):
        t = i * math.pi / 6
        x0, y0 = C + math.cos(t) * 214, C + math.sin(t) * 214
        x1, y1 = C + math.cos(t) * 238, C + math.sin(t) * 238
        c.painted(c.shape(lines([(x0, y0, x1, y1)], 8)), "marking", height_add=0.003)
    c.bolts([(30, 30), (S - 30, 30), (30, S - 30), (S - 30, S - 30)], 8)
    return c


def dev_gravity_band() -> Canvas:
    """Пояс генератора гравитации: окно поля со стрелками направления (вверх по V)."""
    c = Canvas(1024, 256, tile_x=True, seed=27)
    c.painted(np.ones((c.h, c.w), np.float32), "metal_dark", height=0.6)
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    diag = (np.mod(xx + yy, 32.0) < 16.0).astype(np.float32)
    for y0, y1 in ((8, 34), (222, 248)):
        m = c.shape(rect(0, y0, 1024, y1))
        c.painted(m, "stripe_dark", height=0.62)
        c.painted(m * diag, "marking", height_add=0.002)
    window = c.shape(rect(0, 60, 1024, 196))
    c.glass(window, height=0.45, bevel=2)
    arrows = np.zeros((c.h, c.w), np.float32)
    for i in range(8):
        x = 64 + i * 128
        arrows = np.maximum(arrows, c.shape(union(chevron(x, 110, 54, -math.pi / 2, 0.3),
                                                   chevron(x, 160, 54, -math.pi / 2, 0.3))))
    c.emissive(window * 0.25 + arrows * window)
    c.height += arrows * window * 0.03
    c.bolts([(32 + i * 64, 47) for i in range(16)] + [(32 + i * 64, 209) for i in range(16)], 5)
    return c


def dev_door_leaf() -> Canvas:
    """Створки двери камеры (обе створки, вид спереди; человеческая рама в чужой стене)."""
    c = Canvas(1024, 1024, seed=28)
    S = 1024.0
    c.painted(np.ones((c.h, c.w), np.float32), "metal_dark", height=0.6)
    seam = c.shape(rect(506, 0, 518, S))
    c.fill(seam, rgb("dark"), height=0.3, bevel=2, rough=0.8, paint=False)
    yy, xx = np.mgrid[0:c.h, 0:c.w].astype(np.float32)
    diag = (np.mod(xx + yy, 64.0) < 32.0).astype(np.float32)
    for x0, x1 in ((462, 504), (520, 562)):
        m = c.shape(rect(x0, 40, x1, S - 40))
        c.painted(m, "stripe_dark", height=0.62)
        c.painted(m * diag, "marking", height_add=0.002)
    for x0, x1 in ((40, 440), (584, 984)):
        for y0 in (60, 380, 700):
            p = c.shape(rect(x0, y0, x1, y0 + 270, 16))
            c.painted(p, "metal_dark", height=0.68, bevel=4)
    lock = disk(c, 512, 512, 92)
    c.painted(lock, "metal_dark", height=0.8, bevel=4)
    c.steel(ring(c, 512, 512, 84, 92), height=0.85)
    c.painted(c.shape(rect(496, 440, 528, 584, 6)), "marking", height_add=0.01)
    lamp = c.shape(rect(472, 380, 552, 404, 6))
    c.glass(lamp, height=0.62)
    c.emissive(c.shape(rect(478, 384, 546, 400, 4)))
    c.painted(c.shape(digits("17", 60, 6, 44, 8)), "panel_light", height_add=0.002)
    c.painted(c.shape(digits("17", 880, 6, 44, 8)), "panel_light", height_add=0.002)
    c.bolts([(x, y) for x in (24, 484, 540, 1000) for y in range(60, 1024, 120)], 6)
    return c


def dev_power_node() -> Canvas:
    """Боковая панель силового узла (~34 кг): окно заряда из восьми сегментов, номер борта 02."""
    c = Canvas(512, 256, seed=29)
    W, H = 512.0, 256.0
    c.painted(np.ones((c.h, c.w), np.float32), "panel_light", height=0.6)
    for x0, x1 in ((0, 56), (W - 56, W)):
        cap = c.shape(rect(x0, 0, x1, H))
        c.painted(cap, "metal_dark", height=0.75, bevel=3)
    for y in (40, H - 40):
        c.rubber(c.shape(rect(0, y - 9, 56, y + 9, 6)), height=0.5)
        c.rubber(c.shape(rect(W - 56, y - 9, W, y + 9, 6)), height=0.5)
    frame = c.shape(rect(90, 150, W - 90, 210, 10))
    c.painted(frame, "metal_dark", height=0.7, bevel=2)
    c.glass(c.shape(rect(100, 158, W - 100, 202, 6)), height=0.55)
    seg_w = (W - 220) / 8
    for i in range(8):
        x0 = 110 + i * seg_w
        c.emissive(c.shape(rect(x0 + 3, 164, x0 + seg_w - 3, 196, 3)))
    c.painted(c.shape(lightning(130, 80, 90)), "marking", height_add=0.003)
    c.painted(c.shape(digits("02", 300, 48, 64, 11)), "stripe_dark", height_add=0.003)
    c.painted(c.shape(rect(190, 60, 270, 104)), "marking", height_add=0.003)
    c.bolts([(76, 24), (W - 76, 24), (76, H - 24), (W - 76, H - 24)], 6)
    return c


def dev_cable() -> Canvas:
    """Силовой кабель: бесшовно по обеим осям; U — вдоль кабеля, V — по окружности."""
    c = Canvas(256, 64, True, True, seed=30)
    c.rubber(np.ones((c.h, c.w), np.float32), height=0.5)
    xx = np.mgrid[0:c.h, 0:c.w][1].astype(np.float32)
    c.height = 0.5 + 0.06 * (0.5 + 0.5 * np.cos(xx / 16.0 * 2 * math.pi))
    stripe = c.shape(rect(0, 26, 256, 38))
    c.glass(stripe, height=0.48)
    c.emissive(c.shape(rect(0, 28, 256, 36)))
    return c


LOGIC_SYMBOLS = ("relay", "and", "or", "not", "delay", "latch")


def logic_symbol(kind: str, cx: float, cy: float, s: float):
    if kind == "and":
        def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
            w = s * 0.08
            box = [(cx - s * 0.45 + ox) * SS, (cy - s * 0.35 + oy) * SS, (cx + s * 0.3 + ox) * SS, (cy + s * 0.35 + oy) * SS]
            d.line([box[0], box[1], (cx + ox) * SS, box[1]], fill=255, width=int(w * SS))
            d.line([box[0], box[3], (cx + ox) * SS, box[3]], fill=255, width=int(w * SS))
            d.line([box[0], box[1], box[0], box[3]], fill=255, width=int(w * SS))
            d.arc([(cx - s * 0.35 + ox) * SS, box[1], (cx + s * 0.35 + ox) * SS, box[3]], 270, 90, fill=255, width=int(w * SS))
        return union(draw, lines([(cx - s * 0.65, cy - s * 0.18, cx - s * 0.45, cy - s * 0.18),
                                  (cx - s * 0.65, cy + s * 0.18, cx - s * 0.45, cy + s * 0.18),
                                  (cx + s * 0.35, cy, cx + s * 0.6, cy)], s * 0.08))
    if kind == "or":
        def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
            w = int(s * 0.08 * SS)
            d.arc([(cx - s * 0.75 + ox) * SS, (cy - s * 0.35 + oy) * SS, (cx - s * 0.25 + ox) * SS, (cy + s * 0.35 + oy) * SS], 300, 60, fill=255, width=w)
            d.arc([(cx - s * 1.0 + ox) * SS, (cy - s * 0.35 + oy) * SS, (cx + s * 0.35 + ox) * SS, (cy + s * 1.05 + oy) * SS], 270, 330, fill=255, width=w)
            d.arc([(cx - s * 1.0 + ox) * SS, (cy - s * 1.05 + oy) * SS, (cx + s * 0.35 + ox) * SS, (cy + s * 0.35 + oy) * SS], 30, 90, fill=255, width=w)
        return union(draw, lines([(cx - s * 0.65, cy - s * 0.18, cx - s * 0.33, cy - s * 0.18),
                                  (cx - s * 0.65, cy + s * 0.18, cx - s * 0.33, cy + s * 0.18),
                                  (cx + s * 0.3, cy, cx + s * 0.6, cy)], s * 0.08))
    if kind == "not":
        def draw(d: ImageDraw.ImageDraw, ox: float, oy: float) -> None:
            w = int(s * 0.08 * SS)
            pts = [(cx - s * 0.4, cy - s * 0.35), (cx + s * 0.25, cy), (cx - s * 0.4, cy + s * 0.35), (cx - s * 0.4, cy - s * 0.35)]
            d.line([((x + ox) * SS, (y + oy) * SS) for x, y in pts], fill=255, width=w, joint="curve")
            r = s * 0.08
            d.ellipse([(cx + s * 0.25 + ox) * SS, (cy - r + oy) * SS, (cx + s * 0.25 + 2 * r + ox) * SS, (cy + r + oy) * SS], outline=255, width=max(1, w // 2))
        return union(draw, lines([(cx - s * 0.65, cy, cx - s * 0.4, cy), (cx + s * 0.42, cy, cx + s * 0.62, cy)], s * 0.08))
    if kind == "delay":
        return union(lines([(cx - s * 0.3, cy - s * 0.4, cx + s * 0.3, cy - s * 0.4), (cx - s * 0.3, cy + s * 0.4, cx + s * 0.3, cy + s * 0.4),
                            (cx - s * 0.22, cy - s * 0.4, cx + s * 0.22, cy + s * 0.4), (cx + s * 0.22, cy - s * 0.4, cx - s * 0.22, cy + s * 0.4)], s * 0.08),
                     poly([(cx - s * 0.12, cy + s * 0.36), (cx + s * 0.12, cy + s * 0.36), (cx, cy + s * 0.2)]))
    if kind == "latch":
        return union(rect(cx - s * 0.3, cy - s * 0.05, cx + s * 0.3, cy + s * 0.4, s * 0.05),
                     arc(cx, cy - s * 0.12, s * 0.2, 180, 360, s * 0.08),
                     lines([(cx - s * 0.2, cy - s * 0.12, cx - s * 0.2, cy - s * 0.02), (cx + s * 0.2, cy - s * 0.12, cx + s * 0.2, cy - s * 0.02)], s * 0.08))
    # relay — простое реле: катушка и контакт
    return union(rect(cx - s * 0.35, cy - s * 0.2, cx + s * 0.35, cy + s * 0.2, s * 0.04),
                 lines([(cx - s * 0.6, cy, cx - s * 0.35, cy), (cx + s * 0.35, cy, cx + s * 0.6, cy)], s * 0.08))


def dev_junction_box(kind: str) -> Callable[[], Canvas]:
    def build() -> Canvas:
        c = Canvas(512, 512, seed=31 + LOGIC_SYMBOLS.index(kind))
        S = 512.0
        c.painted(np.ones((c.h, c.w), np.float32), "metal_dark", height=0.6)
        c.fill(1 - c.shape(rect(10, 10, S - 10, S - 10, 18)), None, height=0.42, bevel=4)
        plate = c.shape(rect(70, 110, S - 70, 360, 14))
        c.painted(plate, "panel_light", height=0.66, bevel=3)
        sym = c.shape(logic_symbol(kind, S / 2, 235, 230))
        c.painted(sym * plate, "stripe_dark", height_add=0.003)
        for i, x in enumerate((140, 213, 299, 372)):
            c.painted(disk(c, x, 420, 20), "metal_dark", height=0.75, bevel=2)
            c.glass(disk(c, x, 420, 13), height=0.6)
            c.emissive(disk(c, x, 420, 11))
        c.painted(c.shape(digits("4", 452, 30, 40, 7)), "marking", height_add=0.002)
        c.painted(c.shape(lightning(60, 50, 60)), "marking", height_add=0.002)
        c.bolts([(32, 32), (S - 32, S - 32), (32, S - 32), (S - 32, 32)], 8)
        return c
    return build


@dataclass(frozen=True)
class Asset:
    name: str
    group: str
    build: Callable[[], Canvas]
    emission: str | None
    usage: str


ASSETS: list[Asset] = [
    Asset("panel_light", "surfaces", mat_panel_light, None, "Тайлящийся светлый окрашенный металл человеческого слоя, 1 м на тайл"),
    Asset("metal_dark", "surfaces", mat_metal_dark, None, "Тайлящийся тёмный окрашенный металл, 1 м на тайл"),
    Asset("hazard_stripes", "surfaces", mat_hazard_stripes, None, "Тайлящиеся предупредительные полосы (юбка напольной кнопки, кромки платформ)"),
    Asset("rubber_ribbed", "surfaces", mat_rubber_ribbed, None, "Тайлящаяся рифлёная резина (накладки, ручки), 0,5 м на тайл"),
    Asset("diamond_plate", "surfaces", mat_diamond_plate, None, "Тайлящийся рифлёный стальной настил платформ, 1 м на тайл"),
    Asset("cube_face", "devices", dev_cube_face, "white", "Грань куба 0,5 м; одна карта на шесть граней (BoxMesh: uv1_scale = (3, 2, 1))"),
    Asset("floor_button_top", "devices", dev_floor_button_top, "amber", "Верх напольной кнопки, планарная развёртка диска; кольцо горит при активном сигнале"),
    Asset("wall_button_front", "devices", dev_wall_button_front, "amber", "Лицевая панель настенной кнопки 0,30 × 0,45 м; лампа — состояние выхода"),
    Asset("emitter_body", "devices", dev_emitter_body, None, "Ствол эмиттера, цилиндрическая развёртка (U по окружности бесшовно)"),
    Asset("emitter_lens", "devices", dev_emitter_lens, "cyan", "Торцевая линза эмиттера, планарный диск"),
    Asset("receiver_face", "devices", dev_receiver_face, "cyan", "Лицевая плита приёмника; 12 сегментов кольца для индикации попадания"),
    Asset("gravity_band", "devices", dev_gravity_band, "gravity", "Пояс генератора поля; стрелки указывают направление поля вдоль +V"),
    Asset("door_leaf", "devices", dev_door_leaf, "amber", "Створки двери камеры (вид спереди, обе створки); лампа — питание замка"),
    Asset("power_node_side", "devices", dev_power_node, "amber", "Боковая панель силового узла HEVS-02; 8 сегментов заряда"),
    Asset("cable", "devices", dev_cable, "amber", "Силовой кабель, бесшовный; U вдоль кабеля; полоса горит под питанием"),
] + [
    Asset(f"junction_{k}", "devices", dev_junction_box(k), "amber",
          f"Распределительная коробка цепи: {label}; 4 индикатора входов/выхода")
    for k, label in (("relay", "реле"), ("and", "логическое И"), ("or", "логическое ИЛИ"), ("not", "логическое НЕ"),
                     ("delay", "задержка"), ("latch", "защёлка"))
]


# --------------------------------------------------------------------------- вывод

def to_u8(arr: np.ndarray) -> np.ndarray:
    return (np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8)


def save_maps(asset: Asset, maps: dict[str, np.ndarray], out_dir: Path) -> list[str]:
    target = out_dir / asset.group / asset.name
    target.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    for key in ("albedo", "normal", "orm"):
        path = target / f"{asset.name}_{key}.png"
        Image.fromarray(to_u8(maps[key]), "RGB").save(path, optimize=True)
        written.append(path.name)
    if asset.emission is not None and float(maps["emission"].max()) > 0.0:
        path = target / f"{asset.name}_emission.png"
        Image.fromarray(to_u8(maps["emission"]), "L").save(path, optimize=True)
        written.append(path.name)
    return written


EMISSION_PREVIEW = {"cyan": rgb("cyan"), "amber": rgb("amber"), "gravity": rgb("gravity"), "white": np.array([0.92, 0.95, 1.0], np.float32)}


def shade(maps: dict[str, np.ndarray], emission: str | None) -> np.ndarray:
    """Упрощённый PBR-просмотр: направленный свет сверху-слева, без IBL."""
    alb = maps["albedo"] ** 2.2
    n = maps["normal"] * 2.0 - 1.0
    ao, rough, metal = maps["orm"][..., 0], maps["orm"][..., 1], maps["orm"][..., 2]
    light = np.array([-0.45, 0.55, 0.7], np.float32)
    light /= np.linalg.norm(light)
    ndl = np.clip((n * light).sum(-1), 0, 1)
    half = light + np.array([0, 0, 1], np.float32)
    half /= np.linalg.norm(half)
    ndh = np.clip((n * half).sum(-1), 0, 1)
    power = np.clip(2.0 / np.maximum(rough ** 4, 1e-3) - 2.0, 1, 2048)
    spec = ndh ** power * (power + 8) / 25.0
    f0 = 0.04 * (1 - metal[..., None]) + alb * metal[..., None]
    diffuse = alb * (1 - metal[..., None]) * (0.18 + 0.95 * ndl[..., None])
    col = (diffuse + f0 * spec[..., None] * ndl[..., None] + alb * metal[..., None] * 0.12) * ao[..., None]
    if emission is not None:
        col += maps["emission"][..., None] * EMISSION_PREVIEW[emission][None, None, :] ** 2.2 * 2.2
    col = col / (1 + col)  # Reinhard
    return np.clip(col ** (1 / 2.2) * 1.15, 0, 1)


def preview_font(size: int) -> ImageFont.ImageFont:
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/arial.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def contact_sheet(rows: list[tuple[Asset, dict[str, np.ndarray]]], path: Path, title: str) -> None:
    cell = 256
    label_h = 26
    cols = ["просмотр", "albedo", "normal", "orm", "emission"]
    width = cell * len(cols) + 300
    height = 70 + len(rows) * (cell + label_h + 10)
    sheet = Image.new("RGB", (width, height), (24, 26, 28))
    d = ImageDraw.Draw(sheet)
    f_big, f = preview_font(24), preview_font(15)
    d.text((16, 16), title, fill=(232, 228, 220), font=f_big)
    for i, (asset, maps) in enumerate(rows):
        y = 70 + i * (cell + label_h + 10)
        imgs = [shade(maps, asset.emission), maps["albedo"], maps["normal"], maps["orm"],
                np.repeat(maps["emission"][..., None], 3, -1)]
        for j, img in enumerate(imgs):
            pil = Image.fromarray(to_u8(img))
            pil.thumbnail((cell, cell), Image.LANCZOS)
            sheet.paste(pil, (300 + j * cell + (cell - pil.width) // 2, y + label_h + (cell - pil.height) // 2))
            if i == 0:
                d.text((300 + j * cell + 6, 44), cols[j], fill=(150, 155, 160), font=f)
        d.text((16, y + label_h), asset.name, fill=(232, 228, 220), font=f_big)
        sem = EMISSION_SEMANTIC.get(asset.emission or "", "без свечения")
        d.text((16, y + label_h + 34), f"{maps['albedo'].shape[1]}×{maps['albedo'].shape[0]}", fill=(150, 155, 160), font=f)
        words, line, ty = sem.split(), "", y + label_h + 58
        for w in words:
            if len(line) + len(w) > 30:
                d.text((16, ty), line, fill=(200, 150, 90), font=f)
                line, ty = w, ty + 20
            else:
                line = f"{line} {w}".strip()
        d.text((16, ty), line, fill=(200, 150, 90), font=f)
    sheet.save(path, optimize=True)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="content/textures", type=Path)
    ap.add_argument("--preview", default=None, type=Path, help="папка для листов предпросмотра (не для игры)")
    ap.add_argument("--only", nargs="*", default=None, help="имена ассетов")
    args = ap.parse_args()
    manifest: list[dict[str, object]] = []
    rows: dict[str, list[tuple[Asset, dict[str, np.ndarray]]]] = {"surfaces": [], "devices": []}
    for asset in ASSETS:
        if args.only and asset.name not in args.only:
            continue
        canvas = asset.build()
        maps = canvas.finish(wear=0.55 if asset.group == "devices" else 0.35,
                             grime=0.55, scratches=50 if asset.group == "devices" else 120)
        files = save_maps(asset, maps, args.out)
        manifest.append({"name": asset.name, "group": asset.group, "size": [canvas.w, canvas.h],
                         "tile": [canvas.tile_x, canvas.tile_y], "emission": asset.emission,
                         "files": files, "usage": asset.usage})
        rows[asset.group].append((asset, maps))
        print(f"{asset.group}/{asset.name}: {', '.join(files)}")
    manifest_path = args.out / "textures_manifest.json"
    if args.only and manifest_path.exists():
        # Частичная пересборка не должна терять записи остальных ассетов: обновляем только выбранные.
        fresh = {str(entry["name"]): entry for entry in manifest}
        previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        merged = [fresh.pop(str(entry["name"]), entry) for entry in previous]
        manifest = merged + list(fresh.values())
    order = {asset.name: i for i, asset in enumerate(ASSETS)}
    manifest.sort(key=lambda entry: order.get(str(entry["name"]), len(order)))
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.preview is not None:
        args.preview.mkdir(parents=True, exist_ok=True)
        for group, items in rows.items():
            if items:
                contact_sheet(items, args.preview / f"{group}.png", f"Abandoned · процедурные текстуры · {group}")


if __name__ == "__main__":
    main()
