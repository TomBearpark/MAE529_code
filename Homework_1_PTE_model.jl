using JuMP
using Clp
using DataFrames

# Initialise model
PTE_model = Model(Clp.Optimizer);

# Set up the decision variables
days = [1 2 3]
@variables(
    PTE_model,
    begin
        X_b[t in days] >= 0
        X_pro[t in days] >= 0
        X_ph[t in days] >= 0
        I_b[t in days] >= 0
        I_pro[t in days] >= 0
        Inv[t in days] >= 0
    end
)

# Set the constraints - see overleaf for details:
# https://www.overleaf.com/7247998739rhxcmxswzghb

@constraint(PTE_model,
    c_production1,
    sum(X_b[t] + I_b[t] for t in days) >= 30
)

@constraint(PTE_model,
    c_production2,
    sum(X_ph[t] for t in days) >= 6
)

@constraint(PTE_model,
    c_tech1_b_[t in days],
    X_ph[t] == 5  * I_b[t]
)

@constraint(PTE_model,
    c_tech1_pro_[t in days],
    X_ph[t] == I_pro[t]
)

@constraint(PTE_model,
    c_tech2_[t in days],
    2 * (I_b[t] + X_b[t]) + I_pro[t] + X_pro[t] ==Inv[t]
)

@constraint(PTE_model,
    c_tech3_[t in days],
    I_b[t] + X_b[t] <= 50
)

@constraint(PTE_model,
    c_tech4_[t in days],
    I_pro[t] + X_pro[t] <= 10
)

@constraint(PTE_model,
    c_inventory,
    sum(Inv[t] for t in days) <= 150
)

# Set objective function

@expression(PTE_model,
    e_profit,
    sum(X_b[t] + 5 * X_pro[t] +  X_ph[t]* (150 - 5 * I_b[t] - 10 * I_pro[t])
            for t in days )
)

# Set the objective function
@objective(PTE_model, Max, e_profit)

print(PTE_model)

# Run the model!
optimize!(PTE_model)

results = DataFrame(
    X_b = value.(X_b).data,
    X_pro = value.(X_pro).data,
    X_ph = value.(X_ph).data,
    I_b = value.(I_b).data,
    I_pro = value.(I_pro).data,
    Inv = value.(Inv).data,
)

results
