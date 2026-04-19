#-------------------
#Question_1
#Last Updated on 2026-04-19
#Updated by Betty Chen
#-------------------
#need debug
# Objective: 
# Create an SDTM Disposition (DS) domain dataset from raw clinical trial data
# using the {sdtm.oak}.  

# Task: 
# Develop an R program to create the DS domain using
# STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, VISITNUM, 
# VISIT, DSDTC, DSSTDTC, DSSTDY

#--------------------------------------------------
# 1.load library and input data (1.1-1.4)
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
setwd("C:/Users/betty chen/Documents/ADS_Programmer_Early_Development_coding_assessment/Question1")
study_ct <- read_csv("sdtm_ct.csv")

#1.4 load DM for build DSSTDTC
dm<-pharmaversesdtm::dm

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
# 3. build DS with identifiers using sdtm.oak (3.1-3.10)
#--------------------------------------------------

# KEY function clarification :
# assign_no_ct() maps raw variables that do not need controlled terminology. 
# assign_ct() maps raw values through the study CT file into a standardized SDTM value. 
# assign_datetime() parses raw date and time pieces into ISO 8601 character values. 

# Workflow:
# Part_1: no CT variables
# Part_2:date time variables
# Part_3:different logic variables
# Part_4:Derive variables with CT
# Part_5:Require Sort then derive variables
# Part_6:Require other source then derive variables

# ---------------
# Part_1: no CT variables: 
# using assign_no_ct,hardcode_no_ct
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
# Part_2:date time variables: using assign_datetime
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
# Part_3:different logic variables: transmute() + left_join()
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
# Part_4:Derive variables that has CT: using assign_ct()
# ---------------
#3.8 VISIT and VISITNUM 
ds <- assign_ct(
  raw_dat = ds_raw_oak,
  raw_var = "VISIT_RAW",
  tgt_dat = ds,
  tgt_var = "VISIT",
  ct_spec = study_ct,
  ct_clst = "VISIT",
  id_vars = oak_id_vars()
) %>%
  mutate(VISIT=str_to_upper(VISIT))

ds <- assign_ct(
  raw_dat = ds_raw_oak,
  raw_var = "VISIT_RAW",
  tgt_dat = ds,
  tgt_var = "VISITNUM",
  ct_spec = study_ct,
  ct_clst = "VISITNUM",
  id_vars = oak_id_vars()
) %>%
  # handle VISITNUM terms could not be mapped by this controlled terminology
  mutate(
    VISITNUM = str_extract(VISITNUM, "\\d+\\.?\\d*") #extracts numeric part
  )

# ---------------
# Part_5:Require Sort then derive variables
# ---------------
#3.9 DSSEQ : last step to derive require sort first

ds <- ds %>%
  arrange(oak_id )%>%
  mutate(DSTERM = str_to_upper(DSTERM))
  # arrange(USUBJID, DSSTDTC, VISITNUM, DSDTC, DSTERM, DSDECOD)

ds <- derive_seq(
  tgt_dat = ds,
  tgt_var = "DSSEQ",
  rec_vars = c("STUDYID", "USUBJID")#note: this debug the visit issue (think this as a group by)
)
temp_grp_ds <- ds %>%
  group_by(STUDYID, USUBJID) %>%
  mutate(seq = row_number()) %>%
  ungroup()
# ---------------
# Part_6:Require other source then derive variables
#----------------
#3.10 DSSTDY : using subject reference start date in DM, usually RFSTDTC

ds <- derive_study_day(
  sdtm_in = ds,
  dm_domain = dm,
  tgdt = "DSSTDTC",
  refdt = "RFSTDTC",
  study_day_var = "DSSTDY",
  merge_key = "USUBJID"
)

#--------------------------------------------------
# 4. Final DS domain
#--------------------------------------------------
#only keep varibles for final result
ds_final <- ds %>%
  select(
    STUDYID,
    DOMAIN,
    USUBJID,
    DSSEQ,
    DSTERM,
    DSDECOD,
    DSCAT,
    VISITNUM,
    VISIT,
    DSDTC,
    DSSTDTC,
    DSSTDY
  ) %>%
  arrange(USUBJID, DSSEQ)



#--------------------------------------------------
# 5. QC Checks
#--------------------------------------------------
#check column name
names(ds_final)
head(ds_final, 20)

#check category
table(ds_final$DSCAT, useNA = "ifany")
table(ds_truth$DSCAT, useNA = "ifany")
#sth wrong debuggg --> solved in DSSEQ LINE 234
#SAME--> YEAH!

table(ds_final$VISIT, ds_final$VISITNUM, useNA = "ifany")
table(ds_truth$VISIT, ds_final$VISITNUM, useNA = "ifany")
#Now SAME--> YEAH!

# #DEBUG code for ref:
# ds_final <- ds_final %>%
#   arrange(STUDYID, DOMAIN, USUBJID, DSSEQ)
# ds_truth <- ds_truth %>%
#   arrange(STUDYID, DOMAIN, USUBJID, DSSEQ)
# ds <- ds %>%
#   arrange(STUDYID, DOMAIN, USUBJID, DSSEQ, oak_id)
# 
# 
# temp_final <- ds_final %>%
#   filter(ds_final$VISIT != ds_truth$VISIT)
# temp_truth <- ds_truth %>%
#   filter(ds_final$VISIT != ds_truth$VISIT)
# temp_ds <- ds %>%
#     filter(ds$VISIT != ds_truth$VISIT)
# temp_ds_raw <- ds_raw_oak %>%
#     filter(ds$VISIT != ds_truth$VISIT)


table(ds_final$DSDECOD, useNA = "ifany")
table(ds_truth$DSDECOD, useNA = "ifany")
#SAME--> YEAH!

table(ds$DSSTDY==ds_truth$DSSTDY,useNA = 'ifany')
# TRUE <NA> 
#   798   52 
##SAME--> YEAH!


# ---------------------------------------------------------------------------
# 6. Save outputs
# ---------------------------------------------------------------------------
write.csv(
  ds_final,
  file = "ds_final_20260419.csv",
  row.names = FALSE,
  na = ""
)






