using JuMP
using GLPK
using DataFrames
using CSV
using Plots; plotly();
using VegaLite;
using Query # dplyr like

##############################
# Question 1
##############################


# Note - tweaked this to use an absolute path, since i'm writing this code 
# outside of the repo. Would prefer to swtich this to a URL link
pso_dir = "/Users/tombearpark/Documents/princeton/1st_year/MAE529/power-systems-optimization"
datadir = joinpath(pso_dir,"Notebooks","ieee_test_cases") 
gens = CSV.read(joinpath(datadir,"Gen14.csv"), DataFrame);
lines = CSV.read(joinpath(datadir,"Tran14.csv"), DataFrame);
loads = CSV.read(joinpath(datadir,"Load14.csv"), DataFrame);

# Rename all columns to lowercase (by convention)
for f in [gens, lines, loads]
    rename!(f,lowercase.(names(f)))
end

# create generator ids 
gens.id = 1:nrow(gens);

# create line ids 
lines.id = 1:nrow(lines);
# add set of rows for reverse direction with same parameters
lines2 = copy(lines)
lines2.f = lines2.fromnode
lines2.fromnode = lines.tonode
lines2.tonode = lines2.f
lines2 = lines2[:,names(lines)]
append!(lines,lines2)

# calculate simple susceptance, ignoring resistance as earlier 
lines.b = 1 ./ lines.reactance

# keep only a single time period
loads = loads[:,["connnode","interval-1_load"]]
rename!(loads,"interval-1_load" => "demand");

# 1A - run the default system to check it out... 

# Copy the IEEE 14 bus system and DCOPF solver function from Notebook 6.
# In addition, add the following line to the return call of the function:
# status = termination_status(DCOPF)


#=
Function to solve DC OPF problem using IEEE test cases
Inputs:
    gen_info -- dataframe with generator info
    line_info -- dataframe with transmission lines info
    loads  -- dataframe with load info
=#
function dcopf_ieee(gens, lines, loads)
    DCOPF = Model(GLPK.Optimizer) # You could use Clp as well, with Clp.Optimizer
    
    # Define sets based on data
      # Set of generator buses
    G = gens.connnode
    
      # Set of all nodes
    N = sort(union(unique(lines.fromnode), 
            unique(lines.tonode)))
    
      # sets J_i and G_i will be described using dataframe indexing below

    # Define per unit base units for the system 
    # used to convert from per unit values to standard unit
    # values (e.g. p.u. power flows to MW/MVA)
    baseMVA = 100 # base MVA is 100 MVA for this system
    
    # Decision variables   
    @variables(DCOPF, begin
        GEN[N]  >= 0     # generation        
        # Note: we assume Pmin = 0 for all resources for simplicty here
        THETA[N]         # voltage phase angle of bus
        FLOW[N,N]        # flows between all pairs of nodes
    end)
    
    # Create slack bus with reference angle = 0; use bus 1 with generator
    fix(THETA[1],0)
                
    # Objective function
    @objective(DCOPF, Min, 
        sum( gens[g,:c1] * GEN[g] for g in G)
    )
    
    # Supply demand balances
    @constraint(DCOPF, cBalance[i in N], 
        sum(GEN[g] for g in gens[gens.connnode .== i,:connnode]) 
            + sum(load for load in loads[loads.connnode .== i,:demand]) 
        == sum(FLOW[i,j] for j in lines[lines.fromnode .== i,:tonode])
    )

    # Max generation constraint
    @constraint(DCOPF, cMaxGen[g in G],
                    GEN[g] <= gens[g,:pgmax])

    # Flow constraints on each branch; 
    # In DCOPF, line flow is a function of voltage angles
       # Create an array of references to the line constraints, 
       # which we "fill" below in loop
    cLineFlows = JuMP.Containers.DenseAxisArray{Any}(undef, 1:nrow(lines)) 
    for l in 1:nrow(lines)
        cLineFlows[l] = @constraint(DCOPF, 
            FLOW[lines[l,:fromnode],lines[l,:tonode]] == 
            baseMVA * lines[l,:b] * 
            (THETA[lines[l,:fromnode]] - THETA[lines[l,:tonode]])
        )
    end
    
    # Max line flow limits
       # Create an array of references to the line constraints, 
       # which we "fill" below in loop
    cLineLimits = JuMP.Containers.DenseAxisArray{Any}(undef, 1:nrow(lines)) 
    for l in 1:nrow(lines)
        cLineLimits[l] = @constraint(DCOPF,
            FLOW[lines[l,:fromnode],lines[l,:tonode]] <=
            lines[l,:capacity]
        ) 
    end

    # Solve statement (! indicates runs in place)
    optimize!(DCOPF)

    # Output variables
    generation = DataFrame(
        node = gens.connnode,
        gen = value.(GEN).data[gens.connnode]
        )
    
    angles = value.(THETA).data
    
    flows = DataFrame(
        fbus = lines.fromnode,
        tbus = lines.tonode,
        flow = baseMVA * lines.b .* (angles[lines.fromnode] .- 
                        angles[lines.tonode]))
    
    # We output the marginal values of the demand constraints, 
    # which will in fact be the prices to deliver power at a given bus.
    prices = DataFrame(
        node = N,
        value = dual.(cBalance).data)
    
    # Return the solution and objective as named tuple
    return (
        generation = generation, 
        angles,
        flows,
        prices,
        cost = objective_value(DCOPF),
        status = termination_status(DCOPF)
    )
end

# helper function for printing cost info
function print_cost_and_status(solution)
    println("Termination status was " * string(solution.status))
    println("Optimised cost was " * string(round(solution.cost)))
end

# First - run the model with baseline to get a comparison
solution = dcopf_ieee(gens, lines, loads);
print_cost_and_status(solution)
solution.generation
solution.flows

# Now - do problem 1a)
# Make the following change to the system:
# Increase the variable cost of Generator 1 to $30 / MWh
# Run the DCOPF and output generation, flows, and prices.

# Increase the variable cost of generator 1
gens_1a = copy(gens) 
gens_1a.c1[gens_1a.id .==1] .= 30

solution_1a = dcopf_ieee(gens_1a, lines, loads);
print_cost_and_status(solution_1a)
solution_1a.generation

# How has generation changed compared to the default system?
# What explains the new prices?

# Compare generation across models 
gen_comparison_df = DataFrame(
    baseline = solution.generation.gen, 
    increased_price_scen = solution_1a.generation.gen)
# No change in the optimal generation 

# Compare prices across models
price_comparison_df = DataFrame(
    baseline = solution.prices.value, 
    increased_price_scen = solution_1a.prices.value)
# Uniform increase in prices- the generator with the increased variable cost
# is the marginal plant, so it increases the prices 


# 1B

s


























lines = CSV.read(joinpath(datadir,"Tran14.csv"), DataFrame);
rename!(lines,lowercase.(names(lines)))

function format_lines(lines)
    # create line ids 
    lines.id = 1:nrow(lines);
    # add set of rows for reverse direction with same parameters
    lines2 = copy(lines)
    lines2.f = lines2.fromnode
    lines2.fromnode = lines.tonode
    lines2.tonode = lines2.f
    lines2 = lines2[:,names(lines)]
    append!(lines,lines2)

    # calculate simple susceptance, ignoring resistance as earlier 
    lines.b = 1 ./ lines.reactance
    return(lines)
end







