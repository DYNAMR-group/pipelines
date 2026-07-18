#!/usr/bin/env nextflow

/*
* Trim adaptors with trim_galore and run fastqc
*/
process TRIM_GALORE {

    input:
    // Define input channel for paired-end reads
    tuple val(sample_id), path(read1), path(read2)

    output:
    // Define output channels for trimmed reads and fastqc reports
    tuple val(sample_id), path("*_val_1.fq.gz"), path("*_val_2.fq.gz"), emit: trimmed_reads
    path "*_trimming_report.txt", emit: trim_reports
    path "*_1_fastqc.{zip,html}", emit: fastqc_report_1
    path "*_2_fastqc.{zip,html}", emit: fastqc_report_2

    script:
    // Define the command to run trim_galore with fastqc for paired-end reads
    """
    trim_galore --fastqc -q 20 --paired ${read1} ${read2}
    """
}