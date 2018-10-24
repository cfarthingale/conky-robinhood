#!/bin/bash
#todo todays return? change since open? change since open plus premarket?
width=100
authtoken=(your_api_key)
apiurl=(https://api.robinhood.com)
dc=$((( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
if [[ $(date "+%H%M") > 0629 ]] && [[ $(date "+%H%M") < 1300 ]] && [[ $dc == "true" ]] ; then opencheck=(true); else opencheck=(false); fi
positions=$(curl -s $apiurl/positions/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
positionsc=$(echo $(echo "$positions"|grep url|wc -l)-1|bc)
echo " | + \${exec printf \"%-6s %-5s %-6s %-7s %-8s %-6s %-5s %-9s\" "SYMBOL" "QUANT" "PRICE" "PAID" "SPENT" "EQUITY" "%" "RETURN"}"
function pos () {
for e in $(seq 0 $positionsc); do (
	symbol=$(echo "$positions"|jq .results[$e].instrument|xargs curl -s|jq -r '.symbol')
	quantity=$(echo "$positions"|jq -r .results[$e].quantity|cut -c1-5)
	paid=$(echo "$positions"|jq -r .results[$e].average_buy_price)
	spentusd=$(echo "${quantity}*${paid}"| bc)
	if [[ $spentusd == "0" ]];then continue; fi
	if [[ $opencheck == "true" ]];then
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_trade_price'|cut -c1-6)
	else
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_extended_hours_trade_price'|cut -c1-6)
	fi
	if [[ $price == "null" ]];then
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_trade_price'|cut -c1-6)
	fi
	equity=$(echo "${price}*${quantity}"| bc|cut -c1-6)
	return=$(echo "${equity}-${spentusd}"| bc)
	returnc=$(echo "${return}"|cut -c1)
	returnp=$(echo ${return} ${spentusd}|awk '{print $1/$2*100}'|cut -c1-5)
	if [[ $returnc == "-" ]];then printf  "%-6s %-5s %-6s %-7s %-8s %-6s %-5s %-9s\n" $symbol $quantity $price $paid $spentusd $equity "\${color red}"$returnp $return"\${color}"; continue; else
	printf "%-6s %-5s %-6s %-7s %-8s %-6s %-5s %-9s\n" $symbol $quantity $price $paid $spentusd $equity "\${color green}"$returnp $return"\${color}"; continue; fi ) &
done }
pos|sort| awk '{ print " | + " $0; }'
exit 0
