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
    mutate(CT_string = factor(CT_string, levels=c("Carbon Tax: $0", "Carbon Tax: $50","Carbon Tax: $100")))
  return(df)
}
