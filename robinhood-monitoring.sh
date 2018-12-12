#!/bin/bash
authtoken="your_api_token"
apiurl="https://api.robinhood.com"
totaldeposits="1000.00"
totalwithdrawals="0"
#todo: minimize deps, dep install function.
#
function rh-account () {
	portfolios=$(curl -s $apiurl/portfolios/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
	accounts=$(curl -s $apiurl/accounts/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
	dc=$( (( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
	if [[ $(date "+%H%M") > 0629 ]] && [[ $(date "+%H%M") < 1300 ]] && [[ $dc == "true" ]]; then opencheck="true"; else opencheck="false"; fi
	if [[ $opencheck == "true" ]];then
		equity=$(echo "$portfolios"|jq -r '.results[0].equity // empty')
		marketvalue=$(echo "$portfolios"|jq -r '.results[0].market_value // empty')
	else
		equity=$(echo "$portfolios"|jq -r '.results[0].extended_hours_equity // empty')
		marketvalue=$(echo "$portfolios"|jq -r '.results[0].extended_hours_market_value // empty')
	fi
	buyingpower=$(echo "$accounts"|jq -r '.results[0].buying_power // empty')
	unsettledfunds=$(echo "$accounts"|jq -r '.results[0].unsettled_funds // empty')
	unsettleddebit=$(echo "$accounts"|jq -r '.results[0].unsettled_debit // empty')
	#uncleareddeposits=$(echo "$accounts"|jq -r '.results[0].uncleared_deposits // empty')
	withdrawable=$(echo "$accounts"|jq -r '.results[0].cash_available_for_withdrawal // empty')
	cash=$(echo "$accounts"|jq -r '.results[0].cash // empty'|cut -c1-7)
	totalprofit=$(echo "${equity}-${totaldeposits}"| bc)
	totalprofitc=$(echo "${totalprofit}"|cut -c1)
	totalprofitp=$(echo "${totalprofit} ${totaldeposits}"|awk '{print $1/$2*100}')
	function marketstatus () {
		dc=$( (( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
		if [[ $(date "+%H%M") > 0400 ]] && [[ $(date "+%H%M") < 0630 ]]; then pc="true"; else pc="false"; fi
		if [[ $(date "+%H%M") > 0630 ]] && [[ $(date "+%H%M") < 1259 ]]; then oc="true"; else oc="false"; fi
		if [[ $(date "+%H%M") > 1300 ]] && [[ $(date "+%H%M") < 1700 ]]; then ac="true"; else ac="false"; fi
		if [[ $dc == "true" ]] && [[ $pc == "true" ]];then echo " | + Markets are  : \${color green}OPEN\${color orange} - PRE-MARKET\${color}"; fi
		if [[ $dc == "true" ]] && [[ $oc == "true" ]];then echo " | + Markets are  : \${color green}OPEN\${color}"; fi
		if [[ $dc == "true" ]] && [[ $ac == "true" ]];then echo " | + Markets are  : \${color green}OPEN\${color orange} - AFTER HOURS\${color}"; fi
		if [[ $dc == "false" ]] || [[ $pc == "false" ]] && [[ $oc == "false" ]] && [[ $ac == "false" ]]; then echo " | + Markets are  : \${color red}CLOSED\${color}"; fi }
	echo "+ Robinhood Account 0 - \${time %d %b %Y %H:%M:%S}"
	echo " +"
	marketstatus
	if (( $(echo "$equity > $totaldeposits" |bc) )); then echo " | + Equity       : \${color green}$equity\${color}"; else echo " | + Equity       : \${color red}$equity\${color}"; fi
	#Total profits?
	if [[ $totalprofitc == "-" ]];then
		echo " | + Total Profit : \${color red} "${totalprofit}" "${totalprofitp}%"\${color}"
	else
		echo " | + Total Profit?: \${color green} "${totalprofit}" +"${totalprofitp}%"\${color}"
	fi
	echo " | + Market Value : $marketvalue"
	echo " | + Buying Power : $buyingpower"
	echo " | + Uns Funds    : $unsettledfunds"
	echo " | + Uns Debit    : $unsettleddebit"
	echo " | + Deposited    : $totaldeposits"
	echo " | + Cash         : $cash"
	echo " | + Withdrawn    : $totalwithdrawals"
	echo " | + Withdrawable : $withdrawable"
	echo " +"
	exit 0
}

function rh-alerts () {
	dc=$( (( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
	if [[ $(date "+%H%M") -gt 0629 ]] && [[ $(date "+%H%M") -lt 1300 ]] && [[ $dc == "true" ]] ; then opencheck="true"; else opencheck="false"; fi
	positions=$(curl -s $apiurl/positions/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
	positionsc=$(echo "$(echo "$positions"|grep url|grep -c)"-1|bc)
	function alerts () {
		for e in $(seq 0 "$positionsc"); do (
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
		equity=$(echo "${price}*${quantity}"| bc)
		return=$(echo "${equity}-${spentusd}"| bc)
		returnc=$(echo "${return}"|cut -c1)
		returnp=$(echo "${return} ${spentusd}"|awk '{print $1/$2*100}'|cut -c1-5)
		if (( $(echo "$returnp < -25" |bc) )); then echo "\${font Terminus:size=12,weight:bold}\${color orange}ALERT - $symbol DOWN $returnp%, SELL\${color}\${font}"; continue; fi
		if (( $(echo "$returnp > 10" |bc) )); then echo "\${color green}ALERT - $symbol up $returnp%, SELL for $return\${color}"; continue; fi ) &
	done }
	echo "+ Alerts"
	echo " +"
	alerts|sort| awk '{ print " | + " $0; }'
	echo " +"
	wait
	exit 0
}

function rh-orders () {
	orders=$(curl -s $apiurl/orders/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
	#ordersc=$(echo $(echo "$orders"|jq -r '.results[].url'|wc -l)-1|bc)
	function orders () {
	#for e in $(seq 0 $ordersc); do # ALL ORDERS
	for e in $(seq 0 9); do ( # 10 most recent orders
		symbol=$(echo "$orders"|jq .results[$e].instrument|xargs curl -s|jq -r '.symbol')
		quantity=$(echo "$orders"|jq -r .results[$e].quantity|cut -c1-5)
		price=$(echo "$orders"|jq -r .results[$e].executions[0].price|cut -c1-6)
		type=$(echo "$orders"|jq -r .results[$e].type)
		date=$(echo "$orders"|jq -r .results[$e].updated_at|cut -c6-10)
		time=$(echo "$orders"|jq -r .results[$e].updated_at|cut -c12-19)
		side=$(echo "$orders"|jq -r .results[$e].side)
		usd=$(echo "${quantity} ${price}"|awk '{print $1*$2}')
		printf "%-2s %-6s %-6s %-6s %-9s %-7s %-7s %-7s %-4s\n" "$e" "$symbol" "$quantity" "$date" "$time" "$price" "$usd" "$type" "$side" ) &
	done }
	wait
	echo "+ Last 10 orders"
	echo " +"
	echo " | + \${exec printf \"%-2s %-6s %-6s %-6s %-9s %-7s %-7s %-7s %-4s\" "+" "SYMBOL" "QUANT" "DATE" "TIME" "PRICE" "USD" "TYPE" "SIDE"}"
	orders|sort|awk '{ print " | + " $0; }'
	echo " +"
	exit 0
}

function rh-positions () {
	#todo todays return? change since open? change since open plus premarket?
	#width=100
	dc=$( (( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
	if [[ $(date "+%H%M") > 0629 ]] && [[ $(date "+%H%M") < 1300 ]] && [[ $dc == "true" ]] ; then opencheck="true"; else opencheck="false"; fi
	positions=$(curl -s $apiurl/positions/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
	positionsc=$(echo "$(echo "$positions"|grep url -c)"-1|bc)
	echo " | + \${exec printf \"%-6s %-5s %-6s %-7s %-8s %-6s %-5s %-9s\" "SYMBOL" "QUANT" "PRICE" "PAID" "SPENT" "EQUITY" "%" "RETURN"}"
	function pos () {
		for e in $(seq 0 "$positionsc"); do (
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
			returnp=$(echo "${return} ${spentusd}"|awk '{print $1/$2*100}'|cut -c1-5)
			if [[ $returnc == "-" ]];then printf  "%-6s %-5s %-6s %-7s %-8s %-6s %-5s %-9s\n" $symbol $quantity $price $paid $spentusd $equity "\${color red}"$returnp $return"\${color}"; continue; else
			printf "%-6s %-5s %-6s %-7s %-8s %-6s %-5s %-9s\n" $symbol $quantity $price $paid $spentusd $equity "\${color green}"$returnp $return"\${color}"; continue; fi ) &
		done }
	pos|sort| awk '{ print " | + " $0; }'
	exit 0
}

function rh-watchlist () {
curl -s $apiurl/watchlists/Default/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.' > /dev/shm/watchlist.tmp
hourcheck=$((( 6 <= $(date "+%k") && $(date "+%k") < 13 )) && echo true || echo false)
daycheck=$((( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
if [[ $daycheck == "true" ]] && [[ $hourcheck == "true" ]];then opencheck=(true); else opencheck=(false); fi
watchlist=$(cat /dev/shm/watchlist.tmp)
watchlistc=$(echo $(echo "$watchlist"|grep url|wc -l)-1|bc)
echo "AASYMBOL,PRICE,LOW,HIGH,OPEN,CHANGE,%"
for e in $(seq 0 $watchlistc); do (
	symbol=$(echo "$watchlist"|jq .results[$e].instrument|xargs curl -s|jq -r '.symbol')
	if [[ $opencheck == "true" ]];then
		price=$(echo "$watchlist"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_trade_price'|cut -c1-5)
	else
		price=$(echo "$watchlist"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_extended_hours_trade_price'|cut -c1-5)
	fi
	if [[ $price == "null" ]];then
		price=$(echo "$watchlist"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_trade_price'|cut -c1-5)
	fi
	high=$(echo "$watchlist"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.fundamentals'|xargs curl -s|jq -r '.high'|cut -c1-5)
	low=$(echo "$watchlist"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.fundamentals'|xargs curl -s|jq -r '.low'|cut -c1-5)
	open=$(echo "$watchlist"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.fundamentals'|xargs curl -s|jq -r '.open'|cut -c1-5)
#	lastclose=$(echo "$watchlist"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.previous_close'|cut -c1-5)
	changed=$(echo ${price}-${open}|bc)
	changep=$(echo ${price} ${open}|awk '{print 100*$1/$2-100}'|cut -c1-5)
	echo $symbol,$price,$low,$high,$open,$changed,$changep ) &
done
wait
exit 0
}
$1
exit 0
