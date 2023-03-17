#!/bin/bash

# For example: 
# sh ssh-carrier.sh key ow issuer APT 18.191.254.192
# sh ssh-carrier.sh key ow acquirer SB 3.145.67.126
# sh ssh-carrier.sh key ccps0 issuer APT 18.191.254.192
# sh ssh-carrier.sh key ccps0 acquirer SB 3.145.67.126

key=$1
ow_or_ccps0=$2
issuer_or_acquirer=$3
carrier_name=$4
carrier_bastion_ip=$5

port_json="port.json"

get_port_ip() {
  ow_or_ccps0=$1
  issuer_or_acquirer=$2

  if [[ "$ow_or_ccps0" = "ow" ]]; then
    local_port=$(cat "$port_json" | jq -r ".$issuer_or_acquirer[].ow_port")
    remote_port="9200"
    ip="10.8.8.70"

  elif [[ "$ow_or_ccps0" = "ccps0" ]]; then
    local_port=$(cat "$port_json" | jq -r ".$issuer_or_acquirer[].ccps0_port")
    remote_port="4568"
    ip="10.8.8.50"
  fi

  echo $local_port $remote_port $ip
}


if [[ "$issuer_or_acquirer" = "issuer" ]]; then
  echo $(jq '(.issuer[].carrier) |= "'$carrier_name'"' $port_json) > $port_json
elif [[ "$issuer_or_acquirer" = "acquirer" ]]; then
  echo $(jq '(.acquirer[].carrier) |= "'$carrier_name'"' $port_json) > $port_json
fi

read -r local_port remote_port ip <<< $(get_port_ip $ow_or_ccps0 $issuer_or_acquirer)

echo "$ow_or_ccps0-ip is [$ip], $ow_or_ccps0-$carrier_name port (local_port is [$local_port], remote_port is [$remote_port])"

ssh -i ~/.ssh/$1.pem -L $local_port:localhost:$remote_port -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -i ~/.ssh/$key.pem  -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$carrier_bastion_ip  -W %h:%p" ubuntu@$ip
