#!/usr/bin/env bash

rc=0

echo '- response time 50th percentile less than 200ms'
if ! jq -re '200 > (.overall.quantiles.q50 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

exit $rc
