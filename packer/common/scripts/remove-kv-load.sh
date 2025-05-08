#!/bin/sh
    # change the 100 to however many entries you want to do
    KEY_PREFIX="t-mobile/secrets/confidential"
    for i in {1..50}
    do
     consul kv delete -recurse "$KEY_PREFIX-$i"
    done