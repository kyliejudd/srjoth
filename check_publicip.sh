#!/bin/bash
# script to check if docker containers are sending traffic via vpn 
# assumes the container has curl installed

cd /mnt/local/docker/pirate


# check the public ip of the host (assumed not on vpn)
MyIp=$(curl -s ifconfig.me)


declare -a ContainerArray=("vpn" "transmission" "radarr" "sonarr" "jackett")


# Iterate over each container to see the public ip they are using
# if the ip matches we assume the vpn container is down and stop all containers in the compose file 
for val in ${ContainerArray[@]}; do
	containerIp=$(docker-compose exec $val curl ifconfig.me)
	echo '---------------------------'
	echo "container IP: $containerIp"
	echo "home IP: $MyIp"
	if [ "$containerIp" = "$MyIp" ]; then
		echo "vpn not working for $val, killing stack"
		docker-compose stop
		exit 1
	else
		echo "vpn working for $val"
	fi
	echo ' '
done

docker-compose ps

