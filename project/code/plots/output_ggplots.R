# Plots of optimization results 
rm(list = ls())
library(tidyverse)
library(ggplot2)
theme_set(theme_bw())

dir = paste0("/Users/tombearpark/Documents/princeton/1st_year/MAE529/",
             "MAE529_code/project/")
data = paste0(dir, "results/")
output = paste0(dir, "outputs/figs/")

# helper function - loading data, given the parameter values of interest 
load_data = function(file, time = "52_weeks", CT, elec_cap, stor_cap = 0.6, h2_eff, data){
  path = paste0(data, time, "/c_tax_", CT, "/EleCpx_", elec_cap, "_StorCpx_", 
               stor_cap, "_Eff_", h2_eff, "/")
  df = read_csv(paste0(path, file, "_results.csv")) %>% 
    mutate(CT = paste0("Carbon Tax: $", CT) , 
           elec_cpx = elec_cap, stor_cap = stor_cap, 
           h2_eff = paste0("H2 Efficiency: ", h2_eff, "%"))
  return(df)
}


# Function to create a plotting dataframe

get_comp_df = function(data, elect_CPX, var){
  
  df= load_data(var, CT = 0, elec_cap = elect_CPX, h2_eff = 80, data = data) %>% 
    bind_rows(
      load_data(var, CT = 0, elec_cap = elect_CPX, h2_eff = 85, data = data) 
    )  %>% 
    bind_rows(
      load_data(var, CT = 50, elec_cap = elect_CPX, h2_eff = 80, data = data) 
    ) %>%  
    bind_rows(
      load_data(var, CT = 50, elec_cap = elect_CPX, h2_eff = 85, data = data) 
    )  %>% 
    bind_rows(
      load_data(var, CT = 100, elec_cap = elect_CPX, h2_eff = 80, data = data) 
    ) %>%  
    bind_rows(
      load_data(var, CT = 100, elec_cap = elect_CPX, h2_eff = 85, data = data) 
    ) 
  return(df)
}

df = get_comp_df(data = data, elect_CPX = "200.0", var  = "charge") %>% 
    select(c(hour, SOC56, SOC57,  SOC58,    CT, elec_cpx, stor_cap, h2_eff)) %>%
    pivot_longer(cols = c(SOC56, SOC57, SOC58), values_to = "SOC", names_to = "Zone") %>% 
    mutate(CT_F = factor(CT, levels=c("Carbon Tax: $0", "Carbon Tax: $50","Carbon Tax: $100"))) %>% 
  mutate(Zone = recode(Zone, "SOC56" ="1", "SOC57" ="2", "SOC58" ="3"))

ggplot(data = df) + 
  geom_line(aes(x = hour, y = SOC, color= Zone)) + 
  facet_wrap(vars(h2_eff, CT_F)) + 
  ggtitle("Hydrogen SOC at each node, Elec Cpx 200, Varying efficiency and Carbon Tax")

ggsave(paste0(output, "/SOC_comparison.png"))


