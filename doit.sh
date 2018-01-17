#!/bin/bash -x
# don't go before 2004
#for y in 2016
#for y in 2015 2016
for y in `seq 2004 2017`
do
 for m in 01 02 03 04 05 06 07 08 09 10 11 12
 do
   if [ ! -f ./data/v6percountry.$y-$m-01.txt ]
   then
     echo "$y-$m-01"
     ./v6percountry.pl $y-$m-01
   fi
 done
done
# remove empties
find ./data -size 0 -type f  | xargs rm
./tojson.pl
