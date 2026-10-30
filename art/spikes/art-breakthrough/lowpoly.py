"""Faceted low-poly (Teyvat-style) triangulation -> 1 Miliastra triangle image per facet.
Each arbitrary triangle = library triangle 100003 (isosceles template) + size + rotZ + ONE of rotX/rotY
(single-axis orthographic squash; device-observed per simulator ROTXY2 note). Reuse: Delaunay (scipy), Sobel edges.
usage: lowpoly.py src.png out.json N [--alpha] [--width 340]"""
import sys, json, math, numpy as np
from PIL import Image, ImageFilter
from scipy.spatial import Delaunay
src, out, N = sys.argv[1], sys.argv[2], int(sys.argv[3])
use_alpha = '--alpha' in sys.argv
width = int(sys.argv[sys.argv.index('--width') + 1]) if '--width' in sys.argv else 340
crop = sys.argv[sys.argv.index('--crop') + 1] if '--crop' in sys.argv else None
im = Image.open(src).convert('RGBA')
if crop: im = im.crop(tuple(int(v) for v in crop.split(',')))
H0 = round(im.height * width / im.width); im = im.resize((width, H0), Image.LANCZOS)
rgb = np.asarray(im.convert('RGB'), dtype=np.float32); A = np.asarray(im)[..., 3].astype(np.float32) / 255
g = np.asarray(im.convert('L').filter(ImageFilter.GaussianBlur(1.0)), dtype=np.float32)
gx = np.abs(np.diff(g, axis=1, prepend=g[:, :1])); gy = np.abs(np.diff(g, axis=0, prepend=g[:1]))
e = (gx + gy); 
if use_alpha: e = e * (A > 0.05) + 40 * (np.abs(np.diff(A, axis=1, prepend=A[:, :1])) > 0.2)
# importance: edges + face region boost (upper third) handled by edge density itself
rng = np.random.default_rng(7)
w = (e ** float(sys.argv[sys.argv.index("--gamma") + 1] if "--gamma" in sys.argv else 1.2) + 2.0); 
if use_alpha: w = w * (A > 0.05)
if '--boost' in sys.argv:
    x0, y0, x1, y1, f = [float(v) for v in sys.argv[sys.argv.index('--boost') + 1].split(',')]
    w[int(y0 * H0):int(y1 * H0), int(x0 * width):int(x1 * width)] *= f
p = (w / w.sum()).ravel()
idx = rng.choice(p.size, size=int(N * (0.6 if "--gamma" in sys.argv else 0.42)), replace=False, p=p)
pts = np.stack([idx % width, idx // width], 1).astype(float)
# sparse uniform + border points
gu = rng.uniform([0, 0], [width - 1, H0 - 1], size=(int(N * 0.08), 2))
if use_alpha: gu = gu[A[gu[:, 1].astype(int), gu[:, 0].astype(int)] > 0.05]
b = [[x, y] for x in np.linspace(0, width - 1, 12) for y in (0, H0 - 1)] + [[x, y] for y in np.linspace(0, H0 - 1, 16) for x in (0, width - 1)]
pts = np.concatenate([pts, gu, np.array(b)])
tri = Delaunay(pts)

from PIL import ImageDraw
lab = Image.new('I', (width, H0), -1); d = ImageDraw.Draw(lab)
S = tri.simplices
for i, t in enumerate(S): d.polygon([tuple(pts[j]) for j in t], fill=i)
L = np.asarray(lab).ravel(); ok = L >= 0
cnt = np.bincount(L[ok], minlength=len(S)).astype(float)
col = np.stack([np.bincount(L[ok], weights=rgb.reshape(-1, 3)[ok, c] * A.ravel()[ok], minlength=len(S)) for c in range(3)], 1)
asum = np.bincount(L[ok], weights=A.ravel()[ok], minlength=len(S))
cov = asum / np.maximum(cnt, 1)
col = col / np.maximum(asum, 1e-6)[:, None]
# Teyvat-style grade: lift saturation & contrast slightly
if "--grade" in sys.argv:
    mu = col.mean(1, keepdims=True); col = mu + (col - mu) * 1.2; col = (col - 128) * 1.06 + 130

def solve(P0, P1, P2):
    M = (P1 + P2) / 2; c1 = P2 - P1; c2 = P0 - M; C = (P0 + M) / 2
    best = None
    for axis in ('x', 'y'):
        p_, q_ = c1; r_, s_ = c2
        if axis == 'x': num, den = -(q_ * s_), (p_ * r_)
        else: num, den = -(p_ * r_), (q_ * s_)
        if abs(p_ * r_ + q_ * s_) < 1e-9: k2 = 1.0
        elif abs(den) < 1e-12: continue
        else: k2 = num / den
        if not (0 < k2 <= 1.0000001): continue
        for k in (math.sqrt(min(k2, 1)), -math.sqrt(min(k2, 1))):
            D = np.array([1, 1 / k]) if axis == 'x' else np.array([1 / k, 1])
            b1, b2 = c1 * D, c2 * D
            W = math.hypot(*b1); th = math.atan2(b1[1], b1[0])
            Hh = b2 @ np.array([-math.sin(th), math.cos(th)])
            if Hh <= 0: continue
            ang = math.degrees(math.acos(max(-1, min(1, k))))
            cand = dict(cx=C[0], cy=C[1], w=W, h=Hh, rz=math.degrees(th), rx=ang if axis == 'x' else 0, ry=ang if axis == 'y' else 0)
            score = ang
            if best is None or score < best[0]: best = (score, cand)
    return best[1] if best else None

from scipy.optimize import least_squares
def Lmat(rx, ry, rz, W, H):
    cs, sn, cX, sX, cY, sY = math.cos(rz), math.sin(rz), math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry)
    return np.array([[cY*cs + sY*sX*sn, -cY*sn + sY*sX*cs], [cX*sn, cX*cs]]) @ np.diag([W, H])
def solve_mixed(P0, P1, P2):
    M = (P1 + P2) / 2; c1 = P2 - P1; c2 = P0 - M; C = (P0 + M) / 2
    T = np.stack([c1, c2], 1)
    best = None
    for x0 in ([0.5, 0.5, math.atan2(c1[1], c1[0]), np.linalg.norm(c1), np.linalg.norm(c2)], [-0.5, 0.5, math.atan2(c1[1], c1[0]), np.linalg.norm(c1), np.linalg.norm(c2)]):
        r = least_squares(lambda v: (Lmat(*v) - T).ravel(), x0, bounds=([-3.1, -3.1, -7, 0.1, 0.1], [3.1, 3.1, 7, 2000, 2000]))
        if r.cost < 1e-6 and (best is None or r.cost < best.cost): best = r
    if best is None: return None
    rx, ry, rz, W, Hh = best.x
    return dict(cx=C[0], cy=C[1], w=W, h=Hh, rz=math.degrees(rz), rx=math.degrees(rx), ry=math.degrees(ry), mixed=1)

tris, fails = [], 0
for i, t in enumerate(S):
    if cov[i] < (0.5 if use_alpha else -1) or cnt[i] == 0: continue
    P = pts[t].copy(); cen = P.mean(0); P = cen + (P - cen) * 1.0 + np.sign(P - cen) * 1.1  # seam overlap
    P[:, 1] = H0 - P[:, 1]  # to y-up
    def place(P, depth=0):
        global fails
        for a in range(3):
            P0, P1, P2 = P[a], P[(a + 1) % 3], P[(a + 2) % 3]
            sol = solve(P0, P1, P2) or solve(P0, P2, P1)
            if sol:
                sol['c'] = '#%02x%02x%02x' % tuple(int(v) for v in np.clip(col[i], 0, 255))
                tris.append({k: (round(v, 2) if isinstance(v, float) else v) for k, v in sol.items()}); return
        if depth >= 1:
            sol = solve_mixed(P[0], P[1], P[2])
            if sol:
                sol['c'] = '#%02x%02x%02x' % tuple(int(v) for v in np.clip(col[i], 0, 255)); tris.append({k: (round(v, 2) if isinstance(v, float) else v) for k, v in sol.items()}); return
            fails += 1; return
        L2 = [np.sum((P[(j + 1) % 3] - P[(j + 2) % 3]) ** 2) for j in range(3)]; j = int(np.argmax(L2))
        m = (P[(j + 1) % 3] + P[(j + 2) % 3]) / 2
        place(np.array([P[j], P[(j + 1) % 3], m]), depth + 1); place(np.array([P[j], m, P[(j + 2) % 3]]), depth + 1)
    place(P)
json.dump({'W': width, 'H': H0, 'tris': tris}, open(out, 'w'))
print('mixed', sum(1 for t in tris if t.get('mixed')), 'tris', len(tris), 'unsolved', fails, 'delaunay', len(S))
