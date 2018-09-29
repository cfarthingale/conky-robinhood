#!/bin/bash
authtoken=(your_api_token)
apiurl=(https://api.robinhood.com)
totaldeposits=(1000.00)
totalwithdrawals=(0)
curl -s $apiurl/portfolios/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.' > /dev/shm/data.tmp
curl -s $apiurl/accounts/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.' >> /dev/shm/data.tmp
hourcheck=$((( 6 <= $(date "+%k") && $(date "+%k") < 13 )) && echo true || echo false)
daycheck=$((( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
if [[ $daycheck == "true" ]] && [[ $hourcheck == "true" ]];then opencheck=(true); else opencheck=(false); fi
#opencheck=$(curl -s $apiurl/markets/|jq -r .results[3].todays_hours|xargs curl -s|jq -r '.is_open') # UNRELIABLE
if [[ $opencheck == "true" ]];then
	equity=$(cat /dev/shm/data.tmp |jq -r '.results[0].equity // empty')
	marketvalue=$(cat /dev/shm/data.tmp |jq -r '.results[0].market_value // empty')
else
	equity=$(cat /dev/shm/data.tmp |jq -r '.results[0].extended_hours_equity // empty')
	marketvalue=$(cat /dev/shm/data.tmp |jq -r '.results[0].extended_hours_market_value // empty')
fi
buyingpower=$(cat /dev/shm/data.tmp |jq -r '.results[0].buying_power // empty')
unsettledfunds=$(cat /dev/shm/data.tmp |jq -r '.results[0].unsettled_funds // empty')
unsettleddebit=$(cat /dev/shm/data.tmp |jq -r '.results[0].unsettled_debit // empty')
uncleareddeposits=$(cat /dev/shm/data.tmp |jq -r '.results[0].uncleared_deposits // empty')
withdrawable=$(cat /dev/shm/data.tmp |jq -r '.results[0].cash_available_for_withdrawal // empty')
cash=$(cat /dev/shm/data.tmp |jq -r '.results[0].cash // empty'|cut -c1-7)
totalprofit=$(echo "${equity}-${totaldeposits}"| bc)
totalprofitc=$(echo "${totalprofit}"|cut -c1)
totalprofitp=$(echo "${totalprofit} ${totaldeposits}"|awk '{print $1/$2*100}')
echo "+ Robinhood Account 0 - \${time %d %b %Y %H:%M:%S}"
echo " +"
#
#Check if market is open
if [[ $opencheck == "true" ]];then
	echo " | + Markets are  : \${color green}OPEN\${color}"
else
	echo " | + Markets are  : \${color red}CLOSED\${color}"
fi
#Equity
if (( $(echo "$equity > $totaldeposits" |bc) )); then
	echo " | + Equity       : \${color green}"${equity}"\${color}"
else
	echo " | + Equity       : \${color red}"${equity}"\${color}"
fi
#Total Profits?
if [[ $totalprofitc == "-" ]];then
	echo " | + Total Profit : \${color red}"${totalprofit} ${totalprofitp}%"\${color}"
else
	echo " | + Total Profit?: \${color green}"${totalprofit} +${totalprofitp}%"\${color}"
fi
#Market Value
echo " | + Market Value : $marketvalue"
#Buying Power
echo " | + Buying Power : $buyingpower"
#Unsettled Funds
echo " | + Uns Funds    : $unsettledfunds"
#Unsettled Debit
echo " | + Uns Debit    : $unsettleddebit"
#Uncleared Deposits
echo " | + Unc Depos    : $uncleareddeposits"
#Total Deposited
echo " | + Deposited    : $totaldeposits"
#Cash
echo " | + Cash         : $cash"
#Total Withdrawals
echo " | + Withdrawn    : $totalwithdrawals"
#Total Withdrawals
echo " | + Withdrawable : $withdrawable"
echo " +"
exit 0
