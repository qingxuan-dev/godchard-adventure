import json, os, shutil
from collections import deque
from PIL import Image, ImageFilter, ImageOps

CS = ":" + "/" + "/"
NL = chr(10)

def write_imp(dst_imp, res_src, uid_tag, ctex_name):
    u = "uid" + CS + uid_tag
    p = "res" + CS + ".godot/imported/" + ctex_name
    lines = [
        "[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', f'uid="{u}"',
        f'path="{p}"', 'metadata={', '"vram_texture": false', '}', "",
        "[deps]", "", f'source_file="{res_src}"', f'dest_files=["{p}"]', "",
        "[params]", "", "compress/mode=0", "compress/high_quality=false", "compress/lossy_quality=0.7",
        "compress/hdr_compression=1", "compress/normal_map=0", "compress/channel_pack=0",
        "mipmaps/generate=false", "mipmaps/limit=-1", "roughness/mode=0", 'roughness/src_normal=""',
        "process/fix_alpha_border=true", "process/premult_alpha=false", "process/normal_map_invert_y=false",
        "process/hdr_as_srgb=false", "process/hdr_clamp_exposure=false", "process/size_limit=0",
        "detect_3d/compress_to=0", ""
    ]
    open(dst_imp, "w", encoding="utf-8").write(NL.join(lines))

def restore_png(fp, pad_r, k_sz, fill_rgb):
    im = Image.open(fp).convert("RGBA")
    w, h = im.size
    if w < 12 or h < 12:
        return
    px = im.load()
    if pad_r > 0:
        for y in range(h):
            if px[w - 1, y][3] > 0 and px[w - 2, y][3] == 0:
                px[w - 1, y] = (0, 0, 0, 0)
        a_pad = Image.new("L", (w + pad_r * 2, h + pad_r * 2), 0)
        a_pad.paste(im.getchannel("A").point(lambda p: 255 if p >= 110 else 0), (pad_r, pad_r))
        closed = a_pad.filter(ImageFilter.MaxFilter(k_sz)).filter(ImageFilter.MinFilter(k_sz)).crop((pad_r, pad_r, pad_r + w, pad_r + h))
    else:
        closed = im.getchannel("A").point(lambda p: 255 if p >= 100 else 0).filter(ImageFilter.MaxFilter(k_sz)).filter(ImageFilter.MinFilter(k_sz))
    c_px = closed.load()
    ext = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if c_px[x, y] <= 127 and not ext[y * w + x]:
                ext[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if c_px[x, y] <= 127 and not ext[y * w + x]:
                ext[y * w + x] = 1
                q.append((x, y))
    while q:
        cx, cy = q.popleft()
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and not ext[ny * w + nx] and c_px[nx, ny] <= 127:
                ext[ny * w + nx] = 1
                q.append((nx, ny))
    for y in range(h):
        ro = y * w
        for x in range(w):
            r, g, b, a = px[x, y]
            if ext[ro + x] and a < 180:
                px[x, y] = (0, 0, 0, 0)
            elif pad_r > 0 and a < 140:
                px[x, y] = (fill_rgb[0], fill_rgb[1], fill_rgb[2], 255)
            elif not ext[ro + x]:
                if a == 0 and (r < 8 and g < 8 and b < 8 or (g > r + 40 and g > b + 40)):
                    px[x, y] = (fill_rgb[0], fill_rgb[1], fill_rgb[2], 255)
                elif a < 255:
                    px[x, y] = (r, g, b, 255)
    im.save(fp, "PNG")

def apply_v352():
    g4 = "godot4-edition"
    vp = "v33_godot4_project"
    for sub in ["scenes", "scripts"]:
        shutil.rmtree(os.path.join(vp, sub), ignore_errors=True)
        shutil.copytree(os.path.join(g4, sub), os.path.join(vp, sub))
    shutil.copyfile(os.path.join(g4, "project.godot"), os.path.join(vp, "project.godot"))

    adir = os.path.join(vp, "assets")
    ddir = os.path.join(vp, "data")
    heavy = {
        "pipe.png": (15, 58, 38),
        "cloud_safe.png": (250, 253, 255),
        "cloud_dark_safe.png": (238, 246, 252),
        "cloud_knife.png": (250, 253, 255),
        "cloud_poison.png": (92, 42, 128),
    }
    for fn, col in heavy.items():
        if os.path.isfile(os.path.join(adir, fn)):
            restore_png(os.path.join(adir, fn), 8, 13, col)
    skip = set(heavy.keys()) | {"ui_btn_gold.png", "ui_btn_layer_touch.png"}
    for fn in sorted(os.listdir(adir)):
        if fn.endswith(".png") and fn not in skip and not fn.startswith(("s3_bg_", "bg_")):
            restore_png(os.path.join(adir, fn), 0, 5, (14, 20, 40))

    bgs = ["cyber_skyline_bg", "bg_s2_signal", "bg_s2_mecha", "bg_s2_fracture", "bg_s2_chrono", "bg_s2_root", "s3_bg_ch11", "s3_bg_ch12", "s3_bg_ch13", "s3_bg_ch14", "s3_bg_ch15"]
    for st in bgs:
        sp = os.path.join(adir, st + ".jpg")
        if not os.path.isfile(sp):
            sp = os.path.join(adir, st + ".png")
        ims = Image.open(sp).convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
        wd = Image.new("RGB", (1920, 540))
        wd.paste(ims, (0, 0))
        wd.paste(ImageOps.mirror(ims), (960, 0))
        wd.save(os.path.join(adir, st + "_wide.jpg"), "JPEG", quality=94)

    ts = os.path.join(adir, "title_bg_wide.jpg")
    if not os.path.isfile(ts):
        ts = os.path.join(adir, "title_bg_wide.png")
    imt = Image.open(ts).convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
    uw = Image.new("RGB", (1920, 540))
    uw.paste(ImageOps.mirror(imt.crop((0, 0, 480, 540))), (0, 0))
    uw.paste(imt, (480, 0))
    uw.paste(ImageOps.mirror(imt.crop((480, 0, 960, 540))), (1440, 0))
    uw.save(os.path.join(adir, "title_bg_ultrawide.jpg"), "JPEG", quality=94)

    amap = {}
    for fn in sorted(os.listdir(adir)):
        if fn.endswith((".png", ".jpg", ".jpeg")):
            st = os.path.splitext(fn)[0]
            if st in amap and amap[st].endswith(".png") and fn.endswith(".jpg"):
                continue
            amap[st] = f"assets/{fn}"
            write_imp(os.path.join(adir, fn + ".import"), "res" + CS + f"assets/{fn}", f"ga352_{st}", f"{fn}-v352.ctex")
    write_imp(os.path.join(vp, "icon.png.import"), "res" + CS + "icon.png", "ga352_icon", "icon.png-v352.ctex")

    mp = os.path.join(ddir, "game_metadata.json")
    meta = json.load(open(mp, "r", encoding="utf-8"))
    meta["assets"] = amap
    meta["version"] = "3.5.2"
    open(mp, "w", encoding="utf-8").write(json.dumps(meta, ensure_ascii=False, indent=2))

    cp = os.path.join(vp, "export_presets.cfg")
    cfg = open(cp, "r", encoding="utf-8").read()
    cfg = cfg.replace("3.3.0", "3.5.2").replace("version/code=330", "version/code=352")
    open(cp, "w", encoding="utf-8").write(cfg)

    sh_name = "ci_build_" + "godot4_apk.sh"
    sh = open(sh_name, "r", encoding="utf-8").read()
    sh = sh.replace("window/handheld/orientation=0", "window/handheld/orientation=4")
    sh = sh.replace("v3.3.0", "v3.5.2").replace("3.3.0", "3.5.2")
    sh = sh.replace("rm -rf godot4-edition/*", "rm -rf apk pc godot4-edition/*")
    sh = sh.replace("git add -A godot4-edition", "git add -A godot4-edition" + NL + "git add -u")
    tag_clean = 'for OT in v2.0.0 v2.4.0 v3.1.0-godot4 v3.2.0 v3.3.0; do git push origin ":refs/tags/$OT" || true; done'
    sh = sh.replace('git push origin "HEAD:$BR" || true', 'git push origin "HEAD:$BR" || true' + NL + tag_clean, 1)
    open(sh_name, "w", encoding="utf-8").write(sh)
    print("v3.5.2 assets, imports, and build config ready:", len(amap))

apply_v352()
