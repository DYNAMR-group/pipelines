#!/usr/bin/env nextflow

/*
* FASTQC process to run after trimmomatic
* This process will run FASTQC on the trimmed reads and generate a report
*/

process FASTQC {
    tag "$sample_id"

    input:
    tuple val(sample_id), path(reads)

    output:
    path "${sample_id}_fastqc.html", emit: fastqc_html
    path "${sample_id}_fastqc.zip", emit: fastqc_zip

    script:
    """
    fastqc -o . ${reads}
    """
}
