#!/bin/bash

list=$1

spec=$2

while read line
do

runArray+=('/cache/hallc/spring17/raw/'${spec}'_all_0'${line}'.dat')

done < ${list}

eval jcache pin "${runArray[*]}" -D 60
