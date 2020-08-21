Pkg.add("JuMP")
Pkg.add("Ipopt")

# Ipopt optimizer chosen as it can handle non-linear constraints
using JuMP, Ipopt

# Initialise the model and an optimiser
model = Model(Ipopt.Optimizer)

# Set up the variables
@variable(model, 0<=x)
@variable(model, 0<=y)
@variable(model, 0<=z)

# Define objective function
@NLobjective(model, Max, x * y * z)

# Set constraints
@constraint(model, con, x+y+z<=1)

# Optimise!
optimize!(model)

num_results(model)
println("x = ", round.(value(x);digits = 3),
        " y = ", round.(value(y);digits = 3),
        " z = ", round.(value(z);digits = 3)
        )
