#!/usr/bin/env nextflow

/*
 * Process: ASSEMBLE
 * Description: Assemble raw sequence data into contigs and scaffolds using SPAdes.
 * Inputs:
 *   - read1: Path to the first paired-end FASTQ file
 *   - read2: Path to the second paired-end FASTQ file
 * Outputs:
 *   - assembly_dir: Path to the assembly directory
 *   - contigs: Path to the assembled contigs FASTA file
 *   - scaffolds: Path to the assembled scaffolds FASTA file
 */

process ASSEMBLE {

    tag "Assembling: ${sample_id}"

    input:
    tuple val(sample_id), path(read1), path(read2)

    output:
    tuple val(sample_id), path("${sample_id}/spades.log"), emit: log_file
    tuple val(sample_id), path("${sample_id}/contigs.fasta"), 
                            path("${sample_id}/scaffolds.fasta"), emit: assembly

    script:
    """
    spades.py \\
    -1 ${read1} \\
    -2 ${read2} \\
    -o ${sample_id} \\
    --isolate
    """
}
