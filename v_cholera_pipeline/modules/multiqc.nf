#!/usr/bin/env nextflow

/*
 * Aggregate QC reports with MultiQC
 */
process MULTIQC {

    //container "community.wave.seqera.io/library/pip_multiqc:a3c26f6199d64b7c"

    input:
    path '*'
    val qc_reports

    output:
    path "${qc_reports}.html", emit: html
    path "${qc_reports}_data", emit: data

    script:
    """
    multiqc . -n ${qc_reports}.html
    """
}
