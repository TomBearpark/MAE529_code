# Utility functions for assignment 5
println("-----------------------------------------------")
println("1 loading data preparation function")
println("-----------------------------------------------")


function prepare_inputs(input_path::String, time_subset::String; 
            carbon_tax::Number, 
            H2_Fixed_Inv_cost_MWyr, H2_Fixed_OM_cost_MWyr, H2_Var_OM_cost_per_MWh, 
            H2_STOR_Inv_cost_MWhyr, H2_STOR_OM_cost_MWhyr, 
            H2_eff)

    # Input data path, based on time subset
    inputs_path = input_path  * time_subset * "/"

    # Generators (and storage) data:
    generators = DataFrame(CSV.File(joinpath(inputs_path, "Generators_data.csv")))
    # Many of the columns in the input data will be unused 
    # Select the ones we want for this model
    generators = select(generators, :R_ID, :Resource, :zone, :THERM, :DISP, 
                        :NDISP, :STOR, :HYDRO, :RPS, :CES,
                        :Commit, :Existing_Cap_MW, :Existing_Cap_MWh, :Cap_size, 
                        :New_Build, :Max_Cap_MW,
                        :Inv_cost_per_MWyr, :Fixed_OM_cost_per_MWyr, 
                        :Inv_cost_per_MWhyr, :Fixed_OM_cost_per_MWhyr,
                        :Var_OM_cost_per_MWh, :Start_cost_per_MW, 
                        :Start_fuel_MMBTU_per_MW, :Heat_rate_MMBTU_per_MWh, 
                        :Fuel,
                        :Min_power, :Ramp_Up_percentage, :Ramp_Dn_percentage, 
                        :Up_time, :Down_time,
                        :Eff_up, :Eff_down);
    
    # Add in hydrogen information, based on scenario
    generators = add_H2_rows_to_gen_df(generators, 
        H2_Fixed_Inv_cost_MWyr = H2_Fixed_Inv_cost_MWyr, 
        H2_Fixed_OM_cost_MWyr = H2_Fixed_OM_cost_MWyr, 
        H2_Var_OM_cost_per_MWh = H2_Var_OM_cost_per_MWh, 
        H2_STOR_Inv_cost_MWhyr = H2_STOR_Inv_cost_MWhyr, 
        H2_STOR_OM_cost_MWhyr = H2_STOR_OM_cost_MWhyr, 
        H2_eff = H2_eff)
    
    # Set of all generators
    G = generators.R_ID;

    # Read demand input data and record parameters
    demand_inputs = DataFrame(CSV.File(joinpath(inputs_path, "Load_data.csv")))
    # Value of lost load (cost of involuntary non-served energy)
    VOLL = demand_inputs.Voll[1]
        # Set of price responsive demand (non-served energy) segments
    S = convert(Array{Int32}, collect(skipmissing(demand_inputs.Demand_segment))) 
    #NOTE:  collect(skipmising(input)) is needed here in several spots 
    # because the demand inputs are not 'square' (different column lengths)
    
        # Data frame for price responsive demand segments (nse)
        # NSE_Cost = opportunity cost per MWh of demand curtailment
        # NSE_Max = maximum % of demand that can be curtailed in each hour
        # Note that nse segment 1 = involuntary non-served energy (load shedding) at $9000/MWh
        # and segment 2 = one segment of voluntary price responsive demand at $600/MWh (up to 7.5% of demand)
    nse = DataFrame(Segment=S, 
                    NSE_Cost = VOLL .* collect(skipmissing(demand_inputs.Cost_of_demand_curtailment_perMW)),
                    NSE_Max = collect(skipmissing(demand_inputs.Max_demand_curtailment)))
    
    # Set of sequential hours per sub-period. Force consistency of 52 week version
    if time_subset == "52_weeks"
        hours_per_period = 8760
        demand_inputs.Sub_Weights .= 8760
    else 
        hours_per_period = convert(Int32, demand_inputs.Hours_per_period[1])
    end
        # Set of time sample sub-periods (e.g. sample days or weeks)
    P = convert(Array{Int32}, 1:demand_inputs.Subperiods[1])
        # Sub period cluster weights = number of hours represented by each sample period
    W = convert(Array{Int32}, collect(skipmissing(demand_inputs.Sub_Weights)))
        # Set of all time steps
    T = convert(Array{Int32}, demand_inputs.Time_index)
        # Create vector of sample weights, representing how many hours in the year
        # each hour in each sample period represents
    sample_weight = zeros(Float64, size(T,1))
    t=1
    for p in P
        for h in 1:hours_per_period
            sample_weight[t] = W[p]/hours_per_period
            t=t+1
        end
    end

    
        # Set of zones 
    Z = convert(Array{Int32}, 1:3)
    # Notes on zones: 
    # Zone 1 is the Texas Panhandle, home to good wind resource 
    # but no local demand (not part of ERCOT)
    # Zone 2 is eastern half of ERCOT, home to majority of Texas population 
    # and major cities like Houston, Dallas-Forth Worth, Austin, and San Antonio
    # Zone 3 is western half of ERCOT, less populated, but great wind and solar 
    # resources
    
        # Load/demand time series by zone (TxZ array)
    demand = select(demand_inputs, :Load_MW_z1, :Load_MW_z2, :Load_MW_z3);
    # Uncomment this line to explore the data if you wish:
    # show(demand, allrows=true, allcols=true)

        # Read generator capacity factors by hour (used for variable renewables)
    # There is one column here for each resource (row) in the generators DataFrame
    variability = DataFrame(CSV.File(joinpath(inputs_path, "Generators_variability.csv")))
    variability = add_H2_to_variability(variability)

    # Drop the first column with row indexes, as these are unecessary
    variability = variability[:,2:ncol(variability)];
    # Uncomment this line to explore the data if you wish:
    # show(variability, allrows=true, allcols=true)

    # Read fuels data
    fuels = DataFrame(CSV.File(joinpath(inputs_path, "Fuels_data.csv")));

    # Read network data
    network = DataFrame(CSV.File(joinpath(inputs_path, "Network.csv")));
    #Again, there is a lot of entries in here we will not use (formatted for GenX inputs), so let's select what we want
    # Array of network zones (z1, z2, z3)
    zones = collect(skipmissing(network.Network_zones))
    # Network map showing lines connecting zones
    lines = select(network[1:2,:], 
        :Network_lines, :z1, :z2, :z3, 
        :Line_Max_Flow_MW, :Line_Min_Flow_MW, :Line_Loss_Percentage, 
        :Line_Max_Reinforcement_MW, :Line_Reinforcement_Cost_per_MW_yr)
    # Add fixed O&M costs for lines = 1/20 of reinforcement cost
    lines.Line_Fixed_Cost_per_MW_yr = lines.Line_Reinforcement_Cost_per_MW_yr./20
    # Set of all lines
    L = convert(Array{Int32}, lines.Network_lines);
    # Uncomment this line to explore the data if you wish:
    # show(lines, allrows=true, allcols=true)

    # Calculate generator (and storage) total variable costs, start-up costs, 
    # and associated CO2 per MWh and per start
    generators.Var_Cost = zeros(Float64, size(G,1))
    generators.CO2_Rate = zeros(Float64, size(G,1))
    generators.Start_Cost = zeros(Float64, size(G,1))
    generators.CO2_Per_Start = zeros(Float64, size(G,1))

    for g in G
        # Variable cost ($/MWh) = variable O&M ($/MWh) + fuel cost ($/MMBtu) 
        # * heat rate (MMBtu/MWh)
        generators.Var_Cost[g] = generators.Var_OM_cost_per_MWh[g] +
            fuels[fuels.Fuel.==generators.Fuel[g],
                :Cost_per_MMBtu][1]*generators.Heat_rate_MMBTU_per_MWh[g]
        # CO2 emissions rate (tCO2/MWh) = fuel CO2 content (tCO2/MMBtu) 
            # * heat rate (MMBtu/MWh)
        generators.CO2_Rate[g] = fuels[fuels.Fuel.==generators.Fuel[g],
            :CO2_content_tons_per_MMBtu][1]*generators.Heat_rate_MMBTU_per_MWh[g]
        # Start-up cost ($/start/MW) = start up O&M cost ($/start/MW) + 
        #   fuel cost ($/MMBtu) * start up fuel use (MMBtu/start/MW) 
        generators.Start_Cost[g] = generators.Start_cost_per_MW[g] +
            fuels[fuels.Fuel.==generators.Fuel[g],
            :Cost_per_MMBtu][1]*generators.Start_fuel_MMBTU_per_MW[g]
        # Start-up CO2 emissions (tCO2/start/MW) = 
        # fuel CO2 content (tCO2/MMBtu) * start up fuel use (MMBtu/start/MW) 
        generators.CO2_Per_Start[g] = fuels[fuels.Fuel.==generators.Fuel[g],
            :CO2_content_tons_per_MMBtu][1]*generators.Start_fuel_MMBTU_per_MW[g]
    end
        
    # Carbon tax for part 1d
    # add an additional element to the total Variable Cost and Start-up Cost that 
    # 50 times the CO2 content of the fuel (tCO2/MMBtu) times the total fuel 
    # consumed by each resource (MMBtu).


    println("adding in carbon tax elements")
    generators.Var_Cost = generators.Var_Cost + 
        generators.CO2_Rate .* carbon_tax
    
    generators.Start_Cost = generators.Start_Cost + 
        generators.CO2_Per_Start .* carbon_tax
    


    # Note: after this, we don't need the fuels Data Frame again...

    G = intersect(generators.R_ID[.!(generators.HYDRO.==1)],G)
    G = intersect(generators.R_ID[.!(generators.NDISP.==1)],G)

    #SUBSETS
    # By naming convention, all subsets are UPPERCASE

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

    # Return everying needed for the optimization, in a big list  
    return(
        # Parameters
        nse = nse, generators  = generators, demand = demand, zones = zones, 
            lines = lines, variability = variability, 
        # Sets
        G  = G, S  = S, P = P, T  = T, Z  = Z, L  = L,  
        # subsets
        UC = UC, ED = ED, STOR = STOR, VRE =VRE, NEW = NEW, OLD  = OLD, 
            RPS = RPS, 
        # values
        VOLL = VOLL, sample_weight = sample_weight, 
            hours_per_period = hours_per_period
    )
end 

println("-----------------------------------------------")
println("2 loading model solving function")
println("-----------------------------------------------")

# Function for solving the model, given the cleaned inputs from the 
# above function 

function solve_model(input)

    # Get the relevant names so it matches Jesse's code... 
    # params
    nse         = input.nse
    generators  = input.generators
    demand      = input.demand
    zones       = input.zones
    lines       = input.lines
    variability = input.variability
    # sets
    G  = input.G 
    P  = input.P 
    S  = input.S 
    # W  = input.W   - not needed 
    T  = input.T  
    Z  = input.Z  
    L  = input.L  
    # subsets
    UC = input.UC
    ED = input.ED
    STOR = input.STOR
    VRE =input.VRE
    NEW = input.NEW
    OLD  = input.OLD
    RPS = input.RPS
    # values
    VOLL = input.VOLL
    sample_weight = input.sample_weight
    hours_per_period = input.hours_per_period

    # LP model using Clp solver
    Expansion_Model =  Model(Clp.Optimizer);
    # DECISION VARIABLES
    # By naming convention, all decision variables start with v and then are in UPPER_SNAKE_CASE
  
    # Capacity decision variables
    @variables(Expansion_Model, begin
        vCAP[g in G]            >= 0     # power capacity (MW)
        vRET_CAP[g in OLD]      >= 0     # retirement of power capacity (MW)
        vNEW_CAP[g in NEW]      >= 0     # new build power capacity (MW)

        vE_CAP[g in STOR]       >= 0     # storage energy capacity (MWh)
        vRET_E_CAP[g in intersect(STOR, OLD)]   >= 0     # retirement of storage energy capacity (MWh)
        vNEW_E_CAP[g in intersect(STOR, NEW)]   >= 0     # new build storage energy capacity (MWh)

        vT_CAP[l in L]          >= 0     # transmission capacity (MW)
        vRET_T_CAP[l in L]      >= 0     # retirement of transmission capacity (MW)
        vNEW_T_CAP[l in L]      >= 0     # new build transmission capacity (MW)
    end)

    # Set upper bounds on capacity for renewable resources 
    # (which are limited in each resource 'cluster')
    for g in NEW[generators[NEW,:Max_Cap_MW].>0]
        set_upper_bound(vNEW_CAP[g], generators.Max_Cap_MW[g])
    end

    # Set upper bounds on transmission capacity expansion
    for l in L
        set_upper_bound(vNEW_T_CAP[l], lines.Line_Max_Reinforcement_MW[l])
    end

    # Operational decision variables
    @variables(Expansion_Model, begin
        vGEN[T,G]       >= 0  # Power generation (MW)
        vCHARGE[T,STOR] >= 0  # Power charging (MW)
        vSOC[T,STOR]    >= 0  # Energy storage state of charge (MWh)
        vNSE[T,S,Z]     >= 0  # Non-served energy/demand curtailment (MW)
        vFLOW[T,L]      # Transmission line flow (MW); 
        # note line flow is positive if flowing
        # from source node (indicated by 1 in zone column for that line) 
        # to sink node (indicated by -1 in zone column for that line); 
        # flow is negative if flowing from sink to source.
    end)
    println("assigned variables")
    # CONSTRAINTS
    # By naming convention, all constraints start with c and then are TitleCase

    # (1) Supply-demand balance constraint for all time steps and zones
    @constraint(Expansion_Model, cDemandBalance[t in T, z in Z], 
        sum(vGEN[t,g] for g in intersect(generators[generators.zone.==z,:R_ID],G)) +
        sum(vNSE[t,s,z] for s in S) - 
        sum(vCHARGE[t,g] for g in intersect(generators[generators.zone.==z,:R_ID],STOR)) -
            demand[t,z] - 
        sum(lines[l,Symbol(string("z",z))] * vFLOW[t,l] for l in L) == 0
    )
    println("assigned constraint 1")
    # Notes: 
    # 1. intersect(generators[generators.zone.==z,:R_ID],G) is the subset of all 
    # generators/storage located at zone z in Z.
    # 2. sum(lines[l,Symbol(string("z",z))].*FLOW[l,t], l in L) is the net sum of 
    # all flows out of zone z (net exports) 
    # 3. We use Symbol(string("z",z)) to convert the numerical reference to z in Z
    # to a Symbol in set {:z1, :z2, :z3} as this is the reference to the columns
    # in the lines data for zone z indicating which whether z is a source or sink
    # for each line l in L.
    # (2-6) Capacitated constraints:
    @constraints(Expansion_Model, begin
    # (2) Max power constraints for all time steps and all generators/storage
        cMaxPower[t in T, g in G], vGEN[t,g] <= variability[t,g]*vCAP[g]
    # (3) Max charge constraints for all time steps and all storage resources
        cMaxCharge[t in T, g in STOR], vCHARGE[t,g] <= vCAP[g]
    # (4) Max state of charge constraints for all time steps and all storage resources
        cMaxSOC[t in T, g in STOR], vSOC[t,g] <= vE_CAP[g]
    # (5) Max non-served energy constraints for all time steps and all segments and all zones
        cMaxNSE[t in T, s in S, z in Z], vNSE[t,s,z] <= nse.NSE_Max[s]*demand[t,z]
    # (6a) Max flow constraints for all time steps and all lines
        cMaxFlow[t in T, l in L], vFLOW[t,l] <= vT_CAP[l]
    # (6b) Min flow constraints for all time steps and all lines
        cMinFlow[t in T, l in L], vFLOW[t,l] >= -vT_CAP[l]
    end)
    println("assigned constraint 2")

    # (7-9) Total capacity constraints:
    @constraints(Expansion_Model, begin
    # (7a) Total capacity for existing units
        cCapOld[g in OLD], vCAP[g] == generators.Existing_Cap_MW[g] - vRET_CAP[g]
    # (7b) Total capacity for new units
        cCapNew[g in NEW], vCAP[g] == vNEW_CAP[g]
            
    # (8a) Total energy storage capacity for existing units
        cCapEnergyOld[g in intersect(STOR, OLD)], 
            vE_CAP[g] == generators.Existing_Cap_MWh[g] - vRET_E_CAP[g]
    # (8b) Total energy storage capacity for existing units
        cCapEnergyNew[g in intersect(STOR, NEW)], 
            vE_CAP[g] == vNEW_E_CAP[g]
            
    # (9) Total transmission capacity
        cTransCap[l in L], vT_CAP[l] == lines.Line_Max_Flow_MW[l] - vRET_T_CAP[l] + vNEW_T_CAP[l]
    end)
    println("assigned constraint 3")

    # Because we are using time domain reduction via sample periods (days or weeks),
    # we must be careful with time coupling constraints at the start and end of each
    # sample period. 

    # First we record a subset of time steps that begin a sub period 
    # (these will be subject to 'wrapping' constraints that link the start/end of each period)
    STARTS = 1:hours_per_period:maximum(T)        
    # Then we record all time periods that do not begin a sub period 
    # (these will be subject to normal time couping constraints, looking back one period)
    INTERIORS = setdiff(T,STARTS)
    
    println("check")
    
    # (10-12) Time coupling constraints
    @constraints(Expansion_Model, begin
        # (10a) Ramp up constraints, normal
        cRampUp[t in INTERIORS, g in G], 
            vGEN[t,g] - vGEN[t-1,g] <= generators.Ramp_Up_percentage[g]*vCAP[g]
        # (10b) Ramp up constraints, sub-period wrapping
        cRampUpWrap[t in STARTS, g in G], 
            vGEN[t,g] - vGEN[t+hours_per_period-1,g] <= generators.Ramp_Up_percentage[g]*vCAP[g]    
        # (11a) Ramp down, normal
        cRampDown[t in INTERIORS, g in G], 
            vGEN[t-1,g] - vGEN[t,g] <= generators.Ramp_Dn_percentage[g]*vCAP[g] 
        # (11b) Ramp down, sub-period wrapping
        cRampDownWrap[t in STARTS, g in G], 
            vGEN[t+hours_per_period-1,g] - vGEN[t,g] <= generators.Ramp_Dn_percentage[g]*vCAP[g]     
        
        # (12a) Storage state of charge, normal
        cSOC[t in INTERIORS, g in STOR], 
            vSOC[t,g] == vSOC[t-1,g] + generators.Eff_up[g]*vCHARGE[t,g] - vGEN[t,g]/generators.Eff_down[g]
        # (12a) Storage state of charge, wrapping
        cSOCWrap[t in STARTS, g in STOR], 
            vSOC[t,g] == vSOC[t+hours_per_period-1,g] + generators.Eff_up[g]*vCHARGE[t,g] - vGEN[t,g]/generators.Eff_down[g]
    end)

    println("assigned constraints")
    # The objective function is to minimize the sum of fixed costs associated with
    # capacity decisions and variable costs associated with operational decisions

    # Create expressions for each sub-component of the total cost (for later retrieval)
    @expression(Expansion_Model, eFixedCostsGeneration,
        # Fixed costs for total capacity 
        sum(generators.Fixed_OM_cost_per_MWyr[g]*vCAP[g] for g in G) +
        # Investment cost for new capacity
        sum(generators.Inv_cost_per_MWyr[g]*vNEW_CAP[g] for g in NEW)
    )
    @expression(Expansion_Model, eFixedCostsStorage,
        # Fixed costs for total storage energy capacity 
        sum(generators.Fixed_OM_cost_per_MWhyr[g]*vE_CAP[g] for g in STOR) + 
        # Investment costs for new storage energy capacity
        sum(generators.Inv_cost_per_MWhyr[g]*vNEW_CAP[g] for g in intersect(STOR, NEW))
    )
    @expression(Expansion_Model, eFixedCostsTransmission,
        # Investment and fixed O&M costs for transmission lines
        sum(lines.Line_Fixed_Cost_per_MW_yr[l]*vT_CAP[l] +
        lines.Line_Reinforcement_Cost_per_MW_yr[l]*vNEW_T_CAP[l] for l in L)
    )
    @expression(Expansion_Model, eVariableCosts,
        # Variable costs for generation, weighted by hourly sample weight
        sum(sample_weight[t]*generators.Var_Cost[g]*vGEN[t,g] for t in T, g in G)
    )
    @expression(Expansion_Model, eNSECosts,
        # Non-served energy costs
        sum(sample_weight[t]*nse.NSE_Cost[s]*vNSE[t,s,z] for t in T, s in S, z in Z)
    )

    @objective(Expansion_Model, Min,
        eFixedCostsGeneration + eFixedCostsStorage + eFixedCostsTransmission +
        eVariableCosts + eNSECosts
    )

    time = @elapsed optimize!(Expansion_Model)

    # Record generation capacity and energy results
    generation = zeros(size(G,1))
    for i in 1:size(G,1)
        # Note that total annual generation is sumproduct of sample period weights and hourly sample period generation 
        generation[i] = sum(sample_weight.*value.(vGEN)[:,G[i]].data) 
    end
    # Note: Total annual demand is sumproduct of sample period weights and hourly sample period demands
    total_demand = sum(convert(Array, sample_weight.*demand))
    # Note, sum(A; dims=x) sums a given Array over the specified dimension; 
    # here we sum demand in each zone over dim=2 (columns=zones) to get aggregate demand in each period
    # then find the maximum aggregate demand 
    peak_demand = maximum(sum(convert(Array, demand); dims=2))
    MWh_share = generation./total_demand.*100
    cap_share = value.(vCAP).data./peak_demand.*100
    generator_results = DataFrame(
        ID = G, 
        Resource = generators.Resource[G],
        Zone = generators.zone[G],
        Total_MW = value.(vCAP).data,
        Start_MW = generators.Existing_Cap_MW[G],
        Change_in_MW = value.(vCAP).data.-generators.Existing_Cap_MW[G],
        Percent_MW = cap_share,
        GWh = generation/1000,
        Percent_GWh = MWh_share
    )

    # Record energy storage energy capacity results (MWh)
    storage_results = DataFrame(
        ID = STOR, 
        Zone = generators.zone[STOR],
        Resource = generators.Resource[STOR],
        Total_Storage_MWh = value.(vE_CAP).data,
        Start_Storage_MWh = generators.Existing_Cap_MWh[STOR],
        Change_in_Storage_MWh = value.(vE_CAP).data.-generators.Existing_Cap_MWh[STOR],
    )


    # Record transmission capacity results
    transmission_results = DataFrame(
        Line = L, 
        Total_Transfer_Capacity = value.(vT_CAP).data,
        Start_Transfer_Capacity = lines.Line_Max_Flow_MW,
        Change_in_Transfer_Capacity = value.(vT_CAP).data.-lines.Line_Max_Flow_MW,
    )


    ## Record non-served energy results by segment and zone
    num_segments = maximum(S)
    num_zones = maximum(Z)
    nse_results = DataFrame(
        Segment = zeros(num_segments*num_zones),
        Zone = zeros(num_segments*num_zones),
        NSE_Price = zeros(num_segments*num_zones),
        Max_NSE_MW = zeros(num_segments*num_zones),
        Total_NSE_MWh = zeros(num_segments*num_zones),
        NSE_Percent_of_Demand = zeros(num_segments*num_zones)
    )
    i=1
    for s in S
        for z in Z
            nse_results.Segment[i]=s
            nse_results.Zone[i]=z
            nse_results.NSE_Price[i]=nse.NSE_Cost[s]
            nse_results.Max_NSE_MW[i]=maximum(value.(vNSE)[:,s,z].data)
            nse_results.Total_NSE_MWh[i]=sum(sample_weight.*value.(vNSE)[:,s,z].data)
            nse_results.NSE_Percent_of_Demand[i]=sum(sample_weight.*value.(vNSE)[:,s,z].data)/total_demand*100
            i=i+1
        end
    end

    # Record costs by component (in million dollars)
    # Note: because each expression evaluates to a single value, 
    # value.(JuMPObject) returns a numerical value, not a DenseAxisArray;
    # We thus do not need to use the .data extension here to extract numeric values
    cost_results = DataFrame(
        Total_Costs = objective_value(Expansion_Model)/10^6,
        Fixed_Costs_Generation = value.(eFixedCostsGeneration)/10^6,
        Fixed_Costs_Storage = value.(eFixedCostsStorage)/10^6,
        Fixed_Costs_Transmission = value.(eFixedCostsTransmission)/10^6,
        Variable_Costs = value.(eVariableCosts)/10^6,
        NSE_Costs = value.(eNSECosts)/10^6
    )
    return(
        generator_results = generator_results, 
        storage_results = storage_results, 
        transmission_results = transmission_results, 
        nse_results = nse_results, 
        cost_results = cost_results, 
        time = time
    )
end

# Function for writing results to csv files
function write_results(wd::String, solutions, time_subset::String;
        carbon_tax::Number, 
        electro_capex::Number, stor_capex::Number, efficiency::Number)

        outpath = wd * "/results/data/" * time_subset* "/"  * 
                    "c_tax_"* string(carbon_tax) *"/" * 
                    "EleCpx_" * string(electro_capex) * 
                    "_StorCpx_" * string(stor_capex) * 
                    "_Eff_" * string(100*efficiency) 

    if !(isdir(outpath))
        mkpath(outpath)
    end
    
    times = DataFrame(time = solutions.time)

    CSV.write(joinpath(outpath, "generator_results.csv"), 
        solutions.generator_results)
    CSV.write(joinpath(outpath, "storage_results.csv"), 
        solutions.storage_results)
    CSV.write(joinpath(outpath, "transmission_results.csv"), 
        solutions.transmission_results)
    CSV.write(joinpath(outpath, "nse_results.csv"), 
        solutions.nse_results)
    CSV.write(joinpath(outpath, "cost_results.csv"), 
        solutions.cost_results)
    CSV.write(joinpath(outpath, "time.csv"), 
        times);
end

# Helper function for loading csv files 
# function return_totals(wd, d, carbon_tax::Bool)
    
#     # Load in the relevant data
#     path = wd * "/results/data/question_1/" * d* "_Thomas_Bearpark/"
    
#     if carbon_tax
#         path = path * "carbon_tax"
#     else 
#         path = path * "without_carbon_tax"
#     end

#     cost_results = CSV.read(joinpath(path, "cost_results.csv"))
#     gen = CSV.read(joinpath(path, "generator_results.csv"))
#     times = DataFrame(
#         time_subset = ["10_days", "4_weeks", "8_weeks", "16_weeks"], 
#         hours = [10 * 24, 4 * 7 * 24, 8 * 7 * 24, 16 * 7 * 24])

#     # Return dataframe of needed data 
#     return DataFrame(time_subset = d, 
#                 total_hours = times.hours[times.time_subset .== d][1],
#                 total_cost = cost_results.Total_Costs[1], 
#                 total_final_capacity = sum(gen.Total_MW), 
#                 total_generation = sum(gen.GWh))
# end

# # Wraps around return totals, to append for each time period 
# function append_all_totals(wd, carbon_tax::Bool)
#     df = return_totals(wd, "10_days", carbon_tax) 
#     df = append!(df, return_totals(wd, "4_weeks", carbon_tax))
#     df = append!(df, return_totals(wd, "8_weeks", carbon_tax))
#     df = append!(df, return_totals(wd, "16_weeks", carbon_tax))
#     # Find percentage differences, relative to 16 week version 
#     for var in ("total_cost",  "total_final_capacity", "total_generation")
#         df[var * "_deviation"] = 0.0
#         for i in 1:3
#             df[var * "_deviation"][i] =  100 * 
#                 (df[var][i] - df[var][4]) / df[var][4]
#         end
#     end
#     return(df)
# end

# function load_cost_result(wd, time_subset, carbon_tax)
#     outpath = wd * "/results/data/question_1/" * time_subset* "_Thomas_Bearpark/"
    
#     if carbon_tax
#         outpath = outpath * "carbon_tax"
#     else 
#         outpath = outpath * "without_carbon_tax"
#     end
#     df = CSV.read(joinpath(outpath, "cost_results.csv")) 
#     df.time_subset = time_subset
#     return df
# end

# function load_generator_result(wd, time_subset, carbon_tax)
#     outpath = wd * "/results/data/question_1/" * time_subset* "_Thomas_Bearpark/"
    
#     if carbon_tax
#         outpath = outpath * "carbon_tax"
#     else 
#         outpath = outpath * "without_carbon_tax"
#     end
#     df = CSV.read(joinpath(outpath, "generator_results.csv")) 
#     df.time_subset = time_subset
#     return df
# end