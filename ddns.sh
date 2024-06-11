#!/usr/bin/env bash
set -o errexit
set -o nounset

# Automatically update your CloudFlare DNS record to the IP, Dynamic DNS
# Can retrieve cloudflare Domain id and list zone's, because, lazy

# Place at:
# mv ddns.sh /usr/local/bin/ddns.sh && chmod +x /usr/local/bin/ddns.sh
# run `crontab -e` and add next line:
# */1 * * * * /usr/local/bin/ddns.sh >/dev/null 2>&1
# or you need log:
# */1 * * * * /usr/local/bin/ddns.sh >> /var/log/cf-ddns.log 2>&1


# Usage:
# ddns.sh -k cloudflare-api-key \
#            -u user@example.com \
#            -h host.example.com \     # fqdn of the record you want to update
#            -z example.com \          # will show you all zones if forgot, but you need this
#            -t A|AAAA|Both                 # specify ipv4/ipv6/Both, default: Both

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

# Record type, A(IPv4)|AAAA(IPv6)|Both(IPv4+IPv6), default Both
CFRECORD_TYPE=Both

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

getWANIP(){
    CFRECORD_TYPE=$1
    
    if [ "$CFRECORD_TYPE" = "AAAA" ]; then
        WANIP="$(curl -s http://ipv6.icanhazip.com)"
    else
        WANIP="$(curl -s http://ipv4.icanhazip.com)"
    fi
    echo "$WANIP"
}
getUpdate(){
    CFKEY=$1
    CFUSER=$2
    CFZONE_NAME=$3
    CFRECORD_NAME=$4
    CFRECORD_TYPE=$5
    WANIP=$6
    
    CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)
   
    CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME&type=$CFRECORD_TYPE" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
        -H "X-Auth-Email: $CFUSER" \
        -H "X-Auth-Key: $CFKEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WANIP\"}")
    if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
        echo "Updated succesfuly!"
        echo "$WANIP"
    else
        echo 'Something went wrong :('
        echo "Response: $RESPONSE"
    fi      
}

if [ "$CFRECORD_TYPE" = "AAAA" ] || [ "$CFRECORD_TYPE" = "Both" ]; then
    IPV6="$(getWANIP "AAAA")"
fi
if [ "$CFRECORD_TYPE" = "A" ] || [ "$CFRECORD_TYPE" = "Both" ]; then
    IPV4="$(getWANIP "A")"
fi

if [ "$IPV6" != "" ]; then
    getUpdate $CFKEY $CFUSER $CFZONE_NAME $CFRECORD_NAME "AAAA" $IPV6
fi
if [ "$IPV4" != "" ]; then
    getUpdate $CFKEY $CFUSER $CFZONE_NAME $CFRECORD_NAME "A" $IPV4
fi
exit 0
