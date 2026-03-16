#!/usr/bin/env python3

import gzip
import json
import os
import re
import subprocess
import tempfile
import time
import urllib.request
import urllib.error

BASE_URL = "https://guolab.wchscu.cn/AnimalTFDB4_static/download"
ALL_TF_URL = f"{BASE_URL}/all_tf_list"
ALL_COF_URL = f"{BASE_URL}/all_cof_list"


def solve_challenge_with_node(html_content):
    arg1_match = re.search(r"var\s+arg1\s*=\s*'([^']+)'", html_content)
    if not arg1_match:
        return None
    arg1 = arg1_match.group(1)

    script_match = re.search(
        r'<script[^>]*>\s*(var\s+_0x.*?)</script>',
        html_content,
        re.DOTALL,
    )
    if not script_match:
        return None
    waf_script = script_match.group(1)

    helper_match = re.search(
        r'function\s+setCookie\b.*?function\s+reload\b.*?(?=</script>)',
        html_content,
        re.DOTALL,
    )
    helper_code = helper_match.group(0) if helper_match else ""

    mock_env = """
var cookie_value = null;
var _original_doc_cookie = '';
var document = {
    addEventListener: function(evt, fn) { fn(); },
    attachEvent: function(evt, fn) { fn(); },
    createElement: function() { return {}; },
    getElementsByTagName: function() { return [{appendChild: function(){}}]; },
    location: { reload: function() {} }
};
var window = {
    headless: undefined,
    addEventListener: function() {},
    navigator: { webdriver: undefined },
    location: { reload: function() {} }
};
var navigator = { userAgent: 'Mozilla/5.0' };
var location = window.location;
var setTimeout = function(fn, t) { if (typeof fn === 'function') fn(); else eval(fn); };
var setInterval = function() {};
Object.defineProperty(document, 'cookie', {
    set: function(val) {
        _original_doc_cookie = val;
        if (val.indexOf('acw_sc__v2') !== -1) {
            var match = val.match(/acw_sc__v2=([^;]+)/);
            if (match) cookie_value = match[1];
        }
    },
    get: function() { return _original_doc_cookie; }
});
"""

    node_code = mock_env + '\nvar arg1 = "' + arg1 + '";\n' + helper_code + '\n' + waf_script + '\nprocess.stdout.write(JSON.stringify({cookie: cookie_value}));'

    tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.js', delete=False)
    tmp.write(node_code)
    tmp.close()

    import shutil
    debug_path = os.path.join(os.path.dirname(tmp.name), "debug_node_generated.js")
    shutil.copy(tmp.name, "/Users/mx/Study/repositories/scop/test/AnimalTFDB4/debug_node_generated.js")

    try:
        result = subprocess.run(
            ["node", tmp.name],
            capture_output=True,
            text=True,
            timeout=10,
        )
        print(f"  [debug] node returncode={result.returncode}")
        if result.stderr:
            print(f"  [debug] node stderr: {result.stderr[:500]}")
        if result.stdout:
            print(f"  [debug] node stdout: {result.stdout[:500]}")
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout.strip())
            return data.get("cookie")
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"  [debug] exception: {e}")
    finally:
        os.unlink(tmp.name)
    return None


def fetch_with_antibot(url, max_retries=3):
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,*/*",
        "Accept-Encoding": "gzip, deflate",
        "Accept-Language": "en-US,en;q=0.9",
    }

    for attempt in range(max_retries):
        req = urllib.request.Request(url, headers=headers)
        try:
            resp = urllib.request.urlopen(req, timeout=60)
        except urllib.error.HTTPError:
            raise

        data = resp.read()
        if resp.headers.get("Content-Encoding") == "gzip":
            data = gzip.decompress(data)
        text = data.decode("utf-8", errors="replace")

        if "acw_sc__v2" in text or "arg1" in text:
            cookie_val = solve_challenge_with_node(text)
            if cookie_val:
                headers["Cookie"] = f"acw_sc__v2={cookie_val}"
                req2 = urllib.request.Request(url, headers=headers)
                resp2 = urllib.request.urlopen(req2, timeout=60)
                data2 = resp2.read()
                if resp2.headers.get("Content-Encoding") == "gzip":
                    data2 = gzip.decompress(data2)
                text2 = data2.decode("utf-8", errors="replace")
                if "acw_sc__v2" not in text2:
                    return text2
            time.sleep(1)
            continue

        return text

    raise RuntimeError(f"Failed to bypass WAF after {max_retries} retries: {url}")


def split_by_species(tsv_text, output_dir, suffix):
    lines = tsv_text.strip().split("\n")
    if len(lines) < 2:
        print(f"  [error] No data rows found")
        return {}

    header = lines[0]
    species_data = {}

    for line in lines[1:]:
        fields = line.split("\t")
        if not fields or not fields[0].strip():
            continue
        species = fields[0].strip()
        if species == "Species":
            continue
        if species not in species_data:
            species_data[species] = [header]
        species_data[species].append(line)

    os.makedirs(output_dir, exist_ok=True)
    results = {}

    for species, rows in sorted(species_data.items()):
        out_path = os.path.join(output_dir, f"{species}{suffix}")
        with open(out_path, "w") as f:
            f.write("\n".join(rows) + "\n")
        results[species] = len(rows) - 1
        print(f"  {species}: {len(rows) - 1} records")

    return results


def load_or_download(label, url, local_path):
    """Load data from local file if it exists, otherwise download from URL."""
    if os.path.isfile(local_path):
        print(f"\n[{label}] Found local file: {local_path}")
        with open(local_path, "r", encoding="utf-8") as f:
            text = f.read()
        lines = text.strip().split("\n")
        print(f"  Loaded {len(lines)} lines from local file (skipping download)")
        return text
    else:
        print(f"\n[{label}] Local file not found, downloading ...")
        print(f"  URL: {url}")
        text = fetch_with_antibot(url)
        lines = text.strip().split("\n")
        print(f"  Downloaded {len(lines)} lines")
        return text


def main():
    output_dir = os.path.dirname(os.path.abspath(__file__))

    print(f"Output dir: {output_dir}")
    print("=" * 70)

    tf_local = os.path.join(output_dir, "all_tf_list.txt")
    cof_local = os.path.join(output_dir, "all_cof_list.txt")

    tf_text = load_or_download("1/2 TF", ALL_TF_URL, tf_local)
    cof_text = load_or_download("2/2 Cof", ALL_COF_URL, cof_local)

    print(f"\nSplitting TF data by species ...")
    tf_dir = os.path.join(output_dir, "TF_list_final")
    tf_results = split_by_species(tf_text, tf_dir, "_TF")

    print(f"\nSplitting Cof data by species ...")
    cof_dir = os.path.join(output_dir, "Cof_list_final")
    cof_results = split_by_species(cof_text, cof_dir, "_Cof")

    print("\n" + "=" * 70)
    print(f"Done! TF species: {len(tf_results)}, Cof species: {len(cof_results)}")


if __name__ == "__main__":
    main()
