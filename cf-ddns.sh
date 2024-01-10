#!/usr/bin/env bash
set -o errexit
set -o nounset

# Automatically update your CloudFlare DNS record to the IP, Dynamic DNS
# Can retrieve cloudflare Domain id and list zone's, because, lazy

# Place at:
# mv cf-ddns.sh /usr/local/bin/cf-ddns.sh && chmod +x /usr/local/bin/cf-ddns.sh
# run `crontab -e` and add next line:
# */1 * * * * /usr/local/bin/cf-ddns.sh >/dev/null 2>&1
# or you need log:
# */1 * * * * /usr/local/bin/cf-ddns.sh >> /var/log/cf-ddns.log 2>&1


# Usage:
# cf-ddns.sh -k cloudflare-api-key \
#            -u user@example.com \
#            -h host.example.com \     # fqdn of the record you want to update
#            -z example.com \          # will show you all zones if forgot, but you need this
#            -t A|AAAA|All                 # specify ipv4/ipv6/All, default: All

# default config

# API key, see https://www.cloudflare.com/a/account/my-account,
# incorrect api-key results in E_UNAUTH error
CFKEY=

# Username, eg: user@example.com
CFUSER=

# Zone name, eg: example.com
CFZONE_NAME=

# Hostname to update, eg: ddns.example.com
CFRECORD_NAME=

# Record type, A(IPv4)|AAAA(IPv6)|All(IPv4+IPv6), default All
CFRECORD_TYPE=All

# If required settings are missing just exit
if [ "$CFKEY" = "" ]; then
  echo "Missing api-key, get at: https://www.cloudflare.com/a/account/my-account"
  echo "and save in ${0} or using the -k flag"
  exit 2
fi
if [ "$CFUSER" = "" ]; then
  echo "Missing username, probably your email-address"
  echo "and save in ${0} or using the -u flag"
  exit 2
fi
if [ "$CFRECORD_NAME" = "" ]; then 
  echo "Missing hostname, eg: ddns.example.com"
  echo "save in ${0} or using the -h flag"
  exit 2
fi

if [ "$CFZONE_NAME" = "" ]; then 
  echo "Missing Zone name, eg: example.com"
  echo "save in ${0} or using the -z flag"
  exit 2
fi
# If the hostname is not a FQDN
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [ -z "${CFRECORD_NAME##*$CFZONE_NAME}" ]; then
  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
  echo " => Hostname is not a FQDN, assuming $CFRECORD_NAME"
fi


# get parameter
while getopts k:u:h:z:t: opts; do
  case ${opts} in
    k) CFKEY=${OPTARG} ;;
    u) CFUSER=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
  esac
done

CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)

getUpdate_V4(){
    WANIP="$(curl -s http://ipv4.icanhazip.com)"
	CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*' | head -1)
	RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
        -H "X-Auth-Email: $CFUSER" \
        -H "X-Auth-Key: $CFKEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WANIP\"}")
    if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
        echo "Updated ipv4 succesfuly!"
        echo $WANIP
	else
        echo 'Something went wrong :('
        echo "Response: $RESPONSE"
    fi		
}

getUpdate_V6(){
	WANIP="$(curl -s http://ipv6.icanhazip.com)"
	CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*' | tail -1)
	RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
        -H "X-Auth-Email: $CFUSER" \
        -H "X-Auth-Key: $CFKEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"AAAA\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WANIP\"}")
    if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
        echo "Updated ipv6 succesfuly!"
        echo $WANIP
	else
        echo 'Something went wrong :('
        echo "Response: $RESPONSE"
    fi		
}

if [ "$CFRECORD_TYPE" = "A" ]; then
	getUpdate_V4
elif [ "$CFRECORD_TYPE" = "AAAA" ]; then
	getUpdate_V6
else
	getUpdate_V4
	sleep 5
	getUpdate_V6
fi
exit 0
