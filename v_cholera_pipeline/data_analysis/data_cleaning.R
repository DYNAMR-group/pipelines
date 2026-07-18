library(tidyverse)
library(stringr)
library(rlang)
library(tidyr)
library(lubridate)


### CORRECT VALUES ARISING FROM TYPOS AND OTHER MISTAKES IN A COLUMN

# HELPER FUNCTION
# Normalize text: lowercase, remove extra spaces, and strip punctuation

normalize_text_values = function(text_vector) {
  text_vector %>%
    str_to_lower() %>% # convert all letters to lowercase
    str_squish() %>%# remove extra spaces
    str_replace_all("[^a-z0-9]+", "")
}

# MAIN FUNCTION
normalize_column_names = function(
    data_frame, 
    target_column, 
    rules_table, # columns: pattern, to
    keep_diagnostics = FALSE) {
  
  # Get the target column name
  target_column_quo = enquo(target_column)
  
  # Extract the actual column values as a plain vector
  original_values = dplyr::pull(data_frame, !!target_column_quo)
  
  # Create a normalized version for pattern matching
  normalized_values = normalize_text_values(original_values)
  
  # 4. Clean the rules table
  cleaned_rules_table = rules_table %>%
    mutate(
      pattern = as.character(pattern),
      corrected_value = as.character(to),
      pattern_normalized = normalize_text_values(pattern) 
    ) %>%
    tidyr::drop_na(pattern_normalized, corrected_value) %>%
    distinct(pattern_normalized, corrected_value, .keep_all = TRUE)
  
  # Initialize output and tracking variables
  corrected_values = original_values  # copy of original column to edit
  # Initialize the variable name to use later
  rule_match_index = integer(length(original_values))  # 0 means no rule matched
  
  # Apply each rule in order, the first matching pattern is applied
  for (i in seq_len(nrow(cleaned_rules_table))) {
    normalized_pattern = cleaned_rules_table$pattern_normalized[i]
    
    # Identify rows that match the current regex pattern AND haven't been changed yet
    matched_rows = str_detect(normalized_values, normalized_pattern) &
      rule_match_index == 0 & !is.na(normalized_values)
    
    # Replace matched rows with the correct value
    corrected_values[matched_rows] = cleaned_rules_table$corrected_value[i]
    
    # Record which rule matched each row using the current loop index 'i'
    rule_match_index[matched_rows] = i
  }
  
  # Insert the corrected column back into the data frame
  output_data_frame = data_frame %>%
    mutate(!!quo_name(target_column_quo) := corrected_values)
  
  # Optional diagnostics: show which rule matched each row
  if (keep_diagnostics) {
    output_data_frame = output_data_frame %>%
      mutate(
        normalized_text = normalized_values,
        rule_number_matched = dplyr::na_if(rule_match_index, 0), 
        normalized_pattern_used = if_else(
          is.na(rule_number_matched), NA_character_,
          cleaned_rules_table$pattern_normalized[rule_number_matched]
        ),
        value_replaced_with = if_else(
          is.na(rule_number_matched), NA_character_,
          cleaned_rules_table$corrected_value[rule_number_matched]
        )
      )
  }
  # Return the final data frame
  return(output_data_frame)
}

# Example usage

#rules_table = read_csv("rules_table.csv")
#input_df_corrected = normalize_names(df_name, column_name, rules_table, keep_diagnostics = TRUE/FALSE)

# Select required columns at the end to remove diagnostic columns


## *************************************************************************************************
  
### FORMAT DATES TO ONE FORMAT: YYYY-MM-DD FOR MULTIPLE DATE COLUMNS

# helper: normalize separators/spaces and keep as character
  
normalize_date_text = function(x) {
  x %>%
    as.character() %>%
    str_replace_all("\u00A0", " ") %>% # remove non-breaking spaces
    str_squish() %>%  # trim extra spaces
    str_replace_all("[\\.\\-\\u2215\\u2044]", "/") # unify all separators to "/"
}

  
# MAIN FUNCTION
normalize_dates = function(data_frame, ..., keep_original = FALSE, day_first = TRUE){
    
  # Capture all the unquoted date columns (like *args in Python)
  date_columns = enquos(...)
    
  # For each column, apply the same date normalization and formatting logic
  for (col in date_columns) {
    
    col_name = quo_name(col) # get actual column name as a string e.g "date_collected"
    raw_text = pull(data_frame, !!col)  # original vector values
    normalised = normalize_date_text(raw_text) # normalized text
    
    n = length(normalised) # get the number of rows in the date vector
    parsed_date = rep(as.Date(NA), n) # create placeholders (n) for final Date values
    detected_format = rep(NA_character_, n) # Original values (text value placeholder)
    
    # Masks for patterns
    is_blank = is.na(normalised) | normalised == ""
    is_serial = str_detect(normalised, "^[0-9]+$") # Excel serial
    is_iso_ymd1 = str_detect(normalised, "^\\d{4}/\\d{1,2}/\\d{1,2}$") # yyyy/mm/dd
    is_iso_ymd2 = str_detect(normalised, "^\\d{4}-\\d{1,2}-\\d{1,2}$") # yyyy-mm-dd (after normalizing)
    # DMY with 4-digit year: dd/mm/yyyy
    is_dmy_4y = str_detect(normalised, "^\\d{1,2}/\\d{1,2}/\\d{4}$")
    # DMY with 2-digit year: dd/mm/yy
    is_dmy_2y = str_detect(normalised, "^\\d{1,2}/\\d{1,2}/\\d{2}$")
    # yy/mm/dd — two-digit year first
    is_y2k_ymd = str_detect(normalised, "^\\d{2}/\\d{1,2}/\\d{1,2}$")
    
    
    # Parse each class safely, ensuring we only affect currently unparsed dates (is.na(parsed_date))
    
    # (a) Excel serial numbers (origin = 1899-12-30 handles Excel's 1900 bug): number of days after 1899-12-30
    # idx is calculated as the intersection of is_serial, not blank, AND not already parsed.
    idx = which(is_serial & !is_blank & is.na(parsed_date))
    if (length(idx) > 0) {
      suppressWarnings({
        parsed_date[idx] = as_date(as.numeric(normalised[idx]), origin = "1899-12-30")
      })
      detected_format[idx] = "excel_serial"
    }
    
    # (b) ISO yyyy/mm/dd (separators normalized to "/")
    idx = which(is_iso_ymd1 & is.na(parsed_date))
    if (length(idx) > 0) {
      suppressWarnings({
        parsed_date[idx] = ymd(str_replace_all(normalised[idx], "/", "-"), quiet = TRUE)
      })
      detected_format[idx] = "iso_ymd"
    }
    
    # (c) ISO yyyy-mm-dd (might exist in original vector if it was already Date or clean)
    idx = which(is_iso_ymd2 & is.na(parsed_date))
    if (length(idx) > 0) {
      suppressWarnings({
        parsed_date[idx] = ymd(normalised[idx], quiet = TRUE)
      })
      detected_format[idx] = "iso_ymd"
    }
    
    # (d) dd/mm/yyyy — build explicitly
    idx = which(is_dmy_4y & is.na(parsed_date))
    if (length(idx) > 0) {
      parts = str_match(normalised[idx], "^(\\d{1,2})/(\\d{1,2})/(\\d{4})")
      suppressWarnings({
        parsed_date[idx] = make_date(
          year  = as.integer(parts[,4]),
          month = as.integer(parts[,3]),
          day   = as.integer(parts[,2])
        )
      })
      detected_format[idx] = "dmy_4y"
    }
    
    # (e) dd/mm/yy — assume 2000–2099 (adjust if you need a different pivot)
    idx = which(is_dmy_2y & is.na(parsed_date))
    if (length(idx) > 0) {
      parts = str_match(normalised[idx], "^(\\d{1,2})/(\\d{1,2})/(\\d{2})")
      suppressWarnings({
        parsed_date[idx]  = make_date(
          year  = 2000L + as.integer(parts[,4]),
          month = as.integer(parts[,3]),
          day   = as.integer(parts[,2])
        )
      })
      detected_format[idx] = "dmy_2y"
    }
    
    # (f) Ambiguous d/m/y vs m/d/y (both <= 12) — resolve with day_first preference
    amb_pat = "^\\d{1,2}/\\d{1,2}/\\d{2,4}$"
    # We define idx here as the intersection of ambiguity pattern AND still unparsed
    idx = which(str_detect(normalised, amb_pat) & is.na(parsed_date) & !is_blank)
    if (length(idx) > 0) {
      parts = str_match(normalised[idx], "^(\\d{1,2})/(\\d{1,2})/(\\d{2,4})")
      a = as.integer(parts[,2])  # first number
      b = as.integer(parts[,3])  # second number
      y = parts[,4]
      
      # Expand year to 4 digits if needed
      year4 = ifelse(nchar(y) == 2, 2000L + as.integer(y), as.integer(y))
      
      # Heuristics:
      # if a > 12 -> D/M/Y ; if b > 12 -> M/D/Y ; else use day_first flag
      use_dmy = ifelse(a > 12, TRUE,
                       ifelse(b > 12, FALSE, day_first))
      
      day = ifelse(use_dmy, a, b)
      month = ifelse(use_dmy, b, a)
      
      suppressWarnings({
        parsed_date[idx] = make_date(
          year  = year4,
          month = month,
          day   = day
        )
      })
      detected_format[idx] = ifelse(use_dmy, "amb_dmy", "amb_mdy")
    }
    
    # (g) yy/mm/dd — two-digit year first (Your original block, now corrected)
    
    # We define idx here specifically for the yy/mm/dd format and currently NA dates
    idx = which(is_y2k_ymd & is.na(parsed_date) & !is_blank)
    
    if (length(idx) > 0) {
      
      parts = str_match(normalised[idx], "^(\\d{2})/(\\d{1,2})/(\\d{1,2})$")
      
      suppressWarnings({
        parsed_date[idx] = make_date(
          year  = 2000L + as.integer(parts[,2]), # expand 23 -> 2023
          month = as.integer(parts[,3]),
          day   = as.integer(parts[,4])
        )
      })
      
      # Corrected this line to use the current 'idx'
      detected_format[idx] = "yy/mm/dd"
    }
    
    # Build output data frame: replace target col with parsed Date
    output = data_frame %>%
      mutate(!!sym(col_name) := parsed_date)
    
    # optionally keep the original column as a backup
    if (isTRUE(keep_original)) {
      backup_name = paste0(col_name, "_original")
      # Check if original column name is already in the data frame before adding it
      if (!backup_name %in% names(output)) { 
        output[[backup_name]] = raw_text
      }
    }
    
    # Update the input data frame for the next loop iteration
    data_frame = output
  }
    
  output # same as return(output)
}

# Example usage:
# 1. dates_corrected = normalize_dates(data, date_col1, date_col2, date_col3, keep_original = TRUE/FALSE, day_first = TRUE/FALSE)
# Hint: When using piping operator, the data frame is passed argument is passed implicitly by the pipe as shown below:
# 2. previous_function() %>% normalize_dates(date_col1, date_col2, date_col3, keep_original = TRUE/FALSE, day_first = TRUE/FALSE)


# ******************************************************************************************

### DATA GROUPING FUNCTION
