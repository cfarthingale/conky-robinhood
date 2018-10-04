#robinhood-monitoring-column.sh
#!/bin/bash
authtoken=(your_api_token)
apiurl=(https://api.robinhood.com)
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
