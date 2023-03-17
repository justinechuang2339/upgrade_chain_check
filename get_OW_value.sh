#!/bin/bash

# use this file in local
# For Example: sh get_OW_value.sh CARRIER issuer 15
# $1 is CARRIER_or_TC ex: CARRIER
# $2 is issuer_or_acquirer ex : issuer
# $3 is last x minus ex : 15

start_color="\033[44;37m"
error_start_color="\033[0;31m"
end_color="\033[0m"

port_json="port.json"

CARRIER_or_TC=$1
issuer_or_acquirer=$2
carrier_name=$(cat "$port_json" | jq -r ".$issuer_or_acquirer[].carrier")
x_minutes=$3

echo "carrier_name $carrier_name"

cur_time=$(date --date "now" +"%Y-%m-%dT%T.%3NZ" -u) # -u means display in UTC time zone (output will become 2023-03-01T01:36:33.160Z)
cur_time_minus_x_minutes=$(date --date "now - $x_minutes minutes" +"%Y-%m-%dT%T.%3NZ" -u)
echo "Date and Time Range: Default Last $x_minutes minutes ${start_color}($cur_time_minus_x_minutes ~ $cur_time)${end_color}"

auditlogs_Summary_List_json="auditlogs_Summary_List_$carrier_name.json"
debug_error_applogs_Summary_List_json="debug_error_applogs_Summary_List_$carrier_name.json"
debug_applogs_Summary_List_event_handler_json="debug_applogs_Summary_List_event_handler_$carrier_name.json"
ola_summary_ow_core_Blockchain_Transactions_json="ola_summary_ow_core_Blockchain_Transactions_$carrier_name.json"
ola_summary_ow_core_BSS_Latency_json="ola_summary_ow_core_BSS_Latency_$carrier_name.json"
ola_summary_ow_core_User_Pay_Latency_json="ola_summary_ow_core_User_Pay_Latency_$carrier_name.json"
jobmodels_data_list_json="jobmodels_data_list_$carrier_name.json"

kibana_api_path="$(pwd)/kibana_api_request_json_file"

get_port() {
  CARRIER_or_TC=$1
  carrier_name=$2
  if [ "$CARRIER_or_TC" = "CARRIER" ]
  then
    echo $(cat "$port_json" | jq -r ".$issuer_or_acquirer[].ow_port")
  elif [ "$CARRIER_or_TC" = "TC" ]
  then
    echo $(cat "$port_json" | jq -r ".TC[].ow_port")
  fi
}

mkfile() { #$CARRIER_or_TC $carrier_name $auditlogs_summary_list_json
  if [ "$1" = "CARRIER" ]
  then
    mkdir -p $2
    echo "$(pwd)/$2/$3"
  elif [ "$1" = "TC" ]
  then
    mkdir -p "TC"
    echo "$(pwd)/TC/$3"
  fi
}

relative_file_path() { #$CARRIER_or_TC $carrier_name $file_name 
  CARRIER_or_TC=$1
  carrier_name=$2
  file_name=$3

  if [ "$CARRIER_or_TC" = "CARRIER" ]
  then
    file="$carrier_name/$file_name"
  elif [ "$CARRIER_or_TC" = "TC" ]
  then
    file="TC/$file_name"
  fi
  echo $file
}

absolute_file_path() { #$CARRIER_or_TC $carrier_name $file_name
  CARRIER_or_TC=$1
  carrier_name=$2
  file_name=$3

  echo "$(pwd)/$(relative_file_path $CARRIER_or_TC $carrier_name $file_name)"
}

curl_kibana_api() { # "overwatch-applogs-*/_search" "$kibana_api_path/debug_event_group_handler.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $auditlogs_summary_list_json
  subdirectory=$1
  CARRIER_or_TC=$3
  issuer_or_acquirer=$4
  carrier_name=$(cat "$port_json" | jq -r ".$issuer_or_acquirer[].carrier")
  cur_time_minus_x_minutes=$5
  cur_time=$6
  output_json=$7

  echo "$cur_time_minus_x_minutes $cur_time"
  
  if [ "$CARRIER_or_TC" = "CARRIER" ] 
  then
    kibana_api_require_json=$(cat "$2" | jq '(.query.bool.filter[] | select(.range) | .range."@timestamp".gte) |= "'$cur_time_minus_x_minutes'" | (.query.bool.filter[] | select(.range) | .range."@timestamp".lte) |= "'$cur_time'"')
  elif  [ "$CARRIER_or_TC" = "TC" ] 
  then
    
    kibana_api_require_json=$(cat "$2" | jq '(.query.bool.filter[] | select(.range) | .range."@timestamp".gte) |= "'$cur_time_minus_x_minutes'" | 
      (.query.bool.filter[] | select(.range) | .range."@timestamp".lte) |= "'$cur_time'" | 
      .query.bool.filter += [{
        "match_phrase": {
          "tbca_metadata.env.siteSrc.keyword": "'$carrier_name'"
        }
      }]' )
    
  fi

  port=$(get_port $CARRIER_or_TC $carrier_name)
  echo "port $port"
  echo "$carrier_name"
  echo "$(pwd)/$carrier_name/$output_json"
  curl -X GET "localhost:$port/$subdirectory" -H 'Content-Type: application/json' -d "$kibana_api_require_json" > $(mkfile $CARRIER_or_TC $carrier_name $output_json)
  echo "$(mkfile $CARRIER_or_TC $carrier_name $output_json)"
}

# Data Table - (jobmodels -> jobmodels_rlid.txt, debug_error -> debug_error_xxx.txt)
store_table_txt() { # $CARRIER_or_TC $carrier_name $jobmodels_data_list_json "Job Models - jobmodels - Data List" "jobmodels_data_list"

  repeatChar() {
      local input="$1"
      local count="$2"
      printf -v myString '%*s' "$count"
      printf '%s\n' "${myString// /$input}"
  }

  value_empty_to_dash() {
    if [ -z "$1" ]
    then
      echo "-"
    fi
    echo $1
  }

  if [ "$1" = "CARRIER" ]
  then
    folder_path="$(pwd)/$2"
  elif [ "$1" = "TC" ]
  then
    folder_path="$(pwd)/TC"
  fi

  value=$(cat "$folder_path/$3" | jq -r '.hits.hits[].fields')

  if [ -z "$value" ]
  then
    echo "there is ${start_color}0${end_color} data in $4, so $5{rlId}_$2.txt will not be created."
  else
    format="%-20s %-20s %-20s %-20s\n"
    if [ "$5" = "jobmodels_data_list" ]
    then
      type=($(jq -r '.hits.hits[].fields.type[]' "$folder_path/$3")) # I want to write dictionary list or 2D array, but it seems bash script can't not use them
      sourceTelcoId=($(jq -r ".hits.hits[].fields.sourceTelcoId[]" "$folder_path/$3"))
      targetCarrierId=($(jq -r ".hits.hits[].fields.targetCarrierId[]" "$folder_path/$3"))
      status=($(jq -r ".hits.hits[].fields.status[]" "$folder_path/$3"))
      rlId=($(jq -r ".hits.hits[].fields.rlId[]" "$folder_path/$3"))
      for ((i=0;i<${#type[@]};i++)); do
        if [ ! -z ${rlId[i]} ]
        then
          if [ ! -f "$(absolute_file_path $1 $2 "$5_${rlId[i]}_$2.txt")" ]
          then
            printf "%s\n" "RLID : ${rlId[i]}" >> $(mkfile $1 $2 "$5_${rlId[i]}_$2.txt")
            printf "$format" type sourceTelcoId targetCarrierId status >> $(mkfile $1 $2 "$5_${rlId[i]}_$2.txt")
            printf "%s\n" "$(repeatChar - 100)" >> $(mkfile $1 $2 "$5_${rlId[i]}_$2.txt")
          fi
          printf "$format" ${type[i]} ${sourceTelcoId[i]} ${targetCarrierId[i]} ${status[i]} >> $(mkfile $1 $2 "$5_${rlId[i]}_$2.txt")
        fi
      done
      
      txt_file=$(find "$folder_path/" -name '*.txt' -name "$5*")
      echo "\n\n${start_color}$(repeatChar - 25) $4 $(repeatChar - 25)${end_color}\n"
      for file in $txt_file; do
        [ -f "$file" ] || continue
        one_txt_file=$file
        one_txt_file=${one_txt_file/"$folder_path"/}
        one_txt_file=${one_txt_file///}
        echo "(details see $2/$one_txt_file)"
        echo "$(cat $file)"
        echo "\n\n$(repeatChar + 100)"
      done
    elif [ "$5" = "debug_error_applogs_Summary_List" ]
    then
      format="%-30s %-20s %-40s %-40s %-40s %-20s %-20s %-20s\n"
      timestamp=($(jq -r '.hits.hits[].fields."@timestamp"[]' "$folder_path/$3")) # I want to write dictionary list or 2D array, but it seems bash script can't not use them
      service=($(jq -r ".hits.hits[].fields.service[]" "$folder_path/$3"))
      rlId=($(jq -r ".hits.hits[].fields.rlId[]" "$folder_path/$3"))
      jId=($(jq -r ".hits.hits[].fields.jId[]" "$folder_path/$3"))
      requestURI=($(jq -r '.hits.hits[].fields."req.requestURI"[]' "$folder_path/$3"))
      method=($(jq -r '.hits.hits[].fields."req.method"[]' "$folder_path/$3"))
      HOSTNAME=($(jq -r ".hits.hits[].fields.HOSTNAME[]" "$folder_path/$3"))
      level=($(jq -r ".hits.hits[].fields.level[]" "$folder_path/$3"))
      message=($(jq -r '.hits.hits[].fields.message' "$folder_path/$3"))

      mi=0
      for ((i=0;i<${#timestamp[@]};i++)); do
        if [ ! -z ${timestamp[i]} ]
        then
          printf "%s\n" "$(repeatChar + 230)" >> $(mkfile $1 $2 "$5_$2.txt")
          printf "$format" @timestamp service rlId jId .req.requestURI .req.method HOSTNAME level >> $(mkfile $1 $2 "$5_$2.txt")
          printf "%s\n" "$(repeatChar - 230)" >> $(mkfile $1 $2 "$5_$2.txt")

          t=$(value_empty_to_dash ${timestamp[i]})
          s=$(value_empty_to_dash ${service[i]})
          rl=$(value_empty_to_dash ${rlId[i]})
          j=$(value_empty_to_dash ${jId[i]})
          r=$(value_empty_to_dash ${requestURI[i]})
          m=$(value_empty_to_dash ${method[i]})
          h=$(value_empty_to_dash ${HOSTNAME[i]})
          l=$(value_empty_to_dash ${level[i]})

          printf "$format" $t $s $rl $j $r $m $h $l >> $(mkfile $1 $2 "$5_$2.txt")
          
          single_meassage=""
          for ((j=$mi;j<${#message[@]};j++)); do
            if [ ${message[$j]} = ']' ]
            then
              mi=$j+1
              break
            elif [ ${message[$j]} = '[' ]
            then
              true
            else
              single_meassage="${single_meassage} ${message[$j]}"
            fi
          done
          printf "%s\n\n\n" "message: $single_meassage" >> $(mkfile $1 $2 "$5_$2.txt")
        fi
      done
      
      txt_file=$(find "$folder_path/" -name '*.txt' -name "$5*")
      echo "\n\n${start_color}$(repeatChar - 25) $4 $(repeatChar - 25)${end_color}\n"
      for file in $txt_file; do
        [ -f "$file" ] || continue
        one_txt_file=$file
        one_txt_file=${one_txt_file/"$folder_path"/}
        one_txt_file=${one_txt_file///}
        echo "(details see $2/$one_txt_file)"
        echo "$(cat $file)"
        echo "\n\n${start_color}$(repeatChar - 100)${end_color}"
      done
    elif [ "$5" = "debug_applogs_Summary_List_event_handler" ]
    then
      format="%-30s %-20s %-40s %-40s %-40s %-20s %-20s %-20s\n"
      timestamp=($(jq -r '.hits.hits[].fields."@timestamp"[]' "$folder_path/$3")) # I want to write dictionary list or 2D array, but it seems bash script can't not use them
      service=($(jq -r ".hits.hits[].fields.service[]" "$folder_path/$3"))
      rlId=($(jq -r ".hits.hits[].fields.rlId[]" "$folder_path/$3"))
      jId=($(jq -r ".hits.hits[].fields.jId[]" "$folder_path/$3"))
      HOSTNAME=($(jq -r ".hits.hits[].fields.HOSTNAME[]" "$folder_path/$3"))
      level=($(jq -r ".hits.hits[].fields.level[]" "$folder_path/$3"))
      message=($(jq -r '.hits.hits[].fields.message' "$folder_path/$3"))
      logger_name=($(jq -r '.hits.hits[].fields.logger_name[]' "$folder_path/$3"))

      mi=0
      for ((i=0;i<${#timestamp[@]};i++)); do
        if [ ! -z ${timestamp[i]} ]
        then
          printf "%s\n" "$(repeatChar + 230)" >> $(mkfile $1 $2 "$5_$2.txt")
          printf "$format" @timestamp service rlId jId HOSTNAME level logger_name >> $(mkfile $1 $2 "$5_$2.txt")
          printf "%s\n" "$(repeatChar - 230)" >> $(mkfile $1 $2 "$5_$2.txt")

          t=$(value_empty_to_dash ${timestamp[i]})
          s=$(value_empty_to_dash ${service[i]})
          rl=$(value_empty_to_dash ${rlId[i]})
          j=$(value_empty_to_dash ${jId[i]})
          h=$(value_empty_to_dash ${HOSTNAME[i]})
          l=$(value_empty_to_dash ${level[i]})
          log=$(value_empty_to_dash ${logger_name[i]})

          printf "$format" $t $s $rl $j $h $l $log >> $(mkfile $1 $2 "$5_$2.txt")
          
          single_meassage=""
          for ((j=$mi;j<${#message[@]};j++)); do
            if [ ${message[$j]} = ']' ]
            then
              mi=$j+1
              break
            elif [ ${message[$j]} = '[' ]
            then
              true
            else
              single_meassage="${single_meassage} ${message[$j]}"
            fi
          done
          printf "%s\n\n" "message: $single_meassage" >> $(mkfile $1 $2 "$5_$2.txt")
        fi
      done
      
      txt_file=$(find "$folder_path/" -name '*.txt' -name "$5*")
      echo "\n\n${start_color}$(repeatChar - 25) $4 $(repeatChar - 25)${end_color}\n"
      for file in $txt_file; do
        [ -f "$file" ] || continue
        one_txt_file=$file
        one_txt_file=${one_txt_file/"$folder_path"/}
        one_txt_file=${one_txt_file///}
        echo "(details see $2/$one_txt_file)"
        echo "$(cat $file)"
        echo "\n\n${start_color}$(repeatChar - 100)${end_color}"
      done
    fi
  fi
}

check_if_value_in_json() { #$CARRIER_or_TC $carrier_name $auditlogs_summary_list_json ".hits.total.value" "Audit - auditlogs - Summary List"
  CARRIER_or_TC=$1
  carrier_name=$2
  file_name=$3
  jq_filter=$4
  msg=$5

  absolute_file_dir=$(absolute_file_path $CARRIER_or_TC $carrier_name $file_name)
  relative_file_dir=$(relative_file_path $CARRIER_or_TC $carrier_name $file_name)

  if [ -f $absolute_file_dir ] 
  then 
    value=$(cat $absolute_file_dir | jq -r $jq_filter)
    echo "$msg ${start_color}$value${end_color} (details see ${start_color}$relative_file_dir${end_color})"
  else echo "${error_start_color}$msg (there is no file $relative_file_dir)${end_color}"
  fi
}

curl_kibana_api "overwatch-auditlogs-*/_search" "$kibana_api_path/auditlogs_Summary_List.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $auditlogs_Summary_List_json
curl_kibana_api "overwatch-applogs-*/_search" "$kibana_api_path/debug_error_applogs_Summary_List.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $debug_error_applogs_Summary_List_json
curl_kibana_api "overwatch-core-*/_search" "$kibana_api_path/ola_summary_ow_core_Blockchain_Transactions.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $ola_summary_ow_core_Blockchain_Transactions_json
curl_kibana_api "overwatch-core-*/_search" "$kibana_api_path/ola_summary_ow_core_BSS_Latency.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $ola_summary_ow_core_BSS_Latency_json
curl_kibana_api "overwatch-core-*/_search" "$kibana_api_path/ola_summary_ow_core_User_Pay_Latency.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $ola_summary_ow_core_User_Pay_Latency_json
curl_kibana_api "overwatch-jobmodels-*/_search" "$kibana_api_path/jobmodels_data_list.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $jobmodels_data_list_json
curl_kibana_api "overwatch-applogs-*/_search" "$kibana_api_path/debug_applogs_Summary_List_event_handler.json" $CARRIER_or_TC $issuer_or_acquirer $cur_time_minus_x_minutes $cur_time $debug_applogs_Summary_List_event_handler_json

check_if_value_in_json $CARRIER_or_TC $carrier_name $auditlogs_Summary_List_json ".hits.total.value" "Audit - auditlogs - Summary List"
check_if_value_in_json $CARRIER_or_TC $carrier_name $debug_error_applogs_Summary_List_json ".hits.total.value" "Debug check level : error - applogs - Summary List"
check_if_value_in_json $CARRIER_or_TC $carrier_name $ola_summary_ow_core_Blockchain_Transactions_json ".hits.total.value" "OLA Summary - ow_core - Blockchain Transactions"
check_if_value_in_json $CARRIER_or_TC $carrier_name $ola_summary_ow_core_BSS_Latency_json '.aggregations."1".value' "OLA Summary - ow_core - BSS Latency (ms)"
check_if_value_in_json $CARRIER_or_TC $carrier_name $ola_summary_ow_core_User_Pay_Latency_json '.aggregations."1".value' "OLA Summary - ow_core - User Pay Latency"
check_if_value_in_json $CARRIER_or_TC $carrier_name $jobmodels_data_list_json '.hits.total.value' "Job Models - jobmodels - Data List"
check_if_value_in_json $CARRIER_or_TC $carrier_name $debug_applogs_Summary_List_event_handler_json '.hits.total.value' "Debug check level : event_handler"

store_table_txt $CARRIER_or_TC $carrier_name $jobmodels_data_list_json "Job Models - jobmodels - Data List" "jobmodels_data_list"
store_table_txt $CARRIER_or_TC $carrier_name $debug_error_applogs_Summary_List_json "Debug check level : error - applogs - Summary List" "debug_error_applogs_Summary_List"
store_table_txt $CARRIER_or_TC $carrier_name $debug_applogs_Summary_List_event_handler_json "Debug check level : event_handler" "debug_applogs_Summary_List_event_handler"

