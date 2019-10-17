#! /bin/bash

rm -rf /home/tfenster/github/end2end/*
cp -r /mnt/c/Users/tfenster8982/GitHub/end2end/* /home/tfenster/github/end2end/
cd /home/tfenster/github/end2end/
echo './publish.sh && rake publish'