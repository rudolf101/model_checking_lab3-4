#!/usr/bin/env bash
# Лаба 4: прогон PRISM. Логи -> logs/
set -u
cd "$(dirname "$0")"
PRISM="${PRISM:-prism}"
command -v "$PRISM" >/dev/null || { echo "prism не найден: задайте PRISM=/путь/к/bin/prism"; exit 1; }
mkdir -p logs
# p_err и p_sneak в модели не определены, чтобы их можно было варьировать -const
BASE="p_err=0.03,p_sneak=0.3"
start=$(date +%s.%N)
"$PRISM" turnstile.pm turnstile.props -const "$BASE" -exportresults logs/results.txt > logs/prism.log 2>&1
echo "elapsed: $(awk "BEGIN{print $(date +%s.%N) - $start}") s" >> logs/prism.log

# Эксперимент 1: время прохода (K = 0..15)
"$PRISM" turnstile.pm experiments.props -const "K=0:1:15,$BASE" \
  -exportresults logs/exp_walk_by_K.csv:csv > logs/exp_walk_by_K.log 2>&1

# Эксперимент 2: влияние вероятности ложного отказа валидатора на PR2
"$PRISM" turnstile.pm turnstile.props -prop PR2_value -const p_err=0:0.01:0.1,p_sneak=0.3 \
  -exportresults logs/exp_p_err.csv:csv > logs/exp_p_err.log 2>&1

# Эксперимент 3: зависимость P(безбилетник за 100 тактов) от p_sneak
"$PRISM" turnstile.pm turnstile.props -prop PR4_value -const p_err=0.03,p_sneak=0:0.1:0.5 \
  -exportresults logs/exp_p_sneak.csv:csv > logs/exp_p_sneak.log 2>&1

echo "== Итог =="
grep -E "^(Model checking|Result)|States:|Transitions:|Error" logs/prism.log
echo; echo "== Эксперименты =="; cat logs/exp_walk_by_K.csv logs/exp_p_err.csv logs/exp_p_sneak.csv 2>/dev/null
