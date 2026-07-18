library(janitor)
library(tidyverse)

# Load datasets for processing

# 1: AMRfinder data
amr_data = read_tsv("amrfinder/amrfinderplus_results.tsv",
                    show_col_types = FALSE)

# 2: Mob_recon data
mob_data = read_tsv("mobsuite_reports/contig_report_all.tsv", 
                    show_col_types = FALSE)

# 3: Plasmid ID data from mob_recon
mob_ids = read_tsv("mobsuite_reports/plasmid_ids.tsv", 
                       show_col_types = FALSE)

# 4: ICE data from kma
ice_data = read_csv("metadata_files/combined_presence_absence_matrix.csv",
               show_col_types = FALSE)

# Clean data and extract contig IDs

# Regex breakdown:
# ^([^_]+_[^_]+) matches everything from the start up to the second underscore
# .* matches everything after it
# \\1 replaces the whole string with just the matched part inside the parentheses

# Get plasmid IDs
plasmid_ids = clean_names(mob_ids) %>%
  mutate(contig_id = str_replace(contig_id, "^([^_]+_[^_]+).*", "\\1")) %>%
  mutate(contig = paste(sample, contig_id, sep = "_")) %>%
  select(label = sample, unique_plasmid_id, contig) 

# Get actual plasmid report data from mob_recon
plasmid_data = clean_names(mob_data) %>%
  mutate(contig_id = str_replace(contig_id, "^([^_]+_[^_]+).*", "\\1")) %>%
  mutate(contig = paste(sample, contig_id, sep = "_")) %>%
  select(label = sample, molecule_type, contig, size, replicon = rep_type_s)

# Assign plasmid IDs to plasmid report data
plasmids_with_ids = plasmid_data %>%
  left_join(plasmid_ids, by = c("contig", "label"))

# Create a plasmid replicon lookup table
replicons = plasmids_with_ids %>%
  filter(
    !is.na(unique_plasmid_id), # Removes chromosome contigs
    !is.na(replicon)
    ) %>%
  select(
    unique_plasmid_id,
    replicon_contig = contig, # Rename for easy identification
    plasmid_replicon = replicon,
    contig_size = size
  )

# Clean and prepare AMR data
amr = clean_names(amr_data) %>%
  rename(label = assembly_id, gene = element_symbol) %>%
  mutate(length = as.numeric(str_extract(contig_id, "(?<=length_)\\d+(?=_cov)"))) %>%
  relocate(length, .after = 3) %>%
  mutate(contig_id = str_replace(contig_id, "^([^_]+_[^_]+).*", "\\1")) %>%
  mutate(contig = paste(label, contig_id, sep = "_")) %>% # For easy identification
  filter(type == "AMR") %>% # Only get AMR genes
  select(label, contig, length, gene, subclass) %>%
  mutate(present = 1) %>%
  mutate(present = factor(present)) %>%
  separate_longer_delim(subclass, delim = "/") 

# Join AMR data with plasmid data to assess association
# All chromosome contigs will not have a unique plasmid ID (NA)
amr_plasmid_combined = left_join(
  amr, plasmids_with_ids, by = c("label", "contig")) %>%
  relocate(size, .after = 3) %>%
  relocate(unique_plasmid_id, .after = 2) %>%
  relocate(replicon, .after = 6)

# Join the dataset with the replicon lookup to retain replicon contig IDs
amr_rep_contigs = amr_plasmid_combined %>%
  left_join(
    replicons,
    by = "unique_plasmid_id"
  ) %>%
  mutate(
    replicon_status = case_when(
      molecule_type == "chromosome" ~ "Chromosome",
      !is.na(plasmid_replicon) & plasmid_replicon != "-" ~ plasmid_replicon,
      TRUE ~ "Plasmid_No_Replicon"
    )
  )

# View(amr_rep_contigs)

# Prepare wide format for gheatmap (Drug Subclasses)
amr_wide = amr_rep_contigs %>%
  select(label, gene, subclass, present, replicon_status) %>%
  mutate(present = as.numeric(as.character(present))) %>%
  group_by(label, subclass) %>%
  summarise(present = as.integer(max(present)), .groups = "drop") %>%
  pivot_wider(
    names_from = subclass,
    values_from = present,
    values_fill = 0
  ) %>%
  column_to_rownames("label")

# AMR genes for Heatmap
# Assign gene location and get wide dataset
amr_gene_loc = amr_rep_contigs %>%
  filter(present == 1) %>%
  group_by(label, gene) %>%
  summarise(
    state = case_when(
      any(replicon_status == "IncC") ~ "IncC Plasmid",
      
      any(replicon_status == "Col3M") ~ "Col3M Plasmid",
      
      any(replicon_status == "Plasmid_No_Replicon") ~ "Unknown Plasmid",
      
      any(replicon_status == "Chromosome") ~ "Chromosome",
      
      TRUE ~ "Unknown"
    ),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = gene,
    values_from = state,
    values_fill = "Absent"
  ) %>%
  column_to_rownames("label")

# Sort data in decreasing order for clean heatmap
totals = colSums(amr_gene_loc != "Absent")

sorted_amr_gene_loc = amr_gene_loc[, 
                                    order(-totals, colnames(amr_gene_loc)),
                                    drop = FALSE]


# Process ICE data VC1786ICE, PM19 CTX Phage, ICEVchban5
transposed_data = ice_data %>%
  mutate(ice_sequence = sub("\\..*", "", ice_sequence)) %>%
  pivot_longer(
    cols = -ice_sequence, 
    names_to = "label", 
    values_to = "value") %>%
  pivot_wider(
    names_from = ice_sequence, 
    values_from = value, 
    values_fn = max) %>%
  column_to_rownames("label") %>%
  select(JN648379, KJ540278, GQ463140) %>%
  rename(
    VC1786ICE = JN648379,
    "PM19 CTX Phage" = KJ540278,
    ICEVchban5 = GQ463140
    )

# Sort data in decreasing order for a heatmap
sorted_ice_data = transposed_data[, order(colSums(transposed_data), decreasing = TRUE)]

sorted_ice_data[] = lapply(sorted_ice_data, factor,
                      levels = c(0,1),
                      labels = c("Absent","Present"))


# Source tree data
source("plot_tree.R")

# Attach AMR heatmap to tree
p_genes = gheatmap(
  ps4,
  sorted_amr_gene_loc,
  offset = 32, #0.35
  width = 1.9, #1.2
  color = NA,
  colnames_angle = 90,
  colnames_position = "top",
  colnames_offset_y = 1,
  font.size = 9,
  hjust = 0
) +
  scale_fill_manual(
    values = c(
      "Absent" = "#f7f7f7", 
      "Chromosome" = "#2166ac", #"#E41A1C"
      "Unknown Plasmid" = "#090909",
      "Col3M Plasmid" = "#FF7F00",
      "IncC Plasmid" ="#984EA3" # "#FF7F00" "#377EB8", "#4DAF4A", "#E41A1C", "#4D4D4D",
    ),
    name = "AMR GENE LOCATION"
  ) +
  new_scale_fill() 

print(p_genes)

ggsave(
  "IQtree2/plots/amr_genes_ordered.png",
  width = 28, height = 22, dpi = 300
)
  
p_ice = gheatmap(
    p_genes,
    sorted_ice_data,
    offset = tile_offset * 2.30, #1.6
    width = 0.26, #0.23
    color = NA,
    colnames_angle = 90,
    colnames_position = "top",
    colnames_offset_y = 1,
    font.size = 8,
    hjust = 0
  ) +
  scale_fill_manual(
    values = c(
      "Absent" = "#f7f7f7",
      "Present" = "#A32D2D" #"#ff9181"
    ),
    name = "ICE STATUS"
  ) +
  theme(
    plot.margin = margin(t = 85, r = 0, b = 5, l = 0, unit = "pt") #130
  )

print(p_ice)

ggsave(
  "iqtree_filtered_poly/plots/amr_genes_ice_ordered.png",
  width = 28, height = 22, dpi = 300
)