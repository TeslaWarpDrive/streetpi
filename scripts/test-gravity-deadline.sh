#!/usr/bin/env bash
set -euo pipefail

# Build once, then run each repetition in a fresh test process.
filter='AwayGravityTests.testAPollAcrossTheDeadlineIsCancelled'
swift test --package-path StreetPiCore --filter "$filter"
log=$(mktemp)
trap 'rm -f "$log"' EXIT
for ((iteration = 1; iteration <= 200; iteration++)); do
    if ! swift test --package-path StreetPiCore --skip-build --filter "$filter" >"$log" 2>&1; then
        cat "$log"
        echo "Gravity deadline cancellation failed on repetition $iteration/200."
        exit 1
    fi
    if ((iteration % 25 == 0)); then
        echo "Gravity deadline cancellation passed $iteration/200 repetitions."
    fi
done
