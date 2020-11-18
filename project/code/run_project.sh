# Get into the relevant directory
cd /Users/tombearpark/Documents/princeton/1st_year/MAE529/MAE529_code/project/code

# Electr capex is first arg. Second arg is H2 efficiency. Loop over the jobs
# Sending them all out at once 
for elec_cpx in 200 400 600 800 
do
	for eff in 0.75 0.8 0.85
	do
		echo $eff
		echo $elec_cpx
		nohup julia draft_code.jl $elec_cpx $eff &
	done
done
