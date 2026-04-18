#-------------------
#Question_1
#Last Updated on 2026-04-18
#Updated by Betty Chen
#-------------------

# Objective: 
# Create an SDTM Disposition (DS) domain dataset from raw clinical trial data
# using the {sdtm.oak}.  

# Task: 
# Develop an R program to create the DS domain using
# STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, VISITNUM, 
# VISIT, DSDTC, DSSTDTC, DSSTDY

#--------------------------------------------------
# 1.load library and input data (1.1-1.3)
#--------------------------------------------------
library(sdtm.oak)
library(pharmaverseraw)
library(pharmaversesdtm)
library(dplyr)
library(readr)
library(stringr)

#1.1 input data
ds_raw<-pharmaverseraw::ds_raw

#quick QC
names(ds_raw)
# [1] "STUDY"      "PATNUM"     "SITENM"     "INSTANCE"   "FORM"      
#"FORML"      "IT.DSTERM"  "IT.DSDECOD" "OTHERSP"   
# [10] "DSDTCOL"    "DSTMCOL"    "IT.DSSTDAT" "DEATHDT"  

#1.2 input for QC later
ds_truth <- pharmaversesdtm::ds

#quick QC
names(ds_truth)
# [1] "STUDYID"  "DOMAIN"   "USUBJID"  "DSSEQ"    "DSSPID"   
# "DSTERM"   "DSDECOD"  "DSCAT"    "VISITNUM" "VISIT"   
# [11] "DSDTC"    "DSSTDTC"  "DSSTDY"  

#1.3 Read in CT
study_ct <- read_csv("sdtm_ct.csv")


#--------------------------------------------------
# 2. Add oak ID vars and prepare raw data
#--------------------------------------------------

ds_raw_oak <- ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  ) %>%
  mutate(
    STUDYID_RAW = STUDY,
    DOMAIN_RAW  = "DS", #DOMAIN is hard coded to "DS"
    USUBJID_RAW = paste0("01-", PATNUM), #PATNUM came from USUBJID
    
    OTHERSP_CLEAN = str_squish(OTHERSP),
    DSTERM_RAW    = str_squish(`IT.DSTERM`),
    DSDECOD_RAW   = str_squish(`IT.DSDECOD`),
    VISIT_RAW     = str_squish(INSTANCE)
  ) %>%
  mutate(
    VISIT_RAW = case_when(
      VISIT_RAW == "Ambul Ecg Removal" ~ "Ambul ECG Removal",
      TRUE ~ VISIT_RAW
    )
  )


#--------------------------------------------------
# 3. build DS with identifiers using sdtm.oak
#--------------------------------------------------
# ---------------
# no CT variables: using assign_no_ct,hardcode_no_ct
# ---------------
#3.1 STUDYID
ds <- assign_no_ct(
  raw_dat = ds_raw_oak,
  raw_var = "STUDYID_RAW",
  tgt_var = "STUDYID",
  id_vars = oak_id_vars()
)

#3.2 DOMAIN
ds <- hardcode_no_ct(
  raw_dat = ds_raw_oak,
  raw_var = "DOMAIN_RAW",
  tgt_dat = ds,
  tgt_var = "DOMAIN",
  tgt_val = "DS",
  id_vars = oak_id_vars()
)

#3.3 USUBJID
ds <- assign_no_ct(
  raw_dat = ds_raw_oak,
  raw_var = "USUBJID_RAW",
  tgt_dat = ds,
  tgt_var = "USUBJID",
  id_vars = oak_id_vars()
)

#3.4 VISIT: come from INSTANCE 
ds <- assign_no_ct(
  raw_dat = ds_raw_oak,
  raw_var = "VISIT_RAW",
  tgt_dat = ds,
  tgt_var = "VISIT",
  id_vars = oak_id_vars()
)

# ---------------
# date time variables: using assign_datetime
# ---------------
#3.5 DSDTC: come from DSDTCOL and DSTMCO 
ds <- assign_datetime(
  raw_dat = ds_raw_oak,
  raw_var = c("DSDTCOL", "DSTMCOL"),
  tgt_dat = ds,
  tgt_var = "DSDTC",
  raw_fmt = list(
    c("m-d-Y", "m/d/Y", "m-d-y", "m/d/y"),
    c("H:M", "H:M:S")
  ),
  id_vars = oak_id_vars()
)

#3.6 DSSTDTC: come from IT.DSSTDAT 
ds <- assign_datetime(
  raw_dat = ds_raw_oak,
  raw_var = "IT.DSSTDAT", 
  tgt_dat = ds,
  tgt_var = "DSSTDTC",
  raw_fmt = list(c("m-d-Y", "m/d/Y", "m-d-y", "m/d/y")),
  id_vars = oak_id_vars()
)

# ---------------
# different logic variables: transmute() + left_join()
# ---------------
#3.7 DSTERM, DSDECOD, DSCAT using required logic in CRF
ds_logic <- ds_raw_oak %>%
  transmute(
    across(all_of(oak_id_vars())),
    DSTERM = case_when(
      !is.na(OTHERSP_CLEAN) & OTHERSP_CLEAN != "" ~ OTHERSP_CLEAN,
      TRUE ~ DSTERM_RAW
    ),
    DSDECOD = case_when(
      !is.na(OTHERSP_CLEAN) & OTHERSP_CLEAN != "" ~ OTHERSP_CLEAN,
      TRUE ~ DSDECOD_RAW
    ),
    DSCAT = case_when(
      !is.na(OTHERSP_CLEAN) & OTHERSP_CLEAN != "" ~ "OTHER EVENT",
      DSDECOD_RAW == "Randomized" ~ "PROTOCOL MILESTONE",
      TRUE ~ "DISPOSITION EVENT"
    )
  ) %>%
  mutate(
    DSDECOD = str_to_upper(str_squish(DSDECOD))
  )

#Join back to DS domain
ds <- ds %>%
  left_join(ds_logic, by = oak_id_vars())



# ---------------
# Derive variables: using assign_ct()
# ---------------
#3.8 VISIT and VISITNUM using assign_ct()



# LAST ON DSSTDY is then derived against the subject reference start date from DM. 
# LAST ON DSSEQ is not magic; it is determined by your chosen ordering keys. A defensible self-written approach is to derive all content variables first, sort records in a stable subject-level order, and then call derive_seq()

#assign_no_ct() maps raw variables that do not need controlled terminology. 
# assign_ct() maps raw values through the study CT file into a standardized SDTM value. 
# assign_datetime() parses raw date and time pieces into ISO 8601 character values. 
# derive_seq() creates DSSEQ, and derive_study_day() calculates DSSTDY from the DS event date relative to the subject reference date in DM. 










