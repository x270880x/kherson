#!/usr/bin/env bash
# Перегенерация векторных тайлов всех участков -> tiles/{z}/{x}/{y}.pbf
# Запускать при изменении parcels/ или councils/. Требует: tippecanoe (brew install tippecanoe), python3.
# Тайлы: zoom 8-14 (выше — overzoom на клиенте), без сжатия (GitHub Pages отдаёт raw .pbf).
# Свойство только o = форма собственности (p/k/g/n) для раскраски; кадастр/площадь/данные участка
# берутся при клике из оригинальных parcels/*.geojson + councils/*.json (point-in-polygon), не из тайлов.
# Лимит тайла 2 МБ + только o => с z9 и выше участки НЕ прореживаются (карта залита на обзоре).
set -euo pipefail
cd "$(dirname "$0")"
TMP="$(mktemp -d)/all_parcels.geojsonl"

python3 - "$TMP" <<'PY'
import json, glob, os, sys
OT = {'Приватна власність':'p','Комунальна власність':'k','Державна власність':'g','Не визначено':'n'}
out = open(sys.argv[1], 'w', encoding='utf-8')
for cf in sorted(glob.glob('councils/*.json')):
    code = os.path.basename(cf)[:-5]
    meta = {p['c']: OT.get(p.get('ot'), 'n') for p in json.load(open(cf, encoding='utf-8'))['parcels']}
    gp = f'parcels/{code}.geojson'
    if not os.path.exists(gp): continue
    for ftr in json.load(open(gp, encoding='utf-8'))['features']:
        geom = ftr.get('geometry')
        if not geom: continue
        cad = ftr['properties'].get('cadnum')
        out.write(json.dumps({'type':'Feature','properties':{'o':meta.get(cad,'n')},'geometry':geom}, ensure_ascii=False) + '\n')
out.close()
PY

rm -rf tiles
tippecanoe -e tiles -l parcels -P -Z6 -z14 -y o \
  --drop-densest-as-needed --maximum-tile-bytes 2000000 \
  --no-tile-compression --force --name="Kherson parcels" "$TMP"
echo "tiles: $(find tiles -name '*.pbf' | wc -l | tr -d ' ') files, $(du -sh tiles | cut -f1)"
