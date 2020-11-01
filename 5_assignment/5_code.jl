# Homework 5

# Set up environment
using JuMP, GLPK                       # optimisation packages
using DataFrames, CSV, DataFramesMeta  # data cleaning

# consider adding later...
# using Plots; plotly()
# using RCall

# Set string as location of Power System Optimisation git repo. 
pso_dir = "/Users/tombearpark/Documents/princeton/" *
 "1st_year/MAE529/power-systems-optimization/"

# Load functions 
include("5_functions.jl")


# Part 1 
# Read input data for a case with 10 sample days of data


# Generators (and storage) data:
generators = load_generators(pso_dir, 10)
# Set of all generators
G = generators.R_ID;


# Read demand input data and record parameters
demand_inputs = load_demand(pso_dir, 10)


# Value of lost load (cost of involuntary non-served energy)
VOLL = demand_inputs.Voll[1]
  # Set of price responsive demand (non-served energy) segments
S = convert(Array{Int32}, collect(skipmissing(demand_inputs.Demand_segment))) 
#NOTE:  collect(skipmising(input)) is needed here in several spots because 
# the demand inputs are not 'square' (different column lengths)

  # Data frame for price responsive demand segments (nse)
  # NSE_Cost = opportunity cost per MWh of demand curtailment
  # NSE_Max = maximum % of demand that can be curtailed in each hour
  # Note that nse segment 1 = involuntary non-served energy (load shedding) at $9000/MWh
  # and segment 2 = one segment of voluntary price responsive demand at $600/MWh (up to 7.5% of demand)
nse = DataFrame(Segment=S, 
                NSE_Cost = VOLL.*collect(skipmissing(demand_inputs.Cost_of_demand_curtailment_perMW)),
                NSE_Max = collect(skipmissing(demand_inputs.Max_demand_curtailment)))

  # Set of sequential hours per sub-period
hours_per_period = convert(Int32, demand_inputs.Hours_per_period[1])
  # Set of time sample sub-periods (e.g. sample days or weeks)
P = convert(Array{Int32}, 1:demand_inputs.Subperiods[1])
  # Sub period cluster weights = number of periods (days/weeks) represented by each sample period
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
# Zone 1 is the Texas Panhandle, home to good wind resource but no local demand (not part of ERCOT)
# Zone 2 is eastern half of ERCOT, home to majority of Texas population and major cities like Houston, Dallas-Forth Worth, Austin, and San Antonio
# Zone 3 is western half of ERCOT, less populated, but great wind and solar resources

  # Load/demand time series by zone (TxZ array)
demand = select(demand_inputs, :Load_MW_z1, :Load_MW_z2, :Load_MW_z3);
# Uncomment this line to explore the data if you wish:
# show(demand, allrows=true, allcols=true)