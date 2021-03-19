# PLotting outputs of temporal simplification test

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

# Plot smoothed vs unsmoothed version
var = read_csv(paste0(dir, 
        "/input_data/ercot_brownfield_expansion/52_weeks/Load_data.csv")) %>% 
  select(c(Time_index, Load_MW_z1, Load_MW_z2, Load_MW_z3)) %>% 
  pivot_longer(cols = c("Load_MW_z1", "Load_MW_z2", "Load_MW_z3"), 
               names_to = "region", values_to = "load")

# Variability information collapsed 
var_simplified = var %>% 
  group_by(region) %>% 
    mutate(id = row_number() - 1) %>% 
  ungroup() %>% 
  mutate(grp = floor(id /2)) %>% 
  group_by(grp, region) %>% 
    summarise(load = mean(load)) %>% 
  ungroup() %>% 
  group_by(region) %>% 
    mutate(Time_index = row_number() * 2) %>% 
  ungroup()

t = 24 * 100
ggplot() + 
  geom_line(data = var, aes(x= Time_index,y=load , color = region)) + 
  geom_line(data = var_simplified, aes(x= Time_index,y=load , color = "Simplified")) + 
  facet_wrap(~region, scales = "free") + 
  xlim( c(t,t + 48))

ggplot() + 
  geom_line(data = var_simplified, aes(x= Time_index,y=load , color = region)) + 
  facet_wrap(~region, scales = "free")


# Times comparison

df = load_data(
  "time", time = "52_weeks", data = data, CT = 100, elec_cap = 200, h2_eff = 50
) %>%  bind_rows( 
  load_data(
    "time", time = "52_weeks", data = data, CT = 100, elec_cap = 200, h2_eff = 50, 
    block = "_2hr"
  )
)

df = load_data(
  "charge", time = "52_weeks", data = data, CT = 100, elec_cap = 200, h2_eff = 50
) %>%  bind_rows( 
  load_data(
    "charge", time = "52_weeks", data = data, CT = 100, elec_cap = 200, h2_eff = 50, 
    block = "_2hr"
  )
)
ggplot(data =df %>% mutate(hour = ifelse(block == "_2hr", 2*hour, hour))) + 
  geom_line(aes(x = hour, y = SOC57)) + 
  geom_line(aes(x = hour, y = SOC56), color = "red") + 
  geom_line(aes(x = hour, y = SOC58), color = "blue") + 
    facet_grid(~block)










