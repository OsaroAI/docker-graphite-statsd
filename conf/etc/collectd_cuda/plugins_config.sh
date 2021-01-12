
# The array contents is in format:
#
# ["query_string"]=value_type
#
# One can add more parameters using the list returned
# from 'nvidia-smi --help-query-gpu'. Each dot '.' should
# be replaced with underscore.
declare -A config=(
	["temperature_gpu"]=temperature
	["fan_speed"]=percent
	["pstate"]=absolute
	["memory_used"]=memory
	["memory_free"]=memory
	["utilization_gpu"]=percent
	["utilization_memory"]=percent
	["power_draw"]=power
)
