#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
* Module includes
* Check script: nextflow lint main.nf
*/
include { VALIDATE_READS } from './modules/validate_reads.nf'
include { TRIM_GALORE } from './modules/trim_galore_fastqc.nf'
include { TRIMMOMATIC } from './modules/trimmomatic.nf'
//include { FASTQC } from './modules/fastqc.nf'
include { MULTIQC } from './modules/multiqc.nf'
include { ASSEMBLE } from './modules/assembly.nf'
include { RUN_QUAST } from './modules/quast.nf'
include { COMBINED_QUAST } from './modules/quast.nf'
include { FILTER_ASSEMBLIES } from './modules/filter_assemblies.nf'
include { RUN_VISTA } from './modules/run_vista.nf'
include { COMBINE_VISTA_REPORTS } from './modules/run_vista.nf'

/*
* Define input parameters
*/
params {
    // Input 
    input: Path

    // Trimmomatic settings
    threads: Integer = 2
    adapters: Path = "${System.getenv('EBROOTTRIMMOMATIC')}/adapters/TruSeq3-PE.fa"
    phred: Integer = 33
    slidingwin: String = "4:20"
    leading: Integer = 3
    trailing: Integer = 3
    minlen: Integer = 30
    illuminaclip: String = "2:30:10"

       // Report ID
    report_id: String
}

/*
* Define workflow block
*/
workflow {

    main:
    // Create input channel from a file path
    reads_ch = channel.fromPath(params.input)
                    .splitCsv(header: true)
                    .map { row -> tuple(row.sample, file(row.read1), file(row.read2)) }
                    
    VALIDATE_READS(reads_ch)

    // Collect validated reads
    validated_ch = VALIDATE_READS.out.validated

    validated = validated_ch.branch { sample_id, read1, read2, status_file ->

        valid: status_file.text.trim() == 'VALID'

        invalid: status_file.text.trim() != 'VALID'
    }

    // Collect just the sample IDs for invalid and valid pairs
    invalid_samples_file = validated.invalid
        .map { sample_id, read1, read2, status_file -> sample_id }
        .collectFile(
            name: 'invalid_samples.txt',
            newLine: true
        )

    valid_samples_file = validated.valid
        .map { sample_id, read1, read2, status_file -> sample_id }
        .collectFile(
            name: 'valid_samples.txt',
            newLine: true
        )

    // Send only valid reads to Trimmomatic.
    // TRIMMOMATIC expects tuple(sample_id, read1, read2) -- validated.valid
    // carries a 4th element (status_file) that must be dropped first, and
    // all of Trimmomatic's other required inputs must be supplied here too.
    trimmomatic_input_ch = validated.valid
        .map { sample_id, read1, read2, status_file -> tuple(sample_id, read1, read2) }

    // Run the TRIM_GALORE process for all reads in the channel
    TRIM_GALORE(reads_ch)

    // Run the MULTIQC process for all trimming reports from TRIM_GALORE
    multiqc_results_ch = channel.empty().mix(
        TRIM_GALORE.out.fastqc_report_1,
        TRIM_GALORE.out.fastqc_report_2,
        )

    multiqc_results_list = multiqc_results_ch.collect()
    MULTIQC(multiqc_results_list, params.report_id)

    // Run Trimmomatic for all reads in the channel
     TRIMMOMATIC(
         trimmomatic_input_ch, 
         params.threads, 
         params.adapters,
         params.phred, 
         params.slidingwin,
         params.leading, 
         params.trailing, 
         params.minlen, 
         params.illuminaclip
         )

    // Run FASTQC process on all trimmed Reads from TRIMMOMATIC
    //FASTQC(TRIMMOMATIC.out.trimmed_reads)

    // Run MULTIQC on FASTQC output
    //MULTIQC(multiqc_results_ch.collect(), params.report_id)
    
    // Run the ASSEMBLE process for all QC'd reads from TRIMMOMATIC
    ASSEMBLE(TRIMMOMATIC.out.trimmed_reads)

    // Run the FILTER_ASSEMBLIES process for all contigs 
    // and scaffolds from ASSEMBLE
    FILTER_ASSEMBLIES(ASSEMBLE.out.assembly)
    
    // Run Quast on assembled genomes
    //fasta_ch = channel.fromPath("${params.input}/*.fasta")
    //.map { fasta ->
     //   tuple(fasta.baseName, fasta)
    //}

    RUN_QUAST(FILTER_ASSEMBLIES.out.scaffolds)
    COMBINED_QUAST(RUN_QUAST.out.report_directory.collect())

    // Run the runVista process for all contigs from FILTER_ASSEMBLIES
    RUN_VISTA(FILTER_ASSEMBLIES.out.scaffolds)

    COMBINE_VISTA_REPORTS(RUN_VISTA.out.vista_results.collect())

    publish:
    // Publish the output files to the results directory
    valid_samples = valid_samples_file
    invalid_samples = invalid_samples_file
    trimmed_reads = TRIM_GALORE.out.trimmed_reads
    trimming_reports = TRIM_GALORE.out.trim_reports
    multiqc_html = MULTIQC.out.html
    multiqc_data = MULTIQC.out.data
    trimmed_reads_trimmomatic = TRIMMOMATIC.out.trimmed_reads
    trimmomatic_log = TRIMMOMATIC.out.trimmmoatic_log 
    spades_log = ASSEMBLE.out.log_file
    contigs = FILTER_ASSEMBLIES.out.contigs
    scaffolds = FILTER_ASSEMBLIES.out.scaffolds
    quast_reports = RUN_QUAST.out.quast_output
    combined_quast_reports = COMBINED_QUAST.out.quast_report   
    vista_reports = RUN_VISTA.out.vista_results 
    vista_report = COMBINE_VISTA_REPORTS.out.csv
}

/*
* Define output block
*/
output{
    valid_samples {
        path 'valid_samples'
    }
    invalid_samples {
        path 'invalid_samples'
    }
    trimmed_reads {
        path 'trimmed_reads'
    }
    trimming_reports {
        path 'trimming_reports'
    }
    multiqc_html {
        path 'multiqc'
    }
    multiqc_data {
        path 'multiqc'
    }
    trimmed_reads_trimmomatic {
        path 'trimmed_reads_trimmomatic'
     }
    trimmomatic_log {
        path 'trimmomatic_log'
     }
    contigs {
        path 'contigs'
    }
    scaffolds {
        path 'scaffolds'
    }
    spades_log {
        path 'contigs'
    }
    combined_quast_reports {
        path 'quast_report'
    }
    quast_reports {
        path 'quast_reports'
    }
    vista_reports {
        path 'vista_reports'
    }
    vista_report {
        path '.'
    }
}

