#!/bin/bash

# Loop over the jobs, sending them all out at once, allowing for parallel running 
# This code tests for whether the target csv output exists - useful given 
# sometimes the processes on my laptop got interupted.

# Get into the relevant directory
dir=/Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/project/
cd "${dir}/code"
# Electr capex is first arg. Second arg is H2 efficiency. 
# for elec_cpx in 500 1100 1700
for elec_cpx in 1100
do
	# for eff in "0.5" "0.4"	
	for eff in "0.5" 
	do
		# Get appropriate file string identifier. Need these if statements as
		# cant work out how to do floating point math in bash! Only run code if target 
		# file doesn't exist
		if [ $eff = "0.75" ] ; then
			eff_s="75"
		elif [ $eff = "0.80" ] ; then
			eff_s="80"
		elif [ $eff = "0.5" ] ; then
			eff_s="50"
		elif [ $eff = "0.4" ] ; then
			eff_s="40"
		else
			eff_s="85"
		fi
		# Tests whether target file exists or not, and then produces the output
		for CT in 0 50 75 100
		do
			FILE="${dir}/results/52_weeks/c_tax_${CT}/EleCpx_${elec_cpx}_StorCpx_0.6_Eff_${eff_s}/time_results.csv"
			if test -f "$FILE"; then
			    echo "$FILE exists."
			else 
				echo "running code for ${elec_cpx} ${eff_s} ${CT}"
				echo "$FILE"
				# Run code, with appropriate command line arguments. Sends output to a log file. 
				nohup julia run_code.jl $elec_cpx $eff $dir $CT > logs/E${elec_cpx}_Eff${eff}CT_${CT}.out &
			fi
		done
	done
done

# julia run_code.jl 200 "0.75" $dir 75 

