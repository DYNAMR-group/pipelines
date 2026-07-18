#!/usr/bin/env bash
set -o pipefail

# Basic file validation of paired FASTQ input files:
#   - if gzipped, check gzip archive integrity first
#   - check that read length == quality-score length for every record
#   - report VALID, or INVALID:<reason(s)>, to status.txt
#
# Usage: validate_reads.sh <read1> <read2>

read_one="$1"
read_two="$2"

check_read () {
    local file="$1"
    case "$file" in
        *.gz)
            gzip -t "$file" && zcat "$file" | paste - - - - | \
                awk -F'\t' '{ if (length($2) != length($4)) exit 1 }'
            ;;
        *)
            paste - - - - < "$file" | \
                awk -F'\t' '{ if (length($2) != length($4)) exit 1 }'
            ;;
    esac
}

file_validity=""

check_read "$read_one" || file_validity+="READ_ONE_CORRUPTED;"
check_read "$read_two" || file_validity+="READ_TWO_CORRUPTED;"

if [[ -z "$file_validity" ]]; then
    status="VALID"
else
    file_validity="${file_validity%;}"
    status="INVALID:${file_validity}"
fi

echo "$status" > status.txt
