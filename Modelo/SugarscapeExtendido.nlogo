globals [
  gini-index-reserve
  lorenz-points
  deaths
  starvation            ;; accumulated number of deaths by starvation
  starvation-per-tick
  avg-gini              ;; average Gini index over the last 100 ticks
  ginis                 ;; a list of the last 100 gini index values
  deciles               ;; a list with the upper bounds of each decile
  gini                  ;; current gini index value
  total-wealth          ;; total wealth sum of all agents
  productivity          ;; a measure of sugar accumulation efficiency
  productivities        ;; a list of the last 100 productivity values
  avg-productivity      ;; average productivity value over the last 100 ticks
  treasury              ;; total taxes collected in this tick
  dist-by-decile        ;; distribution of wealth by decile
  medians-diff          ;; a list of the last 100 medians of the agent's difference of sugar
  avg-diff              ;; average of the agents' median sugar differences over the last 100 ticks
]

turtles-own [
  sugar           ;; the amount of sugar this turtle has
  metabolism      ;; the amount of sugar that each turtles loses each tick
  vision          ;; the distance that this turtle can see in the horizontal and vertical directions
  vision-points   ;; the points that this turtle can see in relative to it's current position (based on vision)
  age             ;; the current age of this turtle (in ticks)
  max-age         ;; the age at which this turtle will die of natural causes
  decile          ;; the decile to which this agent belongs
  changed         ;; indicates if there was a change of decile in this tick
  past-sugar      ;; the amount of sugar in the past tick
  diff-sugar      ;; the result of the difference of current sugar - past sugar
]

patches-own [
  psugar           ;; the amount of sugar on this patch
  max-psugar       ;; the maximum amount of sugar that can be on this patch
]

;;
;; Setup Procedures
;;

to setup

  if maximum-sugar-endowment <= minimum-sugar-endowment [
    stop
  ]
  clear-all
  create-turtles initial-population [ turtle-setup ]
  setup-patches
  setup-lists
  set total-wealth sum [sugar] of turtles
  update-lorenz-and-gini
  update-deciles
  set deaths 0
  set starvation 0
  set starvation-per-tick 0
  set gini 0
  set treasury 0
  set productivity total-wealth / count turtles
  set avg-productivity productivity
  set dist-by-decile []
  reset-ticks
end

to turtle-setup ;; turtle procedure
  set color red
  set shape "circle"
  move-to one-of patches with [not any? other turtles-here]
  set sugar random-in-range minimum-sugar-endowment maximum-sugar-endowment
  set metabolism random-in-range 1 4
  set max-age random-in-range 60 100
  set age random-normal 30 10
  set vision random-in-range 1 6
  set changed 0
  ;; turtles can look horizontally and vertically up to vision patches
  ;; but cannot look diagonally at all
  set vision-points []
  foreach (range 1 (vision + 1)) [ n ->
    set vision-points sentence vision-points (list (list 0 n) (list n 0) (list 0 (- n)) (list (- n) 0))
  ]
  run visualization
end

to setup-patches
  file-open "mapas-azucar/sugar-map.txt"
  foreach sort patches [ p ->
    ask p [
      set max-psugar file-read
      set psugar max-psugar
      patch-recolor
    ]
  ]
  file-close
end

to setup-lists
  set ginis []
  set productivities []
  set medians-diff []
  repeat 100[
    set ginis lput 0 ginis
    set productivities lput 0 productivities
    set medians-diff lput 0 medians-diff
  ]
end



;;
;; Runtime Procedures
;;

to go

  if maximum-sugar-endowment <= minimum-sugar-endowment [
    stop
  ]

  if not any? turtles [
    stop
  ]

  set starvation-per-tick 0

  ask patches [
    patch-growback
    patch-recolor
  ]
  ask turtles [
    set past-sugar sugar
    turtle-move
    turtle-eat
    set age (age + 1)
    let past-decile decile
    set decile my-current-decile
    ifelse decile != past-decile [set changed 1][set changed 0]
    if sugar <= 0 or age > max-age [
      hatch 1 [ turtle-setup ]
      set deaths (deaths + 1)
      if sugar <= 0 [
        set starvation (starvation + 1)
        set starvation-per-tick (starvation-per-tick + 1)
      ]
      die
    ]
    run visualization
  ]
  set total-wealth sum [sugar] of turtles

  let index 1
  set dist-by-decile []
  repeat 10 [
    let wealth 0
    let percent 0
    ask turtles with [decile = index][
      set wealth wealth + sugar
    ]
    set percent wealth / total-wealth
    set dist-by-decile lput percent dist-by-decile
    set index index + 1
  ]
  run taxation
  run redistribution
  ask turtles [set diff-sugar sugar - past-sugar]
  update-lorenz-and-gini
  update-deciles
  set gini (gini-index-reserve / count turtles) * 2
  set productivity total-wealth / count turtles
  update-avg-gini
  update-avg-productivity
  update-medians
  tick
end

to turtle-move ;; turtle procedure
  ;; consider moving to unoccupied patches in our vision, as well as staying at the current patch
  let choice random-float 1.0
  let move-candidates (patch-set patch-here (patches at-points vision-points) with [not any? turtles-here])
  ifelse choice < 0.8[ ; most of the times the agent will take the best patch
    let possible-winners move-candidates with-max [psugar]
    if any? possible-winners [
      ;; if there are any such patches move to one of the patches that is closest
      move-to min-one-of possible-winners [distance myself]
    ]
  ][; irrational agent, random choice
    move-to one-of move-candidates
  ]

end

to turtle-eat ;; turtle procedure
  ;; metabolize some sugar, and eat all the sugar on the current patch
  set sugar (sugar - metabolism + psugar)
  set psugar 0
end

to patch-recolor ;; patch procedure
  ;; color patches based on the amount of sugar they have
  set pcolor (yellow + 4.9 - psugar)
end

to patch-growback ;; patch procedure
  ;; gradually grow back all of the sugar for the patch
  set psugar min (list max-psugar (psugar + 1))
end

to update-lorenz-and-gini
  let num-people count turtles
  let sorted-wealths sort [sugar] of turtles
  let wealth-sum-so-far 0
  let index 0
  set gini-index-reserve 0
  set lorenz-points []
  repeat num-people [
    set wealth-sum-so-far (wealth-sum-so-far + item index sorted-wealths)
    set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
    set index (index + 1)
    set gini-index-reserve
      gini-index-reserve +
      (index / num-people) -
      (wealth-sum-so-far / total-wealth)
  ]
end

to update-avg-gini
  let index ticks mod 100
  set ginis replace-item index ginis gini ;; replaces the oldest value of the list with the current one
  ifelse ticks < 100 [set avg-gini gini][set avg-gini mean ginis]
end

to update-avg-productivity
  let index ticks mod 100
  set productivities replace-item index productivities productivity ;; replaces the oldest value of the list with the current one
  ifelse ticks < 100 [set avg-productivity productivity][set avg-productivity mean productivities]
end

to update-medians
  let median-diff median [diff-sugar] of turtles
  let index ticks mod 100
  set medians-diff replace-item index medians-diff median-diff ;;replaces the oldes value of the list with the current one
  ifelse ticks < 100 [set avg-diff median-diff][set avg-diff mean medians-diff]
end


to update-deciles ;; updates the upper bounds of the deciles for turtles to know their decile
  let sorted-wealths sort [sugar] of turtles
  let num-people count turtles
  set deciles [0 0 0 0 0 0 0 0 0 0]
  let batch int num-people / 10 ;divides the population in ten equal batches
  let index 0
  repeat 10[
    let current-upper item ( (index + 1) * batch - 1) sorted-wealths ; the upper bound of the current decile
    set deciles replace-item  index deciles current-upper
    set index (index + 1)
  ]
end

;;
;; Taxes methods
;;

;;
;; Gathering taxes
;;

to no-collection
end

to dynamic-collection
  let index 1
  repeat 10[
    let percent item (index - 1) dist-by-decile
    ask turtles with [decile = index][
      let my-contribution int(sugar * percent)
      set sugar sugar - my-contribution
      set treasury treasury + my-contribution
    ]
   set index index + 1
  ]
end

to linear-collection
  ask turtles[
    let my-percent (decile * 0.03)
    let my-contribution int(sugar * my-percent)
    set sugar sugar - my-contribution
    set treasury treasury + my-contribution
  ]
end

to uniform-collection
  ask turtles[
    let my-contribution int(sugar * 0.1)
    set sugar sugar - my-contribution
    set treasury treasury + my-contribution
  ]
end
;;
;; Redistribution
;;

to no-redistribution
end

to UBI ;; wealth redistribution method
  ;; Universal Basic Income
  let individual-income int(treasury / count turtles)
  let rounding-loss treasury mod count turtles ;; avoid rounding losses
  set treasury (treasury - individual-income * count turtles) + rounding-loss
  ask turtles[
    set sugar sugar + individual-income
  ]
end

to poorest ;; wealth redistribution method
  ;; Deciles 1 and 2 will recive an income
  let population (count turtles) / 10 ; population amount for any decile
  let total-i int(treasury * .6)
  let total-ii int(treasury * .4)
  let individual-i int (total-i / population)
  let individual-ii int (total-ii / population)

  get-welfare 1 individual-i
  get-welfare 2 individual-ii
  ; let's avoid rounding loses:
  let rounding-loss total-i mod population
  set rounding-loss (rounding-loss + (total-ii mod population))
  set treasury treasury + rounding-loss
end

to linear ;; wealth redistribution method
  ;; Every decile will recive an income
  let population (count turtles) / 10 ; population amount for any decile
  let i 1
  let dist-deciles [0 0 0 0 0 0 0 0 0 0 0]
  repeat 10[
    let my-dist (10 - i) / 45
    ; percentage of dist for decile. p.e. 9/45 = 20 % for decile I
    ; 8/45 = 17 % for decile II...
    set dist-deciles insert-item i dist-deciles my-dist
    set i i + 1
  ]
  set i 1
  repeat 10 [
    ; redistribution
    let current-dist item i dist-deciles
    let total-current int(treasury * current-dist)
    let individual int (total-current / population)
    get-welfare i individual
    ; prevents rounding losses
    let rounding-loss total-current mod population
    set treasury treasury + rounding-loss
    set i i + 1
  ]
end

to dynamic ;; wealth redistribution method
  ;; Every decile will recive an income
  let population (count turtles) / 10 ; population amount for any decile
  let i 1
  let j 9
  repeat 10[
    ; redistribution
    let percent item j dist-by-decile
    let total-current int(treasury * percent)
    let individual int (total-current / population)
    get-welfare i individual
    ; prevents rounding losses
    let rounding-loss total-current mod population
    set treasury treasury + rounding-loss
    set i i + 1
    set j j - 1
  ]

end

to get-welfare [my-decile  individual] ; distributes wealth to the specific decile
  ask turtles with [decile = my-decile] [
    set sugar (sugar + individual)
    set treasury (treasury - individual)
  ]
end

;;
;; Utilities
;;

to-report random-in-range [low high]
  report low + random (high - low + 1)
end

to-report my-current-decile ;; turtle procedure
  let my-decile 1
  let x 0
  let index 0
  repeat 10[
    set x item index deciles ;; the current upper bound
    ifelse (sugar >= x and index != 9) [
      set my-decile (my-decile + 1)
    ][
      report my-decile
    ]
    set index (index + 1)
  ]
  report my-decile
end

;;
;; Visualization Procedures
;;

to no-visualization ;; turtle procedure
  set color red
end

to color-agents-by-vision ;; turtle procedure
  set color red - (vision - 3.5)
end

to color-agents-by-metabolism ;; turtle procedure
  set color red + (metabolism - 2.5)
end

to color-agents-by-age
  set color blue - ( int(age / 10) * 10 )
end

to color-agents-by-decile
  set color blue - (decile - 1) * 10
end


; Copyright 2009 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
505
10
913
419
-1
-1
8.0
1
10
1
1
1
0
1
1
1
0
49
0
49
1
1
1
ticks
30.0

BUTTON
10
135
90
175
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
90
135
180
175
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
180
135
270
175
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

CHOOSER
10
190
290
235
visualization
visualization
"no-visualization" "color-agents-by-vision" "color-agents-by-metabolism" "color-agents-by-age" "color-agents-by-decile"
4

PLOT
915
10
1120
140
Distribución de riqueza
Azucar
Agentes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "set-histogram-num-bars 10\nset-plot-x-range 0 (max [sugar] of turtles + 1)\nset-plot-pen-interval (max [sugar] of turtles + 1) / 10\nhistogram [sugar] of turtles"

SLIDER
10
10
290
43
initial-population
initial-population
10
1000
400.0
10
1
NIL
HORIZONTAL

SLIDER
10
50
290
83
minimum-sugar-endowment
minimum-sugar-endowment
0
200
11.0
1
1
NIL
HORIZONTAL

PLOT
915
145
1120
295
curva de Lorenz
Pob %
Riqueza %
0.0
100.0
0.0
100.0
false
true
"" ""
PENS
"identidad" 100.0 0 -16777216 true ";; draw a straight line from lower left to upper right\nset-current-plot-pen \"identidad\"\nplot 0\nplot 100" ""
"lorenz" 1.0 0 -2674135 true "" "plot-pen-reset\nset-plot-pen-interval 100 / count turtles\nplot 0\nforeach lorenz-points plot"

PLOT
915
300
1120
440
indice Gini vs. tiempo
Tiempo
Gini
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" "plot gini"

SLIDER
10
90
290
123
maximum-sugar-endowment
maximum-sugar-endowment
0
200
20.0
1
1
NIL
HORIZONTAL

MONITOR
25
350
137
395
Muertes totales
deaths
1
1
11

MONITOR
25
300
160
345
Muertes por hambruna
starvation
17
1
11

PLOT
1125
145
1335
295
Edades
edades
cantidad
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "set-histogram-num-bars 10\nset-plot-x-range 0 (max [age] of turtles + 1)\nset-plot-pen-interval (max [age] of turtles + 1) / 10\nhistogram [age] of turtles"

MONITOR
25
250
137
295
Edad promedio
mean [age] of turtles
0
1
11

MONITOR
280
140
335
185
gini
avg-gini
3
1
11

TEXTBOX
305
190
475
235
monitores del promedio en las ultimos 100 ticks
12
0.0
1

PLOT
1125
10
1330
140
Riqueza per cápita
tiempo
porducción
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot productivity"

MONITOR
335
140
432
185
R per capita
avg-productivity
2
1
11

CHOOSER
295
70
467
115
redistribution
redistribution
"no-redistribution" "UBI" "poorest" "linear" "dynamic"
0

PLOT
1130
305
1335
440
Impuestos recaudados
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot treasury"

CHOOSER
295
20
487
65
taxation
taxation
"no-collection" "linear-collection" "dynamic-collection" "uniform-collection"
0

PLOT
290
285
490
435
Cambios de decil
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [changed] of turtles"

MONITOR
435
140
497
185
NIL
avg-diff
17
1
11

@#$#@#$#@
## WHAT IS IT?

This third model in the NetLogo Sugarscape suite implements Epstein & Axtell's Sugarscape Wealth Distribution model, as described in chapter 2 of their book Growing Artificial Societies: Social Science from the Bottom Up. It provides a ground-up simulation of inequality in wealth. Only a minority of the population have above average wealth, while most agents have wealth near the same level as the initial endowment.

The inequity of the resulting distribution can be described graphically by the Lorenz curve and quantitatively by the Gini coefficient.

## HOW IT WORKS

Each patch contains some sugar, the maximum amount of which is predetermined. At each tick, each patch regains one unit of sugar, until it reaches the maximum amount.
The amount of sugar a patch currently contains is indicated by its color; the darker the yellow, the more sugar.

At setup, agents are placed at random within the world. Each agent can only see a certain distance horizontally and vertically. At each tick, each agent will move to the nearest unoccupied location within their vision range with the most sugar, and collect all the sugar there.  If its current location has as much or more sugar than any unoccupied location it can see, it will stay put.

Agents also use (and thus lose) a certain amount of sugar each tick, based on their metabolism rates. If an agent runs out of sugar, it dies.

Each agent also has a maximum age, which is assigned randomly from the range 60 to 100 ticks.  When the agent reaches an age beyond its maximum age, it dies.

Whenever an agent dies (either from starvation or old age), a new randomly initialized agent is created somewhere in the world; hence, in this model the global population count stays constant.

## HOW TO USE IT

The INITIAL-POPULATION slider sets how many agents are in the world.

The MINIMUM-SUGAR-ENDOWMENT and MAXIMUM-SUGAR-ENDOWMENT sliders set the initial amount of sugar ("wealth") each agent has when it hatches. The actual value is randomly chosen from the given range.

Press SETUP to populate the world with agents and import the sugar map data. GO will run the simulation continuously, while GO ONCE will run one tick.

The VISUALIZATION chooser gives different visualization options and may be changed while the GO button is pressed. When NO-VISUALIZATION is selected all the agents will be red. When COLOR-AGENTS-BY-VISION is selected the agents with the longest vision will be darkest and, similarly, when COLOR-AGENTS-BY-METABOLISM is selected the agents with the lowest metabolism will be darkest.

The WEALTH-DISTRIBUTION histogram on the right shows the distribution of wealth.

The LORENZ CURVE plot shows what percent of the wealth is held by what percent of the population, and the the GINI-INDEX V. TIME plot shows a measure of the inequity of the distribution over time.  A GINI-INDEX of 0 equates to everyone having the exact same amount of wealth (collected sugar), and a GINI-INDEX of 1 equates to the most skewed wealth distribution possible, where a single person has all the sugar, and no one else has any.

## THINGS TO NOTICE

After running the model for a while, the wealth distribution histogram shows that there are many more agents with low wealth than agents with high wealth.

Some agents will have less than the minimum initial wealth (MINIMUM-SUGAR-ENDOWMENT), if the minimum initial wealth was greater than 0.

## THINGS TO TRY

How does the initial population affect the wealth distribution? How long does it take for the skewed distribution to emerge?

How is the wealth distribution affected when you change the initial endowments of wealth?

## NETLOGO FEATURES

All of the Sugarscape models create the world by using `file-read` to import data from an external file, `sugar-map.txt`. This file defines both the initial and the maximum sugar value for each patch in the world.

Since agents cannot see diagonally we cannot use `in-radius` to find the patches in the agents' vision.  Instead, we use `at-points`.

## RELATED MODELS

Other models in the NetLogo Sugarscape suite include:

* Sugarscape 1 Immediate Growback
* Sugarscape 2 Constant Growback

For more explanation of the Lorenz curve and the Gini index, see the Info tab of the Wealth Distribution model.  (That model is also based on Epstein and Axtell's Sugarscape model, but more loosely.)

## CREDITS AND REFERENCES

Epstein, J. and Axtell, R. (1996). Growing Artificial Societies: Social Science from the Bottom Up.  Washington, D.C.: Brookings Institution Press.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Li, J. and Wilensky, U. (2009).  NetLogo Sugarscape 3 Wealth Distribution model.  http://ccl.northwestern.edu/netlogo/models/Sugarscape3WealthDistribution.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2009 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2009 Cite: Li, J. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="dinamico-dinamico" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;dynamic-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;dynamic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="lineal-lineal" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;linear-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="lineal-dirigidos" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;linear-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;poorest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="uniforme-uniforme" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;uniform-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;UBI&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="dinamico-linear" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;dynamic-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="dinamico-uniforme" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;dynamic-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;UBI&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="lineal-dinamico" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;linear-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;dynamic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="linear-uniforme" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;linear-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;UBI&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="uniforme-dinamico" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;uniform-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;dynamic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="uniforme-lineal" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;uniform-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;linear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sin politicas" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>avg-gini</metric>
    <metric>starvation</metric>
    <metric>avg-productivity</metric>
    <metric>total-wealth</metric>
    <metric>avg-diff</metric>
    <steppedValueSet variable="maximum-sugar-endowment" first="0" step="10" last="200"/>
    <steppedValueSet variable="minimum-sugar-endowment" first="0" step="10" last="200"/>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;color-agents-by-decile&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="taxation">
      <value value="&quot;no-collection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="redistribution">
      <value value="&quot;no-redistribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
