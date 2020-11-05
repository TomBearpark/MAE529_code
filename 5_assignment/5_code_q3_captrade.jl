# Homework 5 - cap and trade bonus question

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

include("5_functions_q3_captrade.jl")


# Solve the model for different stringency levels
# 1 corresponds to 100% CES generation. 0 is the unbounded solution 
input = prepare_inputs(pso_dir, "8_weeks", carbon_tax = false)
zero_col =  [0.0; 0.0; 0.0; 0.0; 0.0; 0.0 ]

df = DataFrame(stringency = [0; 0.2; 0.4; 0.6; 0.8; 1],
                emmisions =zero_col, 
                cost = zero_col, 
                time = zero_col)
for s in df.stringency
    println(s)
    solution = solve_model_q3(input, s)
    df.emmisions[df.stringency .== s] .= solution.emmisions[1]
    df.cost[df.stringency .== s] .= solution.cost_results.Total_Costs[1]
    df.time[df.stringency .== s] .= solution.time[1]
end

# Produce a plot of the key ouputs asked for in the question. 
p1  = plot(df.stringency, df.cost, ylabel = "Cost")
p2 =  plot(df.stringency, df.time, ylabel = "Compute Time")
p3 =  plot(df.stringency, df.emmisions, ylabel = "Emmisions")

plot(p1, p2, p3, layout = (1, 3), legend = false, 
    xlabel = "Percent CES")
png(wd* "/results/figs/CES_standard_plots.png")