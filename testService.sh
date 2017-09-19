#!/bin/bash



./emqtt_bench_pub -c 200 -i 10 -I 1000 -t omma/influxClient/query -u janpos -P janpos -h 101.37.69.122
#./emqtt_bench_pub -c 100 -i 10 -I 80 -t omma/device/data -u janpos -P janpos -h 192.168.0.22
#./emqtt_bench_pub -c 100 -i 10 -I 1000 -t bench/%i -u janpos -P janpos -h 192.168.0.22
