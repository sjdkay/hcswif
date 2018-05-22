#!/bin/bash

list=$1

spec=$2

while read line
do

runArray+=('/mss/hallc/spring17/raw/'${spec}'_all_0'${line}'.dat')

done < ${list}

eval jcache get "${runArray[*]}" -e pooser@jlab.org
