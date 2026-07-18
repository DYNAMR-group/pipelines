library(tidyverse)
library(readxl)
library(readr)
library(janitor)

# Check Assembly quality metrics (Quast + Checkm)
quast_report = read_csv("metadata_files/quast_full.csv", 
                        show_col_types = FALSE)

checkm_report = read_tsv("metadata_files/checkm_report.tsv", 
                         show_col_types = FALSE)

checkm = clean_names(checkm_report) %>%
  select(label = bin_id, marker_lineage, completeness,
         contamination, strain_heterogeneity)

good_quality = clean_names(quast_report) %>%
  select(label = sample, number_contigs, gc_percent,
         n50, l50, n90, l90, total_length) %>%
  left_join(checkm, by = 'label') %>%
  filter(!number_contigs > 500,
         !contamination > 5,
         !gc_percent < 45 & !gc_percent > 49)

# Mapping quality check
mapping_data = read_tsv("metadata_files/snippy_mapping_qc.tsv", 
                        show_col_types = FALSE)
mapping_qc = clean_names(mapping_data) %>%
  filter(genome_coverage > 70)
# Overall, good mapping QC 

# Virulence genes data processing from pathogenwatch
vista_file = read_csv("pathogenwatch/pathogenwatch-vista.csv", 
                      show_col_types = FALSE)
vista = clean_names(vista_file) %>%
  mutate(
    tcp_a = ifelse(!is.na(tcp_tcp_a), "Present", NA_character_)
  ) %>%
  select(label = genome_name, serogroup, ace, ctx_a, ctx_b, tcp_a)

# Abricate output from using the cholerafinder database
abricate_report = read_tsv("abricate/v_chol_summary.tsv", 
                           show_col_types = FALSE)

abricate = abricate_report %>%
  mutate(label = str_extract(label, "(?<=/)[\\w]+(?=\\.fasta)")) %>%
  select(label, `VC2346:1:AE003852`, starts_with("VSP"), starts_with("VPI"), 
         starts_with("ctx"), starts_with("tcp")) %>%
  rename(ctxA = starts_with("ctxA:"),
         ctxB1 = starts_with("ctxB_1"), ctxB3 = starts_with("ctxB_3"),
         ctxB7 = starts_with("ctxB_7"), tcpA = starts_with("tcpA"),
         VC2346 = `VC2346:1:AE003852`)

# Join with vista output to confirm and assign ctxB variants
abr_vista = left_join(vista, abricate, by = "label") %>%
  mutate(
    ctxb = case_when(
      ctx_b == "Present" & trimws(ctxB1) %in% c("100", "100.00;100.00") ~ "ctxB1",
      ctx_b == "Present" & trimws(ctxB3) == "100" ~ "ctxB3",
      ctx_b == "Present" & trimws(ctxB7) == "100" ~ "ctxB7",
      TRUE ~ ctx_b
    )
  ) %>%
  relocate(ctxb, .after = 5)

# Load lineage data from pathogenwatch
pwcore = read_csv("pathogenwatch/pathogenwatch-core.csv", 
                  show_col_types = FALSE)
core = clean_names(pwcore) %>%
  select(
    label = genome_name, core_lineage = pathogenwatch_reference
  )

# Call Script in plot_tree.R to merge with metadata.


# serotypes = read_tsv("metadata_files/all_ariba_serotypes.tsv", show_col_types = FALSE)
# 
# # Load plasmid data
# plasmidfinder = read_csv("pathogenwatch/pathogenwatch-plasmidfinder.csv", show_col_types = FALSE)
# plasmids = clean_names(plasmidfinder) %>%
#   select(
#     label = genome_name, inctype = inc_match, contig
#   )
# 
# ### PROCESS SEROTYPES DATA
# 
# # Check duplicates
# duplicates = serotypes %>%
#   group_by(sample) %>% 
#   filter(n() > 1) %>%
#   arrange(sample) %>%  # This clusters pairs together
#   ungroup()
# 
# # Handle Duplicates
# serotypes_cleaned = serotypes %>%
#   group_by(sample) %>% 
#   mutate(
#     serotype = if(n_distinct(serotype) == 1) first(serotype) else "undetermined"
#   ) %>%
#   # Keep only one row per ID
#   slice(1) %>%
#   ungroup() %>%
#   select(sample, serotype)