#!/usr/bin/env nextflow

// Basic file validation of input files
process VALIDATE_READS {

    tag "$sample_id"

    input:
    tuple val(sample_id), path(read1), path(read2)

    output:
    tuple val(sample_id), path(read1), path(read2), path('status.txt'), emit: validated

    script:
    """
    validate_reads.sh "${read1}" "${read2}"
    """
}
