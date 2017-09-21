#!/bin/bash

#influx
influx -username paul -password 123 <<EOF
SHOW databases;
USE key_1;	#why error?
SELECT count(*) FROM ngnum LIMIT 1;
EOF



