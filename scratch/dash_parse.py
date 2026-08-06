import json, os, re
with open(os.path.join(os.environ.get('TEMP', ''), 'dashboards.json'), 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

for item in data:
    path = item['Path'].split('lib\\\\')[-1]
    line = item['Line'].strip()
    if 'transparent' in line.lower() or 'white' in line.lower() or 'black' in line.lower() or 'divider' in line.lower(): continue
    if 'background' in line.lower() or 'surface' in line.lower() or 'shadow' in line.lower() or 'gradient' in line.lower() or 'textstyle' in line.lower(): continue
    print(f"{path}:{item['LineNumber']} - {line}")
