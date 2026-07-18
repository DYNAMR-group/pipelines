/*
* Run quast on assembled genomes -> fasta files
*/
process RUN_QUAST {

    tag "${sample_id}"
    
    input: 
    tuple val (sample_id), path (fasta)

    output: 
    tuple val(sample_id), path("${sample_id}_quast"), emit: quast_output
    path "${sample_id}_quast", emit: report_directory
    
    script:
    """
    quast.py ${fasta} -o ${sample_id}_quast
    """
}

process COMBINED_QUAST {
    
    input: 
    path (quast_dirs)

    output: 
    path "assembly_quast_report.csv", emit: quast_report
    
    script:
    """
    quast_consolidate.py ${quast_dirs.join(' ')} assembly_quast_report.csv
    """
}