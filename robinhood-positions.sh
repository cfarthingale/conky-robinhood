#robinhood-monitoring-column.sh
#!/bin/bash
authtoken=(your_api_key)
apiurl=(https://api.robinhood.com)
curl -s $apiurl/positions/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.' > /dev/shm/positions2.tmp
hourcheck=$((( 6 <= $(date "+%k") && $(date "+%k") < 13 )) && echo true || echo false)
daycheck=$((( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
if [[ $daycheck == "true" ]] && [[ $hourcheck == "true" ]];then opencheck=(true); else opencheck=(false); fi
positions=$(cat /dev/shm/positions2.tmp)
positionsc=$(echo $(echo "$positions"|grep url|wc -l)-1|bc)
for e in $(seq 0 $positionsc); do
	symbol=$(echo "$positions"|jq .results[$e].instrument|xargs curl -s|jq -r '.symbol')
	quantity=$(echo "$positions"|jq -r .results[$e].quantity|cut -c1-5)
	paid=$(echo "$positions"|jq -r .results[$e].average_buy_price)
	spentusd=$(echo "${quantity}*${paid}"| bc)
	if [[ $spentusd == "0" ]];then continue; fi
	if [[ $opencheck == "true" ]];then
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_trade_price'|cut -c1-5)
	else
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_extended_hours_trade_price'|cut -c1-5)
	fi
	if [[ $price == "null" ]];then
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_trade_price'|cut -c1-5)
	fi
#	lastclose=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.previous_close'|cut -c1-5) # Price at previous close
#	lastclosep=$(echo ${price} ${lastclose}|awk '{print 100*$1/$2-100}'|cut -c1-5)
	equity=$(echo "${price}*${quantity}"| bc)
	return=$(echo "${equity}-${spentusd}"| bc)
	returnc=$(echo "${return}"|cut -c1)
	returnp=$(echo ${return} ${spentusd}|awk '{print $1/$2*100}'|cut -c1-5)
	echo "+ $symbol +$quantity shares"
	echo " +"
	echo " | + Price  : $price"
	echo " | + Paid   : $paid $spentusd"
	echo " | + Equity : $equity"
	if [[ $returnc == "-" ]];then
		echo " | + Return : \${color red}"${return} ${returnp}\%"\${color}"
	else
		echo " | + Return : \${color green}"${return} +${returnp}\%"\${color}"
	fi
#ALERTS
	if (( $(echo "$returnp > 10" |bc) )); then
		echo "\${color orange} | + ALERT  : Above +10% return = Sell?\${color}"
#		echo "Alert, $symbol up $returnp%, Sell now to lock in $return dollars"|espeak
	fi
echo " +"
done
echo "+"
exit 0
