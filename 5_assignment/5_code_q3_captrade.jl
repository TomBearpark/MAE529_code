# Homework 5

# Set up environment
using JuMP, Clp                      # optimisation packages
using DataFrames, CSV                 # data cleaning
using VegaLite, Plots                 # plots

# Set string as location of Power System Optimisation git repo. 
pso_dir = "/Users/tombearpark/Documents/princeton/" *
                "1st_year/MAE529/power-systems-optimization/"

# Working directory, for saving outputs
wd = "/Users/tombearpark/Documents/princeton/1st_year/" *
     "MAE529/MAE529_code/5_assignment/"

include("5_functions_q3.jl")

