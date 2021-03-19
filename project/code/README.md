Please note - all code is under development, and will be changed/updated before the project is complete. 

- `/functions/` contains functions loaded by the `run_code.jl` file. 
- `/plots/` contains R scripts using the `ggplot2` package to visualise data and model results. 
- `run_code.jl` is julia code that runs the model. Please see comments inline for details. 
- `run_project.sh` is a bash wrapper for the whole project, that will eventually be able to replicate the whole final project from start to finish. You can currently run this file to check replicability of results, just by changing the string in that file to the location of this project on your machine. This string is then passed to `run_code.jl` as a command line argument. 
  - I also use it for parallelising model runs, as it allows me more control than by just using the Julia `Distributed` package (given my limited understanding of this package!).