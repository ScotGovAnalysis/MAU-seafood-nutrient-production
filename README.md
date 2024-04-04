# MAU - Seafood nutrient mapping

<!-- badges: start -->
[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
<!-- badges: end -->

## Introduction 
This repository contains the code and methodology used to match seafood species to (estimated) nutrient contents. This is used internally within the Scottish Government to estimate the total volume of macro- and micronutrients produced from Scottish seafood production by mapping these nutrient content estimates to production volume figures.

For the purposes of this public repository, only the nutrient content assumptions (by species) are included as data files - not the detailed production data files used internally. The nutrient content assumptions could however be used in conjunction with published production data such as the [Scottish sea fisheries statistics](https://www.gov.scot/collections/sea-fisheries-statistics/), the [Scottish fish farm production survey](https://www.gov.scot/collections/scottish-fish-farm-production-surveys/), or the [Scottish shellfish farm production survey](https://www.gov.scot/collections/scottish-shellfish-farm-production-surveys/) (all published by Scottish Government). Fisheries production data for the UK as a whole can be found on the [Marine Management Organisation's website](https://www.gov.uk/government/collections/uk-sea-fisheries-annual-statistics).

## Data sources
The conversion of live weight fish and shellfish to macro- and micronutrients requires estimates for (a) edible fractions and (b) nutrient contents.

### Edible fractions
Edible fractions convert the live weight (whole fish) to edible portions. There is variability in the proportion of any given fish that is edible due to factors like the fish's species, age, and diet, but also due to what parts of the fish are deemed desirable. For example, cuts like fillets and loins may be more commonly consumed than other parts of the fish like tail and liver, but this greatly depends on culture, social settings, affordability, and personal preferences. For the purpose of this analysis, we use edible fractions from a variety of sources.

Two key sources were [FAO (1989)](https://www.fao.org/3/T0219E/T0219E00.htm) and [Robinson et al (2022)](https://iopscience.iop.org/article/10.1088/1748-9326/aca490), which both contain estimates for edible fractions for a number of species (which is taken to mean either lean or fatty meat, without bone, raw). Together, they accounted for 54 individual species (and roughly three quarters of Scottish production by volume).

For the remaining species, a 'fallback' edible fraction estimate was used in the absence of a better estimate. Here, Hilborn et al (2018) was used to create generic edible fractions for species groups. For example, Carp (0.42) and Tilapia (0.38) were averaged to create an estimate for the Commodity Group (CG) 'Freshwater fish', with 0.4 being the assumed edible fraction for any freshwater fish that didn't have an estimate from FAO (1989) or Robinson et al (2022).

We are currently investigating how we can incorporate the added uncertainty for these affected species into this work, and whether there are better sources available ([Fishbase](https://github.com/mamacneil/NutrientFishbase), for example, which is a model that predicts nutrient contents based on certain species characteristics).

### Macronutrients
Currently, the 1989 FAO paper is used to provide macronutrient content estimates (energy, protein, fat) for 45 specific species, accounting for roughly 60% of total Scottish production by volume. The benefit of using this source is that it comes from the same analysis as the majority of the edible fraction data - however, other sources exist exist as well, some more up to date than others. One example of this is [CoFID (2021)](https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid), which we currently use for the majority of micronutrient content estimates.

For the remaining 40% of production, we use 'fallback' estimates from FAO (2001), which provide average estimates for broad species groups (e.g. demersal fish, pelagic fish, crustaceans). Like with edible fractions, we are exploring other options for these species.

### Micronutrients
For micronutrients, we primarily use Cofid (2021), which is a comprehensive and up-to-date collection of nutrient contents for a wide variety of food products consumed in the UK. While many fish and shellfish species are represented, they are not always analysed in a 'raw, flesh only' state (e.g. some are analysed in various cooked forms, or as part of complete dishes). Robinson et al (2022) was used to complement some of the missing species, which meant that in total 32 species or nearly 50% of production by volume was covered.

Note that not every species necessarily had an estimate for the full set of micronutrients covered in Cofid (e.g. many only had a handful, and omega-3 fatty acids had the best coverage), and that in some cases the species in CoFID had to manually matched to one or more specific species (e.g. estimates for 'shrimp' were applied to a variety of shrimp species).

For those species that had an 'unknown substantial amount' denoted by N in CoFID, we imputed these values with the Main Commercial Species' average for that nutrient. Trace amount (denoted by Tr) were given a generic sufficiently small number (0.0001). Any remaining species that had missing values in a specific nutrient were not given any 'broad' fallback estimate like with macronutrients. These adjustments took the species covered (in one or more micronutrients) to over 80% by volume.

## Data dictionary (inputs)

### Lookups

`cofid_species_lookup.csv`

A data file which matches all relevant fish and shellfish-related codes in the CoFID 2021 dataset that concerned raw and flesh-only products (i.e. having a Food Code starting with 16, and filtered by relevant phrases in the Food Name column) to:

* three-letter FAO species code (`ERSCode`) where possible (these will have `Approximated` set to `FALSE`),
* EUMOFA MCS category where not possible, e.g. 'Cuttlefish' in CoFID is matched the MCS category '73 - Cuttlefish' (these will have `Approximated` set to `TRUE`).

In some cases, the CoFID species was matched to more than one MCS category:
* For example, 'Seabass' in CoFID is matched to the MCS categories 'Seabass, other' and 'Seabass, European' in the absence of species information. These will also have `Approximated` set to `TRUE`.

In some cases, the MCS category was an 'Other ...' category where the CoFID species was more specific (an 'Other ...' MCS category generally contains dozens of different species). In these cases, efforts were made to match these to specific species codes:
* For example, 'Parrot fish' in CoFID did not have a specific match in the MCS categories, and so would fall under either '8 - Other freshwater fish' and/or '62 - Other marine fish'. We instead matched this species to various species with an English name matching 'parrotfish' or 'parrot fish'. 
* Another example is 'Plaice', which did have relevant MCS categories (e.g. 99 - Plaice, European) but which could potentially also concern species in '30 - Plaice, other' and '62 - Other marine fish' (in the case of the scale-eye plaice).
* All of these cases also have `Approximated` set to `TRUE`.

Some of these species matches and inclusions are still being revised and are subject to change (e.g. currently, 'Cod' in CoFID in only matched to the MCS category '13 - Cod' but could potentially also apply to some species in MCS categories '24 - Other groundfish' or '62 - Other marine fish'.

## License

The methodology and code is published to facilitate feedback and enable collaboration with researchers at our Main Research Providers and beyond. This repository is available under the [Open Government License v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
