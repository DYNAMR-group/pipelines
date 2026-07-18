#!/usr/bin/env python3
"""
Loops through per-sample vista JSON reports (structure:
serogroup, serogroupMarkers, virulenceGenes, virulenceClusters) and produces
ONE ROW PER SAMPLE, with:
  - sample_id      (parsed from the filename)
  - serogroup
  - one column per serogroup marker  -> "detected" / "not_detected"
  - one column per virulence gene    -> its status (Present/Not found/Incomplete)
  - one column per virulence cluster -> its overall status

Detailed per-match info (contig positions, identity %, etc.) is intentionally
NOT included in this one-row-per-sample summary -- it lives in each sample's
own JSON if you need to dig into a specific hit later.

Sample ID extraction: filenames are assumed to look like
    Sample_S1_report.json  -> sample_id = "Sample_S1"
i.e. just the trailing "_report" suffix is stripped, keeping the rest of the
filename stem intact. Adjust `sample_id_from_filename()` if your real
filenames follow a different pattern.

Gene columns: named directly after the gene (e.g. "ompU", "tcpA") with no
prefix. This includes BOTH the top-level virulenceGenes list AND every
individual gene nested inside each virulenceCluster's own "matches" dict
(e.g. the TCP cluster's tcpA-tcpT, the Lux operon's luxO/P/Q/S/U, etc.) --
so every gene in the report gets its own column, not just the cluster-level
summary. Cluster-level overall completeness is kept separately as
"cluster_<id>" so you still know at a glance whether e.g. the whole TCP
operon is intact, even though its individual genes are also broken out.

Usage:
    ./combine_vista_reports.py /path/to/json_dir -o combined_reports.csv
"""

import argparse
import json
import sys
from pathlib import Path

import pandas as pd


def sample_id_from_filename(path):
    stem = path.stem  # e.g. "Sample_S1_report" without the ".json" extension
    if stem.endswith("_vista"):
        stem = stem[: -len("_vista")]
    return stem


def flatten_one_report(path):
    with open(path) as f:
        data = json.load(f)

    row = {"serogroup": data.get("serogroup", "")}

    for marker in data.get("serogroupMarkers", []):
        col = f"marker_{marker['name']}"
        row[col] = "detected" if marker.get("matches") else "not_detected"

    # Top-level virulence genes
    for gene in data.get("virulenceGenes", []):
        row[gene["name"]] = gene.get("status", "")

    # Cluster-level completeness & every gene inside each cluster
    for cluster in data.get("virulenceClusters", []):
        row[f"cluster_{cluster['id']}"] = cluster.get("status", "")

        for gene_name, gene_info in cluster.get("matches", {}).items():
            row[gene_name] = gene_info.get("status", "")

    return row


def main():
    parser = argparse.ArgumentParser(
        description="Pivot per-sample vista JSON reports into one CSV file."
    )

    parser.add_argument(
        "json_files",
        nargs="+",
        help="One or more per-sample JSON report files"
    )

    parser.add_argument(
        "-o",
        "--output",
        default="combined_virulence.csv",
        help="Output CSV path"
    )

    args = parser.parse_args()

    json_files = [Path(f) for f in args.json_files]

    missing = [str(f) for f in json_files if not f.exists()]
    if missing:
        print("The following input files do not exist:", file=sys.stderr)
        for f in missing:
            print(f"  {f}", file=sys.stderr)
        sys.exit(1)

    rows = []

    for path in sorted(json_files):
        sample_id = sample_id_from_filename(path)
        print(f"Processing {path.name} -> sample_id = {sample_id}")

        row = flatten_one_report(path)
        row = {"sample_id": sample_id, **row}
        rows.append(row)

    df = pd.DataFrame(rows)
    df.to_csv(args.output, index=False)

    print(f"\nWrote {len(df)} row(s), {len(df.columns)} column(s) to {args.output}")


if __name__ == "__main__":
    main()
