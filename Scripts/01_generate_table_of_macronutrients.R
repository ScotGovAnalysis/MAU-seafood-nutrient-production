# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
# GENERATE TABLE OF NUTRIENTS =================================================
# /////////////////////////////////////////////////////////////////////////////

library(readr)
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)

# LOAD DATA ===================================================================

## List of species w/ indicator if produced in Scotland in 2018-21 ------------

# See 00_generate_list_of_species script.

species <- read_csv("Inputs/Production/Processed in R/list_of_species.csv") %>%
  # Pad CG and MCS code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

## Simple fallback cal/protein assumptions ------------------------------------

# Based on 2001 FAO Handbook, kcal and g protein per 100g retail weight:

simple_nutrients <- read_csv("Inputs/Nutrients/fallback_nutrients.csv",
                          skip = 1) %>%
  # Pad CG code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2)
  )

## FAO 1989 nutrients ---------------------------------------------------------

# See 00_match_fao_1989_to_codes script.

fao1989_nutrients <- read_csv("Inputs/Nutrients/fao1989_nutrients_fixed.csv") %>%
  # Pad CG and MCS code columns with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

# JOIN DATA ===================================================================

## Join production data to nutrient data --------------------------------------

# Simple fallback nutrients for each CG category:

joined_data <- species %>%
  # Join with simple nutrients:
  left_join(simple_nutrients %>% select(CG_code, kcal, protein, fat), by = "CG_code") %>%
  rename_with(~ paste0(., "_simple"), c(kcal, protein, fat))

# FAO 1989 joined by species code:

joined_data <- joined_data %>%
  # Join with FAO 1989:
  left_join(fao1989_nutrients %>% select(ERSCode, kcal, protein, fat), by = "ERSCode") %>%
  rename_with(~ paste0(., "_fao"), c(kcal, protein, fat)) %>%
  # Create indicator columns:
  mutate(
    has_nutrients_simple = !is.na(kcal_simple),
    has_nutrients_fao = !is.na(kcal_fao)
  )

## Check for duplicated species -----------------------------------------------

if( length(joined_data$ERSCode) != length(unique(joined_data$ERSCode)) ){
  
  warning("Some species are duplicated! Check that all rows are being joined correctly.")
  
}

## Write to CSV ---------------------------------------------------------------

joined_data %>%
  write_csv("Inputs/Nutrients/Processed in R/combined_macronutrients.csv")

# SUMMARY =====================================================================

## Summarise species count by indicator columns -------------------------------

# In the internal code, tonnage is included here too.

nutrients_source_overview <- joined_data %>%
  filter(ProducedInScotland2021 == TRUE) %>%
  # Summarise:
  group_by(has_nutrients_simple, has_nutrients_fao) %>%
  summarise(
    Count = n()
  ) %>%
  ungroup() %>%
  mutate(
    source_used = case_when(
      has_nutrients_fao ~ "FAO (1989)",
      has_nutrients_simple ~ "Simple estimates",
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

nutrients_source_overview %>%
  write_csv(
    "Outputs/Intermediate/macronutrient_sources.csv"
  )
