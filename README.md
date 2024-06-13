# MAU - Seafood nutrient production

<!-- badges: start -->
[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
<!-- badges: end -->

## Introduction 
This repository contains the code and methodology used to match seafood species to (estimated) nutrient contents. This is used internally by the Marine Analytical Unit (MAU) within the Scottish Government to estimate the total volume of macro- and micro-nutrients produced through Scottish seafood production by combining this with production volume figures. The methodology and code is published in this repository primarily to facilitate feedback and enable collaboration with academic researchers at our Main Research Providers and beyond.

The detailed production data files used internally within MAU are not included in this published repository. Instead, we use a list of species produced by Scotland in 2021. The nutrient content assumptions for these species could however be used in conjunction with published production data such as the [Scottish sea fisheries statistics](https://www.gov.scot/collections/sea-fisheries-statistics/), the [Scottish fish farm production survey](https://www.gov.scot/collections/scottish-fish-farm-production-surveys/), or the [Scottish shellfish farm production survey](https://www.gov.scot/collections/scottish-shellfish-farm-production-surveys/) (all published by the Scottish Government). Fisheries production data for the UK as a whole can be found on the [Marine Management Organisation's website](https://www.gov.uk/government/collections/uk-sea-fisheries-annual-statistics).

In addition, we will publish an interactive report here (link tbc) which provides overviews for aggregate production by species.

## Data sources
The conversion of live weight fish and shellfish to macro- and micro-nutrients requires estimates for (a) edible fractions and (b) nutrient contents.

### Edible fractions
Edible fractions convert the live weight (whole fish) to edible proportions. There is variability in the proportion of any given fish that is edible due to factors like the fish's species, age, and diet, but also due to what parts of the fish are deemed edible or desirable. For example, cuts like fillets and loins may be more commonly consumed than other parts of the fish like tail and liver, but this greatly depends on culture, social settings, affordability, and personal preferences. For the purpose of this analysis, we use edible fractions from a variety of sources.

Two key sources were [FAO (1989)](https://www.fao.org/3/T0219E/T0219E00.htm) and [Robinson et al (2022)](https://iopscience.iop.org/article/10.1088/1748-9326/aca490), which both contain estimates for edible fractions for a number of species (which is taken to mean either lean or fatty meat, without bone, raw). Together, they accounted for 54 individual species (and roughly three quarters of Scottish production by volume in 2021).

For the remaining species, a 'fallback' edible fraction estimate was used in the absence of a better estimate. Here, [Hilborn et al (2018)](https://esajournals.onlinelibrary.wiley.com/doi/abs/10.1002/fee.1822) was used to create generic edible fractions for species groups. For example, Carp (0.42) and Tilapia (0.38) were averaged to create an estimate for the Commodity Group (CG) 'Freshwater fish', with 0.4 being the assumed edible fraction for any freshwater fish that didn't have an estimate from FAO (1989) or Robinson et al (2022).

We are currently investigating how we can incorporate the added uncertainty for these affected species into this work, and whether there are better sources available ([Fishbase](https://github.com/mamacneil/NutrientFishbase), for example, which is a model that predicts nutrient contents based on certain species characteristics).

### Macronutrients
Currently, the 1989 FAO paper is used to provide macronutrient content estimates (energy, protein, fat) for 45 specific species, accounting for roughly 60% of total Scottish production by volume. The benefit of using this source is that it comes from the same analysis as the majority of the edible fraction data - however, other sources exist exist as well, some more up to date than others. One example of this is [CoFID (2021)](https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid), which we currently use for the majority of micronutrient content estimates.

For the remaining 40% of production, we use 'fallback' estimates from FAO (2001), which provide average estimates for broad species groups (e.g. demersal fish, pelagic fish, crustaceans). Like with edible fractions, we are exploring other options for these species.

### Micronutrients
For micronutrients, we primarily use CoFID (2021), which is a comprehensive collection of nutrient contents for a wide variety of food products consumed in the UK. While many fish and shellfish species are represented, they are not always analysed in a 'raw, flesh only' state (e.g. some are analysed in various cooked forms, or as part of complete dishes). For some species, more recent estimate might also be available elsewhere. Robinson et al (2022) was used to complement some of the missing species, which meant that in total 32 species or nearly 50% of production by volume was covered.

Note that not every species necessarily had an estimate for the full set of micronutrients covered in CoFID (e.g. many only had a handful, and omega-3 fatty acids had the best coverage), and that in some cases the species in CoFID had to be manually matched to one or more specific species (e.g. estimates for 'shrimp' were applied to a variety of shrimp species).

For those species that had an 'unknown substantial amount' denoted by N in CoFID, we imputed these values with the Main Commercial Species' average for that nutrient. Trace amounts (denoted by Tr) were given an arbitrary small number (0.0001). Any remaining species that had missing values in a specific nutrient were not given a fallback estimate (unlike with macronutrients). These adjustments took the species covered (in one or more micronutrients) to over 80% by volume.

## Data dictionary (inputs)

### Lookups

`cofid_species_lookup.csv`

A data file which matches all relevant fish and shellfish-related codes in the CoFID 2021 dataset that concerned raw and flesh-only products (i.e. having a Food Code starting with 16, and filtered by relevant phrases in the Food Name column) to:

* three-letter FAO species code (`ERSCode`) where possible (these will have `Approximated` set to `FALSE`),
* EUMOFA MCS category where not possible, e.g. 'Cuttlefish' in CoFID is matched the MCS category '073 - Cuttlefish' (these will have `Approximated` set to `TRUE`).

In some cases, the CoFID species was matched to more than one MCS category:
* For example, 'Seabass' in CoFID is matched to the MCS categories '059 - Seabass, other' and '095 - Seabass, European' in the absence of species information. These will also have `Approximated` set to `TRUE`.

In some cases, the MCS category was an 'Other ...' category where the CoFID species was more specific (an 'Other ...' MCS category generally contains dozens of different species). In these cases, efforts were made to match these to specific species codes:
* For example, 'Parrot fish' in CoFID did not have a specific match in the MCS categories, and so would fall under either '008 - Other freshwater fish' and/or '062 - Other marine fish'. We instead matched this species to various species with an English name matching 'parrotfish' or 'parrot fish'. 
* Another example is 'Plaice', which did have relevant MCS categories (e.g. 099 - Plaice, European) but which could potentially also concern species in '030 - Plaice, other' and '062 - Other marine fish' (in the case of the scale-eye plaice).
* All of these cases also have `Approximated` set to `TRUE`.

Some of these species matches and inclusions are still being revised and are subject to change (e.g. currently, 'Cod' in CoFID in only matched to the MCS category '013 - Cod' but could potentially also apply to some species in MCS categories '024 - Other groundfish' or '062 - Other marine fish'.

`ers_mcs_lookup.csv`

This lookup was created internally within the Marine Analytical Unit and is based on EUMOFA's MCS-ERS lookup available in Annex 3 on [their metadata webpage](https://eumofa.eu/metadata) (as at May 2023). This lookup was adjusted slightly to fix certain spellings (e.g. the several species acronym was either 'spp' or 'spp.', these were harmonised to 'spp.'). In addition, some species (ERS codes) fell outwith an MCS category. For these species, a separate ISSCAAP Group to MCS lookup was constructed to match the remaining species within those broad species categories (ISSCAAP Groups) to the corresponding MCS category (usually within an 'Other ...' category). For example, species missing from EUMOFA's ERS-MCS lookup within ISSCAAP Group '11 - Carps, barbels and other cyprinids' were matched to MCS '008 - Other freshwater fish'. The dataset available here contains those adjustments, as well as the ISSCAAP Division and Group and Commodity Group (CG) and MCS categories (either from EUMOFA, or after adjustment).

A full list of species codes with corresponding ISSCAAP variables can be accessed via [FAO](https://data.apps.fao.org/catalog/dataset/cwp-asfis).

### Nutrients

`McCance_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021.xlsx`

A local copy (as at December 2023) of the CoFID 2021 dataset [available here](https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid).

`fallback_edible_fractions.csv`

A lookup which assigns arbitrary edible fractions to Commodity Group (CG) categories. These edible fractions are loosely based on Hilborn et al (2018). The same FAO broad species groups are included as for the FAO (2001) dataset for macronutrient contents.

`fallback_nutrients.csv`

A lookup which assigns arbitrary kcal and protein content to Commodity Group (CG) categories. These edible fractions are based on the composition tables in the [FAO Food Balance Sheet Handbook (2001)](https://www.fao.org/3/x9892e/X9892e05.htm).

`fao1989_edible_fractions_fixed.csv` and `fao1989_nutrients_fixed.csv`

Two lookups between ERS species codes and nutrient data shown in Table 1 in [FAO (1989)](https://www.fao.org/3/T0219E/T0219E00.htm) were created, one for edible fractions and one for macronutrients. Not all the information contained in Table 1 is incorporated in this CSV file:

* Tentative or provisional figures, indicated by square brackets in Table 1, are taken as given and treated as any other value.
* Where a species had more than one edible fraction or nutrient content figure (e.g. to differentiate between skinless fillet, edible flesh, and meats), these were averaged.
* Rather than using the taxonomic codes provided in Table 2, we match the English name of the species to the name or names in the current ASFIS list. For example, 'Atlantic redfishes' in Table 1 is matched not only to 'Atlantic redfishes nei' as per the taxonomic code (17801001xx) but also to Norway redfish, Beaked redfish, and others. In some cases, Table 1 showed subspecies rather than species (e.g. Sardinops ocellata and Sardinops melanosticta). These were manually matched to species and the associated species codes (e.g. Sardinops sagax, CHP, also known as Pacific sardines). These 'fixes' introduce some new assumptions on species not originally covered in the 1989 analysis, and takes the number of (sub)species covered from 50 to 273. In the case of Pacific sardines, the different edible fractions and nutrient contents covered by the various subspecies were averaged to combine to one species figure.

`robinson2022_edibe_fractions.csv` and `robinson2022_micronutrients.csv`

Edible fractions and micronutrients from Robinson et al (2022) were manually matched to relevant species - either by their FAO species code (ERS), or by MCS category. The MCS category was only used in the cases of 'Shrimp, misc' and 'Shrimp, warmwater' in Robinson et al (and were matched to MCS categories '071 - Shrimp, misc' and '070 - Shrimp, warmwater' respectively).

`rni_targets.csv`

The recommended daily nutrient intakes for kcal, protein, fat, and nine other micronutrients. These were taken from [PHE (2016)](https://assets.publishing.service.gov.uk/media/5a749fece5274a44083b82d8/government_dietary_recommendations.pdf) and, in the case of omega-3, [EFSA (2010)](https://www.efsa.europa.eu/en/efsajournal/pub/1461).

## License

This repository is available under the [Open Government License v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
