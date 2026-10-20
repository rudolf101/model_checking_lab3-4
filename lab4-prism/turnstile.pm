// =====================================================================
// Лабораторная работа №4. Турникет в метро (вариант 2), PRISM, DTMC.
// Все модули синхронизируются по общему действию [tick], поэтому
// семантика совпадает с синхронной моделью nuXmv из ЛР1: на каждом
// такте все компоненты делают шаг одновременно. Недетерминированные
// выборы среды заменены вероятностями, добавлены сбои датчиков.
// =====================================================================
dtmc

// ---------- кодировка значений ----------
const int AWAY=0;  const int APPROACH=1; const int WAIT=2; const int WALK=3;
const int NONE=0;  const int CARD_OK=1;  const int CARD_EMPTY=2; const int TOKEN_OK=3; const int TOKEN_BAD=4;
const int BEHIND=1; const int SNEAK=2;
const int OK=1;    const int FAIL=2;
const int IDLE=0;  const int GRANTED=1;  const int DENIED=2; const int CLOSING=3;
const int CLOSED=0; const int OPEN=1;
const int OFF=0;   const int GREEN=1;    const int RED=2;

// ---------- вероятностные параметры ----------
const double p_arr = 0.3;      // за такт к свободному турникету подходит пассажир
const double q_card_ok    = 0.55;  // распределение носителей
const double q_card_empty = 0.10;
const double q_token_ok   = 0.30;
const double q_token_bad  = 1 - q_card_ok - q_card_empty - q_token_ok;
const double p_err;            // (0.03, задаётся в run.sh) валидатор не прочитал исправную карту (ложный отказ)
const double p_fa  = 0.02;     // приёмник принял посторонний жетон (ложный приём)
const double p_int = 0.05;     // за такт появляется безбилетник
const double p_sneak;          // (0.3, задаётся в run.sh) безбилетник проскакивает при открытых створках
const double p_stay  = 0.5;    // ... или продолжает ждать

// ---------- пользователь / среда ----------
module passenger
  u : [0..3] init AWAY;
  m : [0..4] init NONE;
  [tick] u=AWAY -> (1-p_arr) : true
                 + p_arr*q_card_ok    : (u'=APPROACH)&(m'=CARD_OK)
                 + p_arr*q_card_empty : (u'=APPROACH)&(m'=CARD_EMPTY)
                 + p_arr*q_token_ok   : (u'=APPROACH)&(m'=TOKEN_OK)
                 + p_arr*q_token_bad  : (u'=APPROACH)&(m'=TOKEN_BAD);
  [tick] u=APPROACH                      -> (u'=WAIT);
  [tick] u=WAIT & g=OPEN                 -> (u'=WALK);
  [tick] u=WAIT & g=CLOSED & l=RED       -> (u'=AWAY)&(m'=NONE);
  [tick] u=WAIT & g=CLOSED & l!=RED      -> true;
  [tick] u=WALK                          -> (u'=AWAY)&(m'=NONE);
endmodule

module intruder
  i : [0..2] init NONE;
  [tick] i=NONE             -> (1-p_int) : true + p_int : (i'=BEHIND);
  [tick] i=BEHIND & g=OPEN  -> p_sneak : (i'=SNEAK) + p_stay : true + (1-p_sneak-p_stay) : (i'=NONE);
  [tick] i=BEHIND & g=CLOSED-> 0.8 : true + 0.2 : (i'=NONE);
  [tick] i=SNEAK            -> (i'=NONE);
endmodule

// ---------- датчики ----------
formula card_presented  = cr=NONE & u=APPROACH & (m=CARD_OK  | m=CARD_EMPTY);
formula token_presented = tr=NONE & u=APPROACH & (m=TOKEN_OK | m=TOKEN_BAD);

module card_reader
  cr : [0..2] init NONE;
  [tick] cr!=NONE & c=IDLE                 -> (cr'=NONE);
  [tick] card_presented & m=CARD_OK        -> (1-p_err) : (cr'=OK) + p_err : (cr'=FAIL);
  [tick] card_presented & m=CARD_EMPTY     -> (cr'=FAIL);
  [tick] !(cr!=NONE & c=IDLE) & !card_presented -> true;
endmodule

module token_acceptor
  tr : [0..2] init NONE;
  [tick] tr!=NONE & c=IDLE                 -> (tr'=NONE);
  [tick] token_presented & m=TOKEN_OK      -> (tr'=OK);
  [tick] token_presented & m=TOKEN_BAD     -> p_fa : (tr'=OK) + (1-p_fa) : (tr'=FAIL);
  [tick] !(tr!=NONE & c=IDLE) & !token_presented -> true;
endmodule

module pass_sensor
  beam : bool init false;
  [tick] true -> (beam' = (u=WALK | i=SNEAK));
endmodule

// ---------- управляющий алгоритм ----------
module controller
  c : [0..3] init IDLE;
  [tick] c=IDLE & (cr=OK | tr=OK)                               -> (c'=GRANTED);
  [tick] c=IDLE & !(cr=OK | tr=OK) & (cr=FAIL | tr=FAIL)        -> (c'=DENIED);
  [tick] c=IDLE & !(cr=OK | tr=OK) & !(cr=FAIL | tr=FAIL)       -> true;
  [tick] c=GRANTED & beam                                       -> (c'=CLOSING);
  [tick] c=GRANTED & !beam                                      -> true;
  [tick] c=DENIED                                               -> (c'=IDLE);
  [tick] c=CLOSING & g=CLOSED                                   -> (c'=IDLE);
  [tick] c=CLOSING & g=OPEN                                     -> true;
endmodule

// ---------- актуаторы ----------
module gate
  g : [0..1] init CLOSED;
  [tick] true -> (g' = (c=GRANTED ? OPEN : CLOSED));
endmodule

module lamp
  l : [0..2] init OFF;
  [tick] true -> (l' = (c=GRANTED ? GREEN : (c=DENIED ? RED : OFF)));
endmodule

// ---------- метки и награды ----------
label "paid"     = cr=OK   | tr=OK;
label "rejected" = cr=FAIL | tr=FAIL;
label "valid_card_presented" = u=APPROACH & m=CARD_OK;
label "free_ride" = i=SNEAK;

rewards "free_rides"  i=SNEAK : 1; endrewards   // безбилетных проходов
rewards "passengers"  u=WALK  : 1; endrewards   // оплаченных проходов
rewards "false_rejects" u=WAIT & l=RED & (m=CARD_OK) : 1; endrewards
