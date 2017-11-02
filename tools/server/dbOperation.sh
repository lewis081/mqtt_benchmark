#!/bin/bash

operation=$1;
startIdx=$2;
endIdx=$3;
devStartIdx=$4;
devEndIdx=$5;

#params
user=root
passw=zhutianzhi
database=omma
userInflux=paul
passwInflux=123
auth=janposOmmaRedis


usage()
{
	str='usage: ./dbOperation.sh op compyStartIdx compyEndIdx deviceStartIdx deviceEndIdx \n
		example: ./dbOperation.sh insert 1 1 1 1\n
		default idxs: 1 5 1 10\n
		--------------------------------------\n
		op:\n
		\t insert \n
		\t delete \n\n
		compyStartIdx/compyEndIdx:\n
		\t 1 <= compyStartIdx <= compyEndIdx \n\n
		deviceStartIdx/deviceEndIdx:\n
		\t 1 <= deviceStartIdx <= deviceEndIdx \n\n';
	echo -e $str
}

judge()
{
	if [ "$operation" == "-h" ] || [ "$operation" = "" ]
	then
		usage
		exit 0
	fi

	if [ "$operation" != "insert" ] && [ "$operation" != "delete" ]
	then
		usage
		exit 0
	fi
}

setDefaultValues()
{

	if [ "$startIdx" = "" ]
	then
		startIdx=1
	fi
	if [ "$endIdx" = "" ]
	then
		endIdx=5
	fi
	if [ "$devStartIdx" = "" ]
	then
		devStartIdx=1
	fi
	if [ "$devEndIdx" = "" ]
	then
		devEndIdx=10
	fi
}


judge
setDefaultValues


#company
for((company=$startIdx;company<=$endIdx;company++))
do
    if [ $operation == "insert" ];then
	mysql -u$user -p$passw $database -e "insert into company(access_key,name)values('key_$company','name_$company');"
	influx -username $userInflux -password $passwInflux -execute "create database key_$company"
    elif [ $operation == "delete" ];then
    	mysql -u$user -p$passw $database -e "delete from company where name = 'name_$company';" 
	influx -username $userInflux -password $passwInflux -execute "drop database key_$company" 
    fi
done

#deivce
devDeltaIdx=$[$devEndIdx-$devStartIdx+1]
for((company=$startIdx;company<=$endIdx;company++))
do
    for((device=$devStartIdx;device<=$devEndIdx;device++))
    do
	#problem
	key=key_$company
	uuidNum=$[($company-1)*$devDeltaIdx+$device]
	uuid=uuid_$uuidNum
	if [ $operation == "insert" ];then
		#ms-----10+3(chars)
		curTime=$(date +%s)000
		
		data="{\"line\": \"\", \"name\": \"f\", \"type\": 0, \"uuid\": \"$uuid\", \"online\": false, \"factory\": \"\", \"station\": 2, \"workshop\": \"\", \"company_key\": \"$key\", \"create_time\": \"$curTime\", \"description\": \"\", \"last_active_time\": \"0\"}"
		mysql -u$user -p$passw $database -e "insert into device(uuid,access_key,data)values('$uuid','$key','$data');"

		params="{\"uuid\": \"$uuid\", \"port_type\": 0, \"access_key\": \"$key\", \"data_field\": [{\"key\": \"oknum\", \"name\": \"良品\", \"type\": 1, \"value\": \"\", \"reponse\": \"\", \"request\": \"\", \"is_extra\": false, \"protocol_param\": {\"adu_type\": 1, \"quantity\": 1, \"func_code\": 4, \"slave_num\": 1, \"byte_order\": 0, \"start_addr\": 0}}, {\"key\": \"ngnum\", \"name\": \"不良品\", \"type\": 1, \"value\": \"\", \"reponse\": \"\", \"request\": \"\", \"is_extra\": false, \"protocol_param\": {\"adu_type\": 1, \"quantity\": 1, \"func_code\": 4, \"slave_num\": 1, \"byte_order\": 0, \"start_addr\": 1}}, {\"key\": \"total\", \"name\": \"总数\", \"type\": 3, \"value\": \"\", \"reponse\": \"\", \"request\": \"\", \"is_extra\": false, \"protocol_param\": {\"adu_type\": 1, \"quantity\": 2, \"func_code\": 4, \"slave_num\": 1, \"byte_order\": 0, \"start_addr\": 2}}, {\"key\": \"red\", \"name\": \"红\", \"type\": 1, \"value\": \"\", \"reponse\": \"\", \"request\": \"\", \"is_extra\": false, \"protocol_param\": {\"adu_type\": 1, \"quantity\": 1, \"func_code\": 4, \"slave_num\": 1, \"byte_order\": 0, \"start_addr\": 4}}, {\"key\": \"yellow\", \"name\": \"黄\", \"type\": 1, \"value\": \"\", \"reponse\": \"\", \"request\": \"\", \"is_extra\": false, \"protocol_param\": {\"adu_type\": 1, \"quantity\": 1, \"func_code\": 4, \"slave_num\": 1, \"byte_order\": 0, \"start_addr\": 5}}, {\"key\": \"green\", \"name\": \"绿\", \"type\": 1, \"value\": \"\", \"reponse\": \"\", \"request\": \"\", \"is_extra\": false, \"protocol_param\": {\"adu_type\": 1, \"quantity\": 1, \"func_code\": 4, \"slave_num\": 1, \"byte_order\": 0, \"start_addr\": 6}}], \"port_param\": {}, \"protocol_id\": \"Modbus\", \"polling_interval\": 100}"
		#mysql -u$user -p$passw $database -e "insert into device_pollparam(uuid,access_key,data)values('$uuid','$key','$params');"
		redis-cli -a $auth <<EOF
		SADD acsKey:$key $uuid
		HMSET pollParam:$uuid data '$params'
EOF
    	elif [ $operation == "delete" ];then
    		mysql -u$user -p$passw $database -e "delete from device where uuid = '$uuid';"
		#mysql -u$user -p$passw $database -e "delete from device_pollparam where uuid = '$uuid';"
		redis-cli -a $auth <<EOF
		SREM acsKey:$key $uuid
		HDEL pollParam:$uuid data
EOF
        fi
    done
done



exit 0


