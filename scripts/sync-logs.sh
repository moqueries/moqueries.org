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
go-get-std, \
go-get-root, \
go-get-other, \
index-all, \
root, \
quick-start, \
using-mocks, \
gen-mocks, \
anatomy, \
index-other" > logs/prod-report.csv

for FILE in logs/prod-docs/*.log; do
  TOTAL=$(wc -l "$FILE" | awk '{ print $1 }')
  RC_2XX=0
  RC_4XX=0
  RC_OTHER=0
  GO_GETS=0
  GO_GET_FAILS=0
  GO_GET_CLI=0
  GO_GET_RUNTIME=0
  GO_GET_STD=0
  GO_GET_ROOT=0
  GO_GET_OTHER=0
  INDEX_ALL=0
  ROOT=0
  QUICK_START=0
  USING_MOCKS=0
  GEN_MOCKS=0
  ANATOMY=0
  INDEX_OTHER=0
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
        "/std")     (( GO_GET_STD++ ));;
        "/")        (( GO_GET_ROOT++ ));;
        *)          (( GO_GET_OTHER++ ));;
      esac
    fi
    if [[ $URI =~ .*/index.html ]]; then
      (( INDEX_ALL++ ))
      case $URI in
        "/quick-start/index.html")      (( QUICK_START++ ));;
        "/using-mocks/index.html")      (( USING_MOCKS++ ));;
        "/generating-mocks/index.html") (( GEN_MOCKS++ ));;
        *)
          if [[ $URI =~ /anatomy/.* ]]; then
            (( ANATOMY++ ))
          elif [[ $URI = "/index.html" ]]; then
            (( ROOT++ ))
          else
            (( INDEX_OTHER++ ))
          fi
          ;;
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
$GO_GET_STD, \
$GO_GET_ROOT, \
$GO_GET_OTHER, \
$INDEX_ALL, \
$ROOT, \
$QUICK_START, \
$USING_MOCKS, \
$GEN_MOCKS, \
$ANATOMY, \
$INDEX_OTHER" >> logs/prod-report.csv

  grep "go-get" "$FILE" > "logs/prod-docs/go-gets/$(basename "$FILE")" || true
  grep -v "go-get" "$FILE" > "${FILE%".log"}.other.log" || true
  mv "${FILE%".log"}.other.log" "$FILE"
done
