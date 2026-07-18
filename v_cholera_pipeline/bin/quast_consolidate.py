#!/usr/bin/env python3

def combine_quast_reports(input_paths, output_file):
    from clean_names import clean_names
    import os
    import csv
    all_data = {}
    headers = []

    for input_path in sorted(input_paths):
        if os.path.isdir(input_path):
            tsv_file = os.path.join(input_path, "transposed_report.tsv")
            sample_name = os.path.basename(input_path).replace('_quast', '')
        else:
            tsv_file = input_path
            sample_name = os.path.basename(os.path.dirname(input_path)).replace('_quast', '')
            if not sample_name:
                sample_name = os.path.splitext(os.path.basename(input_path))[0]

        if os.path.exists(tsv_file):
            with open(tsv_file, 'r') as f:
                reader = csv.reader(f, delimiter='\t')
                data = list(reader)
                if len(data) >= 2:
                    if not headers:
                        headers = ['sample_id'] + data[0][13:]
                        headers = clean_names(headers)
                    all_data[sample_name] = data[1][13:]

    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f, delimiter=',')
        if headers:
            writer.writerow(headers)
            for sample, values in sorted(all_data.items()):
                writer.writerow([sample] + values)
        else:
            writer.writerow(["No QUAST reports found"])

def main():
    import sys
    if len(sys.argv) < 3:
        print("Usage: python3 quast_consolidate.py <quast_dir1> [<quast_dir2> ...] <output_file>")
        sys.exit(1)
    output_file = sys.argv[-1]
    input_paths = sys.argv[1:-1]
    combine_quast_reports(input_paths, output_file)

if __name__ == "__main__":
    main()