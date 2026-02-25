#!/usr/bin/env python3
"""
Import DB-IP Lite Country CSV into stats_geoip_country (MySQL).
Table format: start INT UNSIGNED, end INT UNSIGNED, countrycode VARCHAR(2), countryname VARCHAR(50).
Usage: python3 import_geoip_country.py [path_to_csv_or_gz]
If no path given, downloads dbip-country-lite-YYYY-MM.csv.gz from DB-IP.
"""
import csv
import gzip
import io
import os
import re
import sys
from urllib.request import urlopen, Request

# Optional: fetch country code -> name (CC-BY); skip if offline
def get_country_names():
    try:
        u = urlopen("https://raw.githubusercontent.com/annexare/Countries/main/data/countries.json", timeout=10)
        import json
        data = json.load(u)
        return {v["code"]: v["name"] for v in data.values() if isinstance(v.get("name"), str)}
    except Exception:
        pass
    # Fallback: minimal set so at least main countries have names
    return {
        "ES": "Spain", "AR": "Argentina", "MX": "Mexico", "CO": "Colombia", "CL": "Chile",
        "US": "United States", "BR": "Brazil", "PE": "Peru", "EC": "Ecuador", "VE": "Venezuela",
        "FR": "France", "DE": "Germany", "IT": "Italy", "GB": "United Kingdom", "PT": "Portugal",
        "RU": "Russia", "UA": "Ukraine", "PL": "Poland", "NL": "Netherlands", "BE": "Belgium",
        "CA": "Canada", "AU": "Australia", "JP": "Japan", "CN": "China", "IN": "India",
        "UY": "Uruguay", "PY": "Paraguay", "BO": "Bolivia", "CR": "Costa Rica", "PA": "Panama",
        "CU": "Cuba", "DO": "Dominican Republic", "GT": "Guatemala", "HN": "Honduras",
        "SV": "El Salvador", "NI": "Nicaragua", "PR": "Puerto Rico", "HN": "Honduras",
    }


def ip4_to_int(ip):
    try:
        parts = [int(x) for x in ip.split(".")]
        if len(parts) != 4:
            return None
        return (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + parts[3]
    except (ValueError, AttributeError):
        return None


def main():
    country_names = get_country_names()
    if not country_names:
        country_names = {}

    csv_path = sys.argv[1] if len(sys.argv) > 1 else None
    if csv_path and not os.path.isfile(csv_path):
        print("File not found:", csv_path, file=sys.stderr)
        sys.exit(1)

    if not csv_path:
        # Try current month and previous month
        from datetime import datetime
        now = datetime.utcnow()
        for delta in [0, -1]:
            y = now.year if delta == 0 else (now.year - 1 if now.month == 1 else now.year)
            m = now.month + delta if delta == -1 else now.month
            if m < 1:
                m += 12
                y -= 1
            url = f"https://download.db-ip.com/free/dbip-country-lite-{y}-{m:02d}.csv.gz"
            try:
                print("Downloading", url, "...", file=sys.stderr)
                req = Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; GeoIP-Import/1.0)"})
                data = urlopen(req, timeout=60).read()
                csv_path = "/tmp/dbip-country-lite.csv.gz"
                with open(csv_path, "wb") as f:
                    f.write(data)
                break
            except Exception as e:
                print("Download failed:", e, file=sys.stderr)
        else:
            print("Could not download DB-IP CSV. Provide path as argument.", file=sys.stderr)
            sys.exit(1)

    open_fn = gzip.open if csv_path.endswith(".gz") else open
    mode = "rt" if csv_path.endswith(".gz") else "r"
    out_path = "/tmp/stats_geoip_country.csv"
    total = 0
    skipped = 0

    with open_fn(csv_path, mode, encoding="utf-8", errors="replace") as f_in:
        with open(out_path, "w", encoding="utf-8", newline="") as f_out:
            w = csv.writer(f_out)
            for line in f_in:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(",")
                if len(parts) < 3:
                    skipped += 1
                    continue
                ip_start, ip_end, code = parts[0].strip(), parts[1].strip(), (parts[2].strip())[:2]
                start_i = ip4_to_int(ip_start)
                end_i = ip4_to_int(ip_end)
                if start_i is None or end_i is None:
                    skipped += 1
                    continue
                name = country_names.get(code, code or "Unknown")
                w.writerow([start_i, end_i, code or "", name[:50]])
                total += 1
                if total % 100000 == 0:
                    print(total, "ranges...", file=sys.stderr)

    print("Wrote", total, "rows to", out_path, "(skipped", skipped, ")", file=sys.stderr)
    print("Run on DB server:")
    print("  mysql -u stats -pstats123 globalchat -e \"TRUNCATE TABLE stats_geoip_country;\"")
    print("  mysql -u stats -pstats123 globalchat -e \"LOAD DATA LOCAL INFILE '" + out_path + "' INTO TABLE stats_geoip_country FIELDS TERMINATED BY ',' ENCLOSED BY '\\\"' LINES TERMINATED BY '\\n' (start, end, countrycode, countryname);\"")
    print("Or from this host, copy", out_path, "to server and run the LOAD DATA there.")


if __name__ == "__main__":
    main()
