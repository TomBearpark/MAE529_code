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

for
# Optimise!
optimize!(model)

println("x = ", round.(value(x);digits = 3),
        " y = ", round.(value(y);digits = 3),
        " z = ", round.(value(z);digits = 3)
        )

##########
using JuMP, Ipopt
# Initialise the model and an optimiser
model = Model(Ipopt.Optimizer)

# Set up the variables
@variable(model, x)
@variable(model, y)

# Define objective function
@NLobjective(model, Max, -2 * (x-4)^2 -2 * (y-4)^2 )

# Set constraints
@constraint(model, con1, x+y<=4)
@constraint(model, con2, x+3y<=9)

# Optimise!
optimize!(model)

println("x = ", round.(value(x);digits = 3),
        " y = ", round.(value(y);digits = 3))
               )

# Visualise the function and solution
using Plots; pyplot()
x=range(-2,stop=2,length=100)
y=range(-2,stop=2,length=100)
f(x,y) = -2 * (x-4)^2 -2 * (y-4)^2
plot(x,y,f,st=:surface)

g(x,y) = x+y-4
plot!(x,y,g, st =:surface)

h(x,y) = x+3y-9
plot!(2x,y,h, st =:surface)
