# Appendix and robustness model runs code 

dir = "/Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/project/"
# Data input path
input_path = dir * "/input_data/ercot_brownfield_expansion/"
# Working directory, for saving outputs
wd = dir

# Global variables - holding constant for all runs 
time_subset = "52_weeks"
carbon_tax = 50
H2_eff = 0.5
electro_capex = 1100

stor_capex = 0.6

# Set up environment - automatically should get the correct package versions
using Pkg
Pkg.activate(dir * "code/.")
Pkg.instantiate()
using JuMP, Clp, DataFrames, CSV, Statistics

# Load functions - loads a function for cleaning the data and sets, and
# a wrapper for the JUMP model. 
include("functions/H2_functions.jl")
include("functions/functions.jl")

# Run the model, for a given set of parameters 
sol = run_model(input_path, wd, time_subset = time_subset, carbon_tax = carbon_tax, 
            electro_capex = electro_capex, stor_capex = stor_capex, 
            H2_eff = H2_eff, write_full_model = false, collapse = false)

println("Model run complete")


