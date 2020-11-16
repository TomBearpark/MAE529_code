using CSV
using DataFrames
using Plots

url_base = "https://raw.githubusercontent.com/east-winds/" *
    "power-systems-optimization/master/Project/" *
    "ercot_brownfield_expansion/52_weeks/"

#  Helper function - loads and formats csv from the github storage location
function load_df(url_base::String, csv_name::String)
    df = DataFrame(CSV.read(download(url_base * csv_name)));
    rename!(df,lowercase.(names(df)))
    return df
end

loads = load_df(url_base, "Load_data.csv")

plot(loads.time_index, loads.load_mw_z1)
plot!(loads.time_index, loads.load_mw_z2)
plot!(loads.time_index, loads.load_mw_z3)

names(loads)


