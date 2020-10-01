# Uncomment and run this first line if you need to install or update packages
#import Pkg; Pkg.add("JuMP"); Pkg.add("Clp"); Pkg.add("DataFrames"); Pkg.add("CSV"); Pkg.add("Plots"); Pkg.add("VegaLite")
using JuMP
using GLPK
using DataFrames
using CSV
using Plots; plotly();
using VegaLite  # to make some nice plots

#=
Function to convert JuMP outputs (technically, AxisArrays) with two-indexes to a dataframe
Inputs:
    var -- JuMP AxisArray (e.g., value.(GEN))
Reference: https://jump.dev/JuMP.jl/v0.19/containers/
=#
function value_to_df_2dim(var)
    solution = DataFrame(var.data)
    ax1 = var.axes[1]
    ax2 = var.axes[2]
    cols = names(solution)
    insertcols!(solution, 1, :r_id => ax1)
    solution = stack(solution, Not(:r_id), variable_name=:hour)
    solution.hour = foldl(replace, [cols[i] => ax2[i] for i in 1:length(ax2)], 
        init=solution.hour)
    rename!(solution, :value => :gen)
    solution.hour = convert.(Int64,solution.hour)
    return solution
end

################################################
# New code starts here: 
################################################

# Load the data
url_base = "https://raw.githubusercontent.com/east-winds/" * 
        "power-systems-optimization/master/Homeworks/hw3_data/"

# Helper function - loads and formats csv from the github storage location
function load_df(url_base::String, csv_name::String)
    df = DataFrame(CSV.read(download(url_base * csv_name)));
    rename!(df,lowercase.(names(df)))
    return df
end

# Run the function to load all four dataframes needed
Demand = load_df(url_base, "Demand.csv");
Fuels_data = load_df(url_base, "Fuels_data.csv");
Generators_data = load_df(url_base, "Generators_data.csv");
Generators_variability = load_df(url_base, "Generators_variability.csv");

# Clean up the generators dataframe

# 1. Merge in fuel costs, first checking we have full matches 
unique(Generators_data.fuel) == unique(Fuels_data.fuel) && println("All good")
gen_df = outerjoin(Generators_data, Fuels_data, on = :fuel)

rename!(gen_df, :cost_per_mmbtu => :fuel_cost)   # rename column for fuel cost
gen_df.fuel_cost[ismissing.(gen_df[:,:fuel_cost])] .= 0

# create "is_variable" column to indicate if this is a variable generation source (e.g. wind, solar):
gen_df.is_variable = false
gen_df[in(["onshore_wind_turbine","small_hydroelectric","solar_photovoltaic"]).(gen_df.resource),
    :is_variable] .= true;

# create full name of generator (including geographic location and cluster number)
#  for use with variable generation dataframe
gen_df.gen_full = lowercase.(gen_df.region .* "_" .* gen_df.resource .* 
        "_" .* string.(gen_df.cluster) .* ".0");

# remove generators with no capacity (e.g. new build options that we'd use if this was capacity expansion problem)
gen_df = gen_df[gen_df.existing_cap_mw .> 0,:];

# 2. Convert from "wide" to "long" format
gen_variable_long = stack(gen_variable, 
                        Not(:hour), 
                        variable_name=:gen_full,
                        value_name=:cf);
# Now we have a "long" dataframe; 

