#!/bin/bash
authtoken=(your_api_token)
apiurl=(https://api.robinhood.com)
orders=$(curl -s $apiurl/orders/ -H "Accept: application/json" -H "Authorization: Token $authtoken"|jq '.')
ordersc=$(echo $(echo "$orders"|jq -r '.results[].url'|wc -l)-1|bc)
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
	printf "%-2s %-6s %-6s %-6s %-9s %-7s %-7s %-7s %-4s\n" $e $symbol $quantity $date $time $price $usd $type $side ) &
done }
wait
echo "+ Last 10 orders"
echo " +"
echo " | + \${exec printf \"%-2s %-6s %-6s %-6s %-9s %-7s %-7s %-7s %-4s\" "+" "SYMBOL" "QUANT" "DATE" "TIME" "PRICE" "USD" "TYPE" "SIDE"}"
orders|sort|awk '{ print " | + " $0; }'
echo " +"
exit 0
