# Load libraries

pacman::p_load(tidyverse, rnaturalearth, rnaturalearthdata, rnaturalearthhires, sf)

source("colors.R")

# Load metadata
data = read_csv("Iqtree2/metadata_with_fbaps_clusters.csv", show_col_types = FALSE)

# Get per location cluster sizes

# Identify shared locations and compute a small offset per cluster at each location
meta_cluster_loc = data %>%
  # Get number of samples per cluster at each location (level_2 holds sub-clusters)
  group_by(lon, lat, level_1) %>%
  summarise(
    n_samples = n(),
    .groups = "drop"
  ) %>%
  
  # Get number of clusters sharing the same location
  group_by(lon, lat) %>%
  
  mutate(
    n_clusters_here = n(),
    
    # Assign a unique index to each cluster (1, 2, 3, ...)
    cluster_index = row_number(),
    
    # Calculate an angle so clusters are evenly spaced around a circle, e.g.
    # 2 clusters -> 0°, 180°
    # 3 clusters -> 0°, 120°, 240°
    # 4 clusters -> 0°, 90°, 180°, 270°
    # Using formula:
    angle = 2 * pi * (cluster_index - 1) / n_clusters_here,
    
    # Determine circle radius: If more than 1 cluster,
    # ove each cluster 0.9 degrees away from the centre.
    offset = ifelse(n_clusters_here > 1, 0.9, 0),
    
    # Calculate new longitude and latitude with offset & angle
    # x = r × cos(angle)
    lon_jitter = lon + offset * cos(angle),
    
    # y = r × sin(angle)
    lat_jitter = lat + offset * sin(angle)
  ) %>%
  ungroup()

# Get Africa continent polygons (ne -> naturalearth)
africa = ne_countries(
  continent = "Africa", 
  scale = "large", 
  returnclass = "sf" # sf -> simple features
)

# Get bounding coordinates using st_bbox -> function of sf (to be used in the plot)
bbox_africa = st_bbox(africa)
# print(bbox_africa) # to see actual coordinates

# Plot the map with cluster data as open circles -> shape: 21
cluster_colors = pal_npg("nrc", alpha = 0.8)(10)[1:6]
map_plot = ggplot() +
  geom_sf(data = africa, fill = "grey90", color = "grey60", linewidth = 0.3) +
  geom_point(data = meta_cluster_loc,
                      aes(x = lon_jitter,
                          y = lat_jitter,
                          color = as.factor(level_1),
                          fill = as.factor(level_1),
                          size = n_samples),
                      shape = 21,
                      stroke = 1.2 # outline border thickness
            ) +

  scale_color_manual(values = cluster_colors, guide = "none") +
  scale_size_continuous(
    breaks = c(1, 5, 10, 20, 40, 70), # manually determined based on per-location cluster sizes
    range  = c(2, 12), # circle diameter range
    name   = "Samples at location" # scale name
  ) +
  
  # Outline: same hue, mostly opaque
  scale_color_manual(values = scales::alpha(cluster_colors, 0.7)) +
  # Fill: same hue, much more transparent
  scale_fill_manual(values = scales::alpha(cluster_colors, 0.3)) +
  
  coord_sf(xlim = c(bbox_africa["xmin"], bbox_africa["xmax"]), 
           ylim = c(bbox_africa["ymin"], bbox_africa["ymax"])
           ) +
  theme_void() +
  
  theme(
    legend.position = "right",
    plot.margin = margin(5, 5, 5, 10),
    legend.title = element_text(size = 24, face = "bold"),
    legend.text = element_text(size = 21),
    
    legend.key.height = unit(0.7, "cm"),
    legend.key.width  = unit(0.4, "cm"),
    
    legend.spacing = unit(0.7, "cm"),
    legend.spacing.x = unit(0.5, "cm")
  )

print(map_plot)

# Save plot as .png image file
ggsave(
  "plots/gubbins-aln-map-level-clusters.png",
  width = 20, height = 17, dpi = 300
)
