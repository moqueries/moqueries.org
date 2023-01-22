#!/usr/bin/env bash

set -xeEou pipefail

aws s3 sync s3://moqueries-logs logs/sync

rm -rf logs/prod-docs
mkdir -p logs/prod-docs/go-gets
for FILE in logs/sync/prod-docs/*; do
  [[ $FILE =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}).* ]]
  OUT="logs/prod-docs/${BASH_REMATCH[1]}.log"
  gunzip < "$FILE" | grep -v '^#' >> "$OUT"
done

for FILE in logs/prod-docs/*.log; do
  sort "$FILE" > "$FILE.sorted"
  mv "$FILE.sorted" "$FILE"
done

echo "date, \
total, \
total-2xx, \
total-4xx, \
total-other, \
go-gets, \
go-get-fails, \
go-get-cli, \
go-get-runtime, \
go-get-other" > logs/prod-report.csv

for FILE in logs/prod-docs/*.log; do
  TOTAL=$(wc -l "$FILE" | awk '{ print $1 }')
  RC_2XX=0
  RC_4XX=0
  RC_OTHER=0
  GO_GETS=0
  GO_GET_FAILS=0
  GO_GET_CLI=0
  GO_GET_RUNTIME=0
  GO_GET_OTHER=0
  IFS="$(printf '\t')"; while read -r _ _ _ _ _ _ _ URI RC _ _ PARAMS _; do
    case ${RC:0:1} in
      2) (( RC_2XX++ ));;
      4) (( RC_4XX++ ));;
      *) (( RC_OTHER++ ));;
    esac
    if [[ "$PARAMS" == "go-get=1" ]]; then
      (( GO_GETS++ ))
      if [[ "$RC" != "200" ]]; then
        (( GO_GET_FAILS++ ))
      fi
      case $URI in
        "/cli")     (( GO_GET_CLI++ ));;
        "/runtime") (( GO_GET_RUNTIME++ ));;
        *)          (( GO_GET_OTHER++ ));;
      esac
    fi
  done < "$FILE"

  echo "$(basename "${FILE%".log"}"), \
$TOTAL, \
$RC_2XX, \
$RC_4XX, \
$RC_OTHER, \
$GO_GETS, \
$GO_GET_FAILS, \
$GO_GET_CLI, \
$GO_GET_RUNTIME, \
$GO_GET_OTHER" >> logs/prod-report.csv

  grep "go-get" "$FILE" > "logs/prod-docs/go-gets/$(basename "$FILE")" || true
  grep -v "go-get" "$FILE" > "${FILE%".log"}.other.log"
  mv "${FILE%".log"}.other.log" "$FILE"
done
