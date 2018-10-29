#!/usr/bin/python2.7

from __future__ import print_function

runListFile = 'ptemp.txt'
vertListFile = open('shms-f2-boil-list.txt', 'w')

with open(runListFile) as rlf:
    l = rlf.readline()
    rn = [ll.split('-') for ll in l.split(' ')]
    rn = [range(int(i[0]),int(i[1])+1) if len(i) == 2 else i for i in rn]
    nrn = [int(item) for sublist in rn for item in sublist]

for item in nrn:
    print (item, file = vertListFile)
