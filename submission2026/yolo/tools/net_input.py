"""Board-identical RGB565 320x320 -> INT8 160x160x3 (CHW) conversion.

Must match firmware/yolo_preprocess.c exactly: expand 5/6-bit components by bit
replication, average each 2x2 block with (a+b+c+d+2)>>2, then round(v*127/255).
"""
import numpy as np
SIZE = 160

def expand(packed):
    p = packed
    r = ((p >> 11) & 31); g = ((p >> 5) & 63); b = (p & 31)
    rgb = np.stack([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)], -1)
    return rgb.astype(np.uint16)

def downsample(rgb):
    a = rgb.astype(np.uint16)
    s = a[0::2, 0::2] + a[0::2, 1::2] + a[1::2, 0::2] + a[1::2, 1::2]
    return ((s + 2) >> 2).astype(np.uint8)

def to_int8(rgb):
    v = rgb.astype(np.int32)
    return np.rint(v * 127.0 / 255.0).astype(np.int8)

def board_input_int8(packed320):
    """packed320: (320,320) uint16 RGB565 -> (3,160,160) int8 CHW."""
    rgb = downsample(expand(packed320))
    y = to_int8(rgb)
    return np.ascontiguousarray(y.transpose(2, 0, 1))
