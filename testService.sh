#!/bin/bash


payload={\"datas\":{\"green\":\"010402000178F0\",\"ngnum\":\"01040270295D2E\",\"oknum\":\"010402B914CAAF\",\"red\":\"0104020000B930\",\"total\":\"0104020000B930\",\"yellow\":\"0104020000B930\"},\"uuid\":\"uuid_1\"}


#./emqtt_bench_pub -c 500 -i 100 -I 1000 -t omma/device/data -u janpos -P janpos 
./emqtt_bench_pub -c 100 -i 10 -I 1000 -t bench/%i -u janpos -P janpos -h 192.168.0.22
