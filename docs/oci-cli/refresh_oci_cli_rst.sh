#!/usr/bin/env bash
set -euox pipefail

BASE_URL="https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs"
SEED_URL="${BASE_URL}/oci.html"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-15}"
MAX_TIME_HTML="${MAX_TIME_HTML:-60}"
MAX_TIME_RST="${MAX_TIME_RST:-45}"
PARALLEL="${PARALLEL:-16}"

echo "Refreshing OCI CLI rst sources from: ${BASE_URL}"
echo "Settings: PARALLEL=${PARALLEL}, CONNECT_TIMEOUT=${CONNECT_TIMEOUT}, MAX_TIME_HTML=${MAX_TIME_HTML}, MAX_TIME_RST=${MAX_TIME_RST}"

mkdir -p crawl/html _sources

echo "[1/6] Downloading seed page..."
curl -fsSL --connect-timeout "${CONNECT_TIMEOUT}" --max-time "${MAX_TIME_HTML}" \
  "${SEED_URL}" -o crawl/html/oci.html

echo "[2/6] Extracting first-level links from seed..."
python3 - <<'PY'
import re
from urllib.parse import urljoin, urlparse

base = 'https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/oci.html'
raw = open('crawl/html/oci.html', 'r', encoding='utf-8', errors='replace').read()
links = set()
for href in re.findall(r'href=["\']([^"\'#?]+)["\']', raw, flags=re.I):
    u = urljoin(base, href)
    p = urlparse(u)
    if p.netloc == 'docs.oracle.com' and p.path.startswith('/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/') and p.path.endswith('.html'):
        links.add(u)

out = sorted(links)
with open('crawl/links_step1_from_oci_html.txt', 'w', encoding='utf-8') as f:
    for u in out:
        f.write(u + '\n')
print(f'first_level_links={len(out)}')
PY

echo "[3/6] Downloading first-level HTML pages..."
while IFS= read -r url; do
  rel="${url#${BASE_URL}/}"
  out="crawl/html/${rel}"
  mkdir -p "$(dirname "${out}")"
  curl -fsSL --connect-timeout "${CONNECT_TIMEOUT}" --max-time "${MAX_TIME_HTML}" \
    "${url}" -o "${out}" || echo "FAILED ${url}"
done < crawl/links_step1_from_oci_html.txt

echo "[4/6] Expanding links from local HTML snapshot..."
python3 - <<'PY'
import re
from pathlib import Path
from urllib.parse import urljoin, urlparse

seed_base = 'https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/'
all_links = set()
html_files = sorted(Path('crawl/html').rglob('*.html'))

for fp in html_files:
    rel = fp.as_posix().removeprefix('crawl/html/')
    page_url = urljoin(seed_base, rel)
    text = fp.read_text(encoding='utf-8', errors='replace')
    for href in re.findall(r'href=["\']([^"\'#?]+)["\']', text, flags=re.I):
        u = urljoin(page_url, href)
        p = urlparse(u)
        if p.netloc == 'docs.oracle.com' and p.path.startswith('/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/') and p.path.endswith('.html'):
            all_links.add(u)

out = sorted(all_links)
Path('crawl/links_step2_expanded.txt').write_text('\n'.join(out) + ('\n' if out else ''), encoding='utf-8')
print(f'expanded_links={len(out)}')
PY

echo "[5/6] Building rst URL mapping..."
python3 - <<'PY'
from pathlib import Path
from urllib.parse import urlparse

html_urls = [line.strip() for line in Path('crawl/links_step2_expanded.txt').read_text(encoding='utf-8').splitlines() if line.strip()]
rows = []
for u in html_urls:
    p = urlparse(u)
    rel = p.path.removeprefix('/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/')
    if not rel.endswith('.html'):
        continue
    rst_rel = rel[:-5] + '.rst.txt'
    rst_url = 'https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/_sources/' + rst_rel
    local_path = '_sources/' + rst_rel
    rows.append((u, rst_url, local_path))

with open('crawl/rst_map.tsv', 'w', encoding='utf-8') as f:
    f.write('html_url\trst_url\tlocal_path\n')
    for h, r, lp in rows:
        f.write(f'{h}\t{r}\t{lp}\n')

print(f'mapped_rows={len(rows)}')
PY

echo "[6/6] Downloading rst files in parallel..."
: > crawl/rst_failures.txt

awk -F '\t' 'NR>1 {print $2 "\t" $3}' crawl/rst_map.tsv | \
  xargs -P "${PARALLEL}" -n 2 sh -c '
    url="$1"; out="$2";
    mkdir -p "$(dirname "$out")";
    if ! curl -fsSL --connect-timeout "'"${CONNECT_TIMEOUT}"'" --max-time "'"${MAX_TIME_RST}"'" "$url" -o "$out"; then
      printf "%s\n" "$url" >> crawl/rst_failures.txt
    fi
  ' sh

echo "Refresh complete."
echo "Summary:"
printf "  expanded_links: "
wc -l < crawl/links_step2_expanded.txt
printf "  downloaded_rst: "
find _sources -type f | wc -l
printf "  failed_rst: "
wc -l < crawl/rst_failures.txt
echo "Artifacts:"
echo "  crawl/links_step1_from_oci_html.txt"
echo "  crawl/links_step2_expanded.txt"
echo "  crawl/rst_map.tsv"
echo "  crawl/rst_failures.txt"
