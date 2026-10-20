# Model checking: лабораторные 3–4 (TLA+/TLC, PRISM)

Система: турникет в метро (вариант 2), та же, что в [лабах 1–2](https://github.com/rudolf101/model_checking_lab1-2).

| Папка | Инструмент | Модель |
|---|---|---|
| `lab3-tla/` | TLA+ / TLC | `Turnstile.tla`: чередование действий, WF; конфигурации в `cfg/` |
| `lab4-prism/` | PRISM | `turnstile.pm`: DTMC, синхронизация по `[tick]`, сбои датчиков |
| `reports/` | | отчёты в PDF |

## Результаты

**TLC** (132 состояния, тупиков нет): `InvReject` + `P1Live`, `P2`, `P3Step` + `P3Live`, `L1` выполняются; `P4` нарушается («паровозик»); `W1–W3` нарушаются намеренно, это свидетели нетривиальности посылок.

**PRISM** (133 состояния; без сбоев датчиков 108, как в nuXmv):

| | Формула | Результат |
|---|---|---|
| PR1 | `filter(forall, P>=1 [ g=0 U l=2 ], "rejected")` | true |
| PR2 | `filter(forall, P>=0.95 [ l!=2 U<=10 u=3 ], "valid_card_presented")` | true (0.97) |
| PR3 | `P>=1 [ G F (c=0 & g=0) ]` | true |
| PR4 | `P<=0.01 [ F<=100 "free_ride" ]` | **false** (0.782) |

Ещё в отчёте: ожидаемые значения за 1000 тактов и время прохода.

## Запуск

```bash
TLA2TOOLS=/путь/tla2tools.jar bash lab3-tla/run.sh
bash lab4-prism/run.sh     # prism в PATH или PRISM=...
```
