#!/bin/bash
###########
# Create a list of letsencrypt certs.
# assumes you use aws route53 to manage your dns
# requirements: certbot and the certbot route53 plugin
#               aws credentials will be required
#               https://certbot-dns-route53.readthedocs.io/en/stable/
#

## set up variables 
declare -a certArray=( "transmission" "radarr" "sonarr" "jackett" )
domain=$1
email=$2

for cert in ${certArray[@]}; do
	site=${cert}.${domain}
	# create certs and keys 
        certbot certonly   --dns-route53   -d ${site} --agree-tos -m $email
	# check for failures and create a cert + key file for corresponding site. 
	if [ $? -eq 0 ]; then
		echo "completed the renewal of ${site}"
                cat /etc/letsencrypt/live/${site}/fullchain.pem /etc/letsencrypt/live/${site}/privkey.pem > /etc/ssl/private/${site}.pem
	else
		echo "failed to renew ${site}"
		exit 1 
	fi
done

# secure the new files 
chmod 600 /etc/ssl/private/*

# reload haproxy container
docker-compose kill -s HUP web

