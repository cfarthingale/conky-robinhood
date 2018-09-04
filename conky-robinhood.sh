#!/bin/bash
# A poorly commented RobinHood API script for use with Conky.
authtoken=(your_auth_token)
apiurl=(https://api.robinhood.com)
totaldeposits=(1000.00)
totalwithdrawals=(0)
opencheck=$(curl -s $apiurl/markets/|jq -r .results[3].todays_hours|xargs curl -s|jq -r '.is_open')
if [[ $opencheck == "true" ]];then
	equity=$(curl -s $apiurl/portfolios/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq -r '.results[].equity')
else
	equity=$(curl -s $apiurl/portfolios/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq -r '.results[].extended_hours_equity')
fi
marketvalue=$(curl -s $apiurl/portfolios/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq -r '.results[].market_value')
buyingpower=$(curl -s $apiurl/accounts/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq -r '.results[].buying_power')
cash=$(curl -s $apiurl/accounts/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq -r '.results[].cash'|cut -c1-7)
positions=$(curl -s $apiurl/positions/ -H "Accept: application/json" -H "Authorization: Token $authtoken")
totalprofit=$(echo "${equity}-${totaldeposits}"| bc)
totalprofitc=$(echo "${totalprofit}"|cut -c1)
#
#Section A: Gathers various account/status information from api.robinhood.com
echo "+ Robinhood Account 0 \${time %d %b %Y %H:%M:%S} - TESTING"
echo " +"
#Check if market is open
if [[ $opencheck == "true" ]];then
	echo " | + Markets are  : \${color green}OPEN\${color}"
else
	echo " | + Markets are  : \${color red}CLOSED\${color}"
fi
#Equity
if [[ $equity > $totaldeposits ]];then
	echo " | + Equity       : \${color green}"${equity}"\${color}"
else
	echo " | + Equity       : \${color red}"${equity}"\${color}"
fi
#Total Profits?
if [[ $totalprofitc == "-" ]];then
	echo " | + Total Profit : \${color red}"${totalprofit}"\${color}"
else
	echo " | + Total Profit?: \${color green}"${totalprofit}"\${color}"
fi
#Market Value
echo " | + Market Value : $marketvalue"
#Buying Power
echo " | + Buying Power : $buyingpower"
#Total Deposited
echo " | + Deposited    : $totaldeposits"
#Cash
echo " | + Cash         : $cash"
#Total Withdrawals
echo " | + Withdrawn    : $totalwithdrawals"
echo " | + Unsettled    : undefined"
echo " +"
#
#Section B: Gathers and prints information about owned $positions. The next line has to be adjusted to the number of stocks you own (i.e. 0 1 2 3 4 5 if you own 6 stocks.). Any suggestings for a better method here gratefully accepted.
for e in 0 1 2; do
	symbol=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.symbol')
	quantity=$(echo "$positions"|jq -r .results[$e].quantity|cut -c1-5)
	if [[ $quantity == "0.000" ]];then
		break
	fi
	paid=$(echo "$positions"|jq -r .results[$e].average_buy_price)
	spentusd=$(echo "${quantity}*${paid}"| bc)
	if [[ $opencheck == "true" ]];then
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_trade_price'|cut -c1-5)
	else
		price=$(echo "$positions"|jq -r .results[$e].instrument|xargs curl -s|jq -r '.quote'|xargs curl -s|jq -r '.last_extended_hours_trade_price'|cut -c1-5)
	fi
	equity=$(echo "${price}*${quantity}"| bc)
	return=$(echo "${equity}-${spentusd}"| bc)
	returnc=$(echo "${return}"|cut -c1)
	returnp=$(echo ${return} ${spentusd}|awk '{print $1/$2*100}'|cut -c1-5)
	#
	echo "+ $symbol"
	echo " +"
	echo " | + Price  : $price"
	echo " | + Paid   : $paid +$quantity"
	echo " | + Spent  : $spentusd"
	echo " | + Equity : $equity"
	if [[ $returnc == "-" ]];then
		echo " | + Return : \${color red}"${return} ${returnp}\%"\${color}"
	else
		echo " | + Return : \${color green}"${return} +${returnp}\%"\${color}"
	fi
	#ALERTS
	if [[ $returnp > "9" ]];then
		echo "\${color orange} | + ALERT  : Above +9% return = Sell?\${color}"
	fi
echo " +"
done
echo "+"
