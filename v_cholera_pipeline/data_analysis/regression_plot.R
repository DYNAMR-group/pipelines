library(ape)
library(tidyverse)
library(ade4)

# Date processing function
to_decimal_date= function(x){
  # x = character vector of dates (YYYY-MM-DD or YYYY)
  
  # trim spaces
  x = trimws(x)
  
  # identify full dates and year-only ones
  is_full = grepl("^\\d{4}-\\d{2}-\\d{2}$", x)
  is_year = grepl("^\\d{4}$", x)
  
  # initialize output
  out = rep(NA_real_, length(x))
  
  # ---- full dates ----
  if(any(is_full)){
    d = as.Date(x[is_full], format = "%Y-%m-%d")
    yr = as.numeric(format(d, "%Y"))
    doy = as.numeric(format(d, "%j"))
    out[is_full] = yr + (doy - 1) / 365.25 # Subtract 1 to get days completed
  }
  
  # ---- year-only ----
  if(any(is_year)){
    out[is_year] = as.numeric(x[is_year])
  }
  
  # warn if anything didn't match
  if(any(is.na(out))){
    warning("Some dates could not be parsed")
  }
  
  return(out)
}

# Root-to-tip Regression Function
plot_root_to_tip = function(tree_file, dates_file){
  
  # Root-to-tip regression from tree + metadata dates
  # Inputs:
  #   tree_file  = Newick tree file
  #   dates_file = CSV with columns: sample,date
  
  # --------------------------
  # 1. Read tree + dates
  # --------------------------
  if(is.character(tree_file)) {
    if(!file.exists(tree_file)) {
      stop("Tree file does not exist: ", tree_file)
    }
    tree = read.tree(tree_file)
  } else if(inherits(tree_file, "phylo")) {
    tree = tree_file
  } else {
    stop("tree_file must be a file path (character) or a phylo object")
  }
  
  tree$node.label <- NULL
  
  if(any(duplicated(tree$tip.label))) {
    dup_labels = unique(tree$tip.label[duplicated(tree$tip.label)])
    stop("Tree tip labels are not unique. Duplicated labels: ", paste(dup_labels, collapse = ", "))
  }
  
  if(is.character(dates_file)) {
    if(!file.exists(dates_file)) {
      stop("Dates file does not exist: ", dates_file)
    }
    meta = read.csv(dates_file, stringsAsFactors = FALSE)
  } else if(is.data.frame(dates_file)) {
    meta = dates_file
  } else {
    stop("dates_file must be a file path (character) or a data frame")
  }
  
  if(any(duplicated(meta$sample))) {
    dup_samples = unique(meta$sample[duplicated(meta$sample)])
    stop("Metadata sample labels are not unique. Duplicated sample IDs: ", paste(dup_samples, collapse = ", "))
  }
  
  # Expect columns: sample,date
  if(!all(c("sample","date") %in% names(meta))){
    stop("CSV must contain columns named: sample and date")
  }
  
  # --------------------------
  # 2. Convert dates
  # --------------------------
  # Handle both full dates and year-only values
  meta$date = as.character(meta$date)
  
  # Identify year-only vs full dates
  is_year_only = grepl("^\\d{4}$", trimws(meta$date))
  
  decimal_dates = rep(NA_real_, length(meta$date))
  
  # Process full dates
  if(any(!is_year_only)) {
    full_dates = meta$date[!is_year_only]
    parsed = tryCatch(
      as.Date(full_dates, format = "%Y-%m-%d"),
      error = function(e) {
        tryCatch(
          as.Date(full_dates, format = "%Y/%m/%d"),
          error = function(e2) {
            tryCatch(
              as.Date(full_dates),
              error = function(e3) {
                stop("Could not parse dates. Ensure they are in YYYY-MM-DD, YYYY/MM/DD, or other standard format")
              }
            )
          }
        )
      }
    )
    # Convert parsed dates directly to decimal format
    yr = as.numeric(format(parsed, "%Y"))
    doy = as.numeric(format(parsed, "%j"))
    decimal_dates[!is_year_only] = yr + (doy - 1) / 365.25
  }
  
  # Process year-only values - convert directly to decimal dates
  if(any(is_year_only)) {
    decimal_dates[is_year_only] = as.numeric(meta$date[is_year_only])
  }
  
  meta$decimal_date = decimal_dates
  
  # --------------------------
  # 3. Match metadata to tips
  # --------------------------
  idx = match(tree$tip.label, meta$sample)
  
  if(any(is.na(idx))){
    missing_tips = tree$tip.label[is.na(idx)]
    stop(
      paste(
        "These tree tips are missing in metadata:",
        paste(missing_tips, collapse = ", ")
      )
    )
  }
  
  meta = meta[idx, ]
  
  # --------------------------
  # 4. Root-to-tip distances
  # --------------------------
  library(adephylo)
  d = distRoot(tree)
  
  plot_df = data.frame(
    sample = tree$tip.label,
    date = meta$decimal_date,
    root_to_tip = d
  )
  
  x_breaks = seq(
    floor(min(plot_df$date, na.rm = TRUE)),
    ceiling(max(plot_df$date, na.rm = TRUE)),
    by = 0.5
  )
  
  # --------------------------
  # 5. Linear regression
  # --------------------------
  fit = lm(root_to_tip ~ date, data = plot_df)
  
  slope = coef(fit)[2]
  intercept = coef(fit)[1]
  r2 = summary(fit)$r.squared
  
  eq_lab = paste0(
    "y = ",
    signif(slope, 4),
    "x + ",
    signif(intercept, 4),
    "\nR² = ",
    round(r2, 3)
  )
  
  # --------------------------
  # 6. Plot
  # --------------------------
  p = ggplot(plot_df, aes(x = date, y = root_to_tip)) +
    geom_point(
      color = "#34d399",
      size = 2.5,
      alpha = 0.8
    ) +
    geom_smooth(
      method = "lm",
      se = TRUE,
      color = "#0072B2",
      fill = "#56B4E9",
      linewidth = 1.2
    ) +
    annotate(
      "text",
      x = min(plot_df$date),
      y = max(plot_df$root_to_tip),
      label = eq_lab,
      hjust = 0,
      vjust = 1,
      size = 4,
      fontface = "bold"
    ) +
    theme_minimal(base_size = 13) +
    scale_x_continuous(breaks = x_breaks) +
    labs(
      title = "Root-to-Tip Regression",
      x = "Sampling Date (decimal year)",
      y = "Root-to-Tip Distance"
    ) +
    theme(
      plot.title = element_text(
        hjust = 0.5,
        face = "bold",
        size = 16
      ),
      panel.grid.minor = element_blank()
    )
  
  print(p)
  
  # --------------------------
  # 7. Return objects
  # --------------------------
  return(list(
    data = plot_df,
    model = fit,
    slope = slope,
    intercept = intercept,
    r_squared = r2
  ))
}