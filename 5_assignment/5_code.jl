# Homework 5

# Set up environment
using JuMP, Clp                       # optimisation packages
using DataFrames, CSV                 # data cleaning
using VegaLite                        # nice plots

# Set string as location of Power System Optimisation git repo. 
pso_dir = "/Users/tombearpark/Documents/princeton/" *
                "1st_year/MAE529/power-systems-optimization/"

# Working directory, for saving outputs
wd = "/Users/tombearpark/Documents/princeton/1st_year/" *
     "MAE529/MAE529_code/5_assignment/"


# Load functions - loads a function for cleaning the data and sets, and
# a wrapper for the JUMP model. 
# This code is just copied from Notebook 7
include("5_functions.jl")

# Number of days
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

for d in times.time_subset
    sol = run_model(pso_dir, d)
    write_results(wd, sol, d, false)
    println(sol.time[1])
    times.time[times.time_subset .== d] .= sol.time
    times.time1[times.time_subset .== d] .= sol.time1
end

# Create a scatter plot of the run times...
times.hours = [10 * 24, 4 * 7 * 24, 8 * 7 * 24, 16 * 7 * 24]
CSV.write(joinpath(wd, "results/times.csv"), 
        times)  
times |> 
    @vlplot(:point, 
        x={:hours, title="Number of hours optimized"}, 
        y={:time, title="Time to compute (sec)"}, 
        title= "Solve time vs hours", width=400, height=400) |> 
    save(joinpath(wd, "results/figs/time_subset_compute_scatter.png"))

# Question 1C
# Compile a spreadsheet that compares 
#     (a) the total cost results, 
#     (b) total final capacity (MW) results by resource, and 
#     (c) the total generation (GWh) results 
#     for all four iterations of the model.

df = append_all_totals(wd, false)

# Plot percentage divergence from 16 week version 
plot_df =  select(df, :total_hours, :total_cost_deviation, 
    :total_final_capacity_deviation, :total_generation_deviation) 
plot_df = stack(plot_df, Not(:total_hours)) 
rename!(plot_df, :value => :percent_diff)

plot_df |> @vlplot(:point, x = :total_hours, y = :percent_diff, 
            column = :variable, height = 400, width = 200, 
            title = "Percent Deviation From 16 week version") 


# Save a new copy of your Julia file and then modify the following 
# lines of code in the read inputs portion of yor model to incorporate 
# a carbon price of \$50 per ton of CO2 content in the fuel used by each 
# resource. To do so, add an additional element to the total Variable Cost 
# and Start-up Cost that includes 50 times the CO2 content of the fuel 
# (tCO2/MMBtu) times the total fuel consumed by each resource (MMBtu).


# Run model, with carbon tax option selected 
times_tax = DataFrame(
    time_subset = ["10_days", "4_weeks", "8_weeks", "16_weeks"], 
    time = [0.0,0.0,0.0,0.0], time1 = [0.0,0.0,0.0,0.0])
times_tax.hours = times.hours

# Run and write new results
for d in times_tax.time_subset
    sol = run_model(pso_dir, d, true)
    write_results(wd, sol, d, true)
    println(sol.time[1])
    times_tax.time[times_tax.time_subset .== d] .= sol.time
    times_tax.time1[times_tax.time_subset .== d] .= sol.time1
end
# Write results 
CSV.write(joinpath(wd, "results/times_w_carbon_tax.csv"), 
    times_tax)  
times_tax |> 
    @vlplot(:point, 
        x={:hours, title="Number of hours optimized"}, 
        y={:time, title="Time to compute (sec)"}, 
        title= "Solve time vs hours", width=400, height=400) |> 
    save(joinpath(wd, 
    "results/figs/time_subset_compute_scatter_w_carbon_tax.png"))

# Load results from disk
df = append_all_totals(wd, true)
df_old = append_all_totals(wd, false)



# Bonus: run the model for a full year of hours.. 
df.total_hours = df.total_hours + df.total_hours