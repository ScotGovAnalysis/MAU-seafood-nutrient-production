# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
# GENERATE LIST OF SPECIES PRODUCED IN SCOTLAND ===============================
# /////////////////////////////////////////////////////////////////////////////

library(readr)
library(dplyr)
library(tidyr)
library(stringr)

library(httr)
library(readODS)

# LOAD DATA ===================================================================

## Landings -------------------------------------------------------------------

## Scotland production data via MMO

GET("https://assets.publishing.service.gov.uk/media/6512dc41b23dad000de706a6/SFS22_UK_into_all_ports_non_uk_into_uk_ports_landings_2018_22.ods",
    write_disk(tf <- tempfile(fileext = ".ods")))

# Read 2018-21 production:

fisheries_production <- read_ods(tf, sheet = "2021")

# Limit to Scottish waters:

scottish_fisheries_production <- fisheries_production %>%
  filter(
    `Estimated EEZ of Capture` == "UK - Scotland"
  )

# Select species produced:

scottish_fisheries_production <- fisheries_production %>%
  select(
    year = Year,
    species_code = `Species Code`
  ) %>%
  distinct()

## Aquaculture ----------------------------------------------------------------

# The list of species for aquaculture was obtained via the Fish Farm Production
# Survey and the Shellfish Farm Production Survey. For the purpose of this
# (published) script, these species are hard-coded in (and excl. cleaner fish):

# ACH - Arc char
# COD - Atl cod
# HAL - Atl halibut
# MSX - Misc sea mussels
# OYF - European flat oyster
# OYG - Pacific cupped oyster
# QSC - Queen scallops
# SAL - Atl salmon
# SCE - Great Atl scallop
# SVF - Brook trout
# TRR - Rainbow trout
# TRS - Sea trout

scottish_aquaculture_production <-
  tibble(
    year = 2021,
    species_code = c("ACH", "COD", "HAL", "MSX", "OYF", "OYG",
                     "QSC", "SAL", "SCE", "SVF", "TRR", "TRS")
  )

## Join aquaculture to fisheries ----------------------------------------------

scottish_seafood_production <- bind_rows(scottish_fisheries_production,
                                         scottish_aquaculture_production
                                         ) %>%
  distinct()

## Load species to ERS/MCS lookup ---------------------------------------------

ers_mcs_lookup <- read_csv("Inputs/Lookups/ers_mcs_lookup.csv")

# GENERATE LIST OF SPECIES ====================================================

## Join to ERS/MCS lookup and create list--------------------------------------

list_of_species <- ers_mcs_lookup %>%
  left_join(scottish_seafood_production %>% rename(ERSCode = species_code)) %>%
  # Indicator column if it is produced in Scotland:
  mutate(
    ProducedInScotland2021 = case_when(
      is.na(year) ~ FALSE,
      TRUE ~ TRUE
    )
  ) %>%
  # Filter out NA's in ISSCAAP - mainly seabirds, c.a. 200 lines:
  filter(!is.na(ISSCAAP_Division_Code)) %>%
  # Select relevant columns:
  select(ERSCode, contains("CG"), contains("MCS"), contains("ISSCAAP"),
         ScientificName, EnglishName, ProducedInScotland2021)

list_of_species %>%
  write_csv("Inputs/Production/Processed in R/list_of_species.csv")
