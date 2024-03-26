# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
# GENERATE TABLE OF EDIBLE FACTORS ============================================
# /////////////////////////////////////////////////////////////////////////////

library(readr)
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)

# LOAD DATA ===================================================================

## List of species produced in Scotland ---------------------------------------

# See 00_generate_list_of_species script.

species <- read_csv("Inputs/Production/Processed in R/list_of_species.csv") %>%
  # Pad CG and MCS code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

## Simple fallback edible factors ---------------------------------------------

simple_edible <- read_csv("Inputs/Nutrients/fallback_edible_fractions.csv",
                          skip = 1) %>%
  # Pad CG code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2)
    )

## Robinson et al edible factors ----------------------------------------------

robinson_edible <- read_csv("Inputs/Nutrients/robinson2022_edibe_fractions.csv",
                            skip = 1) %>%
  # Pad MCS code column with zeros:
  mutate(
    edible_fraction = edible_fraction/100,
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
    )

## FAO 1989 edible fractions --------------------------------------------------

# See 00_match_fao_1989_to_codes script.

fao1989_edible <- read_csv("Inputs/Nutrients/fao1989_edible_fractions_fixed.csv") %>%
  # Pad CG and MCS code columns with zeros:
  mutate(
    edible_fraction = edible_fraction/100,
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

# JOIN DATA ===================================================================

## Join production data to edible fractions -----------------------------------

# Simple fallback edible fractions for each CG category:

joined_data <- species %>%
  # Join with simple edible fractions:
  left_join(simple_edible %>% select(CG_code, edible_fraction), by = "CG_code") %>%
  rename(edible_fraction_simple = edible_fraction)

# Robinson et al 2022 - averaged where farmed/wild distinction is available,
# and edible fraction for 'shrimp, warmwater' and 'shrim, misc' are matched
# to MCS:

robinson_edible_avg <- robinson_edible %>%
  group_by_at(vars(-farmed_wild, -edible_fraction)) %>%
  summarise(
    edible_fraction = mean(edible_fraction, na.rm = TRUE)
  ) %>%
  ungroup()

# Join:

joined_data <- joined_data %>%
  # Join with Robinson 2022:
  left_join(robinson_edible_avg %>%
              filter(!is.na(ERSCode)) %>%
              select(ERSCode, edible_fraction), 
            by = "ERSCode") %>%
  left_join(robinson_edible_avg %>%
              filter(is.na(ERSCode)) %>%
              select(contains("MCS"), edible_fraction),
            by = c("MCS_code", "MCS_descr"),
            suffix = c("_robinson", "_robinson_shrimp")) %>%
  # Caolesce the two disctinct Robinson edible fraction columns into one:
  mutate(
    edible_fraction_robinson = coalesce(edible_fraction_robinson, edible_fraction_robinson_shrimp)
    ) %>%
  select(-edible_fraction_robinson_shrimp)

# FAO 1989 joined by species code:

joined_data <- joined_data %>%
  # Join with FAO 1989:
  left_join(fao1989_edible %>% select(ERSCode, edible_fraction), by = "ERSCode") %>%
  rename(edible_fraction_fao = edible_fraction) %>%
  # Create indicator columns:
  mutate(
    has_fraction_simple = !is.na(edible_fraction_simple),
    has_fraction_robinson = !is.na(edible_fraction_robinson),
    has_fraction_fao = !is.na(edible_fraction_fao)
  )

## Check for duplicated species -----------------------------------------------

if( length(joined_data$ERSCode) != length(unique(joined_data$ERSCode)) ){
  
  warning("Some species are duplicated! Check that all rows are being joined correctly.")
  
}

## Write to CSV ---------------------------------------------------------------

joined_data %>%
  write_csv("Inputs/Nutrients/Processed in R/combined_edible_fractions.csv")

# SUMMARY =====================================================================

## Summarise species count by indicator columns -------------------------------

# In the internal code, tonnage is included here too.

edible_fraction_source_overview <- joined_data %>%
  filter(ProducedInScotland2021 == TRUE) %>%
  # Summarise:
  group_by(has_fraction_simple, has_fraction_robinson, has_fraction_fao) %>%
  summarise(
    Count = n()
  ) %>%
  ungroup() %>%
  mutate(
    source_used = case_when(
      has_fraction_robinson ~ "Robinson et al (2022)",
      has_fraction_fao ~ "FAO (1989)",
      has_fraction_simple ~ "Simple estimates",
      TRUE ~ NA_character_
    ),
    # Custom order:
    source_used = factor(source_used, levels = unique(source_used))
  ) %>%
  # Summarise by source:
  group_by(source_used) %>%
  summarise(
    Count = sum(Count)
  ) %>%
  ungroup()

# Save this data to CSV for later use:

edible_fraction_source_overview %>%
  write_csv(
    "Outputs/Intermediate/edible_fraction_sources.csv"
  )
