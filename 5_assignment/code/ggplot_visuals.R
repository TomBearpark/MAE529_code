# Script for producing a plot which was hard to wrangle in Julia

# Load packages - make sure you have those installed. 
# If not, run: install.packages(c("ggplot2", "tidyverse"))

library(ggplot2)
library(tidyverse)
theme_set(theme_bw())

# Set strings  - make sure to update this dir to the location of the zip file on
# your machine

dir = paste0("/Users/tombearpark/Documents/princeton/1st_year/MAE529/", 
             "MAE529_code/5_assignment/results")
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
  facet_wrap(~Resource, ncol = 3, scales = "free")
ggsave(paste0(dir, "/figs/q1_generation_no_CT.png"), 
       height = 12.5, width = 12)

ggplot(data = plot_df) + 
  geom_point(aes(x = hours, y = Total_MW, color = carbon_tax)) + 
  facet_wrap(~Resource, ncol = 3, scales = "free")
ggsave(paste0(dir, "/figs/q1_generation_comparison.png"), 
       height = 12.5, width = 12)

# Question 2

# Load data
path = function(q) paste0(dir, "/data/question_", q, 
        "/8_weeks_Thomas_Bearpark/without_carbon_tax/generator_results.csv")

df = bind_rows(read_csv(path(2)) %>% mutate(UC = "With UC") ,
               read_csv(path(1)) %>% mutate(UC = "Without UC") )
  
# Find total capacity by resource
plot_df = df %>% 
  group_by(Resource, UC) %>%
  summarise(Total_MW = sum(Total_MW)) %>% 
  ungroup() 

# Plot and save
ggplot(data = plot_df) + 
  geom_bar(aes(x = UC, y = Total_MW, fill = UC), stat = "identity", 
              position=position_dodge()) + 
  facet_wrap(~Resource, ncol = 3, scales = "free")

ggsave(paste0(dir, "/figs/q2_UC_generation_comparison.png"), 
       height = 12.5, width = 12)

# 2c - linear relaxation

# Load data, and clean up
df2c = read_csv(paste0(dir, "/q2c_linear_gen.csv"))
plot_df = bind_rows(read_csv(path(2)) %>% mutate(UC = "With UC") ,
               read_csv(path(1)) %>% mutate(UC = "Withour UC"), 
               df2c %>% mutate(UC = "Linear Relax."))

# Plot and save
ggplot(data = plot_df) + 
  geom_bar(aes(x = UC, y = Total_MW, fill = UC), stat = "identity", 
           position=position_dodge()) + 
  facet_wrap(~Resource, ncol = 3, scales = "free")

ggsave(paste0(dir, "/figs/q2_UC_and_linear_generation_comparison.png"), 
       height = 12.5, width = 12)
       












