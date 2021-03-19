# Appendix analysis - how much do results change with 
# making it a 2 hour step problem rather than hourly


# Note - edit the following string to run on your machine
dir = "/Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/project/"

# Data input path
input_path = dir * "/input_data/ercot_brownfield_expansion/"

# Working directory, for saving outputs
wd = dir

# Parameters of these model runs
electro_capex = 200
H2_eff = 0.5
time_subset = "52_weeks"
stor_capex = 0.6
carbon_tax = 100

# Set up environment - should automatically ensure you have the 
# correct package and versions of the packages 
using Pkg
Pkg.activate(dir * "code/.")
Pkg.instantiate()
using JuMP, Clp, DataFrames, CSV, Statistics


# Load functions - loads a function for cleaning the data and sets, and
# a wrapper for the JUMP model. 
include("functions/H2_functions.jl")
include("functions/functions.jl")

# Run two versions of the model, one for 2 hour chunks, one for 
sol1 = run_model(input_path, wd, time_subset = time_subset, carbon_tax = carbon_tax, 
            electro_capex = electro_capex, stor_capex = stor_capex, 
            H2_eff = H2_eff, write_full_model = false, collapse = false)

sol2 = run_model(input_path, wd, time_subset = time_subset, carbon_tax = carbon_tax, 
            electro_capex = electro_capex, stor_capex = stor_capex, 
            H2_eff = H2_eff, write_full_model = true, collapse = true)

# Percentage deviation of total costs... 
100 * (sol1.cost_results[1,1] - sol2.cost_results[1,1]) / sol1.cost_results[1,1]

# Check out the cost results... 
sol1.cost_results
sol2.cost_results

sum(sol1.generator_results.Total_MW)
sum(sol2.generator_results.Total_MW)

