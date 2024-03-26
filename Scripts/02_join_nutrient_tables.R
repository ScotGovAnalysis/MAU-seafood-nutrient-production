# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
# JOIN EDIBLE FACTORS, MACRONUTRIENTS, AND MICRONUTRIENTS =====================
# /////////////////////////////////////////////////////////////////////////////

library(readr)
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)

# Define %notin% function:

`%notin%` <- purrr::negate(`%in%`)

# LOAD NUTRIENT TABLES DATA ===================================================

## List of species w/ indicator if produced in Scotland in 2018-21 ------------

# See 00_generate_list_of_species script.

species <- read_csv("Inputs/Production/Processed in R/list_of_species.csv") %>%
  # Pad CG and MCS code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

## Macronutrient assumptions --------------------------------------------------

macronutrient_assumptions <- read_csv("Inputs/Nutrients/Processed in R/combined_macronutrients.csv") %>%
  # Pad CG code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

## Edible fraction assumptions ------------------------------------------------

edible_fraction_assumptions <- read_csv("Inputs/Nutrients/Processed in R/combined_edible_fractions.csv") %>%
  # Pad CG code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

## Micronutrient assumptions --------------------------------------------------

micronutrient_assumptions <- read_csv("Inputs/Nutrients/Processed in R/combined_micronutrients.csv") %>%
  # Pad CG/MCS code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

# Targets from PHE and EFSA:

nutrient_targets <- read_csv("Inputs/Nutrients/rni_targets.csv",
                             skip = 1)

## Choose final edible fractions and nutrients to use -------------------------

# Macro:

macronutrient_assumptions <- macronutrient_assumptions %>%
  # FAO (1989) (species-level) if it exists, FAO (2001) (group-level) when not
  mutate(
    kcal_per_100g = case_when(
      !is.na(kcal_fao) ~ kcal_fao,
      TRUE ~ kcal_simple
    ),
    kcal_source = case_when(
      !is.na(kcal_fao) ~ "FAO (1989)",
      TRUE ~ "FAO (2001)"
    ),
    protein_g_per_100g = case_when(
      !is.na(protein_fao) ~ protein_fao,
      TRUE ~ protein_simple
    ),
    protein_source = case_when(
      !is.na(protein_fao) ~ "FAO (1989)",
      TRUE ~ "FAO (2001)"
    ),
    fat_g_per_100g = case_when(
      !is.na(fat_fao) ~ fat_fao,
      TRUE ~ fat_simple
    ),
    fat_source = case_when(
      !is.na(fat_fao) ~ "FAO (1989)",
      TRUE ~ "FAO (2001)"
    )
  ) %>%
  select(-ends_with("fao"), -ends_with("simple"), -TonnageAvg, -ProducedInScotland201821)

# Edible fraction:

edible_fraction_assumptions <- edible_fraction_assumptions %>%
  mutate(
    edible_fraction = case_when(
      !is.na(edible_fraction_robinson) ~ edible_fraction_robinson,
      !is.na(edible_fraction_fao) ~ edible_fraction_fao,
      TRUE ~ edible_fraction_simple
    ),
    edible_fraction_source = case_when(
      !is.na(edible_fraction_robinson) ~ "Robinson et al (2022)",
      !is.na(edible_fraction_fao) ~ "FAO (1989)",
      TRUE ~ "FAO (2001)"
    )
  ) %>%
  select(-ends_with("robinson"), -ends_with("fao"), -ends_with("simple"), -TonnageAvg, -ProducedInScotland201821)

# Micronutrients:

micronutrient_assumptions <- micronutrient_assumptions %>%
  rename(micronutrients_source = source) %>%
  select(-TonnageAvg, -ProducedInScotland201821, -protein_g_per_100g, -kcal_per_100g, -fat_g_per_100g, -Approximated)

## Join data ------------------------------------------------------------------

joined_data <- species %>%
  select(ERSCode) %>%
  left_join(macronutrient_assumptions, by = "ERSCode") %>%
  left_join(edible_fraction_assumptions) %>%
  left_join(micronutrient_assumptions) %>%
  # Select minimal amount of columns:
  select(ERSCode, contains("ISSCAAP"), ScientificName, EnglishName, CG_code:MCS_descr,
         kcal_per_100g:micronutrients_source, -`Main data references`)

## Write to CSV ---------------------------------------------------------------

write_csv(joined_data, "Outputs/Intermediate/combined_nutrients.csv")
