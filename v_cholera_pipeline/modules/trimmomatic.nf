#!/usr/bin/env nextflow

process TRIMMOMATIC {
input:
    // Define input channel for paired-end reads
    tuple val(sample_id), path(read1), path(read2)
    val threads
    path adapters
    val phred
    val slidingwin
    val leading
    val trailing
    val minlen
    val illuminaclip

    output:
    // Define output channels for trimmed reads and fastqc reports
    tuple val(sample_id), path("${sample_id}_1.trimmed.paired.fq.gz"), path("${sample_id}_2.trimmed.paired.fq.gz"), emit: trimmed_reads
    tuple val(sample_id), path("${sample_id}_1.trimmed.unpaired.fq.gz"), path("${sample_id}_2.trimmed.unpaired.fq.gz"), emit: unpaired_reads
    path "${sample_id}.trimmomatic.log", emit: trimmmoatic_log

    script:
    def trimmomatic = "java -jar \$EBROOTTRIMMOMATIC/trimmomatic-0.39.jar"
    // def sample_id = read1.simpleName.replaceAll(/_1$/, '')
    """
    ${trimmomatic} PE \\
    -phred${phred} \\
    ${read1} ${read2} \\
    ${sample_id}_1.trimmed.paired.fq.gz ${sample_id}_1.trimmed.unpaired.fq.gz \\
    ${sample_id}_2.trimmed.paired.fq.gz ${sample_id}_2.trimmed.unpaired.fq.gz \\
    ILLUMINACLIP:${adapters}:${illuminaclip} \\
    LEADING:${leading} \\
    TRAILING:${trailing} \\
    SLIDINGWINDOW:${slidingwin} \\
    MINLEN:${minlen} \\
    2> ${sample_id}.trimmomatic.log
    """
}
