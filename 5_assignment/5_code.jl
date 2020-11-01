# Homework 5

# Set up environment
using JuMP, GLPK                       # optimisation packages
using DataFrames, CSV, DataFramesMeta  # data cleaning

# Set string as location of Power System Optimisation git repo. 
pso_dir = "/Users/tombearpark/Documents/princeton/" *
                "1st_year/MAE529/power-systems-optimization/"

# Load functions 
include("5_functions.jl")

# Number of days
days = 10

# load the data 

input = prep_sets_and_parameters(pso_dir, days)

SUB = input.SUB
SET = input.SETS
params = input.params
params.lines



# Run the model
sol = solve_model(params = params, SET = SET, SUB = SUB, 
    hours_per_period = input.hours_per_period, VOLL = input.VOLL,
    sample_weight = input.sample_weight)


sol.cost_results
params.lines







    # If output directory does not exist, create it
if !(isdir(outpath))
    mkdir(outpath)
end

CSV.write(joinpath(outpath, "generator_results.csv"), generator_results)
CSV.write(joinpath(outpath, "storage_results.csv"), storage_results)
CSV.write(joinpath(outpath, "transmission_results.csv"), transmission_results)
CSV.write(joinpath(outpath, "nse_results.csv"), nse_results)
CSV.write(joinpath(outpath, "cost_results.csv"), cost_results);
value.(vCAP).data
value.(vGen)