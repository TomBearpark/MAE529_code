# Homework 5

# Set up environment
using JuMP, GLPK                       # optimisation packages
using DataFrames, CSV, DataFramesMeta  # data cleaning

# Set string as location of Power System Optimisation git repo. 
pso_dir = "/Users/tombearpark/Documents/princeton/" *
                "1st_year/MAE529/power-systems-optimization/"

# Load functions 
include("5_functions.jl")

# Number of days
days = 10

# load the data 

input = prep_sets_and_parameters(pso_dir, days)

SUB = input.SUB
SET = input.SETS
params = input.params

# Define the model... 
Expansion_Model =  Model(GLPK.Optimizer);



# Introduce the set of decision variables 
decision_vars(Expansion_Model, params = params, SET = SET, SUB = SUB)







# Introduce constraints
add_constraints(Expansion_Model, params = params, SET = SET, 
            SUB = SUB, hours_per_period = input.hours_per_period)






            vGEN[t,g]
vGEN = Expansion_Model[:vGEN]
@constraint(Expansion_Model, cDemandBalance[t in SET.T, z in SET.Z], 
    sum(vGEN[t,g] for g in intersect(
        params.generators[params.generators.zone.==z,:R_ID],SET.G)) +
    sum(vNSE[t,s,z] for s in SET.S) - 
    sum(vCHARGE[t,g] for g in intersect(
        params.generators[params.generators.zone.==z,:R_ID],SET.STOR)) -
    demand[t,z] - 
    sum(params.lines[l,Symbol(string("z",z))] * 
        vFLOW[t,l] for l in SET.L) == 0
        )
