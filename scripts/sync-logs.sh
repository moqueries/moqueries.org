#!/usr/bin/env bash

set -xeEou pipefail

aws s3 sync s3://moqueries-logs logs/scratch

rm -f logs/prod-docs/*.log
for FILE in logs/scratch/prod-docs/*; do
  [[ $FILE =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}).* ]]
  OUT="logs/prod-docs/${BASH_REMATCH[1]}.log"
  gunzip < "$FILE" | grep -v '^#' >> "$OUT"
done

for FILE in logs/prod-docs/*; do
  sort "$FILE" > "$FILE.sorted"
  mv "$FILE.sorted" "$FILE"
done
