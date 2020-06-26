# srjoth (sir joth??)
sonarr, radarr, jackett, openvpn, transmission & haproxy

## what?

1. Creates an Openvpn container to act as a gateway for services.
2. all containers connect to the network created by the openvpn container.
3. web interfaces are available via reverse proxy (haproxy) 

## How?

running `docker-compose up -d`

checkout status `docker-compose ps`

```
        Name                       Command                       State                  Ports        
-----------------------------------------------------------------------------------------------------
srjoth_jackett_1        /init                            Up                                          
srjoth_radarr_1         /init                            Up                                          
srjoth_sonarr_1         /init                            Up                                          
srjoth_transmission_1   /init                            Up                                          
srjoth_vpn_1            /sbin/tini -- /usr/bin/ope ...   Up (health: starting)                       
srjoth_web_1            /docker-entrypoint.sh hapr ...   Up                      0.0.0.0:443->443/tcp
```

uses [dperson openvpn](https://github.com/dperson/openvpn-client) to create container to route container traffic.
radarr, sonarr, jackett and transmission are only available via the vpn network. 
Haproxy is connected to both the host via the bridge network, and the vpn network created by the openvpn container (via links)

This means that interaction between containers goes out the vpn and back in to the reverse proxy. e.g. setting up transmission as a client in sonarr. 

### haproxy (reverse proxy)

#### certs 

I use 1 cert per dns entry instead of a wildcard, I use letsencrypt so it doesn't cost anymore, and I automate the renewal.
In the haproxy config in this repo, haproxy checks a directory for ssl certs so I can just dump as many certs as needed in there. 


##### bring your own ssl cert and key. 
to create a file for haproxy to use 

`cat fullchain.pem privkey.pem > example.pem`  

and update the docker-compose file section to reflect your cert location.
 
```yaml
web
  volumes:
    - /etc/ssl/private:/etc/ssl/private/:ro
```


##### aws hosted with helper script

ssl is provided by letsencrypt and requires 

* certbot 
* route53 certbot plugin
* an aws route53 hosted dns 
* an aws credential file

[certbot](https://certbot.eff.org/)
[info on the route53 plugin](https://certbot-dns-route53.readthedocs.io/en/stable/)

assuming ubuntu 18.04   
```bash
sudo apt-get install software-properties-common
sudo add-apt-repository universe
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install certbot python3-certbot-dns-route53
```

Run helper script on the docker host

`./cert_renewal.sh example.com webadmin@example.com` 

this will iterate over a list of names and create a cert for each one. 
you should see this output for each cert. 

```
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Credentials found in config file: ~/.aws/config
Plugins selected: Authenticator dns-route53, Installer None
Obtaining a new certificate
Performing the following challenges:
dns-01 challenge for sonarr.example.com
Waiting 10 seconds for DNS changes to propagate
`Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/sonarr.example.com/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/sonarr.example.com/privkey.pem
   Your cert will expire on 2020-09-21. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot
   again. To non-interactively renew *all* of your certificates, run
   "certbot renew"
 - If you like Certbot, please
```

once this runs the cert + key will be concatenated into single file and placed into /etc/ssl/private
then this folder can be mounted into haproxy.

you can also run this again in 3 months time or put it in a cron, this will renew your certs with letsencrypt and restart haproxy.


#### backends 

sonarr, radarr, jackett and transmission are setup as backends, they are contacted over http via their docker service name.
We direct the traffic to certain backends based on SNI. 

update the `haproxy/haproxy.cfg` to reflect your domains 

```
    use_backend sonarr if { ssl_fc_sni sonarr.example.com } # content switching based on SNI
    use_backend radarr if { ssl_fc_sni radarr.example.com } # content switching based on SNI
    use_backend jackett if { ssl_fc_sni jackett.example.com } # content switching based on SNI
    use_backend transmission if { ssl_fc_sni transmission.example.com } # content switching based on SNI
```

### jackett, radarr, sonarr 

head over to the web gui and configure a username and password for the UI. Otherwise configure via environment variable files.

more info over at:  
[jackett](https://hub.docker.com/r/linuxserver/jackett/)
[sonarr](https://hub.docker.com/r/linuxserver/sonarr/)
[radarr](https://hub.docker.com/r/linuxserver/radarr/)

Once you have configured jackett indexers you will notice that your torzbab links are the front end of your webproxy  
`https://jackett.example.com/api/v2.0/indexers/1337x/results/torznab/`

so radarr and sonarr will connect to jackett via haproxy.

this is the same for setting the torrent client. use https://transmission.example.com

### transmission


I've been lazy in this example and put USER and PASS in the compose file Otherwise configure via environment variable files.

more info over at:  
[transmission](https://hub.docker.com/r/linuxserver/transmission/)


### openvpn 

more info over at:
[dperson/openvpn](https://github.com/dperson/openvpn-client)

you will need to create an openvpn config file with your vpn provider 

vpn providers i've tried that support this:  
[nordvpn](https://go.nordvpn.net/aff_c?offer_id=15&aff_id=25061&url_id=902)
[airvpn](https://airvpn.info/?referred_by=292660)

maybe put this in a cron on the docker host

`check_publicip.sh`  

this checks for the public ip that your docker host appears from.  
Then does the same check in each container, in theory all containers should appear as the vpn public ip.
if the ip addresses match the we assume the vpn is down and kill the containers. (this could be true if your docker host was also connected to the same vpn endpoint)
