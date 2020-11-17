# # Prepare hydrogen data
# using CSV, DataFrames

# input_path = "/Users/tombearpark/Documents/princeton/1st_year/MAE529/" * 
#     "MAE529_code/project/input_data/ercot_brownfield_expansion/"


# time_subset = "10_days"
# inputs_path = input_path  * time_subset * "/"

# generators = DataFrame(CSV.File(joinpath(inputs_path, "Generators_data.csv")))

# generators = select(generators, :R_ID, :Resource, :zone, :THERM, :DISP, 
#     :NDISP, :STOR, :HYDRO, :RPS, :CES,
#     :Commit, :Existing_Cap_MW, :Existing_Cap_MWh, :Cap_size, 
#     :New_Build, :Max_Cap_MW,
#     :Inv_cost_per_MWyr, :Fixed_OM_cost_per_MWyr, 
#     :Inv_cost_per_MWhyr, :Fixed_OM_cost_per_MWhyr,
#     :Var_OM_cost_per_MWh, :Start_cost_per_MW, 
#     :Start_fuel_MMBTU_per_MW, :Heat_rate_MMBTU_per_MWh, 
#     :Fuel,
#     :Min_power, :Ramp_Up_percentage, :Ramp_Dn_percentage, 
#     :Up_time, :Down_time,
#     :Eff_up, :Eff_down);

function add_H2_rows_to_gen_df(generators; 
    H2_inv_cost_MWyr, H2_OM_cost_MWyr, H2_var_cost_MWyr, 
    H2_STOR_Inv_cost_MWhyr, H2_STOR_OM_cost_MWhyr, 
    H2_eff)

    genH2 = copy(generators) 
    genH2 = first(genH2, 3)

    # Parameters fixed across runs
    genH2.R_ID = length(generators.R_ID)+1:length(generators.R_ID)+3
    genH2.Resource .= "Hydrogen"
    genH2.zone = 1:3
    genH2.THERM .= 0
    genH2.DISP .= 0
    genH2.NDISP .= 0
    genH2.STOR .= 2
    genH2.HYDRO .= 0
    genH2.RPS .= 0
    genH2.CES .= 0
    genH2.Commit .= 0
    genH2.Existing_Cap_MW .= 0
    genH2.Existing_Cap_MWh .=0
    genH2.Cap_size .= 1
    genH2.New_Build .=1
    genH2.Max_Cap_MW .= -1
    genH2.Start_cost_per_MW .= 0
    genH2.Start_fuel_MMBTU_per_MW .= 0 
    genH2.Heat_rate_MMBTU_per_MWh .= 0
    genH2.Fuel .= "None"
    genH2.Min_power .= 1
    genH2.Ramp_Up_percentage .=1
    genH2.Ramp_Dn_percentage .=1
    genH2.Up_time .=0
    genH2.Down_time .=0

    # Parameters of interest to vary
    
    # Electrolyser costs
    genH2.Inv_cost_per_MWyr = H2_inv_cost_MWyr
    genH2.Fixed_OM_cost_per_MWyr = H2_OM_cost_MWyr

    genH2.Var_OM_cost_per_MWh = H2_var_cost_MWyr

    # Storage fixed costs
    genH2.Inv_cost_per_MWhyr = H2_STOR_Inv_cost_MWhyr
    genH2.Fixed_OM_cost_per_MWhyr = H2_STOR_OM_cost_MWhyr
    
    # Storage efficiency
    genH2.Eff_up .= H2_eff
    genH2.Eff_down .= H2_eff

    return(append!(generators, genH2))
end


# Test function
# add_H2_rows_to_gen_df(generators, 
#     H2_inv_cost_MWyr = 1, 
#     H2_OM_cost_MWyr = 1, 
#     H2_var_cost_MWyr = 1, 
#     H2_STOR_Inv_cost_MWhyr = 1, 
#     H2_STOR_OM_cost_MWhyr = 1, 
#     H2_eff = 1)

# Add variability information for consistency with other inputs
function add_H2_to_variability(variability)
    variability.Hydrogen_56 = .1
    variability.Hydrogen_57 = .1
    variability.Hydrogen_58 = .1
    return(variability)
end