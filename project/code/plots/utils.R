load_data = function(file, time = "52_weeks", stor_cap = 0.6, data,
                     CT, elec_cap, h2_eff, block = "")
{
  # Get string of path from intputs 
  path = paste0(data, time, "/c_tax_", CT, "/EleCpx_", elec_cap, "_StorCpx_", 
                stor_cap, "_Eff_", h2_eff, block, "/")
  
  # Load and format data
  df = read_csv(paste0(path, file, "_results.csv")) %>% 
    mutate(CT_string = paste0("Carbon Tax: $", CT) , CT = CT,  
           elec_cpx = elec_cap, stor_cap = stor_cap, 
           h2_eff_string = paste0("H2 Efficiency: ", h2_eff, "%"), h2_eff = h2_eff, 
           block = block) %>% 
    mutate(CT_string = paste0("Carbon Tax: $", CT))
  return(df)
}
get_dfr_results = function(file, data, CTs = c(0,50,100), 
                           elecCPXs = c(200, 500, 800), effs  = c(75,80,85)){
  options = expand.grid(CTs = CTs, elecCPXs = elecCPXs, effs = effs)
  df= mapply(load_data, 
             CT = options$CTs, elec_cap = options$elecCPXs, h2_eff = options$effs, 
             MoreArgs = list(file = file, time = "52_weeks", stor_cap = 0.6, data = data), 
             SIMPLIFY = FALSE) %>% 
    bind_rows() %>% 
    mutate(CT_string = factor(CT_string, levels = paste0("Carbon Tax: $", CTs)))
}


# df =get_dfr_results("charge", data, CTs = c(0,50,75,100), elecCPXs = c(500), effs = c(50))
# ggplot(df) + 
#   
# paste0("Carbon Tax: $", c(0,50,75,100))
