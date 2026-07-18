# Load Required Packages
if (!require("pacman")) install.packages("pacman")

pacman::p_load(tidyverse, janitor, lubridate, readr, readxl, purrr, tidygeocoder)

source("metrics_data.R")

# MLW 2024 Unpublished Sequence Data
clinical_records = read_csv("metadata_files/2022_2023_cholera_metadata.csv", 
                        show_col_types = FALSE)

mlw_2024 = read_csv("metadata_files/mlw_2024_sequences_metadata.csv", 
                 show_col_types = FALSE)

unpublished = clean_names(mlw_2024) %>%
  select(
    label = study_id, collection_date, 
    district = where_live
  ) %>%
  # create study_id col from sample
  mutate(study_id = sub("_[^_]*$", "", label))

clinical_rec_data = clean_names(clinical_records) %>%
  filter(study_id %in% unpublished$study_id)

# Join datasets on the study_id column
joined_data = left_join(unpublished, clinical_rec_data, by = "study_id") %>%
  
  mutate(district.y = case_when(
    presented_to_location == "SORGIN H/C" ~ "Chikwawa",
    district.x == "Nsanje - Fesestena Alumeta" ~ "Nsanje",
    TRUE ~ district.y # Default value if no conditions above are met
  )) %>%
  
  mutate(
    # Convert date column to an actual Date object
    coll_date = mdy(collection_date.x),
    
    # Convert sample collection date to yyyy-mm-dd format
    coll_date_formatted = format(coll_date, "%Y-%m-%d"),
    
    # Overwrite date column if it is NA or "Not Indicated": from either dataset with correct entry
    collection_date.y = case_when(
      is.na(collection_date.y) ~ coll_date_formatted,
      collection_date.y == "Not Indicated" ~ coll_date_formatted,
      TRUE ~ collection_date.y
    )
  ) %>%
  
  # Add proper collection_date column
  mutate(country = "Malawi",
         collection_date = as.Date(collection_date.y),
         lat_lon = NA_character_,
         year = year(ymd(collection_date)),
         serotype = NA_character_
         ) %>%
  select(label, collection_date, year, country, 
         district = district.y, lat_lon, serotype
         )

# Load and process data from phim
phim_data = read_csv("metadata_files/phim_metadata.csv", 
                     show_col_types = FALSE)

# PHIM Data
phim = clean_names(phim_data) %>%
  rename(accession = bio_sample) %>%
  mutate(
    year = year(ymd(collection_date)),
    serotype = NA_character_
  ) %>%
  select(
    label = run, collection_date, year,
    country = geo_loc_name_country,
    district = geo_loc_name, lat_lon, serotype
  )

# Load and process data from MLW 2023 paper (Chaguza publication)
mlw_23 = read_csv("metadata_files/mlw23_metadata.csv", 
                  show_col_types = FALSE)

mlw23 = clean_names(mlw_23) %>%
  mutate(
    serotype = NA_character_,
    year = year(ymd(collection_date)),
  ) %>%
  select(
    label = run, collection_date, year, 
    country = geo_loc_name_country,
    district = geo_loc_name, lat_lon, serotype
  )

#Load and process historical genomes from MW, MZ, ZA, DRC
historical = read_excel("metadata_files/41467_2024_50484_MOESM4_ESM.xlsx") 

hist_data = clean_names(historical) %>%
  mutate(
    lat_lon = paste(latitude_approximate_for_city,
                    longitude_approximate_for_city,
                    sep = " "),
    collection_date = NA_Date_,
    district = NA_character_,
    serotype = NA_character_
  ) %>%
  relocate(collection_date, .after = 1) %>%
  relocate(district, .after = 4) %>%
  select(label = sample_accession, collection_date,
         year, country, district, lat_lon, serotype
  ) %>%
  
  filter(country %in% c(
    "Democratic Republic of the Congo",
    "Malawi", "Zambia", "Mozambique"),
    !is.na(label)
  ) %>%
  mutate(serotype = NA_character_)

# Load and process data from CholGen publication (2024)
cholgen_data = read_csv("metadata_files/cholgen_data.csv", 
                        show_col_types = FALSE)

cholgen_file1 = read_csv("metadata_files/supplemental_data1.csv", 
                         show_col_types = FALSE)

cholgen_file2 = read_csv("metadata_files/supplemental_data2.csv", 
                         show_col_types = FALSE)

required_data = clean_names(cholgen_file1) %>%
  filter(country %in% c(
    "Democratic Republic of the Congo",
    "Malawi", "Zambia", "Mozambique")
  ) %>%
  separate(taxa, 
           into = c("Continent", "Country_Code", "ID", "Lineage", "Date"), 
           sep = "\\|") %>%
  select(accession, Continent, Country_Code, ID, Lineage, Date, 
         collection_date, collection_year,
         country, admin1, serogroup, serotype) %>%
  mutate(
    # Convert date column to an actual Date object
    coll_date = mdy(collection_date),
    
    # Convert to yyyy-mm-dd string character format
    date_formatted = format(coll_date, "%Y-%m-%d"),
    
    # Overwrite Date column if date value is missing
    Date = ifelse(Date == "?", date_formatted, Date)
  ) 

# Get common field across datasets to access the right accession numbers (label)
merging_field = clean_names(cholgen_data) %>%
  select(accession = bio_sample, label = run, lat_lon)

required_batch = required_data %>%
  left_join(merging_field, by = "accession")

# Select necessary data points
cholgen = required_batch %>%
  mutate(
    collection_date = as.Date(Date),
    year = year(ymd(collection_date))
  ) %>%
  select(label, collection_date, year,
         country, district = admin1, lat_lon, serotype) %>%
  filter(!is.na(label))

# Combine the whole bunch together
combined_metadata = bind_rows(joined_data, mlw23, phim, cholgen, hist_data)

# Correct district names, get representative (approximates) districts for regions, then;
# Get GPS coordinates for map
geo_data = combined_metadata %>%
  mutate(
    district_corrected = case_when(
      district %in% c("ZAMBEZIA", "Zambezia", "Zambézia") ~ "Zambezia",
      district %in% c("Sud-Kivu", "Sud-kivu") ~ "Sud-Kivu",
      district %in% c("southern region", "Malawi: Southern") ~ "Southern Region",
      district %in% c("central region", "Malawi: Central") ~ "Central Region", 
      district %in% c("northern region", "Malawi: Northern") ~ "Nothern Region", 
      district %in% c("Northwestern", "North Western") ~ "North-Western Province", 
      district %in% c("Northern","Northen") ~ "Northern Province", 
      district == "Tete - Changara" ~ "Tete",
      district == "NAMPULA" ~ "Nampula",
      district == "Maputo cidade" ~ "Maputo",
      district == "CABO DELGADO" ~ "Cabo Delgado",
      district == "Central" ~ "Central Province",
      district == "Western" ~ "Western Province", 
      district == "Eastern" ~ "Eastern Province",
      district == "Southern" ~ "Southern Province", 
      TRUE ~ district
    )
  ) %>%
  #filter(label %in% metadata$label) %>%
  mutate(
    district = str_trim(str_remove(district, "^.*?:"))
  ) %>%
  mutate(
    district_corrected = str_trim(str_remove(district_corrected, "^.*?:"))
  ) %>%
  mutate(full_address = ifelse(!is.na(district_corrected) & !is.na(country), 
                               paste(district_corrected, country, sep = ", "), 
                               NA_character_)) %>%
  select(-district_corrected) %>%
  
  geocode(
    address = full_address, 
    method = 'osm', 
    lat = latitude, 
    long = longitude
  ) %>%
  extract(
    lat_lon, # Compute proper latitude and longitude based on given direction
    into = c("lat", "lat_dir", "lon", "lon_dir"),
    regex = "^\\s*([+-]?[0-9.]+)\\s*([NS]?)\\s+([+-]?[0-9.]+)\\s*([EW]?)\\s*$",
    remove = FALSE
  ) %>%
  mutate(
    lat = as.numeric(lat),
    lon = as.numeric(lon),
    
    lat = case_when(
      lat_direction == "S" ~ -abs(lat),
      lat_direction == "N" ~ abs(lat),
      TRUE ~ lat         # already signed or no direction given
    ),
    
    lon = case_when(
      lon_direction == "W" ~ -abs(lon),
      lon_direction == "E" ~ abs(lon),
      TRUE ~ lon 
    )
  ) %>%
  mutate(
    lat = ifelse(is.na(lat), latitude, lat),
    lon = ifelse(is.na(lon), longitude, lon)
  ) %>%
  select(-c(lat_direction, lon_direction, latitude, longitude, lat_lon, district))

# Select high quality genomes only based on quast and checkm reports: Loaded in metrics_data.R
metadatafile = geo_data %>%
  filter(label %in% quality_check$label)

write.csv(metadatafile, "IQtree2/cleaned_metadata.csv", row.names = FALSE)