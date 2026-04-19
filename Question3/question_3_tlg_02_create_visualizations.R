#-------------------
#Question_3
#Last Updated on 2026-04-18
#Updated by Betty Chen
#-------------------

# Task: 
# Visualizations using {ggplot2)
# plot 1: AE severity distribution by treatment (bar chart or heatmap). 
# AE Severity is captured in the AESEV variable in pharmaverseadam::adae dataset


#--------------------------------------------------
# 1.load library and input data (1.1-1.2)
#--------------------------------------------------
library(dplyr)
library(ggplot2)
library(scales)
library(pharmaverseadam)

#1.1 load data
adae <- pharmaverseadam::adae


#--------------------------------------------------
# 2.Prepare plot data (2.1)
#-------------------------------------------------
#2.1 
plot_df <- adae %>%
  filter(!is.na(TRT01A), !is.na(AESEV)) %>%
  group_by(TRT01A, AESEV) %>%
  summarise(n = n(), .groups = "drop")



#--------------------------------------------------
# 3.Build Table using ggplot():Stacked bar chart
#--------------------------------------------------

p_stackbar <- ggplot(plot_df, aes(x = TRT01A, y = n, fill = AESEV)) +
  geom_bar(stat = "identity") +
  labs(
    title = "AE Severity Distribution by Treatment",
    x = "Treatment Arm",
    y = "Count of AEs",
    fill = "Severity/Intensity"
  ) #+
  # theme_minimal()
p_stackbar

# -----------------------------------------------------
# 4. Save outputs: PNG
# -----------------------------------------------------
ggsave(
  filename = "AE_Severity_Distribution_by_Treatment_20260418.png",
  plot = p_stackbar,
  width = 8,
  height = 6,
  dpi = 300
)

######################################################################
######################################################################

# Task: 
# Plot 2: Top 10 most frequent AEs (with 95% CI for incidence rates). 
# AEs are captured in the AETERM variable in the pharmaverseadam::adae dataset.

#--------------------------------------------------
# 1.load library and input data (1.1)
#--------------------------------------------------
library(dplyr)
library(ggplot2)
library(stringr)
library(scales)
library(pharmaverseadam)
library(binom)

#1.1 load data
adae <- pharmaverseadam::adae

#--------------------------------------------------
# 2.Prepare plot data (2.1-2.4)
#-------------------------------------------------
#2.1 find total number of subjects
n_subj <- n_distinct(adae$USUBJID)

# 2.2 create top 10 most frequent AEs by subject count
ae_top10 <- adae %>%
  filter(!is.na(AETERM), AETERM != "") %>%
  distinct(USUBJID, AETERM) %>%   # ensure no duplicate one subject once per AE term
  count(AETERM, name = "n") %>%
  arrange(desc(n), AETERM) %>%
  slice_head(n = 10) %>%
  mutate(
    pct = n / n_subj
  )

# 2.3 Clopper-Pearson 95% CI
ci <- binom.confint(
  x = ae_top10$n,
  n = n_subj,
  methods = "exact"
)

#2.4merge for final number
plot_ae_top10 <- ae_top10 %>%
  mutate(
    lower = ci$lower,
    upper = ci$upper
  ) %>%
  arrange(pct) %>%
  mutate(
    AETERM = factor(AETERM, levels = AETERM)
  )

#--------------------------------------------------
# 3.Build Graph using ggplot():Dot-and-whisker plot
#--------------------------------------------------

p_ae <- ggplot(plot_ae_top10, aes(x = pct, y = AETERM)) +
  geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0.2, size = 0.6) +
  geom_point(size = 3) +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    expand = expansion(mult = c(0.02, 0.05))
  ) +
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = paste0("n = ", n_subj, " subjects; 95% Clopper-Pearson CIs"),
    x = "Percentage of Patients (%)",
    y = NULL
  ) +
  theme_gray(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    axis.text.y = element_text(size = 11),
    panel.grid.major.y = element_line(linewidth = 0.3),
    panel.grid.minor = element_blank()
  )

p_ae

# -----------------------------------------------------
# 4. Save outputs: PNG
# -----------------------------------------------------
ggsave(
  filename = "Top10_Most_Frequent_AEs_20260418.png",
  plot = p,
  width = 8,
  height = 5.5,
  dpi = 300
)
