# Julia testing code

Pkg.add("Distributions")



using Random, Distributions
Random.seed!(123)
d = Bernoulli()
d
x = rand(Bernoulli(), 1000)
x
plot(x)
println(mean(x))
x



fit(Normal, x)
using Plots
density(x)


using CSV
read_csv = function(input):


a1 = [1,2,3,4]
length_a1 = length(a1)

for i in a1
    if i == length_a1
        print(i)
    else
        print(i, ",")
    end
end
println("end")

length_a1==4
