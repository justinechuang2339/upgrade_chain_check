#!/bin/bash

# For example: 
# sh ssh-TC.sh ow qa210s 3.15.189.255
# $1 is chain name ex: qa210s
# $2 is TC-bastion-IP ex: 3.15.189.255

if [[ "$1" = "ow" ]]; then
	ssh -L 9203:localhost:9200 -i ~/.ssh/id_rsa -i /tmp/signed-cert-$2-tc.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -i ~/.ssh/id_rsa -i /tmp/signed-cert-$2-tc.pem  -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$3 -W %h:%p" ubuntu@10.8.14.20
	# 10.8.14.20 is TC overwatch IP
else
	echo "now this script is only for overwatch, you can write it by yourself"
fi