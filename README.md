# DYNAMR pipelines

Nextflow pipelines maintained by the [DYNAMR](https://github.com/DYNAMR-group/dynamr)
group at the Malawi Liverpool Wellcome Research Programme. One folder per
pipeline.

## Pipelines

| Pipeline | Description |
|----------|-------------|
| [`DLBCL_Structural_Analysis`](DLBCL_Structural_Analysis) | Snakemake pipeline for DLBCL analysis |
| [`ena-fetch`](ena-fetch) | Download FASTQ reads from ENA by accession, verify checksums, optional FastQC/MultiQC |
| [`v-cholera-pipeline`](v_cholera_pipeline) | Run illumina read data |

## Adding a pipeline

1. Create a folder named after your pipeline
2. Add `main.nf`, `nextflow.config`, and a `README.md`
3. Include `nextflow.config`
4. Open a pull request
