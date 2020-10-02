# Uncomment and run this first line if you need to install or update packages
#import Pkg; Pkg.add("JuMP"); Pkg.add("Clp"); Pkg.add("DataFrames"); 
# Pkg.add("CSV"); Pkg.add("Plots"); Pkg.add("VegaLite")
using JuMP
using GLPK
using DataFrames
using CSV
using Plots; plotly();
using VegaLite  # to make some nice plots

#=
Function to convert JuMP outputs (technically, AxisArrays) with two-indexes 
to a dataframe
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
(unique(Generators_data.fuel) == unique(Fuels_data.fuel) && println("All good")) 

gen_df = outerjoin(Generators_data, Fuels_data, on = :fuel)

rename!(gen_df, :cost_per_mmbtu => :fuel_cost)   # rename column for fuel cost
gen_df.fuel_cost[ismissing.(gen_df[:,:fuel_cost])] .= 0

# create "is_variable" column to indicate if this is a variable generation source 
# (e.g. wind, solar):
gen_df.is_variable = false
gen_df[in(["onshore_wind_turbine","small_hydroelectric",
    "solar_photovoltaic"]).(gen_df.resource),
    :is_variable] .= true;

# create full name of generator (including geographic location and cluster number)
#  for use with variable generation dataframe
gen_df.gen_full = lowercase.(gen_df.region .* "_" .* gen_df.resource .* 
        "_" .* string.(gen_df.cluster) .* ".0");

# remove generators with no capacity (e.g. new build options that 
# we'd use if this was capacity expansion problem)
gen_df = gen_df[gen_df.existing_cap_mw .> 0,:];

# 2. Convert cf data from "wide" to "long" format
gen_variable_long = stack(Generators_variability, 
                        Not(:hour), 
                        variable_name=:gen_full,
                        value_name=:cf);



#=
Function to solve simple unit commitment problem (commitment equations)
Inputs:
    gen_df -- dataframe with generator info
    loads  -- load by time
    gen_variable -- capacity factors of variable generators (in "long" format)
=#
function unit_commitment_simple(gen_df, loads, gen_variable)
    UC = Model(GLPK.Optimizer)

    # We reduce the MIP gap tolerance threshold here to increase tractability
    # Here we set it to a 1% gap, meaning that we will terminate once we have 
    # a feasible integer solution guaranteed to be within 1% of the objective
    # function value of the optimal solution.
    # Note that GLPK's default MIP gap is 0.0, meaning that it tries to solve
    # the integer problem to optimality, which can take a LONG time for 
    # any complex problem. So it is important to set this to a realistic value.
    set_optimizer_attribute(UC, "mip_gap", 0.01)

    # Define sets based on data
    # Note the creation of several different sets of generators for use in
    # different equations.
        # Thermal resources for which unit commitment constraints apply
    G_thermal = gen_df[gen_df[!,:up_time] .> 0,:r_id] 
        # Non-thermal resources for which unit commitment constraints do NOT apply 
    G_nonthermal = gen_df[gen_df[!,:up_time] .== 0,:r_id]
        # Variable renewable resources
    G_var = gen_df[gen_df[!,:is_variable] .== 1,:r_id]
        # Non-variable (dispatchable) resources
    G_nonvar = gen_df[gen_df[!,:is_variable] .== 0,:r_id]
        # Non-variable and non-thermal resources
    G_nt_nonvar = intersect(G_nonvar, G_nonthermal)
        # Set of all generators (above are all subsets of this)
    G = gen_df.r_id
        # All time periods (hours) over which we are optimizing
    T = loads.hour
        # A subset of time periods that excludes the last time period
    T_red = loads.hour[1:end-1]  # reduced time periods without last one

    # Generator capacity factor time series for variable generators
    gen_var_cf = innerjoin(gen_variable, 
                    gen_df[gen_df.is_variable .== 1 , 
                        [:r_id, :gen_full, :existing_cap_mw]], 
                    on = :gen_full)
        
    # Decision variables   
    @variables(UC, begin
            # Continuous decision variables
        GEN[G, T]  >= 0     # generation
            # Bin = binary variables; 
            # the following are all binary decisions that 
            # can ONLY take the values 0 or 1
            # The presence of these discrete decisions makes this an MILP
        COMMIT[G_thermal, T], Bin # commitment status (Bin=binary)
        START[G_thermal, T], Bin  # startup decision
        SHUT[G_thermal, T], Bin   # shutdown decision
    end)
                
    # Objective function
        # Sum of variable costs + start-up costs for all generators and time periods
    @objective(UC, Min, 
        sum( (gen_df[gen_df.r_id .== i,
            :heat_rate_mmbtu_per_mwh][1] * 
                gen_df[gen_df.r_id .== i,:fuel_cost][1] +
            gen_df[gen_df.r_id .== i,:var_om_cost_per_mwh][1]) * GEN[i,t] 
                        for i in G_nonvar for t in T) + 
        sum(gen_df[gen_df.r_id .== i,:var_om_cost_per_mwh][1] * GEN[i,t] 
                        for i in G_var for t in T)  + 
        sum(gen_df[gen_df.r_id .== i,:start_cost_per_mw][1] * 
            gen_df[gen_df.r_id .== i,:existing_cap_mw][1] *
            START[i,t] 
                        for i in G_thermal for t in T)
    )
    
    # Demand balance constraint (supply must = demand in all time periods)
    @constraint(UC, cDemand[t in T], 
        sum(GEN[i,t] for i in G) == loads[loads.hour .== t,:demand][1])

    # Capacity constraints 
      # 1. thermal generators requiring commitment
    @constraint(UC, Cap_thermal_min[i in G_thermal, t in T], 
        GEN[i,t] >= COMMIT[i, t] * gen_df[gen_df.r_id .== i,:existing_cap_mw][1] *
                        gen_df[gen_df.r_id .== i,:min_power][1])
    @constraint(UC, Cap_thermal_max[i in G_thermal, t in T], 
        GEN[i,t] <= COMMIT[i, t] * gen_df[gen_df.r_id .== i,:existing_cap_mw][1])

      # 2. non-variable generation not requiring commitment
    @constraint(UC, Cap_nt_nonvar[i in G_nt_nonvar, t in T], 
        GEN[i,t] <= gen_df[gen_df.r_id .== i,:existing_cap_mw][1])
    
      # 3. variable generation, accounting for hourly capacity factor
    @constraint(UC, Cap_var[i in 1:nrow(gen_var_cf)], 
            GEN[gen_var_cf[i,:r_id], gen_var_cf[i,:hour] ] <= 
                        gen_var_cf[i,:cf] *
                        gen_var_cf[i,:existing_cap_mw])
    
    # Unit commitment constraints
      # 1. Minimum up time
    @constraint(UC, Startup[i in G_thermal, t in T],
        COMMIT[i, t] >= sum(START[i, tt] 
                        for tt in intersect(T,
                            (t-gen_df[gen_df.r_id .== i,:up_time][1]):t)))

      # 2. Minimum down time
    @constraint(UC, Shutdown[i in G_thermal, t in T],
        1-COMMIT[i, t] >= sum(SHUT[i, tt] 
                        for tt in intersect(T,
                            (t-gen_df[gen_df.r_id .== i,:down_time][1]):t)))
 
      # 3. Commitment state
    @constraint(UC, CommitmentStatus[i in G_thermal, t in T_red],
        COMMIT[i,t+1] - COMMIT[i,t] == START[i,t+1] - SHUT[i,t+1])
    
    # Solve statement (! indicates runs in place)
    optimize!(UC)

    # Generation solution and convert to data frame 
    # with our helper function defined above
    gen = value_to_df_2dim(value.(GEN))

    # Commitment status solution and convert to data frame
    commit = value_to_df_2dim(value.(COMMIT))

    # Calculate curtailment = available wind and/or solar output that 
    # had to be wasted due to operating constraints
    curtail = innerjoin(gen_var_cf, gen, on = [:r_id, :hour])
    curtail.curt = curtail.cf .* curtail.existing_cap_mw - curtail.gen
    
    # Return the solution parameters and objective
    return (
        gen,
        commit,
        curtail,
        cost = objective_value(UC),
        status = termination_status(UC)
    )

end

# Run the UC for the given day and plot a stacked area chart of generation 
# using @vlplot from the VegaLite package.

# Solve
solution = unit_commitment_simple(gen_df, Demand, gen_variable_long);

# Clean up the data so we can run the VLPLOT
# Add in BTM solar and curtailment and plot results
function plot_solution(solution, gen_df)
    sol_gen = innerjoin(solution.gen, 
                        gen_df[!, [:r_id, :resource]], 
                        on = :r_id)

    # this is basically collapsing the data
    sol_gen = combine(groupby(sol_gen, [:resource, :hour]), 
                :gen => sum)

    sol_gen[sol_gen.resource .== "solar_photovoltaic", :resource] .= "_solar_photovoltaic"
    sol_gen[sol_gen.resource .== "onshore_wind_turbine", :resource] .= "_onshore_wind_turbine"
    sol_gen[sol_gen.resource .== "small_hydroelectric", :resource] .= "_small_hydroelectric"

    # BTM solar - we assume we have 600MW available
    btm = DataFrame(resource = repeat(["_solar_photovoltaic_btm"]; outer=length(Demand.demand)), 
        hour = Demand.hour,
        gen_sum = gen_variable_long[gen_variable_long.gen_full .== "wec_sdge_solar_photovoltaic_1.0",:cf] 
                * 600)
    append!(sol_gen, btm)

    # Curtailment
    curtail = combine(groupby(solution.curtail, [:hour]),
                :curt => sum)
    curtail.resource = "_curtailment"
    rename!(curtail, :curt_sum => :gen_sum)
    append!(sol_gen, curtail[:,[:resource, :hour, :gen_sum]])

    # plot! 
    sol_gen |>
        @vlplot(:area, 
            x=:hour, y={:gen_sum, stack=:zero}, 
            color={"resource:n", scale={scheme="category10"}})

end
p = plot_solution(solution, gen_df)

##########################################
# 2: PART 1.2
# Zero startup costs sensitivity
# Next, create a modified version of the generator dataframe (`gen_df_sens = copy(gen_df)`) and set the startup costs for all generators to be 0.
# Rerun the UC and compare with the first solution. What are the main differences and why?

# Create a copy, so we can mess around with it if we want...
gen_df_sens = copy(gen_df)
gen_df_sens.start_cost_per_mw = 0
solution_sens = unit_commitment_simple(gen_df_sens, Demand, gen_variable_long)
p_sens = plot_solution(solution_sens, gen_df_sens)


#=
# Major differences:
- When we dont have start up costs, we dont have curtailment! 
- Natural gas is more flexible, and is used less when there is more solar available.
=#






##########################################
# 2: PART 2
# Implement pubped hydropower storage


function unit_commitment_simple(gen_df, loads, gen_variable)
    UC = Model(GLPK.Optimizer)

    # We reduce the MIP gap tolerance threshold here to increase tractability
    # Here we set it to a 1% gap, meaning that we will terminate once we have 
    # a feasible integer solution guaranteed to be within 1% of the objective
    # function value of the optimal solution.
    # Note that GLPK's default MIP gap is 0.0, meaning that it tries to solve
    # the integer problem to optimality, which can take a LONG time for 
    # any complex problem. So it is important to set this to a realistic value.
    set_optimizer_attribute(UC, "mip_gap", 0.01)

    # Define sets based on data
    # Note the creation of several different sets of generators for use in
    # different equations.
        # Thermal resources for which unit commitment constraints apply
    G_thermal = gen_df[gen_df[!,:up_time] .> 0,:r_id] 
        # Non-thermal resources for which unit commitment constraints do NOT apply 
    G_nonthermal = gen_df[gen_df[!,:up_time] .== 0,:r_id]
        # Variable renewable resources
    G_var = gen_df[gen_df[!,:is_variable] .== 1,:r_id]
        # Non-variable (dispatchable) resources
    G_nonvar = gen_df[gen_df[!,:is_variable] .== 0,:r_id]
        # Non-variable and non-thermal resources
    G_nt_nonvar = intersect(G_nonvar, G_nonthermal)
        # Set of all generators (above are all subsets of this)
    G = gen_df.r_id
        # All time periods (hours) over which we are optimizing
    T = loads.hour
        # A subset of time periods that excludes the last time period
    T_red = loads.hour[1:end-1]  # reduced time periods without last one

    # Generator capacity factor time series for variable generators
    gen_var_cf = innerjoin(gen_variable, 
                    gen_df[gen_df.is_variable .== 1 , 
                        [:r_id, :gen_full, :existing_cap_mw]], 
                    on = :gen_full)
        
    # Decision variables   
    @variables(UC, begin
            # Continuous decision variables
        GEN[G, T]  >= 0     # generation
            # Bin = binary variables; 
            # the following are all binary decisions that 
            # can ONLY take the values 0 or 1
            # The presence of these discrete decisions makes this an MILP
        COMMIT[G_thermal, T], Bin # commitment status (Bin=binary)
        START[G_thermal, T], Bin  # startup decision
        SHUT[G_thermal, T], Bin   # shutdown decision
    end)
                
    # Objective function
        # Sum of variable costs + start-up costs for all generators and time periods
    @objective(UC, Min, 
        sum( (gen_df[gen_df.r_id .== i,
            :heat_rate_mmbtu_per_mwh][1] * 
                gen_df[gen_df.r_id .== i,:fuel_cost][1] +
            gen_df[gen_df.r_id .== i,:var_om_cost_per_mwh][1]) * GEN[i,t] 
                        for i in G_nonvar for t in T) + 
        sum(gen_df[gen_df.r_id .== i,:var_om_cost_per_mwh][1] * GEN[i,t] 
                        for i in G_var for t in T)  + 
        sum(gen_df[gen_df.r_id .== i,:start_cost_per_mw][1] * 
            gen_df[gen_df.r_id .== i,:existing_cap_mw][1] *
            START[i,t] 
                        for i in G_thermal for t in T)
    )


# stuff related to storage 

    # set parameters defined in the problem set question
    hp_power_cap = gen_df.existing_cap_mw[gen_df.resource .=="hydroelectric_pumped_storage" ][1] 
    hp_energy_cap = 4 * hp_power_cap
    battery_eff = 0.84
    start_charge = 0.5 * hp_energy_cap
    end_charge = start_charge

    @variables(UC, begin
        hp_power_cap    >= CHARGE[t in loads.hour]     >= 0
        hp_power_cap    >= DISCHARGE[t in loads.hour]  >= 0
        hp_energy_cap     >= SOC[t in loads.hour]        >= 0
    end)

    # First define an Array of length equal to our time series to contain references to each expression
    cStateOfCharge = Array{Any}(undef, length(loads.hour))
    # First period state of charge:
    cStateOfCharge[1] = @constraint(UC, 
        SOC[1] == start_charge 
    ) 
    # Final period state of charge constraint:
    cStateOfCharge[24] = @constraint(UC, 
        SOC[24] + (CHARGE[24]*battery_eff - DISCHARGE[24]/battery_eff) == end_charge 
    ) 
    # All other time periods, defined recursively based on prior state of charge
    for t in loads.hour[(24 .> loads.hour .> 1)]
        cStateOfCharge[t] = @constraint(UC, 
            SOC[t] == SOC[t-1] + CHARGE[t]*battery_eff - DISCHARGE[t]/battery_eff
        )
    end

    # Add constraint to generation - linking charge to generation. 
    # can i just stick this in the first constraint below?


# end of stuff related to storage 
    # Demand balance constraint (supply must = demand in all time periods)
    @constraint(UC, cDemand[t in T], 
        sum(GEN[i,t] for i in G) == loads[loads.hour .== t,:demand][1])

    # Capacity constraints 
      # 1. thermal generators requiring commitment
    @constraint(UC, Cap_thermal_min[i in G_thermal, t in T], 
        GEN[i,t] >= COMMIT[i, t] * gen_df[gen_df.r_id .== i,:existing_cap_mw][1] *
                        gen_df[gen_df.r_id .== i,:min_power][1])
    @constraint(UC, Cap_thermal_max[i in G_thermal, t in T], 
        GEN[i,t] <= COMMIT[i, t] * gen_df[gen_df.r_id .== i,:existing_cap_mw][1])

      # 2. non-variable generation not requiring commitment
    @constraint(UC, Cap_nt_nonvar[i in G_nt_nonvar, t in T], 
        GEN[i,t] <= gen_df[gen_df.r_id .== i,:existing_cap_mw][1])
    
      # 3. variable generation, accounting for hourly capacity factor
    @constraint(UC, Cap_var[i in 1:nrow(gen_var_cf)], 
            GEN[gen_var_cf[i,:r_id], gen_var_cf[i,:hour] ] <= 
                        gen_var_cf[i,:cf] *
                        gen_var_cf[i,:existing_cap_mw])
    
    # Unit commitment constraints
      # 1. Minimum up time
    @constraint(UC, Startup[i in G_thermal, t in T],
        COMMIT[i, t] >= sum(START[i, tt] 
                        for tt in intersect(T,
                            (t-gen_df[gen_df.r_id .== i,:up_time][1]):t)))

      # 2. Minimum down time
    @constraint(UC, Shutdown[i in G_thermal, t in T],
        1-COMMIT[i, t] >= sum(SHUT[i, tt] 
                        for tt in intersect(T,
                            (t-gen_df[gen_df.r_id .== i,:down_time][1]):t)))
 
      # 3. Commitment state
    @constraint(UC, CommitmentStatus[i in G_thermal, t in T_red],
        COMMIT[i,t+1] - COMMIT[i,t] == START[i,t+1] - SHUT[i,t+1])
    
    # Solve statement (! indicates runs in place)
    optimize!(UC)

    # Generation solution and convert to data frame 
    # with our helper function defined above
    gen = value_to_df_2dim(value.(GEN))

    # Commitment status solution and convert to data frame
    commit = value_to_df_2dim(value.(COMMIT))

    # Calculate curtailment = available wind and/or solar output that 
    # had to be wasted due to operating constraints
    curtail = innerjoin(gen_var_cf, gen, on = [:r_id, :hour])
    curtail.curt = curtail.cf .* curtail.existing_cap_mw - curtail.gen
    
    # Return the solution parameters and objective
    return (
        gen,
        commit,
        curtail,
        cost = objective_value(UC),
        status = termination_status(UC)
    )

end














