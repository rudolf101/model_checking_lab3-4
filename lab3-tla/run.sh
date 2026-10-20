#!/usr/bin/env bash
# Лаба 3: прогон TLC по каждому конфигу из cfg/. Логи -> logs/<ИМЯ>.log
# Нужен tla2tools.jar: export TLA2TOOLS=/путь/к/tla2tools.jar
set -u
cd "$(dirname "$0")"
JAR="${TLA2TOOLS:-$HOME/tla2tools.jar}"
[ -f "$JAR" ] || { echo "Не найден tla2tools.jar ($JAR). Задайте TLA2TOOLS=/путь/к/tla2tools.jar"; exit 1; }
mkdir -p logs build
for cfg in cfg/*.cfg; do
  name=$(basename "$cfg" .cfg)
  start=$(date +%s.%N)
  java -XX:+UseParallelGC -cp "$JAR" tlc2.TLC -workers auto -cleanup \
       -metadir "build/$name" -config "$cfg" Turnstile.tla > "logs/$name.log" 2>&1
  echo "elapsed: $(awk "BEGIN{print $(date +%s.%N) - $start}") s" >> "logs/$name.log"
  if grep -q "No error has been found" "logs/$name.log"; then res="OK (выполняется)"
  else res="НАРУШЕНИЕ: $(grep -m1 -E 'Error:|is violated' "logs/$name.log" | cut -c1-80)"; fi
  states=$(grep -m1 -Eo "[0-9]+ distinct states found" "logs/$name.log")
  printf "%-4s %-60s %s\n" "$name" "$res" "$states"
done | tee logs/summary.txt
