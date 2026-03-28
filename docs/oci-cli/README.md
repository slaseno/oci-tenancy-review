# OCI CLI docs rst mirror (how this was generated)

This workspace contains a local mirror of Oracle OCI CLI rst source files from:

- `https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/`

The files were fetched step-by-step with `curl` and local parsing, and stored under:

- `_sources/...` (downloaded rst files)
- `crawl/...` (intermediate crawl artifacts)

## What was executed

All commands were run from the workspace root.

1. Download seed page (`oci.html`) locally.

```bash
mkdir -p crawl/html && \
curl -fsSL --connect-timeout 15 --max-time 60 \
  'https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/oci.html' \
  -o crawl/html/oci.html
```

2. Extract first-level in-scope doc links from `crawl/html/oci.html` and save to `crawl/links_step1_from_oci_html.txt`.

```bash
python3 - <<'PY'
import re
from urllib.parse import urljoin, urlparse

base = 'https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/oci.html'
raw = open('crawl/html/oci.html','r',encoding='utf-8',errors='replace').read()
links = set()
for href in re.findall(r'href=["\']([^"\'#?]+)["\']', raw, flags=re.I):
    u = urljoin(base, href)
    p = urlparse(u)
    if p.netloc == 'docs.oracle.com' and p.path.startswith('/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/') and p.path.endswith('.html'):
        links.add(u)

out = sorted(links)
with open('crawl/links_step1_from_oci_html.txt','w',encoding='utf-8') as f:
    for u in out:
        f.write(u+'\n')
print(f'links={len(out)}')
PY
```

3. Download those discovered HTML pages into `crawl/html/...` preserving relative path.

```bash
while IFS= read -r url; do
  rel=${url#https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/}
  out="crawl/html/${rel}"
  mkdir -p "$(dirname "$out")"
  curl -fsSL --connect-timeout 15 --max-time 60 "$url" -o "$out" || echo "FAILED $url"
done < crawl/links_step1_from_oci_html.txt
```

4. Parse all locally saved HTML pages and build expanded in-scope link list (`crawl/links_step2_expanded.txt`).

```bash
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
```

5. Convert each HTML URL to its rst source URL and save mapping to `crawl/rst_map.tsv`.

```bash
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

with open('crawl/rst_map.tsv','w',encoding='utf-8') as f:
    f.write('html_url\trst_url\tlocal_path\n')
    for h, r, lp in rows:
        f.write(f'{h}\t{r}\t{lp}\n')
print(f'mapped_rows={len(rows)}')
PY
```

6. Bulk-download all rst files in parallel; log failures to `crawl/rst_failures.txt`.

```bash
mkdir -p _sources crawl
: > crawl/rst_failures.txt

awk -F '\t' 'NR>1 {print $2 "\t" $3}' crawl/rst_map.tsv | \
  xargs -P 16 -n 2 sh -c '
    url="$1"; out="$2";
    mkdir -p "$(dirname "$out")";
    if ! curl -fsSL --connect-timeout 15 --max-time 45 "$url" -o "$out"; then
      printf "%s\n" "$url" >> crawl/rst_failures.txt
    fi
  ' sh
```

7. Verify counts.

```bash
wc -l crawl/links_step2_expanded.txt
find _sources -type f | wc -l
wc -l crawl/rst_failures.txt
```

## Current observed result

- Expanded HTML links: `10880`
- Downloaded rst files: `10878`
- Failures: `2`

The two failures were:

- `https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/_sources/genindex.rst.txt`
- `https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/_sources/search.rst.txt`

Both returned HTTP 404 (index/search pages without published rst source).

## Refresh later

Use the automation script:

```bash
./refresh_oci_cli_rst.sh
```

Optional tuning:

```bash
PARALLEL=24 CONNECT_TIMEOUT=20 MAX_TIME_HTML=90 MAX_TIME_RST=60 ./refresh_oci_cli_rst.sh
```

### Prerequisites

- `bash`
- `curl`
- `python3`
- `awk`, `xargs`, `find`, `wc` (standard Unix tools)

### Recommended execution flow

1. Refresh from a clean state:

```bash
rm -rf crawl _sources
```

2. Run:

```bash
./refresh_oci_cli_rst.sh
```

3. Check result:

```bash
wc -l crawl/links_step2_expanded.txt
find _sources -type f | wc -l
wc -l crawl/rst_failures.txt
```

### Caveats

- If you do not delete `crawl/` first, old HTML files can remain and inflate the expanded link list.
- If you do not delete `_sources/` first, rst files removed upstream will remain locally (stale files).
- `crawl/rst_failures.txt` will contain URLs that failed in the last run (for example expected 404s like `genindex` and `search`).
- Network instability, VPN/proxy settings, or Oracle-side throttling can cause transient curl failures; rerun if needed.
- Higher `PARALLEL` values increase speed but can increase failure rate depending on network conditions.
