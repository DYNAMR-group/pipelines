#!/usr/bin/env python3

"""
Scan FastQC zip outputs and print each summary.txt contents.

Searches recursively for .zip files, opens each archive, locates the
`summary.txt` file (commonly stored under `<sample>_fastqc/summary.txt`),
and prints the parsed summary lines prefixed by the archive path.

Usage:
    python check_fastqc.py --input path/to/fastqc_outputs

Example:
    python check_fastqc.py -i data/fastqc_results
"""

import os
import zipfile
import argparse
from typing import Optional


def find_zip_files(root: str):
	for dirpath, _, filenames in os.walk(root):
		for fn in filenames:
			if fn.lower().endswith('.zip'):
				yield os.path.join(dirpath, fn)


def read_summary_from_zip(zip_path: str) -> Optional[str]:
	try:
		with zipfile.ZipFile(zip_path, 'r') as z:
			# Look for any entry ending with summary.txt
			for name in z.namelist():
				if name.lower().endswith('summary.txt'):
					with z.open(name) as fh:
						return fh.read().decode('utf-8')
	except zipfile.BadZipFile:
		print(f'Warning: Bad zip file: {zip_path}')
	return None


def parse_and_print_summary(zip_path: str, summary_text: str) -> None:
	print(f'== {zip_path} ==')
	for line in summary_text.strip().splitlines():
		# Summary lines are like: PASS\tPer base sequence quality\tfilename
		parts = line.split('\t')
		if len(parts) >= 3:
			status, test, filename = parts[0], parts[1], parts[2]
			print(f'{status}\t{test}\t{filename}')
		else:
			print(line)


def main():
	p = argparse.ArgumentParser(description='Scan FastQC zip files and print summary.txt')
	p.add_argument('--input', '-i', default='.', help='Directory to scan for .zip files')
	args = p.parse_args()

	if not os.path.isdir(args.input):
		raise SystemExit(f'Input directory not found: {args.input}')

	found = False
	for zip_path in find_zip_files(args.input):
		found = True
		summary = read_summary_from_zip(zip_path)
		if summary:
			parse_and_print_summary(zip_path, summary)
		else:
			print(f'No summary.txt found in {zip_path}')

	if not found:
		print('No .zip files found')


if __name__ == '__main__':
	main()

