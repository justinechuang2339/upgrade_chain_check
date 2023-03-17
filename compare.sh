#!/bin/bash

# use this file in local
# For Example: sh ./compare.sh 15
# $1 is last x minus ex : 15

start_color="\033[44;37m"
end_color="\033[0m"
error_start_color="\033[0;31m"
good_start_color="\033[0;32m"

compare_json_carrier_tc() { # "APT" "auditlogs_summary_list_" ".hits.total.value" "Audit - auditlogs - Summary List"
  carrier_value=$(cat "$1/$2$1.json" | jq -r $3)
  TC_carrier_value=$(cat "TC/$2$1.json" | jq -r $3)

  msg="$4 [${start_color}$1${end_color}] $1: ${start_color}$carrier_value${end_color}, TC/$1: ${start_color}$TC_carrier_value${end_color}"

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

display_txt_in_carrier() { # "APT" "debug_error_applogs_Summary_List_" "Debug level: error Table"
  echo "$3 at [${start_color}$1${end_color}]"
  folder_path="$(pwd)"
  every_txt_file_with_path=$(find "$folder_path/$1/" -name "$2*" -name '*.txt') #find $1 folder "debug_error_applogs_Summary_List_*" "*.txt"
  for one_txt_file_with_path in $every_txt_file_with_path; do
    echo "$(cat $one_txt_file_with_path)\n"
  done
}

remove_folder() {
  mydir="$(pwd)/$1"
  rm -rf $mydir
}

# echo "Remove file APT, AB and TC, if they already exist..."
# remove_folder "APT"
# remove_folder "SB"
# remove_folder "TC"

# # Running Sanity test
# sh ./run_sanity_test.sh

# echo "Please wait for getting Overwatch Kibana API..."

# x_minutes=$1
# cur_time=$(date --date "now" +"%Y-%m-%dT%T.%3NZ" -u) # -u means display in UTC time zone (output will become 2023-03-01T01:36:33.160Z)
# cur_time_minus_x_minutes=$(date --date "now - $x_minutes minutes" +"%Y-%m-%dT%T.%3NZ" -u)
# echo "Date and Time Range: Default Last $x_minutes minutes ${start_color}($cur_time_minus_x_minutes ~ $cur_time)${end_color}"

# # $1 is time ex: 15
# echo "GET TC api and create TC folder..."
# sh ./get_OW_value.sh TC APT $1 > /dev/null 2>&1
# sh ./get_OW_value.sh TC SB $1 > /dev/null 2>&1

# echo "GET APT api and create APT folder..."
# sh ./get_OW_value.sh CARRIER APT $1 > /dev/null 2>&1

# echo "GET SB api and create SB folder..."
# sh ./get_OW_value.sh CARRIER SB $1 > /dev/null 2>&1

# echo "Compare CARRIER and TC..."
for carrier in "APT" "SB"
do
  echo "${start_color}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++$carrier++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++${end_color}\n"
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