# Data exploration - final project

rm(list = ls())
library(tidyverse)
library(ggplot2)
theme_set(theme_bw())

dir = paste0("/Users/tombearpark/Documents/princeton/1st_year/MAE529/",
             "MAE529_code/project/")
input = paste0(dir, "input_data/ercot_brownfield_expansion/")
output = paste0(dir, "/outputs/eda/")

# Load in the load data
df = read_csv(paste0(input, "52_weeks/Load_data.csv"))

# Clean up and plot
plot_df  = df %>% 
  select(c(Time_index, Load_MW_z1, Load_MW_z2, Load_MW_z3)) %>% 
  pivot_longer(cols = c("Load_MW_z1", "Load_MW_z2", "Load_MW_z3"), 
               names_to = "region", values_to = "load")

ggplot(data = plot_df) + 
  geom_line(aes(x = Time_index, y = load, color = region)) + 
  facet_wrap(~region, scales = "free")

ggsave(paste0(output, "load_by_node.png"), height = 10, width = 15)

# Variability information
df_var = read_csv(paste0(input, 
                         "52_weeks/Generators_variability.csv")) %>% 
  rename(Time_index = X1)

plot_df_var = df_var %>% 
  pivot_longer(!Time_index, names_to = "generator", values_to = "variability")

ggplot(data = plot_df_var) + 
  geom_line(aes(x = Time_index, y = variability)) + 
  facet_wrap(~generator)
