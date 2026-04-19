#-------------------
#Question_3
#Last Updated on 2026-04-18
#Updated by Betty Chen
#-------------------

# Objective:
# Create outputs for adverse events summary using the ADAE dataset 
# and {gtsummary}

# Task: 
# Create a summary table of treatment-emergent adverse events (TEAEs).

#--------------------------------------------------
# 1.load library and input data (1.1-1.2)
#--------------------------------------------------
library(dplyr)
library(tidyr)
library(purrr)
library(gtsummary)
library(gt)
library(pharmaverseadam)

#1.1-1.2 load data
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

#--------------------------------------------------
# 2.Prepare data (2.1)
#-------------------------------------------------
#2.1 create denominator
adsl_pop <- adsl%>%
  #safety population
  filter(!is.na(ACTARM), ACTARM != "Screen Failure") %>%
  select(USUBJID, ACTARM)

#2.2 create numerator: filter treatment-emergent AE records
teae <- adae %>%
  filter(TRTEMFL == "Y") %>%
  filter(!is.na(ACTARM), ACTARM != "Screen Failure")%>%
  select(USUBJID, ACTARM, AESOC, AETERM,AEDECOD)#keep key variables in table required


#--------------------------------------------------
# 3.Build Table using tbl_hierarchical()
#--------------------------------------------------
# code ref from: https://pharmaverse.github.io/cardinal/quarto/catalog/fda-table_10/


tbl <- teae %>%
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl_pop,
    statistic = everything() ~ "{n} ({p}%)",
    overall_row = TRUE,
    label = list(
      AESOC ~ "Primary System Organ Class",
      AETERM ~ "Reported Term for the Adverse Event",
      "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
    )
  ) %>%
  add_overall(last = TRUE) %>%
  sort_hierarchical(sort = everything() ~ "descending")

tbl

# -----------------------------------------------------
# 4. Save outputs
# -----------------------------------------------------
gt_tbl <- as_gt(tbl)
gtsave(gt_tbl, "Treatment_Emergent_AEs_table.html")


#--------------------------------------------------
# 5.QC TEST for Build Table using tbl_hierarchical()
#--------------------------------------------------

tbl2 <- teae %>%
  tbl_hierarchical(
    variables = c(AESOC, AEDECOD),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl_pop,
    statistic = everything() ~ "{n} ({p}%)",
    overall_row = TRUE,
    label = list(
      AESOC ~ "Primary System Organ Class",
      AEDECOD ~ "Reported Term for the Adverse Event",
      "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
    )
  ) %>%
  add_overall(last = TRUE) %>%
  sort_hierarchical(sort = everything() ~ "descending")

tbl2


# tbl2 <- teae %>%
#   tbl_hierarchical(
#     variables = c(AESOC, AEDECOD),
#     by = ACTARM,
#     id = USUBJID,
#     denominator = adsl_pop,
#     statistic = everything() ~ "{n} ({p}%)",
#     overall_row = TRUE,
#     label = list(
#       "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
#     )
#   ) %>%
#   sort_hierarchical(sort = everything() ~ "descending") %>%
#   modify_header(
#     label ~ "**Primary System Organ Class**<br>**Reported Term for the Adverse Event**"
#   )
# 
# tbl2

tbl2

tbl2 <- adae |>
  tbl_hierarchical(
    variables = c(AESOC, AEDECOD),
    by = TRT01A,
    id = USUBJID,
    denominator = adsl,
    overall_row = TRUE,
    label = "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs",
    #statistic = everything() ~ "{n} ({p}%)",
    #overall_row = TRUE,
  )#%>%
  # add_overall(last = TRUE) %>%
  # sort_hierarchical(sort = everything() ~ "descending")


tbl2


#correct ewith picture 1 but not right with picure 2 
tbl5 <- adae |>
  tbl_hierarchical(
    variables = c(AESOC, AEDECOD),
    by = TRT01A,
    id = USUBJID,
    denominator = adsl,
    overall_row = TRUE,
    label = "..ard_hierarchical_overall.." ~ "Any SAE"
  )

tbl5


