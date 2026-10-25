#!/usr/bin/env python3
"""Switches the models' textures to Godot 4.8's streamed import and shrinks them.

The Hunyuan models (models/plants, models/desert, ...) came with 4096px maps: _0 albedo and _1
normal, which their materials use, and grey _2/_3 maps nothing reads. This scales every map a model
uses down to at most --size and the unused ones to --unused-size (Lanczos, in place: the originals
stay in git), and rewrites each .import for the "Texture2D Streamed" importer (streamed_texture_2d),
keeping its uid so the models still find it. What a texture is for comes from the models' own
materials (scratch/texture_roles.gd writes it), so normal maps get the normal-map compression
whatever their file is called. Godot reimports on the next editor start, or headless with
`Godot --headless --path . --import`.

    Godot --headless --path . -s res://scratch/texture_roles.gd -- /tmp/roles.json res://models/plants
    python3 scratch/stream_textures.py --roles /tmp/roles.json --size 1024 models/plants
    python3 scratch/stream_textures.py --roles /tmp/roles.json --size 1024 --only 04b2c6e2 models/plants
"""
import argparse
import json
import os
import re
import sys

from PIL import Image

IMPORT = """[remap]

importer="streamed_texture_2d"
type="StreamedTexture2D"
uid="{uid}"

[deps]

source_file="{source}"

[params]

compress/high_quality=false
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
roughness/mode=1
roughness/src_normal=""
streaming/min_lod_override=0
streaming/max_lod_override=0
"""

MAP = re.compile(r"^(.+)_([0-9])\.png$")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--roles", required=True, help="JSON from scratch/texture_roles.gd")
    ap.add_argument("--size", type=int, required=True, help="largest side of the maps the models use")
    ap.add_argument("--unused-size", type=int, default=512, help="largest side of the maps nothing uses")
    ap.add_argument("--only", default="", help="only files whose name starts with this")
    ap.add_argument("dirs", nargs="+")
    args = ap.parse_args()
    roles = json.load(open(args.roles))
    root = os.getcwd()
    for d in args.dirs:
        for name in sorted(os.listdir(d)):
            m = MAP.match(name)
            if not m or not name.startswith(args.only):
                continue
            stem = m.group(1)
            if not (os.path.exists(os.path.join(d, stem + ".fbx")) or os.path.exists(os.path.join(d, stem + ".glb"))):
                continue
            path = os.path.join(d, name)
            res_path = "res://" + os.path.relpath(path, root).replace(os.sep, "/")
            used = roles.get(res_path, [])
            limit = args.size if used else args.unused_size
            with Image.open(path) as im:
                w, h = im.size
                if max(w, h) > limit:
                    s = limit / max(w, h)
                    small = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
                    small.save(path, optimize=True)
                    print("%s %dx%d -> %dx%d (%s)" % (path, w, h, small.size[0], small.size[1], ",".join(used) or "unused"))
            imp = path + ".import"
            uid = ""
            if os.path.exists(imp):
                mm = re.search(r'^uid="([^"]+)"', open(imp).read(), re.M)
                if mm:
                    uid = mm.group(1)
            if not uid:
                print("  no uid for %s, skipped its import" % path, file=sys.stderr)
                continue
            # Normal-map compression only for a texture used as nothing but a normal map.
            normal = 1 if used == ["normal"] else 2
            with open(imp, "w") as f:
                f.write(IMPORT.format(uid=uid, source=res_path, normal=normal))
    return 0


if __name__ == "__main__":
    sys.exit(main())
