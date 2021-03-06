#!/bin/bash

#   Copyright 2012 Jacob Beard
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

openBrowser(){
	url="$1"

	#cobbled together from: http://stackoverflow.com/questions/3124556/clean-way-to-launch-the-web-browser-from-shell-script
	if [ -x "$BROWSER" ]; then
		"$BROWSER" "$URL" &
	elif which gnome-open > /dev/null; then
		gnome-open "$url" &
	elif which python > /dev/null; then
		python -mwebbrowser "$url" &
	elif which xdg-open > /dev/null; then
		xdg-open "$url" &
	fi
}

printHelp(){
cat <<-EOF
	This script opens a a number of flight search aggregators in your web browser. It is meant to allow you to specify trips of a certain duration, plus or minus a number of days, and then view ticket prices in a number of flight aggregators over a range of dates. 

	flight-search.sh [OPTIONS] first-date-to-search last-date-to-search origin destination

	OPTIONS are:

	A number of search engines: 
	-h | --hipmunk
	-k | --kayak
	-e | --expedia
	-t | --travelocity
	-s | --skyscanner
	-a | --all : Alias for all search engines. This is the default option.

	-c | --days-before-departure: Extra days to to look before your departure. Defaults to 0.
	-d | --days-after-departure:  Extra days to look after your departure. Defaults to 0.
	-m | --days-before-return: Extra days to look before your return. Defaults to 0.
	-n | --days-after-return: Extra days to look after your return. Defaults to 0. 
	-r | --trip-duration: Length of the trip (before extra days). Default to 9 days.
	-f | dry-run: Just print out URLs, but don't actually attempt to open them.

	EXAMPLE: To look for return trip flights from Syracuse and Cape Town, lasting 9 days, leaving on Thursday or Friday, between 2012-04-06 and 2012-06-08, and returning the following Sunday (9 or 10 day trip duration, depending on whether you leave on Thursday or Friday).

	./flight-search.sh -r 9 --days-before-departure 1 2012-04-06 2012-06-08 SYR CPT
EOF
}


TEMP=`getopt -o pketsac:d:m:n:r:fh \
--long  hipmunk,kayak,expedia,travelocity,skyscanner,all,days-before-departure:,days-after-departure:,days-before-return:,days-after-return:,trip-duration:,dry-run,"help" \
-n 'flight-search.sh' -- "$@"`

if [ $? != 0 ] ; then echo "getopt failed. Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

declare -a engines

allEngines=( hipmunk kayak expedia travelocity skyscanner );

while true ; do
	echo $1
	case "$1" in
		-p|--hipmunk|-k|--kayak|-e|--expedia|-t|--travelocity|-s|--skyscanner) engines+=1; shift ;;
		-a|--all) engines=( ${allEngines[*]} ); shift ;;
		-c|--days-before-departure) departMinusDays=$2; shift 2 ;;
		-d|--days-after-departure)  departPlusDays=$2; shift 2 ;;
		-m|--days-before-return) returnMinusDays=$2; shift 2 ;;
		-n|--days-after-return) returnPlusDays=$2; shift 2 ;;
		-r|--trip-duration) daysToReturnAfter=$2; shift 2 ;;
		-f|--dry-run) dryRun=true; shift ;;
		-h|--help) printHelp; exit 1 ;;
		--) shift ; break ;;
		*) printHelp; exit 1 ;;
	esac
done

if [ ${#engines[*]} -eq 0 ]; then engines=( ${allEngines[*]} ); fi;

echo engines : $engines;

#default values
departMinusDays=${departMinusDays-0}
departPlusDays=${departPlusDays-0}
returnMinusDays=${returnMinusDays-0}
returnPlusDays=${returnPlusDays-0}
daysToReturnAfter=${daysToReturnAfter-9}

firstDepartureDate=${1-`date +%F`}
lastDepartureDate=${2-`date +%F`}
origin=${3}
dest=${4}

if [ -z "$origin" -o -z "$dest" ]; then printHelp; exit 1; fi;

today=`date +%-j`
firstDepartureDay=`date --date "$firstDepartureDate" +%-j`
lastDepartureDay=`date --date "$lastDepartureDate" +%-j`

#echo firstDepartureDate $firstDepartureDate
#echo today $today
#echo firstDepartureDay $firstDepartureDay
#echo lastDepartureDay $lastDepartureDay

daysUntilFirstDepartureDate=$(($firstDepartureDay - $today))
daysUntilLastDepartureDate=$(($lastDepartureDay - $today))

echo daysUntilFirstDepartureDate $daysUntilFirstDepartureDate
echo daysUntilLastDepartureDate $daysUntilLastDepartureDate

declare -a departDates
declare -a returnDates
#TODO: parameterize this
n=0
for baseDaysAhead in `seq $daysUntilFirstDepartureDate 7 $daysUntilLastDepartureDate`; do
	baseReturnDaysAhead=$(($baseDaysAhead + $daysToReturnAfter))	#TODO: parameterize this
	for departDaysAhead in `seq $(($baseDaysAhead - $departMinusDays)) $(($baseDaysAhead + $departPlusDays))`; do
		for returnDaysAhead in `seq $(($baseReturnDaysAhead - $returnMinusDays)) $(($baseReturnDaysAhead + $returnPlusDays))`; do
			departDates[$n]=`date --date="$departDaysAhead days" +%F`
			returnDates[$n]=`date --date="$returnDaysAhead days" +%F`
			echo $departDaysAhead $returnDaysAhead ${departDates[$n]} ${returnDates[$n]}
			n=$((n + 1))
		done;
	done;
done

j=0
declare -a urls

for engine in ${engines[*]}; do
	case $engine in
		hipmunk) s='"http://www.hipmunk.com/#!$origin.$dest,`date --date=${departDates[i]} +%b%d`.`date --date=${returnDates[i]} +%b%d`"';;
		kayak) s='"http://www.kayak.com/#/flights/$origin,nearby-$dest/${departDates[i]}/${returnDates[i]}"';;
		expedia) s='"http://www.expedia.com/Flights-Search?trip=roundtrip&leg1=from:$origin,to:$dest,departure:$(echo $(date -d ${departDates[i]} +%m-%d-%Y) | sed -e s/-/%2F/g)TANYT&leg2=from:CPT,to:SYR,departure:$(echo $(date -d ${returnDates[i]} +%m-%d-%Y) | sed -e s/-/%2F/g)TANYT&passengers=children:0,adults:1,seniors:0,infantinlap:Y&options=cabinclass:economy,nopenalty:N,sortby:price&mode=search&mdpdtl=FLT:SYR:CPT"';; 
		travelocity) s='"http://travel.travelocity.com/flights/InitialSearch.do?Service=TRAVELOCITY&flightType=roundtrip&dateTypeSelect=exactDates&dateLeavingTime=Anytime&dateReturningTime=Anytime&adults=1&children=0&seniors=0&leavingDate=`date --date=${departDates[i]} +%-m/%-d/%Y`&returningDate=`date --date=${returnDates[i]} +%-m/%-d/%Y`&leavingFrom=$origin&goingTo=$dest"';; 
		#cheapoair) s='"http://www.cheapoair.com/Default.aspx?tabid=1685&sid=$i&oa=$origin&da=$dest&adt=1&chd=0&snr=0&infl=0&infs=0&dd=`date --date=${departDates[i]} +%m-%d-%Y`&rd=`date --date=${departDates[i]} +%m-%d-%Y`&tt=ROUNDTRIP&lc=1"';;
		#priceline
		skyscanner) s='"http://www.skyscanner.com/flights/`echo $origin | tr '[A-Z]' '[a-z]'`/`echo $dest | tr '[A-Z]' '[a-z]'`/`date --date=${departDates[i]} +%y%m%d`/`date --date=${returnDates[i]} +%y%m%d`/"' ;;
	esac	

	for((i=0;i < n;i++,j++)); do
		urls[$j]=`eval echo $s`
	done
done


for url in ${urls[*]}; do
	#TODO: parameterize whether to run or just echo
	echo $url

	if [ -n "$dryRun" ]; then 
		continue
	fi;

	openBrowser "$url"
	sleep .2	#chromium seems to time out when you open too many tabs at once
done;
