# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
# GENERATE TABLE OF MICRONUTRIENTS ============================================
# /////////////////////////////////////////////////////////////////////////////

library(readr)
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)

# Define %notin% function:

`%notin%` <- purrr::negate(`%in%`)

# LOAD DATA ===================================================================

## List of species w/ indicator if produced in Scotland in 2018-21 ------------

# See 00_generate_list_of_species script.

species <- read_csv("Inputs/Production/Processed in R/list_of_species.csv") %>%
  # Pad CG and MCS code column with zeros:
  mutate(
    CG_code = str_pad(CG_code, pad = "0", side = "left", width = 2),
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

## CoFID dataset ---------------------------------------------------------------

### Load datasets --------------------------------------------------------------

# Proximates:

cofid_proximates <- read_excel("Inputs/Nutrients/McCance_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021.xlsx",
                                   sheet = "1.3 Proximates") %>%
  # Select only kcal, protein, fat, omega3 fatty acids:
  select(`Food Code`:`Main data references`, 
         protein_g_per_100g = `Protein (g)`, kcal_per_100g = `Energy (kcal) (kcal)`, fat_g_per_100g = `Fat (g)`,
         omega3_g_per_100g = `n-3 poly /100g food (g)`)

# Inorganics:

cofid_inorganics <- read_excel("Inputs/Nutrients/McCance_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021.xlsx",
                               sheet = "1.4 Inorganics") %>%
  rename(`Food Code` = ...1) %>%
  rename_with(.cols = `Sodium (mg)`:`Iodine (µg)`, ~paste0(str_to_lower(str_replace_all(str_remove_all(str_remove_all(., "\\("), "\\)"), " ", "_")), "_per_100g")) %>%
  select(`Food Code`, sodium_mg_per_100g:iodine_µg_per_100g)

# Vitamins:

cofid_vitamins <- read_excel("Inputs/Nutrients/McCance_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021.xlsx",
                               sheet = "1.5 Vitamins") %>%
  rename_with(.cols = `Retinol (µg)`:`Vitamin C (mg)`, ~paste0(str_to_lower(str_replace_all(str_remove_all(str_remove_all(., "\\("), "\\)"), " ", "_")), "_per_100g")) %>%
  select(`Food Code`, retinol_µg_per_100g:vitamin_c_mg_per_100g)

# Bind together:

cofid_micronutrients <- cofid_proximates %>%
  # Limit to fish products:
  filter(
    str_detect(`Food Code`, "^16"),
    str_detect(`Food Name`, "flesh only, raw|, raw"),
  ) %>%
  left_join(cofid_inorganics, by = "Food Code") %>%
  left_join(cofid_vitamins, by = "Food Code") %>%
  # Extract fish species names as best as possible:
  mutate(
    presentation = str_extract(`Food Name`, "flesh only"),
    preservation = str_extract(`Food Name`, "raw"),
    `Food Name` = str_remove_all(str_remove_all(`Food Name`, "flesh only|raw"), ",")
  )

# Manually change species names to match with our production data. This includes
# cases where assumptions on species have been made, e.g. 'seabass' in CoFID is assumed
# to be any seabass species within the 'Seabass' Main Commercial Species category:

cofid_species_categorisation <- read_csv("Inputs/Lookups/cofid_species_lookup.csv") %>%
  select(-`Food Name`) %>%
  rename(Approximated = Approximated)
  
# Join:

cofid_micronutrients <- cofid_micronutrients %>%
  full_join(cofid_species_categorisation, by = c("Food Code")) %>%
  # ASSUMPTION -- data for both yellow and conger eel exists (same species,
  # different life stage). Assume Yellow eel data as this is slightly more complete.
  # Other products removed include smoked/breaded fish include erronously, and
  # wild salmon (assuming farmed salmon is representative of all production in Scotland)
  filter(!str_detect(fixed_name, "REMOVE")) %>%
  select(FixedName = fixed_name, ISSCAAP_Division_Code:Approximated, `Main data references`:vitamin_c_mg_per_100g) %>%
  mutate(
    source = "CoFID (2021)"
  ) %>%
  # Turn numerics to characters for the time being to join with Robinson:
  mutate_if(is.numeric, as.character)

## Robinson 2022 --------------------------------------------------------------

robinson <- read_csv("Inputs/Nutrients/robinson2022_micronutrients.csv",
                     skip = 1) %>%
  mutate(
    Approximated = case_when(
      nutrient_source == "Species-level" ~ FALSE,
      TRUE ~ TRUE
      ),
    # Pad MCS code column with zeros:
    MCS_code = str_pad(MCS_code, pad = "0", side = "left", width = 3)
  )

# Tidy up Robinson dataframe:

robinson <- robinson %>%
  select(ERSCode, MCS_code, MCS_descr, Approximated, selenium:vitamin_a) %>%
  mutate(
    source = "Robinson et al (2022)"
  )

# Join specific species and broad species to the full ERS/ISSCAAP/CG/MCS lookup:

robinson_specific <- robinson %>%
  filter(!is.na(ERSCode)) %>%
  # Join specific species to lookup:
  left_join(
    species %>% select(contains("ISSCAAP"), ERSCode, ScientificName, EnglishName,
                       CG_code:MCS_descr),
    by = c("ERSCode", "MCS_code", "MCS_descr")
  )

# For broader species groups in Robinson (shrimp), only match to MCS:

robinson_broad <- robinson %>%
  filter(is.na(ERSCode)) %>%
  select(-ERSCode) %>%
  # Join shrimp groups to ISSCAAP:
  left_join(
    species %>% select(contains("ISSCAAP"), CG_code:MCS_descr, ERSCode, EnglishName) %>% distinct(),
    by = c("MCS_code", "MCS_descr")
  )

# Bind together:

robinson <- bind_rows(
  robinson_specific,
  robinson_broad
  ) %>%
  mutate(across(contains("ISSCAAP"), ~as.character(.)))

# NOTE: THIS APPLIES NUTRIENT INFORMATION FOR 'SHRIMP, MISC' AND
# 'SHRIMP, WARMATER' to a whole host of shrimp/prawn species - may not be the
# most accurate!

## FishBase model predictions -------------------------------------------------

# Currently not used - future area of improvement

#fishbase <- read_csv("Inputs/Nutrients/NUTRIENT_PREDICTED_DATA_OF_SPECIES_IN_UNITED_KINGDOM_FISHBASE.csv")

# JOIN DATA ===================================================================

## Combine CoFID and Robinson -------------------------------------------------

# Species-specific:

cofid_specific_species <- cofid_micronutrients %>% 
  filter(!is.na(ERSCode)) %>%
  pull(ERSCode) %>%
  unique()

cofid_broad_species <- cofid_micronutrients %>% 
  filter(is.na(ERSCode)) %>%
  pull(ERSCode) %>%
  unique()

# Filter Robinson data to species not contained in CoFID:

robinson_filtered <- robinson %>%
  # Limit to species not in CoFID:
  filter(
    ERSCode %notin% cofid_specific_species,
    ERSCode %notin% cofid_broad_species
  ) %>%
  # Average the various nutrients by CG, ISSCAAP, MCS
  # (for shrimp this won't do much since it's at that level anyway):
  group_by_at(vars(source, ERSCode, contains("ISSCAAP"), contains("CG"), contains("MCS"), Approximated)) %>%
  summarise_if(is.numeric, mean, na.rm = TRUE) %>%
  ungroup() %>%
  # Set NaN to NA:
  mutate_if(is.numeric, ~case_when(is.nan(.) ~ NA_real_, TRUE ~ .)) %>%
  # Turn numerics to characters for the time being to join with CoFID:
  mutate_if(is.numeric, as.character) %>%
  # Change column names to match CoFID dataset:
  rename(
    selenium_µg_per_100g = selenium,
    zinc_mg_per_100g = zinc,
    omega3_g_per_100g = omega_3,
    calcium_mg_per_100g = calcium,
    iron_mg_per_100g = iron,
    retinol_equivalent_µg_per_100g = vitamin_a
  )

micronutrients_combined <- bind_rows(cofid_micronutrients, robinson_filtered)

## Join production data to micronutrient data ---------------------------------

# Isolate codes with (approximated or not) micronutrient data:

species_with_micronutrients <- micronutrients_combined %>% 
  filter(!is.na(ERSCode)) %>%
  pull(ERSCode) %>%
  unique()

# Join CoFID/Robinson data by species code where possible...

joined_data_species_specific <- species %>%
  filter(ERSCode %in% species_with_micronutrients) %>%
  # Join with micronutrient data:
  left_join(micronutrients_combined %>% 
              filter(!is.na(ERSCode)) %>%
              select(source, ERSCode, Approximated:vitamin_c_mg_per_100g),
            by = "ERSCode")

# ...and MCS where not:

joined_data_mcs_group <- species %>%
  filter(ERSCode %notin% species_with_micronutrients) %>%
  # Join with micronutrient data:
  left_join(micronutrients_combined %>% 
              filter(is.na(ERSCode)) %>%
              mutate(MCS_code = str_pad(MCS_code, width = 3, side = "left", pad = "0")) %>%
              select(MCS_code, source, Approximated:vitamin_c_mg_per_100g),
            by = "MCS_code")

# Bind together by rows:

joined_data <- bind_rows(joined_data_species_specific, joined_data_mcs_group) %>%
  arrange(ISSCAAP_Division_Code, ISSCAAP_Group_Code, ScientificName) %>%
  # Pivot to make imputing easier:
  pivot_longer(protein_g_per_100g:vitamin_c_mg_per_100g, names_to = "nutrient", values_to = "value")

# Create vector of species with broad assumptions:

species_with_assumed_micronutrients <- joined_data %>% 
  filter(
    ERSCode %notin% species_with_micronutrients,
    Approximated == TRUE
  ) %>%
  pull(ERSCode) %>%
  unique()

## Impute unknown high amounts and trace amounts ------------------------------

# 'N' means nutrient is present in 'high quantities' but there is no reliable
# information on the amount.

# 'Tr' means there are trace amounts.

# What constitutes a 'high amount'? Assume it's approximated by the average of
# known amounts within the CG group (doing this by MCS might still lead to lots
# of missing values, and CG is slightly more specific than ISCCAAP Division).

average_quantities <- joined_data %>%
  # Set character values N and Tr to NA:
  mutate(
    value = case_when(
      value %in% c("N", "Tr") ~ NA_character_,
      TRUE ~ value
      ),
    value = as.numeric(value)
  ) %>%
  # Compute mean (and set NaN to NA):
  group_by_at(vars(CG_code, CG_descr, nutrient)) %>%
  summarise(
    mean = case_when(
      is.nan(mean(value, na.rm = TRUE)) ~ NA_real_,
      TRUE ~ mean(value, na.rm = TRUE)
      )#,
    #approximated_source = "Average within commodity group"
    ) %>%
  ungroup() %>%
  filter(!is.na(CG_code))

# Join to data:

# If any values are N -- replace these with average quantities within CG.
# If Tr, replace with 0.0001. If NA, leave as NA.

final_micronutrient_table <- joined_data %>%
  left_join(
    average_quantities, by = c("CG_code", "CG_descr", "nutrient")
    ) %>%
  mutate(
    # impute values:
    imputed_value = case_when(
        value == "N" ~ mean,
        value == "Tr" ~ 0.0001,
        is.na(value) ~ NA_real_,
        TRUE ~ as.numeric(value)
      )
    ) %>%
  # Pivot back:
  #select(-value, -mean, -source) %>%
  #pivot_wider(names_from = nutrient, values_from = imputed_value) %>%
  mutate(
    # Create new source column:
    source = case_when(
      value == imputed_value ~ source,
      TRUE ~ "SG calculations using CoFID (2021) and Robinson et al (2022)"
      )
    )


## Check for duplicated species -----------------------------------------------

if( length(final_micronutrient_table$ERSCode)/length(unique(final_micronutrient_table$ERSCode)) != length(unique(final_micronutrient_table$nutrient)) ){
  
  warning("Some species are duplicated! Check that all rows are being joined correctly.")
  
}

#test <- final_micronutrient_table %>%
#  group_by(ERSCode) %>%
#  filter(ERSCode == "AAB") %>%
#  arrange(ERSCode)

## Write to CSV ---------------------------------------------------------------

final_micronutrient_table %>%
  arrange(ISSCAAP_Division_Code, ISSCAAP_Group_Code, ScientificName, nutrient) %>%
  write_csv("Inputs/Nutrients/Processed in R/combined_micronutrients.csv")

# SUMMARY =====================================================================

# Production with species-specific micronutrient data:

## Summarise species count by indicator columns -------------------------------

# In the internal code, tonnage is included here too.

production_with_mucronutrients <- joined_data %>%
  mutate(
    has_micronutrient_data = case_when(
      !is.na(source) ~ TRUE,
      TRUE ~ FALSE
    )
  ) %>%
  group_by_at(vars(nutrient, has_micronutrient_data, source, Approximated)) %>%
  summarise(
    Count = n(),
  ) %>%
  ungroup()

production_with_mucronutrients %>%
  write_csv(
    "Outputs/Intermediate/micronutrient_sources.csv"
  )
