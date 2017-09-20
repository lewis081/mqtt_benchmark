#!/bin/bash

#redis
:<<!
redis-cli <<EOF
auth xxx
config set requirepass janposOmmaRedis
EOF
!

#influx
:<<!
influx -username lewis -password lewis <<EOF
create user paul with password '123' with all privileges
EOF
!

#mysql
mysql -uroot -pzhutianzhi<<EOF
create database abc;
EOF

#mosquitto

