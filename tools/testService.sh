#!/bin/bash


#./emqtt_bench_pub -c 100 -i 10 -I 1000 -t bench/%i -u janpos -P janpos -h 192.168.0.22
./emqtt_bench_pub -c 50 -i 100 -I 1000 -t omma/device/data -u janpos -P janpos -h 192.168.0.22 --pubcount 100 --workmode send 
# ./emqtt_bench_pub -c 50 -i 100 -I 1000 -t omma/influxClient/query -u janpos -P janpos -h 101.37.69.122 --workmode request

