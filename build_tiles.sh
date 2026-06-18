#!/usr/bin/env bash
# Перегенерация векторных тайлов всех участков -> tiles/{z}/{x}/{y}.pbf
# Запускать при изменении parcels/ или councils/. Требует: tippecanoe (brew install tippecanoe), python3.
# Тайлы: zoom 8-14 (выше — overzoom на клиенте), без сжатия (GitHub Pages отдаёт raw .pbf),
# свойства: c=кадастр, o=форма собственности (p/k/g/n), a=площадь(га).
set -euo pipefail
cd "$(dirname "$0")"
TMP="$(mktemp -d)/all_parcels.geojsonl"

python3 - "$TMP" <<'PY'
import json, glob, os, sys
OT = {'Приватна власність':'p','Комунальна власність':'k','Державна власність':'g','Не визначено':'n'}
out = open(sys.argv[1], 'w', encoding='utf-8')
for cf in sorted(glob.glob('councils/*.json')):
    code = os.path.basename(cf)[:-5]
    cj = json.load(open(cf, encoding='utf-8'))
    meta = {p['c']: (OT.get(p.get('ot'), 'n'), p.get('a')) for p in cj['parcels']}
    gp = f'parcels/{code}.geojson'
    if not os.path.exists(gp): continue
    for ftr in json.load(open(gp, encoding='utf-8'))['features']:
        geom = ftr.get('geometry')
        if not geom: continue
        cad = ftr['properties'].get('cadnum'); o, a = meta.get(cad, ('n', None))
        props = {'c': cad, 'o': o}
        if a is not None: props['a'] = a
        out.write(json.dumps({'type':'Feature','properties':props,'geometry':geom}, ensure_ascii=False) + '\n')
out.close()
PY

rm -rf tiles
tippecanoe -e tiles -l parcels -P -Z8 -z14 \
  --drop-densest-as-needed --no-tile-compression --force \
  --name="Kherson parcels" "$TMP"
echo "tiles: $(find tiles -name '*.pbf' | wc -l | tr -d ' ') files, $(du -sh tiles | cut -f1)"
