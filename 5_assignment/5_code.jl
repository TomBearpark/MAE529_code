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
function run_model(pso_dir, time_subset)
    # load the data 
    input = prepare_inputs(pso_dir, time_subset)
    # Run the model
    solutions = solve_model(input)    
    return(solutions)
end

# Part 1A and B 
times = DataFrame(
    time_subset = ["10_days", "4_weeks", "8_weeks", "16_weeks"], 
    time = [0.0,0.0,0.0,0.0], time1 = [0.0,0.0,0.0,0.0])

for d in times.time_subset
    sol = run_model(pso_dir, d)
    write_results(wd, sol, d)
    println(sol.time[1])
    times.time[times.time_subset .== d] .= sol.time
    times.time1[times.time_subset .== d] .= sol.time1
end

# Create a scatter plot of the run times...
times.hours = [10 * 24, 4 * 7 * 24, 8 * 7 * 24, 16 * 7 * 24]
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

function return_totals(wd, d)

    path = "/results/data/" * d * "_Thomas_Bearpark/"
    cost_results = CSV.read(joinpath(wd * path, "cost_results.csv"))
    gen = CSV.read(joinpath(wd * path, "generator_results.csv"))
    
    return DataFrame(time_subset = d, 
                total_hours = times.hours[times.time_subset .== d][1],
                total_cost = cost_results.Total_Costs[1], 
                total_final_capacity = sum(gen.Total_MW), 
                total_generation = sum(gen.GWh))


end
df = return_totals(wd, "10_days") 
df = append!(df, return_totals(wd, "4_weeks"))
df = append!(df, return_totals(wd, "8_weeks"))
df = append!(df, return_totals(wd, "16_weeks"))

# Find percentage differences 
for var in ("total_cost",  "total_final_capacity", "total_generation")
    df[var * "_deviation"] = 0.0
    for i in 1:3
        df[var * "_deviation"][i] =  100* (df[var][i] - df[var][4]) / df[var][4]
    end
end

# d = stack(df, [:total_cost, :total_final_capacity, :total_generation]) |>
#     @vlplot(:point,
#             x = :total_hours, 
#             y = :value, 
#             column = :variable,
#             resolve={scale={y="independent"}}
#             )


# Bonus: run the model for a full year of hours.. 
