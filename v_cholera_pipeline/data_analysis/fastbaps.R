library(tidyverse)
library(vegan)
library(ape)
library(fastbaps)
library(janitor)

# ************FASTBAPS CLUSTERING ***************

# Load metadata
metadata = read_csv("IQtree2/cleaned_metadata.csv", show_col_types = FALSE)

# Load Filtered Alignment
filtered_aln_file = "IQtree2/filtered.aln"

if (!file.exists(filtered_aln_file)) {
  
  # Load SNP alignment
  aln = read.dna(
    "IQtree2/gubbins.filtered_polymorphic_sites.fasta",
    format = "fasta"
  )
  
  # Samples to process
  keep_samples = metadata$label
  
  # Keep only samples present in the metadata
  aln2 = aln[rownames(aln) %in% keep_samples, ]
  
  write.dna(
    aln2,
    file = filtered_aln_file,
    format = "fasta",
    nbcol = -1,
    colsep = ""
  )
  
  message("Created: ", filtered_aln_file)
  
} else {
  
  message("Using existing alignment: ", filtered_aln_file)
  
}

# Read alignment in fastbaps
# import_fasta_sparse_nt: Only reads the SNPs -> Faster
sparse_aln = import_fasta_sparse_nt("IQtree2/filtered.aln") 

# use multi_res_baps to load more cluster levels
multi_hc = multi_res_baps(sparse_aln)

# Prepare data
clusters = clean_names(multi_hc) %>%
  rename(
    label = isolates
  )

# Function to process cluster outcomes properly: cluster size, label, etc
label_clusters = function(data, level_col, min_size = 2) {
  
  cluster_sizes = data %>%
    group_by(.data[[level_col]]) %>%
    summarise(size = n(), .groups = "drop")
  
  selected_clusters = cluster_sizes %>%
    filter(size >= min_size) %>%
    pull(.data[[level_col]])
  
  data = data %>%
    left_join(cluster_sizes, by = setNames(level_col, level_col))
  
  group_col = paste0(level_col, "_group")
  label_col = paste0(level_col, "_label")
  
  data[[group_col]] = ifelse(
    data[[level_col]] %in% selected_clusters,
    paste0("Cluster_", data[[level_col]]),
    "Other"
  )
  
  data[[label_col]] = ifelse(
    data[[group_col]] == "Other",
    "Other",
    paste0(data[[group_col]], " (n=", data$size, ")")
  )
  
  data
}

all_clusters = clusters %>%
  label_clusters("level_1") %>%
  rename(level_1_size = size) %>%
  label_clusters("level_2") %>%
  rename(level_2_size = size)


# Merge metadata first
meta_data_list = list(
  metadata,
  all_clusters
)

meta_data_clusters = meta_data_list %>% 
  reduce(left_join, by = "label")

write_csv(meta_data_clusters, "IQtree2/metadata_with_fbaps_clusters.csv")


# Rarefaction Curve from fastBAPS Cluster Assignments (with 95% CI from resampling)

set.seed(100)  # reproducible random sampling

cluster_vec = meta_data_clusters$level_2  # cluster label per isolate
n = length(cluster_vec) # total number of isolates
n_reps = 500 # resampling repeats per sample size

# Sample sizes to test: every 4th isolate count, plus the full set
sizes = unique(c(seq(1, n, by = 4), n))

# Sample without replacement: repeatedly subsample k isolates
# and count how many unique clusters
rarefaction_df = do.call(rbind, lapply(sizes, function(k) {
  
  # replicate returns a vector of length n_reps: unique-cluster counts
  n_unique = replicate(n_reps, {
    samp = sample(cluster_vec, k, replace = FALSE)
    length(unique(samp))
  })
  
  data.frame(
    sampled = k,
    mean_clusters = mean(n_unique),
    lower = quantile(n_unique, 0.025), # At 2.5% error rate from 95% CI
    upper = quantile(n_unique, 0.975)
  )
}))

# -----------------------------------
# Plot rarefaction curve
# -----------------------------------

ggplot(rarefaction_df, aes(x = sampled, y = mean_clusters)) +
  geom_line(
    color = "#009E73", #"#0072B2"
    linewidth = 1.1
  ) +
  
  theme_minimal(base_size = 13) +
  
  labs(
    title = "Rarefaction Curve of fastBAPS Cluster Diversity",
    subtitle = "Expected clusters with increasing sampling",
    x = "Number of Isolates Sampled",
    y = "Observed Unique Clusters"
  ) +
  
  scale_x_continuous(
    # limits = c(0, max(rare_df$sampled)),
    breaks = seq(1, max(rarefaction_df$sampled), by = 50),
    expand = expansion(mult = c(0.01, 0.08))
  ) +
  
  scale_y_continuous(
    limits = c(0, max(rarefaction_df$upper)),
    breaks = seq(0, max(rarefaction_df$upper), by = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  
  theme(axis.text = element_text(size = 16)) +
  
  theme(
    plot.title = element_text(
      hjust = 0.5,
      face = "bold",
      size = 16
    ),
    plot.subtitle = element_text(
      hjust = 0.5,
      size = 13,
      color = "grey35"
    ),
    axis.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(), # Remove minor grid lines
    panel.grid.major = element_line(color = "grey88"),
    plot.margin = margin(10, 20, 10, 10)
  )

# ggsave(
#   "iqtree_filtered_poly/plots/rarefaction-plot-new.png",
#   width = 10, height = 8, dpi = 300
# )
