#!/usr/bin/env python3

import sys
from Bio import SeqIO

def filter_fasta(input_path, output_path):
    with open(output_path, 'w') as outfile:
        for seq in SeqIO.parse(input_path, 'fasta'):
            if len(seq) >= 500:
                SeqIO.write(seq, outfile, 'fasta')

if __name__ == '__main__':
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    filter_fasta(input_path, output_path)