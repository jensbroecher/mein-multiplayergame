#!/bin/bash
# Makes fonts/NotoSansSC-Yunhai.otf: Noto Sans CJK SC Bold cut down to ASCII and the Chinese characters the Yunhai GP's
# generators write on their signs (YunhaiStage.gd and the regenerate_*.gd of its stages). Run it from the
# project root after adding a sign with new characters, then regenerate the stages. Needs fonttools (pyftsubset) and
# the font (Debian's fonts-noto-cjk: NotoSansCJK-Bold.ttc, face 2 is SC); SIL Open Font License, fonts/NotoSansCJK-OFL.txt.
set -e
SRC=${SRC:-/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc}
TXT=$(mktemp)
python3 - "$TXT" YunhaiStage.gd regenerate_tianqiao.gd regenerate_panlong.gd regenerate_wangjiang.gd <<'PY'
import sys, os
chars = set()
for f in sys.argv[2:]:
    if os.path.exists(f):
        chars |= {c for c in open(f, encoding="utf8").read() if ord(c) > 0x2000}
open(sys.argv[1], "w", encoding="utf8").write("".join(sorted(chars)))
print(len(chars), "characters")
PY
pyftsubset "$SRC" --font-number=2 --text-file="$TXT" --unicodes=U+0020-007E --output-file=fonts/NotoSansSC-Yunhai.otf
rm -f "$TXT"
