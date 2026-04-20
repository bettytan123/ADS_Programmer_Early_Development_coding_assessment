#save the adae data in the same folder for preparation
# Load package
library(pharmaverseadam)

setwd("C:/Users/betty chen/Documents/ADS_Programmer_Early_Development_coding_assessment/Question4")

# Load adae dataset
data("adae")

# Save to CSV in your current working directory
write.csv(
  adae,
  file = "adae.csv",
  row.names = FALSE,
  na = ""
)
