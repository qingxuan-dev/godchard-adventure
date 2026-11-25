import glob, json, os, re, shutil, sys, zipfile

CS = ":" + "/" + "/"

def norm_v352_code(txt):
    t = txt.replace(
        'var delays: Array[float] = [1.7, 3.4] if echo_mode == "dual_coop" else [float(props.get("echoDelay", 1.75))]',
        'var delays: Array = [1.7, 3.4] if echo_mode == "dual_coop" else [float(props.get("echoDelay", 1.75))]'
    )
    return "".join(l + "\n" for l in t.splitlines() if l.strip() and not l.strip().startswith("#"))

def apply_ops(old_txt, ops):
    al = old_txt.splitlines(keepends=True)
    out = []
    for item in ops:
        if item[0] == 0:
            out.extend(al[item[1]:item[2]])
        else:
            out.append(item[1].replace("__CS2__", CS))
    return "".join(out)

def find_font(pat):
    pl = pat.lower()
    for r, _, fs in os.walk("/usr/share/fonts"):
        for f in fs:
            if pl in f.lower() and f.lower().endswith(".ttf"):
                return os.path.join(r, f)
    return ""

def write_imp(dst_imp, res_src, uid_tag, ctex_name):
    u = "uid" + CS + uid_tag
    p = "res" + CS + ".godot/imported/" + ctex_name
    open(dst_imp, "w", encoding="utf-8").write(
        f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\nuid="{u}"\n'
        f'path="{p}"\nmetadata={{\n"vram_texture": false\n}}\n\n'
        f'[deps]\n\nsource_file="{res_src}"\ndest_files=["{p}"]\n\n'
        f'[params]\n\ncompress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\n'
        f'compress/hdr_compression=1\ncompress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=false\n'
        f'mipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=""\nprocess/fix_alpha_border=true\n'
        f'process/premult_alpha=false\nprocess/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\n'
        f'process/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=0\n'
    )

def write_proj_cfg(proj_dir, is_pc):
    ms = "res" + CS + "scenes/Main.tscn"
    ic = "res" + CS + "icon.png"
    hdr = (
        f'config_version=5\n\n[application]\n\nconfig/name="哥查德的大冒险"\nconfig/version="3.5.3"\n'
        f'config/description="GODCHARD ADVENTURE v3.5.3"\nrun/main_scene="{ms}"\n'
        f'config/features=PackedStringArray("4.2", "GL Compatibility")\nconfig/icon="{ic}"\n\n[display]\n\n'
        f'window/size/viewport_width=960\nwindow/size/viewport_height=540\n'
    )
    if is_pc:
        mid = (
            'window/size/window_width_override=1280\nwindow/size/window_height_override=720\n'
            'window/size/mode=0\nwindow/size/resizable=true\nwindow/stretch/mode="canvas_items"\nwindow/stretch/aspect="keep_height"\n\n'
            '[input_devices]\n\npointing/emulate_touch_from_mouse=false\npointing/emulate_mouse_from_touch=false\n\n'
        )
    else:
        mid = (
            'window/size/mode=3\nwindow/handheld/orientation=4\nwindow/stretch/mode="canvas_items"\nwindow/stretch/aspect="keep_height"\n\n'
            '[input_devices]\n\npointing/emulate_touch_from_mouse=false\npointing/emulate_mouse_from_touch=true\n\n'
        )
    ftr = (
        '[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n'
        'textures/canvas_textures/default_texture_filter=0\nanti_aliasing/quality/msaa_2d=0\nanti_aliasing/quality/msaa_3d=0\nanti_aliasing/quality/screen_space_aa=0\nanti_aliasing/quality/use_taa=false\nanti_aliasing/quality/use_debanding=false\n2d/snap/snap_2d_transforms_to_pixel=true\n2d/snap/snap_2d_vertices_to_pixel=true\ntextures/vram_compression/import_etc2_astc=true\n'
        'textures/vram_compression/import_s3tc_bptc=true\n'
    )
    open(os.path.join(proj_dir, "project.godot"), "w", encoding="utf-8").write(hdr + mid + ftr)

def stage_pre(repo_dir, proj_dir):
    g4 = os.path.join(repo_dir, "godot4-edition")
    for sub in ["assets", "audio", "data", "scenes", "scripts"]:
        sd, dd = os.path.join(g4, sub), os.path.join(proj_dir, sub)
        if os.path.isdir(sd):
            if sub in ("audio", "scripts"):
                shutil.rmtree(dd, ignore_errors=True)
            os.makedirs(dd, exist_ok=True)
            shutil.copytree(sd, dd, dirs_exist_ok=True)
    for top_fn in ["icon.png", "icon.png.import"]:
        if os.path.isfile(os.path.join(g4, top_fn)):
            shutil.copyfile(os.path.join(g4, top_fn), os.path.join(proj_dir, top_fn))

    adir, ddir = os.path.join(proj_dir, "assets"), os.path.join(proj_dir, "data")
    for fw in list(os.listdir(adir)):
        if fw.endswith(".webp"):
            os.remove(os.path.join(adir, fw))

    lt, ct = find_font("dejavusans-bold"), find_font("droidsansfallback")
    if lt: shutil.copyfile(lt, os.path.join(ddir, "latin_font.bin"))
    if ct: shutil.copyfile(ct, os.path.join(ddir, "cjk_font.bin"))

    amap = {}
    for fn in sorted(os.listdir(adir)):
        if fn.endswith((".png", ".jpg", ".jpeg")):
            st = os.path.splitext(fn)[0]
            if st in amap and amap[st].endswith(".png") and fn.endswith(".jpg"):
                continue
            amap[st] = f"assets/{fn}"
            imp_p = os.path.join(adir, fn + ".import")
            if not os.path.isfile(imp_p):
                write_imp(imp_p, "res" + CS + f"assets/{fn}", f"ga353_{st}", f"{fn}-v353.ctex")
    if not os.path.isfile(os.path.join(proj_dir, "icon.png.import")):
        write_imp(os.path.join(proj_dir, "icon.png.import"), "res" + CS + "icon.png", "ga353_icon", "icon.png-v353.ctex")

    mp = os.path.join(ddir, "game_metadata.json")
    meta = json.load(open(mp, "r", encoding="utf-8"))
    meta["assets"] = amap
    meta["version"] = "3.5.3"
    open(mp, "w", encoding="utf-8").write(json.dumps(meta, ensure_ascii=False, indent=2))

    if not os.path.isfile(os.path.join(g4, "v353_synced.flag")):
        # If v352 wasn't synced yet, apply v352_s*.json first if present
        if not os.path.isfile(os.path.join(g4, "v352_synced.flag")) and glob.glob(os.path.join(g4, "v352_s*.json")):
            g2 = {}
            for p_fn in sorted(glob.glob(os.path.join(g4, "v352_s*.json"))):
                for rel, idx, op in json.load(open(p_fn, "r", encoding="utf-8"))["p"]:
                    g2.setdefault(rel, []).append((idx, op))
            for rel, idx_ops in g2.items():
                ops = [op for _, op in sorted(idx_ops, key=lambda x: x[0])]
                dst_f = os.path.join(proj_dir, rel)
                open(dst_f, "w", encoding="utf-8").write(apply_ops(open(dst_f, "r", encoding="utf-8").read(), ops))

        g3 = {}
        for p_fn in sorted(glob.glob(os.path.join(g4, "v353_s*.json"))):
            for rel, idx, op in json.load(open(p_fn, "r", encoding="utf-8"))["p"]:
                g3.setdefault(rel, []).append((idx, op))
        for rel, idx_ops in g3.items():
            ops = [op for _, op in sorted(idx_ops, key=lambda x: x[0])]
            dst_f = os.path.join(proj_dir, rel)
            b_src = norm_v352_code(open(dst_f, "r", encoding="utf-8").read())
            open(dst_f, "w", encoding="utf-8").write(apply_ops(b_src, ops))

    for gp in sorted(glob.glob(os.path.join(proj_dir, "scripts/**/*.gd"), recursive=True)):
        assert ":=" not in open(gp, "r", encoding="utf-8").read(), f"Forbidden := in {gp}"

    cp = os.path.join(proj_dir, "export_presets.cfg")
    cfg = open(cp, "r", encoding="utf-8").read()
    cfg = re.sub(r'custom_features=""', 'custom_features="mobile_apk"', cfg, count=1)
    cfg = re.sub(r'include_filter="[^"]*"', 'include_filter="*.json, *.bin, *.ttf, *.png, *.jpg, *.jpeg, *.ogg, *.wav"', cfg)
    cfg = re.sub(r'package/unique_name="[^"]*"', 'package/unique_name="com.qingxuan.godchard.mobile"', cfg)
    cfg = re.sub(r'package/name="[^"]*"', 'package/name="哥查德的大冒险"', cfg)
    cfg = re.sub(r"version/code=\d+", "version/code=353", cfg)
    cfg = re.sub(r'version/name="[^"]*"', 'version/name="3.5.3"', cfg)
    if "[preset.1]" not in cfg:
        cfg += (
            '\n[preset.1]\n\nname="Windows Desktop"\nplatform="Windows Desktop"\nrunnable=true\n'
            'dedicated_server=false\ncustom_features="pc_desktop"\nexport_filter="all_resources"\n'
            'include_filter="*.json, *.bin, *.ttf, *.png, *.jpg, *.jpeg, *.ogg, *.wav"\nexclude_filter=""\n'
            'export_path="../pc_win64/GodchardAdventure_PC_Win64/GodchardAdventure.exe"\n'
            'encryption_include_filters=""\nencryption_exclude_filters=""\nencrypt_pck=false\nencrypt_directory=false\n\n'
            '[preset.1.options]\n\ncustom_template/debug=""\ncustom_template/release=""\n'
            'debug/export_console_script=0\nbinary_format/embed_pck=false\ntexture_format/bptc=true\n'
            'texture_format/s3tc=true\ntexture_format/etc=false\ntexture_format/etc2=false\n'
            'binary_format/architecture="x86_64"\ncodesign/enable=false\napplication/modify_resources=false\n'
        )
    open(cp, "w", encoding="utf-8").write(cfg)
    open(os.path.join(ddir, "build_profile.json"), "w", encoding="utf-8").write('{"platform": "android", "forced_landscape": true}\n')
    write_proj_cfg(proj_dir, False)
    print(f"[v3.5.3 PRE OK] {len(amap)} lossless textures, 11 GDScripts verified!")

def stage_pc_cfg(proj_dir):
    open(os.path.join(proj_dir, "data/build_profile.json"), "w", encoding="utf-8").write('{"platform": "pc", "forced_landscape": false}\n')
    write_proj_cfg(proj_dir, True)
    pc_dir = os.path.join(os.path.dirname(proj_dir), "pc_win64/GodchardAdventure_PC_Win64")
    os.makedirs(pc_dir, exist_ok=True)
    open(os.path.join(pc_dir, "README_电脑端运行说明.txt"), "w", encoding="utf-8").write(
        "哥查德的大冒险 v3.5.3 电脑桌面原生版 (Windows x64)：解压后保持 GodchardAdventure.exe 与 GodchardAdventure.pck 同级目录，双击运行（默认隐藏手机触控键，F11 切换全屏）。\n"
    )

def stage_pack_sync(repo_dir, proj_dir):
    wdir = os.path.dirname(proj_dir)
    pc_dir = os.path.join(wdir, "pc_win64/GodchardAdventure_PC_Win64")
    out_pc = os.path.join(wdir, "GodchardAdventure-PC-Windows-x64-v3.5.3.zip")
    with zipfile.ZipFile(out_pc, "w", zipfile.ZIP_DEFLATED) as zf:
        for fn in sorted(os.listdir(pc_dir)):
            zf.write(os.path.join(pc_dir, fn), f"GodchardAdventure_PC_Win64/{fn}")
    open(os.path.join(proj_dir, "data/build_profile.json"), "w", encoding="utf-8").write('{"platform": "auto", "forced_landscape": true}\n')
    write_proj_cfg(proj_dir, False)
    for op in ["apk", "pc"]:
        shutil.rmtree(os.path.join(repo_dir, op), ignore_errors=True)
    g4_dst = os.path.join(repo_dir, "godot4-edition")
    shutil.copytree(os.path.join(proj_dir, "assets"), os.path.join(g4_dst, "assets"), dirs_exist_ok=True)
    for sr in ["project.godot", "icon.png.import", "scenes/Main.tscn", "data/build_profile.json", "data/game_metadata.json", "data/levels_150.json"]:
        sf = os.path.join(proj_dir, sr)
        if os.path.isfile(sf):
            os.makedirs(os.path.dirname(os.path.join(g4_dst, sr)), exist_ok=True)
            shutil.copyfile(sf, os.path.join(g4_dst, sr))
    shutil.rmtree(os.path.join(g4_dst, "scripts"), ignore_errors=True)
    shutil.copytree(os.path.join(proj_dir, "scripts"), os.path.join(g4_dst, "scripts"))
    open(os.path.join(g4_dst, "v353_synced.flag"), "w", encoding="utf-8").write("3.5.3\n")
    open(os.path.join(wdir, "notes_v353.md"), "w", encoding="utf-8").write(
        "### 《哥查德的大冒险 · GODCHARD ADVENTURE》v3.5.3 物理交互、二段跳、弹簧弹射与全精灵朝向彻底根治版 (Godot 4.2.2 GDScript 原生双端)\n\n"
        "1. **二段跳与安卓多指边沿锁存根治**：\n"
        "   - 修复起跳后 `jump_buffer_timer` 未在同一帧第 2 个物理子步前清零导致空中二段跳瞬间被误耗尽的根因；\n"
        "   - 为安卓多指虚拟手柄新增事件级按下/松开边沿锁存（含单帧超快轻点自动短跳切速保护与安卓防模拟鼠标串扰），并在左上状态栏同步显示 `x2`/`x3` 二段跳徽标。\n\n"
        "2. **弹簧、正反/冲天木夹与高压喷泉管高度彻底校准**：\n"
        "   - 移除 `stage_engine.gd` 对负向升空初速度的 `-765` 错误截断（仅限制正向终端下落速度），并在升空保护期内豁免松开跳跃键的 `0.49` 切跳衰减；\n"
        "   - 逐关校准第 15/52/104/138 关弹簧（`-865`）、第 101 关反向高抛木夹（`-835`）、第 128/148 关冲天暗阁木夹（`-935`）、第 107/135/137/143 关顺风飞跃木夹（`-845`）及第 103/111 关喷泉高管（`-785`）。\n\n"
        "3. **导弹朝向与全 150 关精灵翻转、拟态伪装、残框伪影全量清零**：\n"
        "   - 修复右飞导弹误读 `vx` 导致弹头朝左倒飞的问题（改为严格按 `dir < 0` 翻转并补齐尾焰粒子与发射器后坐力）；\n"
        "   - 同步修复第 39/57/72/96/129 关残像分身隐身、第 139 关双层虚影、字符串 `pairId` 传送门、拟态机关提前剧透、假墙碎裂紫框残留与超宽屏舞台两侧暗边亮线。\n"
    )

if __name__ == "__main__":
    m = sys.argv[1]
    if m == "pre": stage_pre(sys.argv[2], sys.argv[3])
    elif m == "pc": stage_pc_cfg(sys.argv[2])
    elif m == "sync": stage_pack_sync(sys.argv[2], sys.argv[3])
