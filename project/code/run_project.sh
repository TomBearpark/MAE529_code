# Loop over the jobs, sending them all out at once, allowing for parallel running 

# Get into the relevant directory
dir=/Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/project/
cd "${dir}/code"
# Electr capex is first arg. Second arg is H2 efficiency. 
for elec_cpx in 200 500 800 
do
	for eff in 0.75 0.8 0.85
	do
		echo $eff
		echo $elec_cpx
		nohup julia run_code.jl $elec_cpx $eff $dir &
	done
done


# nohup julia run_code.jl 200 0.8 $dir &
