#!/bin/bash

# For example: 
# sh ./ssh-carrier.sh key ow APT 18.191.254.192
# sh ./ssh-carrier.sh key ow SB 3.145.67.126
# sh ./ssh-carrier.sh key ccps0 APT 18.191.254.192
# sh ./ssh-carrier.sh key ccps0 SB 3.145.67.126


# $1 is key
# $2 is ow or ccps0 (ow means overwatch)
# $3 is APT or SB
# $4 is carrier-bastion-IP ex: 18.191.254.192

get_port_ip() {
  if [[ "$1" = "ow" ]]; then

    if [[ "$2" = "APT" ]]; then
      local_port="9201"
    elif [[ "$2" = "SB" ]]; then
      local_port="9202"
    fi
    remote_port="9200"
    ip="10.8.8.70"

  elif [[ "$1" = "ccps0" ]]; then

    if [[ "$2" = "APT" ]]; then
      local_port="8888"
    elif [[ "$2" = "SB" ]]; then
      local_port="4568"
    fi
    remote_port="4568"
    ip="10.8.8.50"

  fi
  echo $local_port $remote_port $ip
}

read -r local_port remote_port ip <<< $(get_port_ip $2 $3)

echo "$2-ip is [$ip], $2-$3 port (local_port is [$local_port], remote_port is [$remote_port])"

ssh -i ~/.ssh/$1.pem -L $local_port:localhost:$remote_port -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -i ~/.ssh/$1.pem  -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$4  -W %h:%p" ubuntu@$ip
