# Utility functions for assignment 5
println("-----------------------------------------------")
println("1 loading data preparation functions")
println("-----------------------------------------------")

# Load and format generation data
function load_generators(input_path::String, num_days::Number)

    dir = input_path * "/Notebooks/complex_expansion_data/" * 
                string(num_days) * "_days/"

    generators = DataFrame(CSV.File(joinpath(dir, 
            "Generators_data.csv")));
    # Many of the columns in the input data will be unused (this is 
    #   input format for the GenX model)

    generators = select(generators, 
                    :R_ID, :Resource, :zone, :THERM, :DISP, 
                    :NDISP, :STOR, :HYDRO, :RPS, :CES,
                    :Commit, :Existing_Cap_MW, :Existing_Cap_MWh, 
                    :Cap_size, :New_Build, :Max_Cap_MW,
                    :Inv_cost_per_MWyr, :Fixed_OM_cost_per_MWyr, 
                    :Inv_cost_per_MWhyr, :Fixed_OM_cost_per_MWhyr,
                    :Var_OM_cost_per_MWh, :Start_cost_per_MW, 
                    :Start_fuel_MMBTU_per_MW, :Heat_rate_MMBTU_per_MWh, :Fuel,
                    :Min_power, :Ramp_Up_percentage, :Ramp_Dn_percentage, 
                    :Up_time, :Down_time,
                    :Eff_up, :Eff_down);
    return(generators)
end


# Load and format demand data
function load_demand(input_path::String, num_days::Number)
    
    dir = input_path * "/Notebooks/complex_expansion_data/" * 
                string(num_days) * "_days/"
    
    demand_inputs = DataFrame(CSV.File(joinpath(dir, 
                "Load_data.csv")))
    return(demand_inputs)
end

# Return NSE cost and max from demand inputs 
# NSE_Cost = opportunity cost per MWh of demand curtailment
# NSE_Max = maximum % of demand that can be curtailed in each hour
# Data frame for price responsive demand segments (nse)
# Note that nse segment 1 = involuntary non-served energy 
#           (load shedding) at $9000/MWh
# and segment 2 = one segment of voluntary price responsive demand 
        # at $600/MWh (up to 7.5% of demand)
function format_nse(demand_inputs::DataFrame, VOLL::Number, S::Array)

    return DataFrame(Segment=S, 
        NSE_Cost = VOLL.*collect(skipmissing(
            demand_inputs.Cost_of_demand_curtailment_perMW)),
        NSE_Max = collect(skipmissing(demand_inputs.Max_demand_curtailment)))

end 

# # Create vector of sample weights, representing how many hours in the year
# each hour in each sample period represents
# Set of sequential hours per sub-period
function return_sample_weights(hours_per_period::Number, W::Array, P::Array, 
                                T::Array)

    sample_weight = zeros(Float64, size(T,1))
    
    t=1
    for p in P
        for h in 1:hours_per_period
            sample_weight[t] = W[p]/hours_per_period
            t=t+1
        end
    end
    
    return sample_weight
end

# Read generator capacity factors by hour (used for variable renewables)
function load_variability(input_path::String, num_days::Number)
    
    dir = input_path * "/Notebooks/complex_expansion_data/" * 
                string(num_days) * "_days/"

    # There is one column here for each resource (row) in the generators DataFrame
    variability = DataFrame(CSV.File(joinpath(dir, "Generators_variability.csv")))
    # Drop the first column with row indexes, as these are unecessary
    variability = variability[:,2:ncol(variability)];
    
    return variability 
end

# Load fuels informations
function load_fuels(input_path::String, num_days::Number)
    
    dir = input_path * "/Notebooks/complex_expansion_data/" * 
                string(num_days) * "_days/"
    
    return DataFrame(CSV.File(joinpath(dir, "Fuels_data.csv")));
end

# Load network informations
function load_network(input_path::String, num_days::Number)
    
    dir = input_path * "/Notebooks/complex_expansion_data/" * 
                string(num_days) * "_days/"
    
    return DataFrame(CSV.File(joinpath(dir, "Network.csv")));
end

# format network dataframe to return lines info
function format_lines(network::DataFrame)
    lines = select(network[1:2,:], 
        :Network_lines, :z1, :z2, :z3, 
        :Line_Max_Flow_MW, :Line_Min_Flow_MW, :Line_Loss_Percentage, 
        :Line_Max_Reinforcement_MW, :Line_Reinforcement_Cost_per_MW_yr)
    # Add fixed O&M costs for lines = 1/20 of reinforcement cost
    lines.Line_Fixed_Cost_per_MW_yr = lines.Line_Reinforcement_Cost_per_MW_yr./20
    return lines
end

# Calculate generator (and storage) total variable costs, start-up costs, 
# and associated CO2 per MWh and per start
function calculate_gen_costs(generators::DataFrame, G::Array, fuels::DataFrame)

    generators.Var_Cost = zeros(Float64, size(G,1))
    generators.CO2_Rate = zeros(Float64, size(G,1))
    generators.Start_Cost = zeros(Float64, size(G,1))
    generators.CO2_Per_Start = zeros(Float64, size(G,1))

    for g in G
        # Variable cost ($/MWh) = variable O&M ($/MWh) + 
            # fuel cost ($/MMBtu) * heat rate (MMBtu/MWh)
        generators.Var_Cost[g] = generators.Var_OM_cost_per_MWh[g] +
            fuels[fuels.Fuel.==generators.Fuel[g],
                    :Cost_per_MMBtu][1]*generators.Heat_rate_MMBTU_per_MWh[g]
        # CO2 emissions rate (tCO2/MWh) = 
        #      fuel CO2 content (tCO2/MMBtu) * heat rate (MMBtu/MWh)
        generators.CO2_Rate[g] = fuels[fuels.Fuel.==generators.Fuel[g],
        :CO2_content_tons_per_MMBtu][1]*generators.Heat_rate_MMBTU_per_MWh[g]
        # Start-up cost ($/start/MW) = start up O&M cost ($/start/MW) 
            # + fuel cost ($/MMBtu) * start up fuel use (MMBtu/start/MW) 
        generators.Start_Cost[g] = generators.Start_cost_per_MW[g] +
            fuels[fuels.Fuel.==generators.Fuel[g],
            :Cost_per_MMBtu][1]*generators.Start_fuel_MMBTU_per_MW[g]
        # Start-up CO2 emissions (tCO2/start/MW) = 
        #   fuel CO2 content (tCO2/MMBtu) * start up fuel use (MMBtu/start/MW) 
        generators.CO2_Per_Start[g] = fuels[fuels.Fuel.==generators.Fuel[g],
            :CO2_content_tons_per_MMBtu][1]*generators.Start_fuel_MMBTU_per_MW[g]
        
            return generators
    end
end

# Get the relevant subsets of generators
function get_subsets(G::Array, generators::DataFrame)
    # Subset of G of all thermal resources subject to unit commitment constraints
    UC = intersect(generators.R_ID[generators.Commit.==1], G)
    # Subset of G NOT subject to unit commitment constraints
    ED = intersect(generators.R_ID[.!(generators.Commit.==1)], G)
    # Subset of G of all storage resources
    STOR = intersect(generators.R_ID[generators.STOR.>=1], G)
    # Subset of G of all variable renewable resources
    VRE = intersect(generators.R_ID[generators.DISP.==1], G)
    # Subset of all new build resources
    NEW = intersect(generators.R_ID[generators.New_Build.==1], G)
    # Subset of all existing resources
    OLD = intersect(generators.R_ID[.!(generators.New_Build.==1)], G)
    # Subset of all RPS qualifying resources
    RPS = intersect(generators.R_ID[generators.RPS.==1], G);
    
    return(UC = UC, ED = ED, STOR = STOR, 
            VRE = VRE, NEW = NEW, OLD = OLD, RPS = RPS)
end

# Big wrapper function to clean and load data for given time step
# Load in data (parameters)
function prep_sets_and_parameters(pso_dir, days)

    variability = load_variability(pso_dir, days)
    fuels = load_fuels(pso_dir, days)
    network = load_network(pso_dir, days)
    generators = load_generators(pso_dir, days)
    demand_inputs = load_demand(pso_dir, days)

    # Set of all generators
    G = generators.R_ID;
    # Value of lost load (cost of involuntary non-served energy)
    VOLL = demand_inputs.Voll[1]


    # Get sets
    # Set of price responsive demand (non-served energy) segments
    S = convert(Array{Int32}, collect(skipmissing(demand_inputs.Demand_segment))) 
    # Set of time sample sub-periods (e.g. sample days or weeks)
    P = convert(Array{Int32}, 1:demand_inputs.Subperiods[1])
    # Sub period cluster weights = number of periods (days/weeks) represented by each sample period
    W = convert(Array{Int32}, collect(skipmissing(demand_inputs.Sub_Weights)))
    # Set of all time steps
    T = convert(Array{Int32}, demand_inputs.Time_index)

    # Format the NSE parameter input data
    nse = format_nse(demand_inputs, VOLL, S) 

    # How many hours each subperidd represents 
    hours_per_period = convert(Int32, demand_inputs.Hours_per_period[1])
    # Get the weighting for each hour
    sample_weight = return_sample_weights(hours_per_period, W, P, T)

    # Set of zones 
    Z = convert(Array{Int32}, 1:3)

    # Load/demand time series by zone (TxZ array)
    demand = select(demand_inputs, :Load_MW_z1, :Load_MW_z2, :Load_MW_z3);

    # Array of network zones (z1, z2, z3)
    zones = collect(skipmissing(network.Network_zones))
    # Network map showing lines connecting zones
    lines = format_lines(network)
    # Set of all lines
    L = convert(Array{Int32}, lines.Network_lines);

    # Calculate generator (and storage) total variable costs, start-up costs, 
    # and associated CO2 per MWh and per start
    generators=calculate_gen_costs(generators, G, fuels)

    # Drop hydropower and biomass plants from generators set for simplicity 
    # (these are a small share of total ERCOT capacity, ~500 MW
    G = intersect(generators.R_ID[.!(generators.HYDRO.==1)],G)
    G = intersect(generators.R_ID[.!(generators.NDISP.==1)],G);

    parameters = (nse = nse, generators = generators, demand = demand, 
                    zones = zones, lines = lines, variability = variability)
    SETS = (G = G, S = S, P = P, W =W, T= T, Z=Z, L=L)  
    SUB = get_subsets(G, generators)
    
    return(params = parameters, SETS = SETS, SUB = SUB, VOLL = VOLL, lines = lines, 
        hours_per_period = hours_per_period, sample_weight = sample_weight)
end

println("-----------------------------------------------")
println("2 loading optimization  functions")
println("-----------------------------------------------")

# DECISION VARIABLES
  # By naming convention, all decision variables start with 
#   v and then are in UPPER_SNAKE_CASE


function solve_model(;params, SET, SUB, hours_per_period, 
        VOLL, sample_weight)
    
    # Initialise model
    Expansion_Model = Model(GLPK.Optimizer)

    # Capacity decision variables
    @variables(Expansion_Model, begin
            vCAP[g in SET.G]            >= 0     # power capacity (MW)
            vRET_CAP[g in SUB.OLD]      >= 0     # retirement of power capacity (MW)
            vNEW_CAP[g in SUB.NEW]      >= 0     # new build power capacity (MW)
            
            vE_CAP[g in SUB.STOR]       >= 0     # storage energy capacity (MWh)
            vRET_E_CAP[g in intersect(SUB.STOR, SUB.OLD)]   >= 0     # retirement of storage energy capacity (MWh)
            vNEW_E_CAP[g in intersect(SUB.STOR, SUB.NEW)]   >= 0     # new build storage energy capacity (MWh)
            
            vT_CAP[l in SET.L]          >= 0     # transmission capacity (MW)
            vRET_T_CAP[l in SET.L]      >= 0     # retirement of transmission capacity (MW)
            vNEW_T_CAP[l in SET.L]      >= 0     # new build transmission capacity (MW)
    end)


    # Set upper bounds on capacity for renewable resources 
    # (which are limited in each resource 'cluster')
    for g in SUB.NEW[params.generators[SUB.NEW,:Max_Cap_MW].>0]
        set_upper_bound(vNEW_CAP[g], params.generators.Max_Cap_MW[g])
    end

    # Set upper bounds on transmission capacity expansion
    for l in SET.L
        set_upper_bound(vNEW_T_CAP[l], params.lines.Line_Max_Reinforcement_MW[l])
    end

    # Operational decision variables
    @variables(Expansion_Model, begin
            vGEN[SET.T,SET.G]       >= 0  # Power generation (MW)
            vCHARGE[SET.T,SUB.STOR] >= 0  # Power charging (MW)
            vSOC[SET.T,SUB.STOR]    >= 0  # Energy storage state of charge (MWh)
            vNSE[SET.T,SET.S,SET.Z]     >= 0  # Non-served energy/demand curtailment (MW)
            vFLOW[SET.T,SET.L]      # Transmission line flow (MW); 
            # note line flow is positive if flowing
            # from source node (indicated by 1 in zone column for that line) 
            # to sink node (indicated by -1 in zone column for that line); 
            # flow is negative if flowing from sink to source.
    end)

    # # # CONSTRAINTS
    # #   # By naming convention, all constraints start with c and then are TitleCase
    # function add_constraints(Expansion_Model; params, SET, SUB, hours_per_period)

    # (1) Supply-demand balance constraint for all time steps and zones
    @constraint(Expansion_Model, cDemandBalance[t in SET.T, z in SET.Z], 
            sum(vGEN[t,g] for g in intersect(
                params.generators[params.generators.zone.==z,:R_ID],SET.G)) +
            sum(vNSE[t,s,z] for s in SET.S) - 
            sum(vCHARGE[t,g] for g in intersect(
                params.generators[params.generators.zone.==z,:R_ID],SUB.STOR)) -
            params.demand[t,z] - 
            sum(params.lines[l,Symbol(string("z",z))] * 
                    vFLOW[t,l] for l in SET.L) == 0
    );
    # (2-6) Capacitated constraints:
    @constraints(Expansion_Model, begin
    # (2) Max power constraints for all time steps and all generators/storage
        cMaxPower[t in SET.T, g in SET.G], vGEN[t,g] <= 
            params.variability[t,g]*vCAP[g]
    # (3) Max charge constraints for all time steps and all storage resources
        cMaxCharge[t in SET.T, g in SUB.STOR], vCHARGE[t,g] <= vCAP[g]
    # (4) Max state of charge constraints for all time steps and all storage resources
        cMaxSOC[t in SET.T, g in SUB.STOR], vSOC[t,g] <= vE_CAP[g]
    # (5) Max non-served energy constraints for all time steps and all segments and all zones
        cMaxNSE[t in SET.T, s in SET.S, z in SET.Z], 
            vNSE[t,s,z] <= params.nse.NSE_Max[s]*params.demand[t,z]
    # (6a) Max flow constraints for all time steps and all lines
        cMaxFlow[t in SET.T, l in SET.L], vFLOW[t,l] <= vT_CAP[l]
    # (6b) Min flow constraints for all time steps and all lines
        cMinFlow[t in SET.T, l in SET.L], vFLOW[t,l] >= -vT_CAP[l]
    end)
    # (7-9) Total capacity constraints:
    @constraints(Expansion_Model, begin
    # (7a) Total capacity for existing units
        cCapOld[g in SUB.OLD], 
            vCAP[g] == params.generators.Existing_Cap_MW[g] - vRET_CAP[g]
    # (7b) Total capacity for new units
        cCapNew[g in SUB.NEW], vCAP[g] == vNEW_CAP[g]
            
    # (8a) Total energy storage capacity for existing units
        cCapEnergyOld[g in intersect(SUB.STOR, SUB.OLD)], 
            vE_CAP[g] == params.generators.Existing_Cap_MWh[g] - vRET_E_CAP[g]
    # (8b) Total energy storage capacity for existing units
        cCapEnergyNew[g in intersect(SUB.STOR, SUB.NEW)], 
            vE_CAP[g] == vNEW_E_CAP[g]
            
    # (9) Total transmission capacity
        cTransCap[l in SET.L], vT_CAP[l] == 
            params.lines.Line_Max_Flow_MW[l] - vRET_T_CAP[l] + vNEW_T_CAP[l]
    end)
    # Because we are using time domain reduction via sample periods (days or weeks),
    # we must be careful with time coupling constraints at the start and end of each
    # sample period. 

    # First we record a subset of time steps that begin a sub period 
    # (these will be subject to 'wrapping' constraints that link the start/end of each period)
    STARTS = 1:hours_per_period:maximum(SET.T)        
    # Then we record all time periods that do not begin a sub period 
    # (these will be subject to normal time couping constraints, looking back one period)
    INTERIORS = setdiff(SET.T,STARTS)

    # (10-12) Time coupling constraints
    @constraints(Expansion_Model, begin
    # (10a) Ramp up constraints, normal
    cRampUp[t in INTERIORS, g in SET.G], 
        vGEN[t,g] - vGEN[t-1,g] <= params.generators.Ramp_Up_percentage[g]*vCAP[g]
    # (10b) Ramp up constraints, sub-period wrapping
    cRampUpWrap[t in STARTS, g in SET.G], 
        vGEN[t,g] - vGEN[t+hours_per_period-1,g] <= 
            params.generators.Ramp_Up_percentage[g]*vCAP[g]    
    
    # (11a) Ramp down, normal
    cRampDown[t in INTERIORS, g in SET.G], 
        vGEN[t-1,g] - 
            vGEN[t,g] <= params.generators.Ramp_Dn_percentage[g]*vCAP[g] 
    # (11b) Ramp down, sub-period wrapping
    cRampDownWrap[t in STARTS, g in SET.G], 
        vGEN[t+hours_per_period-1,g] - vGEN[t,g] <= 
                    params.generators.Ramp_Dn_percentage[g]*vCAP[g]     
    
    # (12a) Storage state of charge, normal
    cSOC[t in INTERIORS, g in SUB.STOR], 
        vSOC[t,g] == vSOC[t-1,g] + params.generators.Eff_up[g]*vCHARGE[t,g] - 
            vGEN[t,g]/params.generators.Eff_down[g]
    # (12a) Storage state of charge, wrapping
    cSOCWrap[t in STARTS, g in SUB.STOR], 
        vSOC[t,g] == vSOC[t+hours_per_period-1,g] + 
            params.generators.Eff_up[g]*vCHARGE[t,g] - 
                vGEN[t,g]/params.generators.Eff_down[g]
    end)

    # The objective function is to minimize the sum of fixed costs associated w
    # capacity decisions, variable costs associated with operational decisions

    # Create expressions for each sub-component of the total cost 
    @expression(Expansion_Model, eFixedCostsGeneration,
    # Fixed costs for total capacity 
    sum(params.generators.Fixed_OM_cost_per_MWyr[g]*vCAP[g] for g in SET.G) +
    # Investment cost for new capacity
    sum(params.generators.Inv_cost_per_MWyr[g]*vNEW_CAP[g] for g in SUB.NEW)
    )
    @expression(Expansion_Model, eFixedCostsStorage,
    # Fixed costs for total storage energy capacity 
    sum(params.generators.Fixed_OM_cost_per_MWhyr[g]*vE_CAP[g] 
            for g in SUB.STOR) + 
    # Investment costs for new storage energy capacity
    sum(params.generators.Inv_cost_per_MWhyr[g]*vNEW_CAP[g] 
            for g in intersect(SUB.STOR, SUB.NEW))
    )
    @expression(Expansion_Model, eFixedCostsTransmission,
    # Investment and fixed O&M costs for transmission lines
    sum(params.lines.Line_Fixed_Cost_per_MW_yr[l]*vT_CAP[l] +
    params.lines.Line_Reinforcement_Cost_per_MW_yr[l]*vNEW_T_CAP[l] 
        for l in SET.L)
    )
    @expression(Expansion_Model, eVariableCosts,
    # Variable costs for generation, weighted by hourly sample weight
    sum(sample_weight[t]*params.generators.Var_Cost[g]*vGEN[t,g] 
        for t in SET.T, g in SET.G)
    )
    @expression(Expansion_Model, eNSECosts,
    # Non-served energy costs
    sum(sample_weight[t]*params.nse.NSE_Cost[s]*vNSE[t,s,z] for t in SET.T, s in SET.S, z in SET.Z)
    )

    @objective(Expansion_Model, Min,
    eFixedCostsGeneration + eFixedCostsStorage + eFixedCostsTransmission +
    eVariableCosts + eNSECosts
    );

    # Run the optimization 
    optimize!(Expansion_Model)
    
    # Record generation capacity and energy results
    generation = zeros(size(SET.G,1))
    for i in 1:size(SET.G,1)
        # Note that total annual generation is sumproduct of sample period weights and hourly sample period generation 
        generation[i] = sum(sample_weight.*value.(vGEN)[:,SET.G[i]].data) 
    end
    # Note: Total annual demand is sumproduct of sample period weights and hourly sample period demands
    total_demand = sum(convert(Array, sample_weight.*params.demand))
    # Note, sum(A; dims=x) sums a given Array over the specified dimension; 
    # here we sum demand in each zone over dim=2 (columns=zones) to get aggregate demand in each period
    # then find the maximum aggregate demand 
    peak_demand = maximum(sum(convert(Array, params.demand); dims=2))
    MWh_share = generation./total_demand.*100
    cap_share = value.(vCAP).data./peak_demand.*100
    generator_results = DataFrame(
        ID = SET.G, 
        Resource = params.generators.Resource[SET.G],
        Zone = params.generators.zone[SET.G],
        Total_MW = value.(vCAP).data,
        Start_MW = params.generators.Existing_Cap_MW[SET.G],
        Change_in_MW = value.(vCAP).data.-
                params.generators.Existing_Cap_MW[SET.G],
        Percent_MW = cap_share,
        GWh = generation/1000,
        Percent_GWh = MWh_share
    )

    # Record energy storage energy capacity results (MWh)
    storage_results = DataFrame(
        ID = SUB.STOR, 
        Zone = params.generators.zone[SUB.STOR],
        Resource = params.generators.Resource[SUB.STOR],
        Total_Storage_MWh = value.(vE_CAP).data,
        Start_Storage_MWh = params.generators.Existing_Cap_MWh[SUB.STOR],
        Change_in_Storage_MWh = value.(vE_CAP).data.-
                params.generators.Existing_Cap_MWh[SUB.STOR],
    )


    # Record transmission capacity results
    transmission_results = DataFrame(
        Line = SET.L, 
        Total_Transfer_Capacity = value.(vT_CAP).data,
        Start_Transfer_Capacity = params.lines.Line_Max_Flow_MW,
        Change_in_Transfer_Capacity = value.(vT_CAP).data.-
            params.lines.Line_Max_Flow_MW,
    )


    ## Record non-served energy results by segment and zone
    num_segments = maximum(SET.S)
    num_zones = maximum(SET.Z)
    nse_results = DataFrame(
        Segment = zeros(num_segments*num_zones),
        Zone = zeros(num_segments*num_zones),
        NSE_Price = zeros(num_segments*num_zones),
        Max_NSE_MW = zeros(num_segments*num_zones),
        Total_NSE_MWh = zeros(num_segments*num_zones),
        NSE_Percent_of_Demand = zeros(num_segments*num_zones)
    )
    i=1
    for s in SET.S
        for z in SET.Z
            nse_results.Segment[i]=s
            nse_results.Zone[i]=z
            nse_results.NSE_Price=params.nse.NSE_Cost[s]
            nse_results.Max_NSE_MW[i]=maximum(value.(vNSE)[:,s,z].data)
            nse_results.Total_NSE_MWh[i]=sum(sample_weight.*
                    value.(vNSE)[:,s,z].data)
            nse_results.NSE_Percent_of_Demand[i]=
                sum(sample_weight.*value.(vNSE)[:,s,z].data)/total_demand*100
            i=i+1
        end
    end

    # Record costs by component (in million dollars)
    # Note: because each expression evaluates to a single value, 
    # value.(JuMPObject) returns a numerical value, not a DenseAxisArray;
    # We thus do not need to use the .data extension here to extract numeric values
    cost_results = DataFrame(
        Fixed_Costs_Generation = value.(eFixedCostsGeneration)/10^6,
        Fixed_Costs_Storage = value.(eFixedCostsStorage)/10^6,
        Fixed_Costs_Transmission = value.(eFixedCostsTransmission)/10^6,
        Variable_Costs = value.(eVariableCosts)/10^6,
        NSE_Costs = value.(eNSECosts)/10^6
    );

    return(
        generator_results = generator_results, 
        storage_results = storage_results, 
        transmission_results = transmission_results, 
        nse_results = nse_results, 
        cost_results = cost_results
    )
end
