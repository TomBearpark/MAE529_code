# Plots of optimization results. Use an R script here due to ggplot 
# versatility compared to julia's plotting 

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

# Appends all scenarios together for a given input file, and allocates string ID
get_dfr_results = function(file, data){
  options = expand.grid(CTs = c(0,50,100), elecCPXs = c(200, 500, 800), effs = c(75,80,85))
  df= mapply(load_data, 
        CT = options$CTs, elec_cap = options$elecCPXs, h2_eff = options$effs, 
        MoreArgs = list(file = file, time = "52_weeks", stor_cap = 0.6, data = data), 
        SIMPLIFY = FALSE) %>% 
    bind_rows()
}


# Try and understand whats going on with solve times
df = get_dfr_results("time", data) %>% 
  arrange(time) %>% mutate(hours = time / 3600) %>% data.frame()

lm(data =df, time~CT)
lm(data =df, time~elec_cpx)
lm(data =df, time~CT + h2_eff + elec_cpx)


# Charge
df = get_dfr_results("charge", data)
df %>%
  pivot_longer(cols = c(SOC56, SOC57, SOC58), 
               values_to = "SOC", names_to = "Zone") %>% 
  ggplot() +
  geom_line(aes(x = hour, y  = SOC, color = Zone)) + 
  facet_wrap(vars(CT_string, h2_eff_string, elec_cpx), ncol = 3) 
ggsave(paste0(output, "/SOC.png"), height = 20, width = 10)


# Total storage build
df = get_dfr_results("storage", data) %>% arrange(Total_Storage_MWh) %>% as.data.frame()
df %>% group_by(h2_eff_string, CT_string,Resource, elec_cpx) %>% 
  summarise(stor = sum(Total_Storage_MWh)) %>% arrange(stor) %>% 
  filter(Resource == "Hydrogen") %>% 
  as.data.frame()

















