# Plots of optimization results 
rm(list = ls())
library(tidyverse)
library(ggplot2)
theme_set(theme_bw())

dir = paste0("/Users/tombearpark/Documents/princeton/1st_year/MAE529/",
             "MAE529_code/project/")
data = paste0(dir, "results/data/")
output = paste0(dir, "outputs/figs/")

load_data = function(time, CT, elec_cap, stor_cap, h2_eff, data){
  path = paste(data, time, "/c_tax_", CT, "/EleCpx_", elec_cap, "StorCpx_", 
               stor_cap, "_Eff_", h2_eff, "/")
}
