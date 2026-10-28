#!/usr/bin/env python3
"""
Convert selected candidate screenshots to final menu tiles in images/menu/
All images are 1376x768 high quality JPEGs without HUD/UI.
"""
import os
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CANDIDATES_DIR = os.path.join(BASE_DIR, "scratch", "candidates")
MENU_DIR = os.path.join(BASE_DIR, "images", "menu")

# Map target filename in images/menu/ -> candidate png filename in scratch/candidates/
MAPPINGS = {
    # 15 Courses
    "tile_lakeside.jpg": "lakeside_start.png",
    "tile_pinecrest.jpg": "pinecrest_start.png",
    "tile_harbor.jpg": "harbor_dock.png",
    "tile_bloombay_dunes.jpg": "bloombay_start.png",
    "tile_frostpeak_creek.jpg": "frostpeak_alpine_bridge.png",
    "tile_glacier_highway.jpg": "glacier_overpass.png",
    "tile_northlight_caverns.jpg": "northlight_crevasse.png",
    "tile_frostfall_gorge.jpg": "frostfall_start.png",
    "tile_mountain.jpg": "mountain_start.png",
    "tile_canyon.jpg": "canyon_start.png",
    "tile_canyon_chasm.jpg": "canyon_chasm_start.png",
    "tile_desert_wadi.jpg": "desert_wadi_start.png",
    "tile_mara_crossing.jpg": "mara_start.png",
    "tile_nyota_stadium.jpg": "nyota_bowl.png",
    "tile_msitu_falls.jpg": "msitu_start.png",

    # 5 GP Cups
    "tile_bloombay_gp.jpg": "lakeside_bridge.png",
    "tile_starter_cup.jpg": "lakeside_bridge.png", # legacy alias
    "tile_svartfjell_gp.jpg": "northlight_aurora_spire.png",
    "tile_arctic_cup.jpg": "northlight_aurora_spire.png", # legacy alias
    "tile_al_raihana_gp.jpg": "mountain_summit.png",
    "tile_desert_cup.jpg": "mountain_summit.png", # legacy alias
    "tile_sierra_del_viento_gp.jpg": "canyon_bridge.png",
    "tile_matumaini_gp.jpg": "mara_migration.png",
}

def main():
    os.makedirs(MENU_DIR, exist_ok=True)
    for target_name, src_name in MAPPINGS.items():
        src_path = os.path.join(CANDIDATES_DIR, src_name)
        dst_path = os.path.join(MENU_DIR, target_name)
        if not os.path.exists(src_path):
            print(f"Error: missing candidate {src_path}")
            continue
        im = Image.open(src_path).convert("RGB")
        im.save(dst_path, "JPEG", quality=92, optimize=True)
        print(f"Saved {dst_path} ({im.size[0]}x{im.size[1]}) from {src_name}")

if __name__ == "__main__":
    main()

