#!/bin/zsh
# Renders the stages' menu tiles into images/menu/ (scratch/menu_tile_shot.gd, one Godot run a stage, windowed), then
# imports them. From the project root:
#   scratch/render_menu_tiles.sh [Lakeside PinecrestRidge ...]   (level names without "Level.tscn"; none: every stage)
#   OUT=<dir> scratch/render_menu_tiles.sh ...                     (write there instead, as .jpg, without importing)
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
typeset -A TILE
TILE=(
	Lakeside tile_lakeside PinecrestRidge tile_pinecrest HarborPier tile_harbor BloombayDunes tile_bloombay_dunes
	FrostpeakCreek tile_frostpeak_creek GlacierHighway tile_glacier_highway NorthlightCaverns tile_northlight_caverns
	FrostfallGorge tile_frostfall_gorge Mountain tile_mountain Canyon tile_canyon CanyonChasm tile_canyon_chasm
	Freight tile_freight_line Mina tile_mina_del_viento DesertWadi tile_desert_wadi RamlatHamra tile_ramlat_hamra
	MarinaNights tile_marina_nights MaraCrossing tile_mara_crossing NyotaStadium tile_nyota_stadium
	MtaaNights tile_mtaa_nights Kronburg tile_kronburg Rheinufer tile_rheinufer Stadtrallye tile_stadtrallye
	Zeche tile_zeche MsituFalls tile_msitu_falls SenbonSakura tile_senbon_sakura YoshinoRapids tile_yoshino_rapids
	Monzenmachi tile_monzenmachi Yamabushi tile_yamabushi Tianqiao tile_tianqiao Panlong tile_panlong Wangjiang tile_wangjiang TestTrack tile_test_track
)
names=("$@")
[ ${#names} -eq 0 ] && names=(${(k)TILE})
for n in $names; do
	if [ -z "${TILE[$n]}" ]; then echo "unknown stage $n"; continue; fi
	if [ -n "$OUT" ]; then out="${OUT:A}/$n.jpg"; else out="$PWD/images/menu/${TILE[$n]}.jpg"; fi
	echo "== $n -> $out"
	$GODOT --path . --resolution 1376x768 res://scratch/menu_tile_shot.tscn -- res://levels/${n}Level.tscn \
		"$out" ${=EXTRA} 2>&1 | grep -E "^TILE|^SAVED|SCRIPT ERROR|ERROR: .*save"
done
if [ -z "$OUT" ]; then
	$GODOT --headless --path . --import > /dev/null 2>&1
fi
