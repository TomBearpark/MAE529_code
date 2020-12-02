# Initial code for project. Run using acompanying bash script: run_project.sh
# To run this interactively in this code, set runBash = false, and then
# change the dir string to the location of the project on your machine 

runBash = true

if runBash
    # Parse command line arguments 
    electro_capex = parse(Float64, ARGS[1])
    H2_eff = parse(Float64, ARGS[2])
    dir = string(ARGS[3])
    carbon_tax = parse(Float64, ARGS[4])
else 
    electro_capex = 200
    H2_eff = 0.85
    # Note - edit the following string to run on your machine
    dir = "/Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/project/"
    carbon_tax = 25
end 

# Data input path
input_path = dir * "/input_data/ercot_brownfield_expansion/"
# Working directory, for saving outputs
wd = dir

# Global variables - holding constant for all runs 
time_subset = "52_weeks"
stor_capex = 0.6

println("This Model run is characterised by...")
println("Electrolyser capex cost of: " * string(electro_capex))
println("H2 efficiency of: " * string(H2_eff))
println("Carbon Tax: " * string(carbon_tax))
println("Number of weeks included: " * time_subset)

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