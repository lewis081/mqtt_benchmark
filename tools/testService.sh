#!/bin/bash



# ./emqtt_bench_pub -c 20 -i 10 -I 1000 -t omma/influxClient/query -u janpos -P janpos -h 101.37.69.122
./emqtt_bench_pub -c 50 -i 100 -I 1000 -b 10 -t omma/device/data -u janpos -P janpos -h 101.37.69.122
#./emqtt_bench_pub -c 100 -i 10 -I 1000 -t bench/%i -u janpos -P janpos -h 192.168.0.22
