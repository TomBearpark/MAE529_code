# Homework 5 - Question 2: MILP problem, with UC 

# Set up environment
using JuMP, Cbc                       # optimisation packages
using DataFrames, CSV                 # data cleaning

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
solutions = solve_model_q2(input, "MILP")    
write_results_q2(wd, solutions, "8_weeks", false)

# Produce analysis for question 2b...
function load_results(file, q_string, time_string, wd) 
     file_name =  wd * "/results/data/question_" * q_string * 
          "/"* time_string * "_Thomas_Bearpark/without_carbon_tax/" * file * ".CSV"
     println(file_name)
     return CSV.read(file_name)
end

# Compare your results to the 8 weeks results without unit commitment 
# constraints, in terms of (a) costs, (b) capacity results, (c) energy results, 
# (d) non-served energy results.

# Cost results table
df1 = load_results("cost_results", "1", "8_weeks", wd)
df1.Start_costs = 0.0     
df2 = load_results("cost_results", "2", "8_weeks", wd)     
plot_df = append!(df1, df2)
plot_df.type = ["No UC", "With UC"]
CSV.write(wd * "/results/q2_cost_comparison.csv", plot_df)

# capacity results... summary table of the four things asked for...
df1_cap = load_results("generator_results", "1", "8_weeks", wd)
total_final_capacity1 = sum(df1_cap.Total_MW)
total_generation1 = sum(df1_cap.GWh)
df2_cap = load_results("generator_results", "2", "8_weeks", wd)
total_final_capacity2 = sum(df2_cap.Total_MW)
total_generation2 = sum(df2_cap.GWh)

sum_df = DataFrame(Solution_Type = ["No UC", "UC"], 
          total_cost = plot_df.Total_Costs, 
          total_capacity = [total_final_capacity1, total_final_capacity2], 
          total_generation = [total_generation1, total_generation2],
          nse_cost = [df1.NSE_Costs[1], df2.NSE_Costs[1]])
CSV.write(wd * "/results/q2_summary_comparison.csv", sum_df)

# Part 2 
# Solve a linear version as an approximation, to compare
using Clp
solutions = solve_model_q2(input, "LP")    

# Compare times: 
times_df = DataFrame(linear_relaxation_time = solutions.time[1], 
                    UC_time = load_results("time", "2", "8_weeks", wd)[1])
CSV.write(wd * "/results/q2c_times_comparison.csv", times_df)

# Compare costs
cost_df = append!(solutions.cost_results, 
                    load_results("cost_results", "2", "8_weeks", wd))
CSV.write(wd * "/results/q2c_costs_comparison.csv", cost_df)