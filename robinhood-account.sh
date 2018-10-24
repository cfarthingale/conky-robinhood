#!/bin.sh
authtoken=(your_api_token)
apiurl=(https://api.robinhood.com)
totaldeposits=(100.00)
totalwithdrawals=(0)
portfolios=$(curl -s $apiurl/portfolios/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
accounts=$(curl -s $apiurl/accounts/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
dc=$((( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
if [[ $(date "+%H%M") > 0629 ]] && [[ $(date "+%H%M") < 1300 ]] && [[ $dc == "true" ]]; then opencheck=(true); else opencheck=(false); fi
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
uncleareddeposits=$(echo "$accounts"|jq -r '.results[0].uncleared_deposits // empty')
withdrawable=$(echo "$accounts"|jq -r '.results[0].cash_available_for_withdrawal // empty')
cash=$(echo "$accounts"|jq -r '.results[0].cash // empty'|cut -c1-7)
totalprofit=$(echo "${equity}-${totaldeposits}"| bc)
totalprofitc=$(echo "${totalprofit}"|cut -c1)
totalprofitp=$(echo "${totalprofit} ${totaldeposits}"|awk '{print $1/$2*100}')
#
function marketstatus () {
	dc=$((( 1 <= $(date "+%w") && $(date "+%w") < 6 )) && echo true || echo false)
	if [[ $(date "+%H%M") > 0400 ]] && [[ $(date "+%H%M") < 0630 ]] ; then pc=(true); else pc=(false); fi
	if [[ $(date "+%H%M") > 0630 ]] && [[ $(date "+%H%M") < 1259 ]] ; then oc=(true); else oc=(false); fi
	if [[ $(date "+%H%M") > 1300 ]] && [[ $(date "+%H%M") < 1700 ]] ; then ac=(true); else ac=(false); fi
	if [[ $dc == "true" ]] && [[ $pc == "true" ]];then echo " | + Markets are  : \${color green}OPEN\${color orange} - PRE-MARKET\${color}"; fi
	if [[ $dc == "true" ]] && [[ $oc == "true" ]];then echo " | + Markets are  : \${color green}OPEN\${color}"; fi
	if [[ $dc == "true" ]] && [[ $ac == "true" ]];then echo " | + Markets are  : \${color green}OPEN\${color orange} - AFTER HOURS\${color}"; fi
	if [[ $dc == "false" ]] || [[ $pc == "false" ]] && [[ $oc == "false" ]] && [[ $ac == "false" ]]; then echo " | + Markets are  : \${color red}CLOSED\${color}"; fi }
#
echo "+ Robinhood Account 0 - \${time %d %b %Y %H:%M:%S}"
echo " +"
marketstatus
# Equity
if (( $(echo "$equity > $totaldeposits" |bc) )); then echo " | + Equity       : \${color green}"${equity}"\${color}"; else echo " | + Equity       : \${color red}"${equity}"\${color}"; fi
#Total profits?
if [[ $totalprofitc == "-" ]];then
	echo " | + Total Profit : \${color red}"${totalprofit} ${totalprofitp}%"\${color}"
else
	echo " | + Total Profit?: \${color green}"${totalprofit} +${totalprofitp}%"\${color}"
fi
#
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
