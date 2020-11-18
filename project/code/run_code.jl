# Initial code for project 

# Parse command line arguments 
electro_capex = parse(Float64, ARGS[1])
H2_eff = parse(Float64, ARGS[2])

# Global variables - holding constant
time_subset = "52_weeks"
stor_capex = 0.6

# Set up environment - make sure you have these packages installed
using JuMP, Clp, DataFrames, CSV     

# Note - edit the following two strings to run on your machine
# Set string as location of Power System Optimisation git repo. 
input_path = "/Users/tombearpark/Documents/princeton/1st_year/MAE529/" * 
    "MAE529_code/project/input_data/ercot_brownfield_expansion/"

# Working directory, for saving outputs
wd = "/Users/tombearpark/Documents/princeton/1st_year/" *
     "MAE529/MAE529_code/project/"

# Load functions - loads a function for cleaning the data and sets, and
# a wrapper for the JUMP model. 
include("H2_functions.jl")
include("functions.jl")

# Helper function for annuitsing costs 
function calc_annuitised_capex(;N, capex, WACC)
    return 1000* capex * ((WACC * (1 + WACC)^N)) / ((1 + WACC)^N - 1)
end 

function run_model(;time_subset, carbon_tax, electro_capex, stor_capex, H2_eff)
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

# Run and save results
for carbon_tax in [0, 50, 100]
    println(carbon_tax)
    run_model(time_subset = time_subset, carbon_tax = carbon_tax, 
            electro_capex = electro_capex, stor_capex = stor_capex, 
            H2_eff = H2_eff)

    println("done")
end

