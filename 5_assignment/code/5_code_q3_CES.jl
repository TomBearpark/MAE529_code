# Homework 5 - cap and trade bonus question

# Set up environment
using JuMP, Clp                      # optimisation packages
using DataFrames, CSV                # data cleaning
using Plots                          # plots

# Set string as location of Power System Optimisation git repo.
pso_dir = "/Users/tombearpark/Documents/princeton/" *
                "1st_year/MAE529/power-systems-optimization/"

# Working directory, for saving outputs. CHANGE THIS to the location of the
# submitted zip file on your machine.
wd = "/Users/tombearpark/Documents/princeton/1st_year/" *
     "MAE529/MAE529_code/5_assignment/"

# load up the functions we need
include("5_functions_q3_CES.jl")

# Solve the model for different stringency levels
# 1 corresponds to 100% CES generation. 0 is the unrestricted solution
input = prepare_inputs(pso_dir, "8_weeks", carbon_tax = false)
zero_col =  [0.0; 0.0; 0.0; 0.0; 0.0; 0.0]
df = DataFrame(stringency = [0; 0.2; 0.4; 0.6; 0.8; 1],
                emmisions =zero_col,
                cost = zero_col,
                time = zero_col,
                NSE_Cost = zero_col,
                storage = zero_col)
# Loop over stringencies, saving results into a dataframe for plotting
for s in df.stringency
    println(s)
    solution = solve_model_q3(input, s)
    df.emmisions[df.stringency .== s] .= solution.emmisions[1]
    df.cost[df.stringency .== s] .= solution.cost_results.Total_Costs[1]
    df.time[df.stringency .== s] .= solution.time[1]
    df.NSE_Cost[df.stringency .== s] .= solution.cost_results.NSE_Costs[1]
end

# Produce a plot of the key ouputs asked for in the question.
p1  = plot(df.stringency, df.cost, label = "Cost", size = (500, 500))
p2 =  plot(df.stringency, df.time, label = "Compute Time", size = (500, 500))
p3 =  plot(df.stringency, df.emmisions, label = "Emmisions", size = (500, 500))
p4 =  plot(df.stringency, df.NSE_Cost, label = "NSE_Cost", size = (500, 500))

# Combine plots and save
plot(p1, p2, p3, p4, legend = true,
    xlabel = "Percent CES")
png(wd* "/results/figs/CES_standard_plots.png")
