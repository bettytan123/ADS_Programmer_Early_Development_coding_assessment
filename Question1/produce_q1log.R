while (sink.number() > 0) sink()

sink("Question1_run_log.txt", split = TRUE)

cat("Run started:", as.character(Sys.time()), "\n")

source("Question_1_sdtm_01_create_ds_domain.R")

cat("Check final dataset\n")
cat("Rows:", nrow(ds), "\n")
cat("Columns:", ncol(ds), "\n")
cat("Column names:\n")
print(names(ds))
cat("Preview:\n")
print(head(ds))

cat("Status: Completed successfully\n")
cat("Run ended:", as.character(Sys.time()), "\n")

sink()