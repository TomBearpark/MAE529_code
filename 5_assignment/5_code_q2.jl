# Homework 5

# Set up environment
using JuMP, Cbc                       # optimisation packages
using DataFrames, CSV                 # data cleaning
using VegaLite, Plots                 # plots

# Set string as location of Power System Optimisation git repo. 
pso_dir = "/Users/tombearpark/Documents/princeton/" *
                "1st_year/MAE529/power-systems-optimization/"

# Working directory, for saving outputs
wd = "/Users/tombearpark/Documents/princeton/1st_year/" *
     "MAE529/MAE529_code/5_assignment/"

# Load functions - loads a function for cleaning the data and sets, and
# a wrapper for the JUMP model. 
# This code is just copied from Notebook 7, except I have made the changes 
# requested in the problem set for question 2
include("5_functions_q2.jl")
input = prepare_inputs(pso_dir, "8_weeks", carbon_tax = false)
solutions = solve_model(input)    
write_results(wd, solutions, "8_weeks", false)

# Produce analysis for question 2b...
function load_results(file, q_string, time_string, wd) 
     file_name =  wd * "/results/data/question_" * q_string * 
          "/"* time_string * "_Thomas_Bearpark/without_carbon_tax/" * file * ".CSV"
     return CSV.read(file_name)
end

load_results("cost_results", "1", "8_weeks", wd)     
load_results("cost_results", "2", "8_weeks", wd)     


# Solve a linear version as an approximation, to compare

