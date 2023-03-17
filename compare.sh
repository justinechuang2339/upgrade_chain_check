#!/bin/bash

# use this file in local
# For Example: sh compare.sh 15
# $1 is last x minus ex : 15

start_color="\033[44;37m"
end_color="\033[0m"
error_start_color="\033[0;31m"
good_start_color="\033[0;32m"
x_minutes=$1

get_issuer_acquirer_carrier_name() {
  issuer_or_acquirer=$1
  echo $(cat "$port_json" | jq -r ".$issuer_or_acquirer[].carrier")
}

compare_json_carrier_tc() { # "issuer" "auditlogs_summary_list_" ".hits.total.value" "Audit - auditlogs - Summary List"
  issuer_or_acquirer=$1
  carrier_name=$(get_issuer_acquirer_carrier_name $issuer_or_acquirer)

  carrier_value=$(cat "$carrier_name/$2$carrier_name.json" | jq -r $3)
  TC_carrier_value=$(cat "TC/$2$carrier_name.json" | jq -r $3)

  msg="$4 [${start_color}$issuer_or_acquirer${end_color}] $carrier_name: ${start_color}$carrier_value${end_color}, TC/$carrier_name: ${start_color}$TC_carrier_value${end_color}"

  if [ "$carrier_value" == "$TC_carrier_value" ]; then 
    echo "$msg -> ${good_start_color}Match!${end_color}"
  else echo "$msg -> ${error_start_color}Not Match${end_color}"
  fi
}

compare_txt_carrier_tc() { # "APT" "jobmodels_data_list_" "Job Models - jobmodels - Data List"
  folder_path="$(pwd)"
  every_txt_file_with_path=$(find "$folder_path/$1/" -name "$2*" -name '*.txt') #find "jobmodels_data_list_*" "*.txt"
  
  for one_txt_file_with_path in $every_txt_file_with_path; do
    one_txt_file=$one_txt_file_with_path
    one_txt_file=${one_txt_file/"$folder_path"/}
    one_txt_file=${one_txt_file/$1/}
    one_txt_file=${one_txt_file///} 
    file_carrier="$folder_path/$1/$one_txt_file"
    file_tc="$folder_path/TC/$one_txt_file"

    rlid=${one_txt_file/"_$1.txt"/}
    rlid=${rlid/"$2"/}
    echo "\n$3"
    # echo "rlid : ${start_color}[$rlid]${end_color}"
    if cmp -s $file_carrier $file_tc; then
        echo "[check ${start_color}$1${end_color}] $1/$one_txt_file is same as TC/$one_txt_file -> ${good_start_color}Match!${end_color}"
        echo "$(cat $file_carrier)"
    else
        echo "[check ${start_color}$1${end_color}] $1/$one_txt_file is different from TC/$one_txt_file -> ${error_start_color}Not Match${end_color}"

        echo "\n$1/$one_txt_file:"
        echo "$(cat $file_carrier)"

        echo "\nTC/$one_txt_file:"
        echo "$(cat $file_tc)"
    fi
  done
}

display_txt_in_carrier() { # "issuer" "debug_error_applogs_Summary_List_" "Debug level: error Table"
  issuer_or_acquirer=$1
  carrier_name=$(get_issuer_acquirer_carrier_name $issuer_or_acquirer)

  echo "$3 at [${start_color}$issuer_or_acquirer${end_color}] $carrier_name "
  folder_path="$(pwd)"
  every_txt_file_with_path=$(find "$folder_path/$carrier_name/" -name "$2*" -name '*.txt') #find $1 folder "debug_error_applogs_Summary_List_*" "*.txt"
  for one_txt_file_with_path in $every_txt_file_with_path; do
    echo "$(cat $one_txt_file_with_path)\n"
  done
}

remove_folder() {
  carrier_or_tc_name="$1"
  if [ "$carrier_or_tc_name" = "TC" ]
  then
    mydir="$(pwd)/$carrier_or_tc_name"
    rm -rf $mydir
  else
    carrier_name=$(get_issuer_acquirer_carrier_name $carrier_or_tc_name)
    if [ ! -z "$carrier_name" ]
    then
      mydir="$(pwd)/$carrier_name"
      rm -rf $mydir
    else
      echo "Remove $msg, but port.json ${error_start_color}.$carrier_name[].carrier${end_color} is empty -> ${error_start_color}you should set port.json first.${end_color}"
    fi
  fi
}

port_json="port.json"
issuer_acquirer_json="issuer_or_acquirer.json"
issuer_carrier=$(cat "$port_json" | jq -r '.issuer[].carrier')
acquirer_carrier=$(cat "$port_json" | jq -r '.acquirer[].carrier')

echo "Remove folder $issuer_carrier, $acquirer_carrier and TC, if they already exist..."
remove_folder "issuer" 
remove_folder "acquirer" 
remove_folder "TC"


# Running Sanity test
sh run_sanity_test.sh

echo "Please wait for getting Overwatch Kibana API..."

cur_time=$(date --date "now" +"%Y-%m-%dT%T.%3NZ" -u) # -u means display in UTC time zone (output will become 2023-03-01T01:36:33.160Z)
cur_time_minus_x_minutes=$(date --date "now - $x_minutes minutes" +"%Y-%m-%dT%T.%3NZ" -u)
echo "Date and Time Range: Default Last $x_minutes minutes ${start_color}($cur_time_minus_x_minutes ~ $cur_time)${end_color}"

echo "GET TC api and create TC folder..."
sh get_OW_value.sh TC issuer $x_minutes > /dev/null 2>&1
sh get_OW_value.sh TC acquirer $x_minutes > /dev/null 2>&1

echo "GET issuer ($issuer_carrier) api and create issuer ($issuer_carrier) folder..."
sh get_OW_value.sh CARRIER issuer $x_minutes > /dev/null 2>&1

echo "GET acquirer ($acquirer_carrier) api and create acquirer ($acquirer_carrier) folder..."
sh get_OW_value.sh CARRIER acquirer $x_minutes > /dev/null 2>&1

echo "Compare issuer ($issuer_carrier), acquirer ($acquirer_carrier) and TC..."

for carrier in "issuer" "acquirer"
do
  # echo "${start_color}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++$carrier++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++${end_color}\n"
  compare_json_carrier_tc $carrier "auditlogs_Summary_List_" ".hits.total.value" "Audit - Summary List Count - " 
  compare_json_carrier_tc $carrier "ola_summary_ow_core_Blockchain_Transactions_" ".hits.total.value" "OLA Summary - No. of Blockchain Transactions - "
  compare_json_carrier_tc $carrier "ola_summary_ow_core_BSS_Latency_" '.aggregations."1".value' "OLA Summary - BSS Latency (ms) - "
  compare_json_carrier_tc $carrier "ola_summary_ow_core_User_Pay_Latency_" '.aggregations."1".value' "OLA Summary - User Pay Latency (ms) - "

  compare_json_carrier_tc $carrier "jobmodels_data_list_" '.hits.total.value' "Job Models - Data List Count - "
  display_txt_in_carrier $carrier "jobmodels_data_list_" "Job Models - Data List Table"

  compare_json_carrier_tc $carrier "debug_error_applogs_Summary_List_" ".hits.total.value" "Debug level : error - Summary List Count -"
  display_txt_in_carrier $carrier "debug_error_applogs_Summary_List_" "Debug level: error Table"

  compare_json_carrier_tc $carrier "debug_applogs_Summary_List_event_handler_" ".hits.total.value" "Debug - All Event handlers “posted” logs - "
  display_txt_in_carrier $carrier "debug_applogs_Summary_List_event_handler_" "Debug - All Event handlers “posted” logs Table"

  echo "\n"
done