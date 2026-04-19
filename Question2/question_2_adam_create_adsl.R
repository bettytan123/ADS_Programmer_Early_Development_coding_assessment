#-------------------
#Question_2
#Last Updated on 2026-04-18
#Updated by Betty Chen
#-------------------

# Objective:
#Create an ADSL (Subject Level) dataset using SDTM source data,
#the {admiral} family of packages, and tidyverse tools.

# Task: 
# Develop an R program to create the ADSL using the input SDTM data

setwd("C:/Users/betty chen/Documents/ADS_Programmer_Early_Development_coding_assessment/Question2")
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
sink("output/Question2_run_log.txt", split = TRUE)

cat("Run started:", as.character(Sys.time()), "\n")


#--------------------------------------------------
# 1.load library and input data (5 files)
#--------------------------------------------------
library(metacore)
library(metatools)
library(pharmaversesdtm)
library(admiral)
library(xportr)
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)

#Read in all input SDTM data
dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae


#--------------------------------------------------
# 2. Prepare raw data (clean NA) + set domain (2.1-2.2)
#--------------------------------------------------
#2.1 CLEAN SDTM source dataset with convert_blanks_to_naNA 
dm <- convert_blanks_to_na(dm)
vs <- convert_blanks_to_na(vs)
ex <- convert_blanks_to_na(ex)
ds <- convert_blanks_to_na(ds)
ae <- convert_blanks_to_na(ae)

#2.2 The DM domain is used as the basis for ADSL:
adsl <- dm %>%
  select(-DOMAIN)


#--------------------------------------------------
# 3.  Build all the derived the variables (3.1-3.4)
#--------------------------------------------------

# ----------------------
# 3.1 Derive AGEGR9 and AGEGR9N
# Categories: "<18", "18 - 50", ">50"
# Numeric groups: 1, 2, 3
# ----------------------
agegr9_def <- exprs(
  ~condition,           ~AGEGR9,    ~AGEGR9N,
  AGE < 18,             "<18",              1,
  between(AGE, 18, 50), "18 - 50",          2,
  AGE > 50,             ">50",              3
)

adsl <- adsl %>%
  derive_vars_cat(definition = agegr9_def)


# ------------------------
# 3.2 Derive ITTFL
# Set to "Y" if DM.ARM is populated, else "N"
# ------------------------
adsl <- adsl %>%
  mutate(
    ITTFL = if_else(!is.na(ARM), "Y", "N")
  )

# ----------------------
# 3.3 Derive TRTSDTM/TRTSTMF
# - use first exposure record for each participant
# - use first valid dose: EXDOSE > 0 OR (EXDOSE == 0 and EXTRT contains "PLACEBO")
# - imputing missing hours and minutes but not seconds 
#   (NOT impute incomplete dates)
# - If only seconds are missing then do not populate the imputation flag (TRTSTMF).
# Note: TRTEDTM/TRTEDT are derived for LSTAVLDT later 
# ----------------------

# Note: Impute start and end time of exposure to first and last respectively,
# Do not impute date
# code ref from https://pharmaverse.github.io/admiral/cran-release/articles/adsl.html#readdata
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    highest_imputation = "h", #imputes time 00:00:00 but NOT impute date
    time_imputation = "first", 
    ignore_seconds_flag = TRUE #if only seconds missing do not populate the imputation flag
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    highest_imputation = "h",
    time_imputation = "last",
    ignore_seconds_flag = TRUE
  )

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    #valid dose definition
    by_vars = exprs(STUDYID, USUBJID),
    filter_add = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) & 
      !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first"
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    by_vars = exprs(STUDYID, USUBJID),
    filter_add = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
      !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last"
  ) %>%
  derive_vars_dtm_to_dt(
    source_vars = exprs(TRTSDTM, TRTEDTM)
  )

# ------------------------
# 3.4 Derive LSTAVLDT
#Workflow
# step1: use complete date:
# - 1)VS: use VSDTC date if VSSTRESN and VSSTRESC are not both missing
# - 2)AE: use AESTDTC date
# - 3)DS: use DSSTDTC date
# - 4)ASDL: use TRTEDTM (already in ADSL as TRTEDT)
# step2: FIND maximum 
# - 1) last valid VS date
# - 2) last AE onset date
# - 3) last DS date
# - 4) last treatment date (TRTEDT)
# ----------------------
#step1
vs_ext <- vs %>%
  derive_vars_dt(
    dtc = VSDTC,
    new_vars_prefix = "VS"
  )

ae_ext <- ae %>%
  derive_vars_dt(
    dtc = AESTDTC,
    new_vars_prefix = "AEST"
  )

ds_ext <- ds %>%
  derive_vars_dt(
    dtc = DSSTDTC,
    new_vars_prefix = "DSST"
  )

# step2
adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event(
        dataset_name = "vs",
        order = exprs(VSDT, VSSEQ),
        mode = "last",
        condition = !is.na(VSDT) & !(is.na(VSSTRESN) & is.na(VSSTRESC)),
        set_values_to = exprs(LSTAVLDT = VSDT)
      ),
      event(
        dataset_name = "ae",
        mode = "last",
        order = exprs(AESTDT, AESEQ),
        condition = !is.na(AESTDT),
        set_values_to = exprs(LSTAVLDT = AESTDT)
      ),
      event(
        dataset_name = "ds",
        order = exprs(DSSTDT, DSSEQ),
        mode = "last",
        condition = !is.na(DSSTDT),
        set_values_to = exprs(LSTAVLDT = DSSTDT)
      ),
      event(
        dataset_name = "adsl",
        order = exprs(TRTEDT),
        mode = "last",
        condition = !is.na(TRTEDT),
        set_values_to = exprs(LSTAVLDT = TRTEDT)
      )
    ),
    source_datasets = list(
      vs = vs_ext,
      ae = ae_ext,
      ds = ds_ext,
      adsl = adsl
    ),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTAVLDT, event_nr),
    mode = "last",
    new_vars = exprs(LSTAVLDT)
  )


#--------------------------------------------------
# 4. Final ADSL domain (Cosmetics: add label + change arrangement)
#--------------------------------------------------
attr(adsl$AGEGR9, "label")  <- "Age Group (<18, 18-50, >50)"
attr(adsl$AGEGR9N, "label") <- "Age Group (Numeric: 1=<18, 2=18-50, 3=>50)"
attr(adsl$ITTFL, "label")   <- "Intent-to-Treat Population Flag"
attr(adsl$TRTSDTM, "label") <- "Date/Time of First Exposure to Treatment"
attr(adsl$TRTSTMF, "label") <- "Start Date/Time of Treatment Imputation Flag"
attr(adsl$TRTEDTM, "label") <- "Date/Time of Last Exposure to Treatment"
attr(adsl$TRTETMF, "label") <- "End Date/Time of Treatment Imputation Flag"
attr(adsl$TRTSDT, "label")  <- "Date of First Exposure to Treatment"
attr(adsl$TRTEDT, "label")  <- "Date of Last Exposure to Treatment"
attr(adsl$LSTAVLDT, "label") <- "Last Date Known Alive"


adsl_final <- adsl %>%
  # Age group after AGE
  relocate(AGEGR9, AGEGR9N, .after = AGE) %>%
  
  # ITTFL after ARM
  relocate(ITTFL, .after = ARM) %>%
  
  # Move treatment + survival-related variables toward end
  relocate(
    TRTSDTM, TRTSTMF,
    TRTEDTM, TRTETMF,
    TRTSDT, TRTEDT,
    LSTAVLDT,
    .after = last_col()
  )

#--------------------------------------------------
# 5. QC Checks
#--------------------------------------------------
#5.1 double coding on AGEGR9 using mutate()
table(adsl_final$AGEGR9, useNA = 'ifany')
# >50 18 - 50 
# 305       1 
table(adsl_final$AGEGR9N, useNA = 'ifany')
# 2   3 
# 1 305 
#SAME--> YEAH!

adsl2 <- dm %>%
  select(-DOMAIN)
adsl2 <- adsl2 %>%
  mutate(
    AGEGR9 = case_when(
      is.na(AGE) ~ NA_character_,
      AGE < 18 ~ "<18",
      AGE >= 18 & AGE <= 50 ~ "18 - 50",
      AGE > 50 ~ ">50"
    ),
    AGEGR9N = case_when(
      is.na(AGE) ~ NA_real_,
      AGE < 18 ~ 1,
      AGE >= 18 & AGE <= 50 ~ 2,
      AGE > 50 ~ 3
    )
  )
table(adsl2$AGEGR9, useNA = 'ifany')
# >50 18 - 50 
# 305       1 
table(adsl2$AGEGR9N, useNA = 'ifany')
# 2   3 
# 1 305
#SAME--> YEAH!

#5.2 check if LSTAVLDT date is last date
table(adsl$LSTAVLDT >= as.Date(adsl$TRTSDTM), useNA = "ifany")
# TRUE <NA> 
#   254   52 

#double-coding LSTAVLDT using dplyr 
# check_vs <- vs_ext %>%
#   filter(!is.na(VSDT) & !(is.na(VSSTRESN) & is.na(VSSTRESC))) %>%
#   arrange(USUBJID, VSDT, VSSEQ) %>%
#   group_by(USUBJID) %>%
#   slice_tail(n = 1) %>%
#   ungroup() %>%
#   select(USUBJID, LAST_VS_DT = VSDT, VSDTC, VSSEQ, VSSTRESN, VSSTRESC)
# 
# check_ae <- ae_ext %>%
#   filter(!is.na(AESTDT)) %>%
#   arrange(USUBJID, AESTDT, AESEQ) %>%
#   group_by(USUBJID) %>%
#   slice_tail(n = 1) %>%
#   ungroup() %>%
#   select(USUBJID, LAST_AE_DT = AESTDT, AESTDTC, AESEQ)
# 
# check_ds <- ds_ext %>%
#   filter(!is.na(DSSTDT)) %>%
#   arrange(USUBJID, DSSTDT, DSSEQ) %>%
#   group_by(USUBJID) %>%
#   slice_tail(n = 1) %>%
#   ungroup() %>%
#   select(USUBJID, LAST_DS_DT = DSSTDT, DSSTDTC, DSSEQ)
# 
# check_trt <- adsl %>%
#   select(USUBJID, TRTEDTM, TRTEDT)
# 
# check_lstavldt <- adsl %>%
#   select(USUBJID, LSTAVLDT) %>%
#   left_join(check_vs, by = "USUBJID") %>%
#   left_join(check_ae, by = "USUBJID") %>%
#   left_join(check_ds, by = "USUBJID") %>%
#   left_join(check_trt, by = "USUBJID") %>%
#   mutate(
#     EXPECTED_LSTAVLDT = pmax(LAST_VS_DT, LAST_AE_DT, LAST_DS_DT, TRTEDT, na.rm = TRUE)
#   )
# 
# wrong<-check_lstavldt %>%
#   filter(LSTAVLDT != EXPECTED_LSTAVLDT | (is.na(LSTAVLDT) != is.na(EXPECTED_LSTAVLDT)))
# wrong
# 0 obs-->means correct 
#SAME--> YEAH!

# -----------------------------------------------------
# 6. Save outputs
# -----------------------------------------------------
write.csv(
  adsl_final,
  file = "output/adsl_final_20260419.csv",
  row.names = FALSE,
  na = ""
)

cat("Output dataset saved to: output/adsl_final_20260419.csv\n")
cat("Number of rows:", nrow(adsl_final), "\n")
cat("Number of columns:", ncol(adsl_final), "\n")
cat("Column names:\n")
print(names(adsl_final))
cat("Preview of dataset:\n")
print(head(adsl_final))

cat("Status: Completed successfully\n")
cat("Run ended:", as.character(Sys.time()), "\n")

# close log
sink()