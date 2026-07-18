library(tidyverse)
library(ggtree)
library(ggtreeExtra)
library(ape)
library(treeio)
library(ggnewscale)
library(ggsci)
library(scales)

source("colors.R")
source("metrics_data.R")

# Load metadata first
meta = read_csv("IQtree2/metadata_with_fbaps_clusters.csv", 
                    show_col_types = FALSE)

datasets = list(meta, core, abr_vista)

metadata = datasets %>%
  reduce(left_join, by = "label")

# Load the tree
tree_original = read.tree("IQtree2/gubbins.node_labelled.final_tree.tre")

# Root on outgroup
rooted = root(tree_original, 
              outgroup = "v_mimicus", 
              resolve.root = TRUE)

# Get metadata tips (sample IDs)
tips_to_keep = metadata[["label"]]

# Get samples to drop from tree, including outgroup
tips_to_drop = setdiff(rooted$tip.label, tips_to_keep)

# Drop tips (get pruned tree)
pruned = drop.tip(rooted, tips_to_drop)

# Save pruned tree
write.tree(pruned, file = "IQtree2/rooted_tree.nwk")

# Get per cluster tip labels, for clade highlighting if necessary:
cluster_tips = metadata %>%
  group_by(level_2) %>%
  summarise(tips = list(as.character(label))) %>%
  deframe()

# Nodes wrapper
highlight_nodes = function(nodes, ...) {
  lapply(nodes, function(n) geom_hilight(node = n, ...))
}

# Load cleaned tree
tree_cleaned = read.tree("IQtree2/rooted_tree.nwk")

p = ggtree(
  tree_cleaned, 
  ladderize = TRUE, 
  right = FALSE,
  linewidth = 0.2
  ) %<+% metadata

#print(p)
 
# Get tree/branch lengths scale label 
ps = p +
  geom_treescale(
    x = max(p$data$x) * 0.005, # x,y coordinate scale position
    y = min(p$data$y) + 100,
    fontsize = 6,    
    linesize = 0.8
  ) +

# Assign tip labels to clusters  
  geom_tippoint(
    aes(color = as.factor(level_1)),
    size = 4,
    alpha = 0.9
  ) +
  
  scale_color_manual(
    values = pal_npg("nrc", alpha = 0.8)(10)[1:6], #distr_colors,
    name = "fastBAPS CLUSTERS",
    breaks = as.character(sort(unique(metadata$level_1))),
    labels = paste0("Cluster ", sort(unique(metadata$level_1))),
    guide = "none"
    # guide = guide_legend(
    #   ncol = 2,
    #   byrow = TRUE,
    #   order = 1,
    #   override.aes = list(size = 4, alpha = 1)
    ) +
  
  #theme_tree2() +
  
  # Add universal theme settings
  theme(
    legend.position = "right",
    legend.title = element_text(size = 24, face = "bold"),
    legend.text = element_text(size = 21),
    
    legend.key.height = unit(0.7, "cm"),
    legend.key.width  = unit(0.4, "cm"),
    
    legend.spacing = unit(0.7, "cm"),
    legend.spacing.x = unit(0.5, "cm")
  ) +
  coord_cartesian(clip = "off") +
  ylim(0, max(p$data$y) + 15)

print(ps)

tree_xmin = min(p$data$x)
tree_xmax = max(p$data$x)
tree_width = tree_xmax - tree_xmin

gap_space = 0.04 # Space between annotation tiles and tree figure (4%)
tree_fig_frac = 0.03 # 3% of tree figure size

tile_start = tree_xmax + gap_space * tree_width
tile_end = tile_start + tree_fig_frac * tree_width
tile_size = tile_end - tile_start

ps1 = ps +
  new_scale_fill() +
  
  # Tile -> variable to plot in "mapping"
  geom_fruit(
    geom = geom_tile,
    mapping = aes(y = label, fill = as.factor(year)),
    width = tile_size,
    offset = gap_space
  ) +
  
  # Tile color control
  scale_fill_manual(
    values = year_colors,
    guide = guide_legend(ncol = 2, byrow = TRUE, order = 2),
    name = "YEAR",
    na.translate = FALSE
  ) +
  
  # Tile title/label annotation
  annotate(
    "text",
    x = max(p$data$x) * 1.04,
    y = max(p$data$y) + 2,
    label = "YEAR",
    angle = 90,
    size = 8,
    hjust = 0
  )

#print(ps1)

ps2 = ps1 +
  new_scale_fill() +
  geom_fruit(
    geom = geom_tile,
    mapping = aes(y = label, fill = lineage),
    width = tile_size,
    offset = gap_space
  ) + 
  scale_fill_manual(
    values = pal_npg("nrc", alpha = 0.8)(10)[1:6],
    guide = guide_legend(ncol = 1, byrow = TRUE, order = 2),
    name = "LINEAGE",
    na.translate = FALSE
  ) +
  
  annotate(
    "text",
    x = max(p$data$x) * 1.08,
    y = max(p$data$y) + 2,
    label = "LINEAGE",
    angle = 90,
    hjust = 0,
    size = 8
  )

#print(ps2)

ps3 = ps2 +
  ggnewscale::new_scale_fill() +
  geom_fruit(
    geom = geom_tile,
    mapping = aes(y = label, fill = ctxb),
    width = tile_size,
    offset = gap_space
  ) + 
  scale_fill_manual(
    values = ctxb_colors,
    guide = guide_legend(ncol = 1, byrow = TRUE, order = 3),
    name = "ctxB TYPE",
    na.translate = FALSE
  ) +
  
  annotate(
    "text",
    x = max(p$data$x) * 1.12,
    y = max(p$data$y) + 2,
    label = "ctxB TYPE",
    angle = 90,
    hjust = 0,
    size = 8
  )

# print(ps3)

ps4 = ps3 +
  new_scale_fill() +
  geom_fruit(
    geom = geom_tile,
    mapping = aes(y = label, fill = inctype),
    width = tile_size,
    offset = gap_space
  ) + 
  scale_fill_manual(
    values = sample_colors,
    guide = guide_legend(ncol = 1, byrow = TRUE, order = 3),
    name = "REP TYPE",
    na.translate = FALSE
  ) +
  
  annotate(
    "text",
    x = max(p$data$x) * 1.16,
    y = max(p$data$y) + 2,
    label = "REP TYPE",
    angle = 90,
    hjust = 0,
    size = 8
  ) +
  theme(
    plot.margin = margin(t = 85, r = 0, b = 5, l = 0, unit = "pt")
  ) + 
  new_scale_fill()

# print(ps4)

ggsave(
  "IQtree2/plots/gubbins-tree-level_2-------.png",
  width = 20, height = 17, dpi = 300
)

ps5 = ps4 +
  ggnewscale::new_scale_fill() +
  geom_fruit(
    geom = geom_tile,
    mapping = aes(y = label, fill = serotype),
    width = tile_size,
    offset = gap_space
  ) +
  scale_fill_manual(
    values = pal_npg("nrc", alpha = 0.8)(10)[7:10],
    guide = guide_legend(ncol = 1, byrow = TRUE, order = 5),
    name = "SEROTYPE",
    na.translate = FALSE
  ) +

  annotate(
    "text",
    x = max(p$data$x) * 1.458,
    y = max(p$data$y) + 1,
    label = "SEROTYPE",
    angle = 90,
    hjust = 0,
    size = 8
  )

#print(ps5)