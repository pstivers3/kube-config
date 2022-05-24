#!/bin/bash

test=""
let a=0
SECONDS=0
while [ -z "$test" ]; do #while null
    sleep 10 
    (( a++ ))
    printf "%s\r" "elapsed time is $((SECONDS/60)) minutes, and $((SECONDS%60)) seconds" 
    if (( a >= 8 )); then
        test="not_null"
    fi
done

