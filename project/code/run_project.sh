#!/bin/bash

# Loop over the jobs, sending them all out at once, allowing for parallel running 
# This code tests for whether the target csv output exists - useful given 
# sometimes the processes on my laptop got interupted.

# Get into the relevant directory
dir=/Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/project/
cd "${dir}/code"
# Electr capex is first arg. Second arg is H2 efficiency. 
for elec_cpx in 200 500 800 
do
	for eff in "0.75" "0.80" "0.85"
	do
		# Get appropriate file string identifier. Need these if statements as
		# cant work out how to do floating point math in bash! Only run code if target 
		# file doesn't exist
		if [ $eff = "0.75" ] ; then
			eff_s="75"
		elif [ $eff = "0.80" ] ; then
			eff_s="80"
		else
			eff_s="85"
		fi
		# Note - the test if just on the 0 carbon tax version, since thats the first one in the 
		# loop to run. If i want to make it more flexible, will need to bring Carbon Tax into 
		# this script as a command line argument (or add additional logic to the julia code)
		FILE="${dir}/results/52_weeks/c_tax_0/EleCpx_${elec_cpx}.0_StorCpx_0.6_Eff_${eff_s}/time_results.csv"
		if test -f "$FILE"; then
		    echo "$FILE exists."
		else 
			echo "running code for $elec_cpx $eff_s"
			echo "$FILE"
			# Run code, with appropriate command line arguments
			nohup julia run_code.jl $elec_cpx $eff $dir & 
		fi
	done
done


# julia run_code.jl 200 0.8 $dir
# elec_cpx=200
# eff=0.7
# eff_s=$((${eff}*100))
# eff_s="${eff_s%.*}"
# FILE="${dir}/results/52_weeks/c_tax_0/EleCpx_${elec_cpx}.0_StorCpx_0.6_Eff_${eff_s}/time_results.csv"
# if test -f "$FILE"; then
#     echo "$FILE exists."
# else 
# 	echo "nice"
# fi
