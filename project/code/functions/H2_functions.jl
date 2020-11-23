# # Prepare hydrogen data
# using CSV, DataFrames

# hydrogen 
# * low efficiency
# 

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
    H2_Fixed_Inv_cost_MWyr, 
    H2_Fixed_OM_cost_MWyr, 
    H2_Var_OM_cost_per_MWh, 
    H2_STOR_Inv_cost_MWhyr, 
    H2_STOR_OM_cost_MWhyr, 
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
    genH2.Inv_cost_per_MWyr = round(H2_Fixed_Inv_cost_MWyr)
    genH2.Fixed_OM_cost_per_MWyr = round(H2_Fixed_OM_cost_MWyr)

    genH2.Var_OM_cost_per_MWh = round(H2_Var_OM_cost_per_MWh)

    # Storage fixed costs
    genH2.Inv_cost_per_MWhyr = round(H2_STOR_Inv_cost_MWhyr)
    genH2.Fixed_OM_cost_per_MWhyr = round(H2_STOR_OM_cost_MWhyr)
    
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
    variability.Hydrogen_56 = 1
    variability.Hydrogen_57 = 1
    variability.Hydrogen_58 = 1
    return(variability)
end

# Helper function for annuitsing costs 
function calc_annuitised_capex(;N, capex, WACC)
    return 1000* capex * ((WACC * (1 + WACC)^N)) / ((1 + WACC)^N - 1)
end 

function run_model(input_path, wd;time_subset, carbon_tax, electro_capex, stor_capex, H2_eff)
    # Calculate reasonable parameter inputs for test run... 
    # * 1. H2_Fixed_Inv_cost_MWyr
    # Note - this is really really low compared to other estimates 
    # Bloomberg slides: Capex: Electrolysers are around 200$/kW = 200000$/MW
    # lifetime of electrolyser: 20 years: from everywhere basically
    H2_Fixed_Inv_cost_MWyr = 
        calc_annuitised_capex(N= 20, capex = electro_capex, WACC = 0.069)

    # * 2. H2_Fixed_OM_cost_MWyr
    # source: p16; 5% of capex
    # https://itpthermal.files.wordpress.com/2018/10/160321-an-assessment-of-the-cost-of-hydrogen-from-pv_final.pdf
    H2_Fixed_OM_cost_MWyr = 0.05 * H2_Fixed_Inv_cost_MWyr

    # * 3. H2_Var_OM_cost_per_MWh
    # following approach as for batteries 
    H2_Var_OM_cost_per_MWh = 0

    # * 4. H2_STOR_Inv_cost_MWhyr
    # 0.5	EUR/kWh ~= 0.6  $/Kwh
    H2_STOR_Inv_cost_MWhyr = 
        calc_annuitised_capex(N= 40, capex = stor_capex, WACC = 0.069)

    # * 5 H2_STOR_OM_cost_MWhyr
    H2_STOR_OM_cost_MWhyr =  0.05 * H2_STOR_Inv_cost_MWhyr

    # * H2_eff
    H2_eff = H2_eff

    input = prepare_inputs(input_path, time_subset, 
                            carbon_tax = carbon_tax, 
                            H2_Fixed_Inv_cost_MWyr = H2_Fixed_Inv_cost_MWyr, 
                            H2_Fixed_OM_cost_MWyr = H2_Fixed_OM_cost_MWyr, 
                            H2_Var_OM_cost_per_MWh = H2_Var_OM_cost_per_MWh, 
                            H2_STOR_Inv_cost_MWhyr = H2_STOR_Inv_cost_MWhyr, 
                            H2_STOR_OM_cost_MWhyr = H2_STOR_OM_cost_MWhyr, 
                            H2_eff = H2_eff)

    solutions = solve_model(input)   
    write_results(wd, solutions, 
                    time_subset , carbon_tax = carbon_tax, 
                    electro_capex = electro_capex, 
                    stor_capex = stor_capex, efficiency = H2_eff)
end 