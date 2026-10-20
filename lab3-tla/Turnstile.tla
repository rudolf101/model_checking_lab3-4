----------------------------- MODULE Turnstile -----------------------------
(***************************************************************************)
(* Лабораторная работа №3. Турникет в метро (вариант 2), TLA+ / TLC.        *)
(* Модель с чередованием: каждый шаг - действие одного компонента.        *)
(*   Среда:        Arrive, Walk, Exit, GiveUp (пассажир),                  *)
(*                 IntrCome, IntrLeave, IntrSneak, IntrExit (безбилетник)  *)
(*   Датчики:      CardRead, TokenRead, PassSense                          *)
(*   Управление:   Grant, Deny, DenyDone, Close, Ready                     *)
(*   Актуаторы:    GateMove, LampSet                                       *)
(* Справедливость (WF) задана только для системы и «реакций» людей;      *)
(* приход пассажира и безбилетника справедливостью не ограничен.          *)
(***************************************************************************)

VARIABLES user, media, intr,       \* среда
          cardRes, tokenRes,       \* датчики оплаты (защёлка до чтения контроллером)
          beam, passed,            \* фотоэлемент: защёлка луча, импульс «проход»
          ctrl, gate, lamp,        \* контроллер и актуаторы
          crossed                  \* вспомогательная (ghost): кто-то прошёл с момента открытия

vars == <<user, media, intr, cardRes, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>

Media      == {"card_ok", "card_empty", "token_ok", "token_bad"}
CardMedia  == {"card_ok", "card_empty"}
TokenMedia == {"token_ok", "token_bad"}

paid     == cardRes = "ok"   \/ tokenRes = "ok"
rejected == cardRes = "fail" \/ tokenRes = "fail"

TypeOK ==
  /\ user     \in {"away", "approach", "wait", "walk"}
  /\ media    \in Media \cup {"none"}
  /\ intr     \in {"none", "behind", "sneak"}
  /\ cardRes  \in {"none", "ok", "fail"}
  /\ tokenRes \in {"none", "ok", "fail"}
  /\ beam \in BOOLEAN /\ passed \in BOOLEAN /\ crossed \in BOOLEAN
  /\ ctrl \in {"idle", "granted", "denied", "closing"}
  /\ gate \in {"closed", "open"}
  /\ lamp \in {"off", "green", "red"}

Init ==
  /\ user = "away" /\ media = "none" /\ intr = "none"
  /\ cardRes = "none" /\ tokenRes = "none"
  /\ beam = FALSE /\ passed = FALSE
  /\ ctrl = "idle" /\ gate = "closed" /\ lamp = "off"
  /\ crossed = FALSE

(* ---------------------------- пассажир -------------------------------- *)
Arrive ==   \* подходит к свободному турникету с произвольным носителем
  /\ user = "away" /\ gate = "closed" /\ lamp = "off"
  /\ user' = "approach" /\ media' \in Media
  /\ UNCHANGED <<intr, cardRes, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>

Walk ==     \* створки открыты - входит в проход
  /\ user = "wait" /\ gate = "open"
  /\ user' = "walk" /\ beam' = TRUE /\ crossed' = TRUE
  /\ UNCHANGED <<media, intr, cardRes, tokenRes, passed, ctrl, gate, lamp>>

Exit ==     \* выходит из прохода
  /\ user = "walk"
  /\ user' = "away" /\ media' = "none"
  /\ UNCHANGED <<intr, cardRes, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>

GiveUp ==   \* увидел красный, забрал носитель и ушёл
  /\ user = "wait" /\ lamp = "red"
  /\ user' = "away" /\ media' = "none"
  /\ UNCHANGED <<intr, cardRes, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>

(* --------------------------- безбилетник ------------------------------ *)
IntrCome  == intr = "none"   /\ intr' = "behind"
             /\ UNCHANGED <<user, media, cardRes, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>
IntrLeave == intr = "behind" /\ intr' = "none"
             /\ UNCHANGED <<user, media, cardRes, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>
IntrSneak == \* вплотную за пассажиром («паровозик»)
  /\ intr = "behind" /\ user = "walk"
  /\ intr' = "sneak" /\ beam' = TRUE /\ crossed' = TRUE
  /\ UNCHANGED <<user, media, cardRes, tokenRes, passed, ctrl, gate, lamp>>
IntrExit  == intr = "sneak"  /\ intr' = "none"
             /\ UNCHANGED <<user, media, cardRes, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>

(* ----------------------------- датчики -------------------------------- *)
CardRead ==
  /\ user = "approach" /\ media \in CardMedia /\ cardRes = "none"
  /\ cardRes' = IF media = "card_ok" THEN "ok" ELSE "fail"
  /\ user' = "wait"
  /\ UNCHANGED <<media, intr, tokenRes, beam, passed, ctrl, gate, lamp, crossed>>

TokenRead ==
  /\ user = "approach" /\ media \in TokenMedia /\ tokenRes = "none"
  /\ tokenRes' = IF media = "token_ok" THEN "ok" ELSE "fail"
  /\ user' = "wait"
  /\ UNCHANGED <<media, intr, cardRes, beam, passed, ctrl, gate, lamp, crossed>>

PassSense == \* луч перекрывался, проход освободился -> импульс «проход»
  /\ beam /\ user # "walk" /\ intr # "sneak" /\ ~passed
  /\ passed' = TRUE /\ beam' = FALSE
  /\ UNCHANGED <<user, media, intr, cardRes, tokenRes, ctrl, gate, lamp, crossed>>

(* ---------------------------- контроллер ------------------------------ *)
Grant ==
  /\ ctrl = "idle" /\ paid
  /\ ctrl' = "granted" /\ cardRes' = "none" /\ tokenRes' = "none"
  /\ UNCHANGED <<user, media, intr, beam, passed, gate, lamp, crossed>>

Deny ==
  /\ ctrl = "idle" /\ rejected
  /\ ctrl' = "denied" /\ cardRes' = "none" /\ tokenRes' = "none"
  /\ UNCHANGED <<user, media, intr, beam, passed, gate, lamp, crossed>>

DenyDone == \* красный показан и носитель забран (валидатор видит пустой слот)
  /\ ctrl = "denied" /\ lamp = "red" /\ media = "none"
  /\ ctrl' = "idle"
  /\ UNCHANGED <<user, media, intr, cardRes, tokenRes, beam, passed, gate, lamp, crossed>>

Close ==
  /\ ctrl = "granted" /\ passed
  /\ ctrl' = "closing" /\ passed' = FALSE
  /\ UNCHANGED <<user, media, intr, cardRes, tokenRes, beam, gate, lamp, crossed>>

Ready ==
  /\ ctrl = "closing" /\ gate = "closed"
  /\ ctrl' = "idle"
  /\ UNCHANGED <<user, media, intr, cardRes, tokenRes, beam, passed, gate, lamp, crossed>>

(* ---------------------------- актуаторы ------------------------------- *)
GateTarget == IF ctrl = "granted" THEN "open" ELSE "closed"
LampTarget == CASE ctrl = "granted" -> "green"
                [] ctrl = "denied"  -> "red"
                [] OTHER            -> "off"

GateMove ==
  /\ gate # GateTarget
  /\ gate' = GateTarget
  /\ crossed' = IF GateTarget = "open" THEN FALSE ELSE crossed
  /\ UNCHANGED <<user, media, intr, cardRes, tokenRes, beam, passed, ctrl, lamp>>

LampSet ==
  /\ lamp # LampTarget
  /\ lamp' = LampTarget
  /\ UNCHANGED <<user, media, intr, cardRes, tokenRes, beam, passed, ctrl, gate, crossed>>

(* ---------------------------------------------------------------------- *)
Env    == Arrive \/ Walk \/ Exit \/ GiveUp \/ IntrCome \/ IntrLeave \/ IntrSneak \/ IntrExit
System == CardRead \/ TokenRead \/ PassSense \/ Grant \/ Deny \/ DenyDone
          \/ Close \/ Ready \/ GateMove \/ LampSet
Next   == Env \/ System

Fairness ==
  /\ WF_vars(CardRead) /\ WF_vars(TokenRead) /\ WF_vars(PassSense)
  /\ WF_vars(Grant) /\ WF_vars(Deny) /\ WF_vars(DenyDone)
  /\ WF_vars(Close) /\ WF_vars(Ready)
  /\ WF_vars(GateMove) /\ WF_vars(LampSet)
  /\ WF_vars(Walk) /\ WF_vars(Exit) /\ WF_vars(GiveUp) /\ WF_vars(IntrExit)

Spec == Init /\ [][Next]_vars /\ Fairness

(* ============================== свойства ============================== *)
(* P1. Отказ => створки закрыты, пока не загорится красный.               *)
(*     В TLA+ нет U, поэтому  rejected => (closed U red)  записано как     *)
(*     безопасная часть (инвариант для всей фазы отказа) + живость (~>).    *)
InvReject == (rejected \/ (ctrl = "denied" /\ lamp # "red")) => gate = "closed"
P1Live    == rejected ~> lamp = "red"

(* P2. Подтверждённая оплата => пассажир пройдёт.                         *)
P2 == paid ~> user = "walk"

(* P3. Створки не закрываются, пока после открытия никто не прошёл       *)
(*     (свойство шагов), и открытые створки обязательно закроются.         *)
P3Step == [][gate = "open" /\ gate' = "closed" => crossed]_vars
P3Live == gate = "open" ~> gate = "closed"

(* P4. Без оплаты пройти нельзя. ОЖИДАЕТСЯ НАРУШЕНИЕ («паровозик»).       *)
P4 == intr # "sneak"

(* Живость системы: контроллер бесконечно часто свободен.                 *)
L1 == []<>(ctrl = "idle" /\ gate = "closed")

(* Свидетели нетривиальности посылок: ожидается НАРУШЕНИЕ, контрпример -  *)
(* поведение (лассо), где посылка выполняется бесконечно часто.          *)
W1 == <>[](~rejected)
W2 == <>[](~paid)
W3 == <>[](gate = "closed")
=============================================================================
