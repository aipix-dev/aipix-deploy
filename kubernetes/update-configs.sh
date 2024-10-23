#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"
## Begining of the functions definitions

# Reads the file and gather all enviroments variables
get_env_dict_from_file () {
	file=$1
	declare -A dict
	dict=()
	for line in $(cat ${file} | sed -e 's/ *= */=/g'); do
		set "${line}"
 		for word in "$@"; do
			if [[ $(echo $word | grep "=") ]]; then
				IFS='=' read -r key val <<< "$word"
				if [[ -n "${val}" ]]; then
					key=$(echo $key | sed -e 's/#//g')
					dict["${key}"]="${val}"
				else
					key=$(echo $key | sed -e 's/#//g')
					dict["${key}"]=""
				fi
			fi
		done
	done
	echo '('
	for key in "${!dict[@]}"; do echo "['$key']='${dict[$key]}'"; done
	echo ')'
}


# Checks if element "$1" is in array "$2"
# @NOTE:
#   Be sure that array is passed in the form:
#       "${ARR[@]}"
elementIn () {
    # shopt -s nocasematch # Can be useful to disable case-matching
    local e
    for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
    return 1
}

# Update config file from new sample file
print_new_config_lines () {
	current_file=$1
	sample_file=$2
	declare -A current="$(get_env_dict_from_file $current_file)"
	declare -A sample="$(get_env_dict_from_file $sample_file)"
	#for key in ${!current[@]}; do echo $key "${current["$key"]}"; done
	for key in "${!sample[@]}"; do
		declare -A new_elements
		if elementIn $key ${!current[@]}
		then continue
		else new_elements["$key"]="${sample[$key]}"
		fi
	done
	if [[ ${#new_elements[@]} > 0 ]]; then
		echo "" >> $current_file;
		echo "### New ${#new_elements[@]} line(s) are added by script at $(date +%d-%m-%Y)" >> $current_file
		#echo "### New ${#new_elements[@]} line(s) are added by script at $(date +%d-%m-%Y)"
	fi
	for key in "${!new_elements[@]}"; do cat $sample_file | grep -w $key >> $current_file; done
	#for key in "${!new_elements[@]}"; do cat $sample_file | grep $key ; done
}


## End of the functions definitions

if [ -f ./sources.sh ]; then print_new_config_lines ./sources.sh ./sources.sh.sample; fi
if [ -f ./k8s-onprem/sources.sh ]; then print_new_config_lines ./k8s-onprem/sources.sh ./k8s-onprem/sources.sh.sample; fi
if [ -f ../vms-backend/environments/.env ]; then print_new_config_lines ../vms-backend/environments/.env ../vms-backend/environments/env.sample; fi
if [ -f ../controller/environments/.env ]; then print_new_config_lines ../controller/environments/.env ../controller/environments/env.sample; fi
if [ -f ../portal/environments/.env ]; then print_new_config_lines ../portal/environments/.env ../portal/environments/env.sample; fi
if [ -f ../portal/environments-stub/.env ]; then print_new_config_lines ../portal/environments-stub/.env ../portal/environments-stub/env.sample; fi
if [ -f ../analytics/.env ]; then print_new_config_lines ../analytics/.env ../analytics/env.sample; fi
if [ -f ../analytics/analytics-worker.conf ]; then print_new_config_lines ../analytics/analytics-worker.conf ../analytics/analytics-worker.conf.sample; fi
if [ -f ../analytics/metrics-pusher.env ]; then print_new_config_lines ../analytics/metrics-pusher.env ../analytics/metrics-pusher.env.sample; fi

echo """

Configurations script is finished successfuly!

"""