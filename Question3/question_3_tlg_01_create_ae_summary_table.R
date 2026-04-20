#-------------------
#Question_3
#Last Updated on 2026-04-19
#Updated by Betty Chen
#-------------------

# Objective:
# Create outputs for adverse events summary using the ADAE dataset 
# and {gtsummary}

# Task: 
# Create a summary table of treatment-emergent adverse events (TEAEs).

setwd("C:/Users/betty chen/Documents/ADS_Programmer_Early_Development_coding_assessment/Question3")
#------------------
# Prepare to save log later
#------------------
# create output folder if it does not exist
if (!dir.exists("output")) {
  dir.create("output")
}

# close any existing sinks
while (sink.number() > 0) sink()

# start log
sink("output/Question3_aesummary_run_log.txt", split = TRUE)

cat("Run started:", as.character(Sys.time()), "\n")


#--------------------------------------------------
# 1.load library and input data (2 files)
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
# 2.Prepare data (2.1-2.2)
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

#--------------------------------------------------
# 4.QC TEST 
#--------------------------------------------------
#alternative way 
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
#SAME--> YEAH!

# -----------------------------------------------------
# 5. Save outputs
# -----------------------------------------------------
gt_tbl <- as_gt(tbl)
gtsave(gt_tbl, "output/Treatment_Emergent_AEs_table.html")


cat("Output dataset saved to: output/Treatment_Emergent_AEs_table.html\n")

cat("Preview of AEs summary table body:\n")
print(head(tbl$table_body, 20))

cat("\nClass of table object:\n")
print(class(tbl))

cat("Table saved successfully\n")
cat("Run ended:", as.character(Sys.time()), "\n")

# close log
sink()



