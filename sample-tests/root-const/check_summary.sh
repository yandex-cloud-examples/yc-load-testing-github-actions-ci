#!/usr/bin/env bash

rc=0

echo '- test status is DONE'
if ! jq -re '"DONE" == (.summary.status)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- no error reported'
if ! jq -re '"" == (.summary.error // "")' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

exit $rc
