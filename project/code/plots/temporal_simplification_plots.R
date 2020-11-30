rm(list = ls())
library(tidyverse)
library(ggplot2)
library(plotly)

theme_set(theme_bw())

dir = paste0("/Users/tombearpark/Documents/princeton/1st_year/MAE529/",
             "MAE529_code/project/")
data = paste0(dir, "results/")
output = paste0(dir, "outputs/figs/")

# helper function - loading data, given the parameter values of interest 
source(paste0(dir, "code/plots/utils.R"))

df = load_data(
  "storage", time = "10_days", data = data, CT = 100, elec_cap = 200, h2_eff = 81
) %>%  bind_rows( 
  load_data(
    "storage", time = "10_days", data = data, CT = 100, elec_cap = 200, h2_eff = 81, 
    block = "_2hr"
  )
)
