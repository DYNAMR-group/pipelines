
#!/usr/bin/env python3

"""
Create a filenames.csv file with the names of the fastq files.

Scans the input directory for FASTQ files and writes a CSV with three
columns: `sample`, `read1`, `read2` from read suffixes e.g.
_R1/_R2, _1/_2, or _R1_001/_R2_001.
"""

import os
import re
import csv
import argparse
from typing import Dict, Tuple
from pathlib import Path


# Match FASTQ file extensions such as .fastq, .fq, and their gzipped variants.
fastq_ext_re = re.compile(r"(?:\.fastq(?:\.gz)?|\.fq(?:\.gz)?)$", re.I)
# Detect read1 suffixes like _R1, _r1, or _1 at the end of the basename.
read1_re = re.compile(r"(?i)(_r?1(?:_|$)|_1(?:_|$))")
# Detect read2 suffixes like _R2, _r2, or _2 at the end of the basename.
read2_re = re.compile(r"(?i)(_r?2(?:_|$)|_2(?:_|$))")
# Remove optional lane tags (_L001) and trailing read suffixes from the sample key.
sample_strip_re = re.compile(r"(?i)(?:_L\d{3})?(?:_r?1(?:_\d+)?|_r?2(?:_\d+)?|_[12])$")


def sample_key(filename: str) -> str:
	"""Return the canonical sample key for a FASTQ filename.

	Removes known FASTQ extensions and trailing read suffixes such as
	"_R1", "_R2", "_1", "_2", and optional lane tags like "_L001".
	This normalized key is used to group paired reads by sample.
	"""
	name = fastq_ext_re.sub('', filename)
	key = sample_strip_re.sub('', name)
	return key


def classify_read(filename: str) -> str:
	"""Classify the FASTQ filename as read1 or read2.

	Returns 'read1' when the filename contains a read1-like suffix,
	'read2' when it contains a read2-like suffix, and defaults to
	'read1' when the suffix cannot be distinguished.
	"""
	name = fastq_ext_re.sub('', filename)
	if read1_re.search(name):
		return 'read1'
	if read2_re.search(name):
		return 'read2'
	# Assume untagged files are first reads by default.
	return 'read1'


def rename_lane_suffix_files(root: str) -> None:
	"""Rename FASTQ files that include lane/read serial suffixes or R1/R2 markers.

	Files such as sample_L001_R2_001.fastq.gz are converted to sample_2.fastq.gz.
	Files such as sample_R2.fastq.gz are also converted to sample_2.fastq.gz.
	"""
	root_path = Path(root)
	for path in sorted(root_path.rglob('*')):
		if not path.is_file():
			continue
		if not fastq_ext_re.search(path.name):
			continue

		# Try matching lane+read+serial suffix first
		match = re.match(r"(?i)(?P<prefix>.+)_L\d{3}_(?P<read>R?[12])_\d+(?P<ext>\.(?:fastq|fq)(?:\.gz)?)$", path.name)
		
		# If no match, try simple R1/R2 suffix
		if not match:
			match = re.match(r"(?i)(?P<prefix>.+)_(?P<read>R[12])(?P<ext>\.(?:fastq|fq)(?:\.gz)?)$", path.name)
		
		if not match:
			continue

		read_num = '1' if match.group('read').lower() in {'r1', '1'} else '2'
		new_name = f"{match.group('prefix')}_{read_num}{match.group('ext')}"
		new_path = path.with_name(new_name)
		if new_path != path:
			path.rename(new_path)


def gather_pairs(root: str) -> Dict[str, Tuple[str, str]]:
	"""Scan a directory tree and pair FASTQ files by sample key.

	Walks the input directory recursively using pathlib and collects files
	that match FASTQ extensions. Each sample key maps to a tuple of
	(read1, read2) with absolute filesystem paths.
	"""
	samples = {}
	root_path = Path(root).resolve()
	for path in sorted(root_path.rglob('*')):
		if not path.is_file():
			continue
		if not fastq_ext_re.search(path.name):
			continue

		# Normalize the sample name and determine whether this file is R1 or R2.
		key = sample_key(path.name)
		kind = classify_read(path.name)

		abs_path = str(path.resolve())

		# Store the pair as [read1, read2] so paths can be updated in place.
		pair = samples.setdefault(key, ["", ""])
		if kind == 'read1':
			pair[0] = abs_path
		else:
			pair[1] = abs_path
		samples[key] = pair
	return samples


def write_csv(samples: Dict[str, Tuple[str, str]], out_path: str) -> None:
	"""Write paired sample paths to a CSV file.

	Creates the output directory if needed and writes a header row
	followed by sorted sample records.
	"""
	os.makedirs(os.path.dirname(out_path) or '.', exist_ok=True)
	with open(out_path, 'w', newline='') as fh:
		writer = csv.writer(fh)
		writer.writerow(['sample', 'read1', 'read2'])
		for sample, (r1, r2) in sorted(samples.items()):
			writer.writerow([sample, r1, r2])


def main() -> None:
	"""Parse CLI arguments and generate the filenames CSV."""
	parser = argparse.ArgumentParser(description='Generate paired filenames CSV')
	parser.add_argument('--input', '-i', default='data', help='Directory to scan')
	parser.add_argument('--output', '-o', default=os.path.join('data', 'files.csv'), 
					 help='Output CSV path')
	args = parser.parse_args()

	if not os.path.isdir(args.input):
		raise SystemExit(f'Input directory not found: {args.input}')

	rename_lane_suffix_files(args.input)
	samples = gather_pairs(args.input)
	write_csv(samples, args.output)
	print(f'Wrote {len(samples)} samples to {args.output}')


if __name__ == '__main__':
	main()


