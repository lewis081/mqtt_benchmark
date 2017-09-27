#!/bin/bash

#STANDARD 
callAbPath=$(pwd)
curFileRelCallPath=$(dirname "$0")
cd $curFileRelCallPath


echo ----------------------------------
echo "              DEVICE SEND PARALLEL"
echo ----------------------------------
cd ../
#../emqtt_bench_pub -c 100 -i 10 -I 1000 -t bench/%i -u janpos -P janpos -h 192.168.0.22
# ./emqtt_bench_pub -c 500 -i 100 -I 1000 -t omma/device/data -u janpos -P janpos -h 101.37.69.122 --workmode send 


echo ----------------------------------
echo "              QUERY PARALLEL"
echo ----------------------------------
./emqtt_bench_pub -c 200 -i 100 -I 1000 -t omma/influxClient/query -u janpos -P janpos -h 101.37.69.122 --workmode request 

#RESTORE PATH AFTER WORK DONE 
cd $callAbPath