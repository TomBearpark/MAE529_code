println("loading functions")

# Load and format generation data
function load_generators(input_path, num_days)

    dir = input_path * "/Notebooks/complex_expansion_data/" * 
                string(num_days) * "_days/"

    generators = DataFrame(CSV.File(joinpath(dir, 
            "Generators_data.csv")));
    # Many of the columns in the input data will be unused (this is 
    #   input format for the GenX model)

    generators = select(generators, :R_ID, :Resource, :zone, :THERM, :DISP, 
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
function load_demand(input_path, num_days)
    
    dir = input_path * "/Notebooks/complex_expansion_data/" * 
                string(num_days) * "_days/"
    
    demand_inputs = DataFrame(CSV.File(joinpath(dir, 
                "Load_data.csv")))
    return(demand_inputs)
end


