#!/usr/bin/env bash

[ -f /tmp/mysql-backup.lock ] && exit

touch /tmp/mysql-backup.lock

t1=$( date -u +%s )

db=$1
DAYOFWEEK=$(date +"%u")

  date=$( date -u +%Y-%m-%d_%H-%M_UTC )
  start_time=$( date -u +%s )
  cd /backup/

  echo "-------------------------------------"
  echo "Dumping $db…"
  mydumper --statement-size 10000000 --tz-utc --database "${db}" --triggers --events --routines --build-empty-files --outputdir /backup/tmp/"${db}"
  end_time1=$( date -u +%s )

  rm /backup/dumps/"${db}"-"${date}".tar.zst > /dev/null 2>&1

  echo "Archiving $db…"
  cd /backup/tmp/
  tar -cf - "${db}" | zstd -T0 -9 - -o /backup/dumps/"${db}"-"${date}".tar.zst

  echo "Cleaning up…"
  rm -rf "${db}"

  end_time2=$( date -u +%s )
  let time1=$end_time1-$start_time
  let time2=$end_time2-$end_time1
  echo "Done $db. Working time1: $time1, time2: $time2"
  echo
#done

t2=$( date -u +%s )
let full_time=$t2-$t1
echo "All done. Working time: $full_time"


mv /backup/dumps/"${db}"-"${date}".tar.zst /backup/hourly/

[ -f /backup/hourly/"${db}"-*_00-00_UTC.tar.zst ] && mv /backup/hourly/"${db}"-*_00-00_UTC.tar.zst /backup/daily/

if [[ "${DAYOFWEEK}" -eq 7 ]];
  then find /backup/daily/ -type f -daystart -mtime 0 -exec mv {} /backup/monthly/ \;
fi

echo "Cleaning up…"

find /backup/hourly/ -type f -mtime +2 -exec rm {} \;
find /backup/daily/ -type f -mtime +14 -exec rm {} \;
find /backup/monthly/ -type f -mtime +90 -exec rm {} \;

rm -rf /backup/dumps/* /tmp/mysql-backup.lock
