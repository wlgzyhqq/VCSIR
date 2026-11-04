"""Pick demo frames that actually contain detections, then pack them as RGB565.

Candidates are decoded from each clip at a few frames per second, run through the
same INT8 quantized graph the board executes, and kept only when the detector
finds something. Survivors are played back in temporal order.
"""
import argparse, json, zlib, hashlib, sys
from pathlib import Path
import numpy as np
import cv2

R = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(R / "tools"))
from net_input import board_input_int8  # noqa: E402
from yolo_quantize import Quant, Graph, torch, non_max_suppression  # noqa: E402

CLIPS = [
    ("store-aisle-detection.mp4", "STORE"),
    ("head-pose-face-detection-male.mp4", "PEOPLE2"),
    ("car-detection.mp4", "CARS"),
    ("worker-zone-detection.mp4", "WORKERS"),
    ("face-demographics-walking.mp4", "WALK"),
    ("people-detection.mp4", "PEOPLE"),
    ("one-by-one-person-detection.mp4", "CORRIDOR"),
    ("bottle-detection.mp4", "BOTTLES"),
]
SIZE = 320
PAD = 114


def letterbox(img, size=SIZE):
    h, w = img.shape[:2]
    ratio = min(size / h, size / w)
    nh, nw = int(round(h * ratio)), int(round(w * ratio))
    resized = cv2.resize(img, (nw, nh), interpolation=cv2.INTER_LINEAR)
    out = np.full((size, size, 3), PAD, dtype=np.uint8)
    top, left = (size - nh) // 2, (size - nw) // 2
    out[top:top + nh, left:left + nw] = resized
    return out


def to_rgb565(rgb):
    a = rgb.astype(np.uint16)
    return ((a[:, :, 0] >> 3) << 11) | ((a[:, :, 1] >> 2) << 5) | (a[:, :, 2] >> 3)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidate-fps", type=float, default=3.0)
    ap.add_argument("--per-clip", type=int, default=40)
    ap.add_argument("--out", default="assets/video")
    a = ap.parse_args()

    ref = R / "model/reference"
    g = json.loads((ref / "graph.json").read_text())
    cal = json.loads((ref / "calibration.json").read_text())
    fw = dict(np.load(ref / "float_weights.npz"))
    q = Quant(g, cal, fw)
    decode = object.__new__(Graph)
    decode.heads, decode.detect = g["heads"], g["detect"]

    out = R / a.out
    out.mkdir(parents=True, exist_ok=True)
    blob = bytearray()
    frames = []
    for name, label in CLIPS:
        path = R / "assets" / "video-src" / name
        if not path.exists():
            continue
        cap = cv2.VideoCapture(str(path))
        if not cap.isOpened():
            print("cannot open", name)
            continue
        src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        step = max(1, int(round(src_fps / a.candidate_fps)))
        kept, seen, idx = [], 0, 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if idx % step == 0:
                seen += 1
                rgb = letterbox(frame)
                packed = to_rgb565(rgb)
                x = torch.from_numpy(board_input_int8(packed).astype(np.float32) / 127.0).unsqueeze(0)
                values, _ = q.run(x)
                det = non_max_suppression(
                    decode.decode({h: torch.from_numpy(values[h]).float() / 1024 for h in g["heads"]}),
                    .25, .45, max_det=100)[0].numpy()
                if len(det) >= 1:
                    kept.append((idx, len(det), packed, round(idx / src_fps, 2)))
            idx += 1
        cap.release()
        kept.sort(key=lambda t: t[0])
        chosen = kept[:a.per_clip]
        print(f"{name}: {seen} candidates, {len(kept)} with >=2 boxes, keeping {len(chosen)}")
        for _, count, packed, secs in chosen:
            blob += packed.astype("<u2").tobytes()
            frames.append(dict(index=len(frames), clip=label, source=name, source_seconds=secs,
                               boxes=count, crc32=f"{zlib.crc32(packed.tobytes()):08x}"))
    p = out / "frames.rgb565"
    p.write_bytes(bytes(blob))
    meta = dict(size=SIZE, format="RGB565 LE letterboxed 320x320",
                frame_bytes=SIZE * SIZE * 2, frame_count=len(frames), fps=a.candidate_fps,
                clips=[c[1] for c in CLIPS], frames=frames,
                bytes=len(blob), sha256=hashlib.sha256(bytes(blob)).hexdigest())
    (out / "manifest.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(f"wrote {len(frames)} frames, {len(blob)/1e6:.1f} MB, playback {len(frames)/1.46:.0f}s")


if __name__ == "__main__":
    main()
