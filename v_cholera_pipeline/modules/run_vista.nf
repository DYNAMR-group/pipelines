/*
* Identify virulence genes using the vista package from pathogenwatch
*/
process RUN_VISTA {

    //container "${projectDir}/containers/vista.sif" // -> defined in nextflow.config

    input:
    tuple val(sample_id), path(fasta)

    output:
    path "${sample_id}_vista.json", emit: vista_results

    script:
    """
    vista search ${fasta} > ${sample_id}_vista.json
    """
}

process COMBINE_VISTA_REPORTS {
    // Concatenate vista json reports to one csv file
    
    input:
    path (vista_json)
    
    output:
    path ("vista.csv"), emit: csv
    
    script:
    """
    combine_vista_reports.py ${vista_json} -o vista.csv
    """
}