# Script for producing a plot which was hard to wrangle in Julia

# Load packages
library(ggplot2)
library(tidyverse)

# Set strings 
dir = "/Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/5_assignment/results"
file = paste0(dir, "/q1_gen_by_resource_without_carbon_tax.csv")
file_c = paste0(dir, "/q1_gen_by_resource_with_carbon_tax.csv")

# load data produced by jl scripts
df = bind_rows(read_csv(file) %>% mutate(carbon_tax="no"), 
               read_csv(file_c) %>% mutate(carbon_tax="yes"))

# Clean up for plotting
plot_df = df %>% 
  group_by(Resource, time_subset, carbon_tax) %>%
  summarise(Total_MW = sum(Total_MW)) %>% 
  ungroup() %>%
  mutate(hours  = ifelse(time_subset == "10_days", 10 * 24, 0)) %>% 
  mutate(hours  = ifelse(time_subset == "4_weeks", 4*7*24, hours))%>% 
  mutate(hours  = ifelse(time_subset == "8_weeks", 8*7*24, hours))%>% 
  mutate(hours  = ifelse(time_subset == "16_weeks", 16*7*24, hours)) 

# Plot! 
plot_df_noCT = plot_df %>% filter(carbon_tax == "no")
ggplot(data = plot_df_noCT) + 
  geom_point(aes(x = hours, y = Total_MW, color = carbon_tax)) + 
  facet_wrap(~Resource, ncol = 3)
ggsave(paste0(dir, "/figs/generation_no_CT.png"))

ggplot(data = plot_df) + 
  geom_point(aes(x = hours, y = Total_MW, color = carbon_tax)) + 
  facet_wrap(~Resource, ncol = 3)
ggsave(paste0(dir, "/figs/generation_comparison.png"))
