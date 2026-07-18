#!/usr/bin/env nextflow

/* 
* Process: FILTER_ASSEMBLIES
* Description: Filter assembled contigs and scaffolds based on length.
* Inputs: ASSEMBLY process outputs (ASSEMBLE.out)
*   - contigs: Path to the assembled contigs FASTA file
*   - scaffolds: Path to the assembled scaffolds FASTA file
* Outputs:
*   - contigs: Published in a contigs directory
*   - scaffolds: Published in a scaffolds directory
*   -log_file: Published in a contigs directory
*/

process FILTER_ASSEMBLIES {

    input:
    tuple val(sample_id), path(contigs), path(scaffolds)

    output:
    tuple val(sample_id), path("${sample_id}_contigs.fasta"), emit: contigs
    tuple val(sample_id), path("${sample_id}_scaffolds.fasta"), emit: scaffolds

    script:
    """
    contigs_filter.py "${contigs}" "${sample_id}_contigs.fasta"
    contigs_filter.py "${scaffolds}" "${sample_id}_scaffolds.fasta"
    """
}