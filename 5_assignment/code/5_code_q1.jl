# Homework 5 - Run script for Question 1 

# Set up environment - make sure you have these packages installed
using JuMP, Clp                       # optimisation packages
using DataFrames, CSV                 # data cleaning
using VegaLite, Plots                 # plots

# Note - edit the following two strings to run on your machine
# Set string as location of Power System Optimisation git repo. 
pso_dir = "/Users/tombearpark/Documents/princeton/" *
                "1st_year/MAE529/power-systems-optimization/"

# Working directory, for saving outputs
wd = "/Users/tombearpark/Documents/princeton/1st_year/" *
     "MAE529/MAE529_code/5_assignment/"


# Load functions - loads a function for cleaning the data and sets, and
# a wrapper for the JUMP model. 
# This code is just copied from Notebook 7, broken up into two functions
# to allow for data analysis before solving the model 
include("5_functions_q1.jl")

# Helper function for running the model, for a given time subset, and 
# for either with or without a carbon tax 
function run_model(pso_dir, time_subset, carbon_tax::Bool)
    # load the data 
    input = prepare_inputs(pso_dir, time_subset, carbon_tax = carbon_tax)
    # Run the model
    solutions = solve_model(input)    
    return(solutions)
end

# Part 1A and B - run the model for each time period 
times = DataFrame(
    time_subset = ["10_days", "4_weeks", "8_weeks", "16_weeks"], 
    time = [0.0,0.0,0.0,0.0], time1 = [0.0,0.0,0.0,0.0])
# Loop over time subsets, running and then saving results into dataframe
for d in times.time_subset
    sol = run_model(pso_dir, d, false)
    write_results(wd, sol, d, false)
    println(sol.time[1])
    times.time[times.time_subset .== d] .= sol.time
    times.time1[times.time_subset .== d] .= sol.time1
end

# Create a scatter plot of the run times...
times.hours = [10 * 24, 4 * 7 * 24, 8 * 7 * 24, 16 * 7 * 24]
CSV.write(joinpath(wd, "results/q1_times.csv"), 
        times)  
times |> 
    @vlplot(:point, 
        x={:hours, title="Number of hours optimized"}, 
        y={:time, title="Time to compute (sec)"}, 
        title= "Solve time vs hours", width=400, height=400) |> 
    save(joinpath(wd, "results/figs/q1_time_subset_compute_scatter.png"))

# Question 1C
# Compile a spreadsheet that compares 
#     (a) the total cost results, 
#     (b) total final capacity (MW) results by resource, and 
#     (c) the total generation (GWh) results 
#     for all four iterations of the model.

# Function to plot percentage divergence from 16 week version 
function plot_percent_diffs(df) 
    plot_df =  select(df, :total_hours, :total_cost_deviation, 
        :total_final_capacity_deviation, :total_generation_deviation) 
    plot_df = stack(plot_df, Not(:total_hours)) 
    rename!(plot_df, :value => :percent_diff)

    plot_df |> @vlplot(:point, x = :total_hours, y = :percent_diff, 
                column = :variable, height = 400, width = 200, 
                title = "Percent Deviation From 16 week version")

end
# Create the spreadsheet 
df = append_all_totals(wd, false)
# Write results 
CSV.write(joinpath(wd, "results/q1_summary_without_carbon_tax.csv"), 
    df)  
plot_percent_diffs(df) |> 
    save(joinpath(wd, "results/figs/q1_accuracy_losses_without_carbon_tax.png"))

# Additional analysis of cost breakdown - can we find whats driving the non
# montonic trends?
df = load_cost_result(wd, "10_days", false)
df = append!(df, load_cost_result(wd, "4_weeks", false))
df = append!(df, load_cost_result(wd, "8_weeks", false))
df = append!(df, load_cost_result(wd, "16_weeks", false))
plot(df.Variable_Costs)
CSV.write(joinpath(wd, "results/q1_cost_break_down_without_carbon_tax.csv"), 
    df)  

# Generation results by resource
df = load_generator_result(wd, "10_days", false)
df = append!(df, load_generator_result(wd, "4_weeks", false))
df = append!(df, load_generator_result(wd, "8_weeks", false))
df = append!(df, load_generator_result(wd, "16_weeks", false))
CSV.write(joinpath(wd, "results/q1_gen_by_resource_without_carbon_tax.csv"), 
    df)  


# Save a new copy of your Julia file and then modify the following 
# lines of code in the read inputs portion of yor model to incorporate 
# a carbon price of \$50 per ton of CO2 content in the fuel used by each 
# resource. To do so, add an additional element to the total Variable Cost 
# and Start-up Cost that includes 50 times the CO2 content of the fuel 
# (tCO2/MMBtu) times the total fuel consumed by each resource (MMBtu).

# Note - I implented this through adding an option the existing function, 
# rather than copying it into a new one.

# Run model, with carbon tax option selected 
times_tax = DataFrame(
    time_subset = ["10_days", "4_weeks", "8_weeks", "16_weeks"], 
    time = [0.0,0.0,0.0,0.0], time1 = [0.0,0.0,0.0,0.0])
times_tax.hours = times.hours
for d in times_tax.time_subset
    sol = run_model(pso_dir, d, true)
    write_results(wd, sol, d, true)
    println(sol.time[1])
    times_tax.time[times_tax.time_subset .== d] .= sol.time
    times_tax.time1[times_tax.time_subset .== d] .= sol.time1
end
# Write results 
CSV.write(joinpath(wd, "results/q1_times_w_carbon_tax.csv"), 
    times_tax)  

# Load results from disk - make these into csv tables for copying into latex
# write up 
df_ct = append_all_totals(wd, true)
# Write results 
CSV.write(joinpath(wd, "results/q1_summary_with_carbon_tax.csv"), 
    df_ct)  
plot_percent_diffs(df_ct) |> 
    save(joinpath(wd, "results/figs/q1_accuracy_losses_with_carbon_tax.png"))

# Visualise some of the outputs
scatter(times.hours, times.time, label = "Without carbon tax", size=(800,500), 
                location=4)
scatter!(times_tax.hours, times_tax.time, label = "With carbon tax")
title!("Number of hours in subset vs compute time (seconds)")
png(joinpath(wd, "results/figs/times_comparison.png"))

# Get a breakdown of generators, save as a spreadsheet. 
df = load_generator_result(wd, "10_days", true)
df = append!(df, load_generator_result(wd, "4_weeks", true))
df = append!(df, load_generator_result(wd, "8_weeks", true))
df = append!(df, load_generator_result(wd, "16_weeks", true))
CSV.write(joinpath(wd, "results/q1_gen_by_resource_with_carbon_tax.csv"), 
    df)  

# Bonus: run the model for a full year of hours.. 
# not working...?