extensions [ view2.5d ]
globals [ 
  
  full-absorption
  
  doing-flood
  flood-type
  continuing-effects-counter 
  
  ;;for getting floodplane estimates
  trials-index
  trial-types
  trial-colors
  
  ;;flooding
  normal-depth
  river-width
  riverbed riverbank river-area non-rivers non-riverbeds
  riverbedpatchlist
  
  bank-alt-list
  upstream downstream midstream allbutleft
  dislevels
  
  flood-percentile-param
  
  bank-mean-height
  bank-low-quartile-height
  bank-high-quartile-height
  flood-proportions
  sorted-bank-altitudes
 
 
  max-land-patch-depth 
  depth-threshold
  
  diseq-going
  
  ;;topography
  foothill-alt foothill-y
    
  field1 field2 field3   ;;patchsets
  f1cc f2cc f3cc         ;;patches
  city-centers
  taxbase1
  taxbase2
  taxbase3
  
  max-patch-pop
  
  relevants  ;;restricted patchset for keeping flood metrix
  floodcost1
  floodcost2
  floodcost3
  
  
  ;land-market 
  land-market-year
  ;population
  shifted-house
  
  pop-assess-proximity
  pop-assess-safety
  
  initial-population
  income-distribution
  population-growth
 
  winnum
  
  available-areas
  default-zoom-level 
  default-levee-height
  default-levee-extent
  default-center-levee-at
  initial-funds-available 
  
  stop-to-make-policy ;;flag to be in listen-clients mode to take hubnet interactions
  
  bankabsorb
  do-rain
  ]


breed [ players player ]
players-own [ my-area-number user-id  my-center
  zoom-level
  levee-height 
  levee-extent
  funds-available
  tax-base
  total-flood-damage
  center-levee-at
  levee-cost
  total-funds-spent
  maintenance-cost
  ]


breed [ citizens citizen ]
breed [ citycenters citycenter ]
citycenters-own [ area-number ]

patches-own [ 
  depth delz 
  
  crossed-flood-threshold
  max-depth-this-flood
  
  bank-rim? 
  
  absorption-rate 
  
  altitude 
  pop-density
  
  prox-value
  safe-value
  value
  
  city-center?
  my-city-center
  
  floodplane-results
  
  test-altitude  ;;original altitude for testing cost of levee construction
  real-pcolor
  ]

citizens-own [ 
  my-center-of-city
  income 
  desire-for-proximity
  desire-for-safety
  low-income-housed?
  ]


to setup-partsim
    hubnet-reset
    setup-partsim-vars
end
to setup-partsim-vars
  set available-areas [1 2 3]
  setup-default-player-values
end

to setup
  ca 
  set bankabsorb 0.36  ;;remove these interface elements
  set do-rain true    ;;remove these interface elements
  
  setup-partsim
  reset-ticks
  set max-patch-pop 6
  set depth-threshold .5
  set-default-shape citycenters "star"
  set-default-shape citizens "circle"
  setup-floodplane-trials
   user-message "Select Bank Topography file"
  setup-income-and-population-growth
  setup-land 
  tick
  place-initial-population
 ; setup-flood-parameters
 user-message "Select Food-Level Distribution file"
 import-flood-proportions-from-file
  set land-market-year 0
  set stop-to-make-policy true
  set doing-flood false
  set continuing-effects-counter 0
  setup-floodplane-trials
  user-message "Do floodplane calculations now (before pressing 'Go'),\nif you want floodplanes to factor into the simulation"
  calculate-taxbases
  tick
  ask patches [ set real-pcolor pcolor ]
  view2.5d:update-all-patch-views
end

to setup-land
  set full-absorption .02
  set foothill-alt 17  ;25
  set foothill-y min-pycor + 5 * world-height / 6
  setup-riverpatches
  import-topography-from-file
  create-city-centers
end

to create-city-centers
  ask patches [ set my-city-center nobody ]
  set field1 patch-set patches with [ not member? self riverbed and pxcor < min-pxcor / 3 ]
  set field2 patch-set patches with [ not member? self riverbed and pxcor >= min-pxcor / 3 and pxcor <= max-pxcor / 3 ]
  set field3 patch-set patches with [ not member? self riverbed and pxcor > max-pxcor / 3 ]
 
  let channel-top [pycor] of one-of riverbank
  set f1cc max-n-of 1 field1 with [ not member? self riverbank and pycor < channel-top + 3] [ altitude ]
  set f2cc max-n-of 1 field2 with [ not member? self riverbank and pycor < channel-top + 3] [ altitude ]
  set f3cc max-n-of 1 field3 with [ not member? self riverbank and pycor < channel-top + 3] [ altitude ]
  ask f1cc [ set city-center? true set pcolor brown sprout-citycenters 1 [ set color orange set size 2.5 set area-number 1 ]]
  ask f2cc [ set city-center? true set pcolor brown sprout-citycenters 1 [ set color orange set size 2.5 set area-number 2 ]]
  ask f3cc [ set city-center? true set pcolor brown sprout-citycenters 1 [ set color orange set size 2.5 set area-number 3 ]]
  ask field1 [ set my-city-center one-of f1cc ]
  ask field2 [ set my-city-center one-of f2cc ]
  ask field3 [ set my-city-center one-of f3cc ]
  
  set city-centers (patch-set f1cc f2cc f3cc)
end


to setup-flood-with-likelihood [ thousandths ]
  set flood-percentile-param item thousandths flood-proportions
  set flood-percentile-param 2 * ( flood-percentile-param - .54)
  if (flood-percentile-param < 0) [ set flood-percentile-param 0 ]
  ;let duration-param 100 * flood-percentile-param
  let duration-param 50 * flood-percentile-param
  show (word "duration = " (3 * duration-param))
  let bank-index floor (flood-percentile-param * length sorted-bank-altitudes)
  if (bank-index > (length sorted-bank-altitudes - 1) ) [ set bank-index length sorted-bank-altitudes - 1 ]
  let flood-max-alt ( item bank-index sorted-bank-altitudes + .81) ;;change --> highest point is .8 units above the chosen bank point.
  show (word "index chosen is " bank-index)
  set flood-max-alt flood-max-alt - normal-depth
  show (word "max surge height = " flood-max-alt)
  set dislevels []
  let index 0
  while [ index < duration-param * 3 ] 
  [
   set dislevels lput (get-height-for-flood index flood-max-alt duration-param) dislevels
   set index index + 1
  ]
  show (word "FLOOD:  duration = " length dislevels " and LEVELS = " dislevels)
   
end

to-report get-height-for-flood [ index flood-max-alt duration-param ]
  ;show (word "for index = " index " and max alt = " flood-max-alt " and duration param = " duration-param )
  let toreport 0
  ifelse index <= duration-param 
  [
    set toreport (flood-max-alt * index ) / duration-param  ;;Alt(t) on [ 0, D] = A*t/D  so that when t  = D, we have achieved max alt A
  ]
  [
    set toreport flood-max-alt - (  (flood-max-alt / (2 * duration-param)) * (index - duration-param)  ) ;;Alt(t) on [D, 3D] = A - (A/2D)*(t-D), so that when t=D, we pick up at max alt A, then at t=3D, Alt = 0
  ]
 ; show (word "im getting " toreport)
  report toreport
end


to setup-riverpatches
  set normal-depth 10
  set river-width 10

  ask patches [ set pcolor white set depth 0  set absorption-rate full-absorption ]
  set riverbed patches with [ pycor >= min-pycor and pycor < min-pycor + river-width ] 
  set riverbank patches with [ pycor = min-pycor + river-width  ] 
  ask patches with [ pycor = min-pycor + river-width + 1 ] [ set bank-rim? true ] 
  
  set river-area patches with [ not member? self riverbank and  pycor >= min-pycor and pycor < min-pycor + 2 * river-width ] 
  ask riverbed [ set pcolor blue set depth normal-depth ]
  ask riverbank [ set pcolor lime  ]
  set non-riverbeds patches with [ not member? self riverbed  ]
  set non-rivers non-riverbeds with [ not member? self riverbank ]
 
  set downstream riverbed with [ pxcor = min-pxcor ]
  set upstream riverbed with [ pxcor = max-pxcor ]
  set midstream riverbed with [ pxcor > min-pxcor and pxcor < max-pxcor ]
  set allbutleft (patch-set upstream midstream)
  
  set riverbedpatchlist []
  let index min-pxcor
  while [ index < max-pxcor  ]  [
   set riverbedpatchlist lput ( riverbed with [ pxcor = index ] ) riverbedpatchlist
   set index index + 1 
  ]
  
end


to setup-floodplane-trials
  reset-ticks
  set trials-index 0
  set trial-types [ 10 20 50 100 200 500 1000 ]
  set trial-colors [ white red orange magenta pink violet yellow ]
  
  set doing-flood false
  ask patches [ set floodplane-results n-values (length trial-types) [false] ]
end

to run-floodplane-trials
  ifelse ( doing-flood ) [
   go-flooding 
   if (ticks mod 2 = 0) [  ask non-rivers with [ depth > .75 ] [ set floodplane-results replace-item trials-index floodplane-results true ]  ]
  ]
  [
    set trials-index trials-index + 1
    ifelse (trials-index < length trial-types ) [
     set flood-type item trials-index trial-types 
     set doing-flood true
     let frandnum 1000 - (1000 / flood-type)
     setup-flood-with-likelihood frandnum
     set diseq-going false
     
     reset-flood-metrix 
     set continuing-effects-counter 0 
     disequilib
    ]
    [
      show-all-floodplanes
      stop
    ]
  ]
  tick
end

to show-floodplane [ index ]
  no-display
  ask non-rivers [ set pcolor white ]
  ask non-rivers with [ item index floodplane-results = true ] [ set pcolor red ]
  display
end

to show-all-floodplanes 
  no-display 
  ask non-rivers [ set pcolor white ]
  let i length trial-types - 1
  while [i > 0] [
  let c item i trial-colors
  ask non-rivers with [ item i floodplane-results = true ] [ set pcolor c ]
  set i i - 1
  ]
  display
end

to go
  if (land-market-year mod 20 = 0 and  stop-to-make-policy) [ user-message "Pause to allow participants to Discuss and make policy" listen-clients false set stop-to-make-policy false stop ]
  if (land-market-year >= length population-growth ) [ user-message "Simulation Complete"  stop] 
  ask riverbank [ set pcolor real-pcolor ]
  ifelse (doing-flood) [ 
    go-flooding
  ]
  [
    listen-clients false
    update-objective-land-values
 ;;   show (word count citizens with [ value > income] " have to move.")
    ask citizens with [ low-income-housed? = false ] [ if value > income [ settle ] ]
    let new-cits (item land-market-year population-growth) - count citizens
 ;;   show (word "New citizens in region: " new-cits)
    repeat new-cits [
      add-new-citizen-to-region
    ] 
    ask non-rivers [ let x ( (max-patch-pop - count citizens-here) / max-patch-pop ) set absorption-rate (.1 * full-absorption) + (full-absorption * 0.9) * x * x * x]
    
    color-as-desired
    
    ;;DECIDE WHETHER WE ARE GOING INTO 'flood mode'
    let floodrnd random 1000  ; change code to "let floodrnd 999" to simulate 1000 year flood
    ;if (floodrnd > 899) [
    if (floodrnd > 949) [   ;;show only 20 year floods and more severe. 
     ; set floodrnd 996 ; 500 year ish flood 
      set doing-flood true
      setup-flood-with-likelihood floodrnd
      set diseq-going false
      set flood-type precision (1000 / (1000 - floodrnd)) 0
    ]
;    if (floodrnd < 10) [ set doing-flood true   set flood-type 100 set dislevels dislevels100 ]
;    if (floodrnd < 2) [ set doing-flood true  set flood-type 500 set dislevels dislevels500 ]
;    if (floodrnd < 1) [ set doing-flood true  set flood-type 1000 set dislevels dislevels1000 ]
    if (doing-flood = true) [ user-message (word "We have a " flood-type " year flood event") reset-flood-metrix set continuing-effects-counter 0 disequilib]
   
    calculate-taxbases
    update-player-info
    set land-market-year land-market-year + 1
    set stop-to-make-policy true
  ]
  tick
  view2.5d:update-all-patch-views
end



;;run by go when flood is active or region is recovering
to go-flooding 
  
  if (do-rain = true and continuing-effects-counter < 100)
  [
    ;let modfloodtype (470 + flood-type / 20)
    ;let rain-amount  modfloodtype / 36000 + random-float (modfloodtype / 36000)
    ;let modfloodtype (470 + flood-type / 20)
    let rain-amount  flood-percentile-param * .011 + random-float (.004)
    ;show rain-amount
    rain rain-amount
  ]
  ;;steady flow via influx
  let flow .08 + random-float .03
  
  ;;saved as a global so that we can avoid a costly monitor
  set max-land-patch-depth max [ depth ] of non-rivers
  
  ask upstream [ set depth depth + flow  ]
  
  ifelse (diseq-going != false) [ disequilib ]
  [ set continuing-effects-counter continuing-effects-counter + 1 ]
  
  if (continuing-effects-counter > world-width  and  max-land-patch-depth < 0.2 ) [ calculate-flood-damage set doing-flood false ] 
  
  let lev min [depth] of riverbed
  set lev max (list lev normal-depth )
  
  ask riverbed [ set delz depth - lev ]
  
  let index 0
  while [ index < world-width - 1  ]  [
    ask item index riverbedpatchlist
    [
      let nbr patch-at 1 0 
      let pull [delz] of nbr + random-float .5 - .25 
      if ( pull > 0 ) [
        set depth depth + pull 
        ask nbr [ set depth depth - pull ]
      ]
    ]
    set index index + 1
  ]
  
  ask downstream [  
    if depth > lev [ set depth depth - flow ] 
    if depth > lev [ set depth depth - ((depth - lev) / 2) ] 
  ]
  
  repeat 4 [ 
    diffuse depth .1
    


;;TODO -- re-examine
    ask riverbank [ 
      let compare [depth] of patch-at 0 -1
      let giveback depth
      if compare > altitude [ 
        if pcolor != brown [  set giveback (min (list bankabsorb depth ))  ]
        ask patch-at 0 1 [ set depth depth + giveback] 
      ]
      ;[
        ;let giveback (min (list bankabsorb depth))
        set depth depth - giveback 
      ;]
      ask patch-at 0 -1 [ set depth depth + .85 * giveback ] 
      ask patch-at 0 -2 [ set depth depth + .15 * giveback ] 
      
    ]
  ]
  
  ask riverbed [ set pcolor scale-color blue depth (2.5 * normal-depth ) 0.3 ]
 
  ask non-rivers [ 
   absorb-and-flow-groundwater 
  ]
  
  if ticks mod 10 = 0 [  update-flood-metrix  ]
  
  color-by-depth
end

to calculate-flood-damage
    let f1damage 0
    let f2damage 0
    let f3damage 0
    no-display
    ask non-rivers [ set pcolor white ]
    
    ask field1 [ if (crossed-flood-threshold < ticks - 40) [ let dam max-depth-this-flood * count citizens-here * value if not member? self riverbank [ set pcolor scale-color red dam 40 0 ] set f1damage f1damage + dam ] ]
    ask field2 [ if (crossed-flood-threshold < ticks - 40) [ let dam max-depth-this-flood * count citizens-here * value if not member? self riverbank [ set pcolor scale-color red dam 40 0 ] set f2damage f2damage + dam ] ]
    ask field3 [ if (crossed-flood-threshold < ticks - 40) [ let dam max-depth-this-flood * count citizens-here * value if not member? self riverbank [ set pcolor scale-color red dam 40 0 ] set f3damage f3damage + dam ] ]
    show (word "DAMAGE: Group 1: " precision f1damage 1 ", Group 2: " precision f2damage 1 ", Group 3: " precision f3damage 1 )
    set floodcost1 floodcost1 + f1damage
    set floodcost2 floodcost2 + f2damage
    set floodcost3 floodcost3 + f3damage
    ;;color by damage
 
    update-player-info
    display
    user-message (word "The flood caused the following DAMAGE: Group 1: " precision f1damage 1 ", Group 2: " precision f2damage 1 ", Group 3: " precision f3damage 1 )
    
end

to reset-flood-metrix 
  ask non-rivers [ set crossed-flood-threshold 0 set max-depth-this-flood 0 ] 
  set relevants  non-rivers with [count citizens-here > 0]
end

to update-flood-metrix
  ask relevants with [ depth > 0 ] [ 
    if (  crossed-flood-threshold = 0  and depth > depth-threshold ) [ set crossed-flood-threshold ticks ] 
    if ( crossed-flood-threshold > 0 ) [ if depth > max-depth-this-flood [ set max-depth-this-flood depth ] ]
  ]
end

to disequilib
  if ( diseq-going  = false )
  [
    set diseq-going ticks
  ]
   ;;addition to the steady-state flow.
   ask upstream [ set depth depth + item (ticks - diseq-going) dislevels ]
   if (ticks - diseq-going)  >= length dislevels - 1 [ set diseq-going false  ]
end


to rain [ amount ]
  ask non-rivers [ set depth depth + amount] 
end

to absorb-and-flow-groundwater 
  if depth > 0 [
    set depth max (list (depth - absorption-rate) 0) 
    ifelse (bank-rim? != true) [
      let low min-one-of neighbors [ depth + altitude ] 
      let diff (depth + altitude) -  [depth + altitude] of low  
      if (diff > 0) [ let give min ( list (diff / 2) (depth / 2) ) set depth depth - give ask low [ set depth depth + give ] ]
    ]
    [
      let togive min (list (2 * depth / 3) bankabsorb)
      ask riverbed with [ pxcor = [pxcor] of myself] [ set depth depth + togive / river-width ] 
      set depth depth - togive
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;LAND MARKET PROCEDURES
; idea.  land has 2 merits.  prox to center and perceived safety
; to evaluate land.  give both a score 0 - 10
; then do a weighted average based on the mean of the population's preferences. <-- minus .05 * population here.
;
; population has
; income, desire for proximity, desire for safety, and inertia (to moving)
; new settlers choose the 'best' patch they can afford.
; existing people may choose to move when their inertia is overcome (initially inertia is zero)
; 
; calculate land value 
; question: how to deal with population density
; proposal: each person moving in on a patch reduces the patch value by some constant (.05 to start - see above)
; and there's a max density of population, which equals 10 * prox-value (to start) -- linear increase in pop density w/ distance to city center.


to setup-income-and-population-growth
  set initial-population 1500
  set income-distribution n-values 300 [ get-income-val ]
  set population-growth (list initial-population)
  let last-population initial-population
  let i 0
  while [ i < 99 ] [ 
    let grow round (random-normal 100 20)
    set population-growth lput (last-population + grow) population-growth
    set last-population last-population + grow
    set i i + 1
  ]
end

to-report get-income-val
  let v random-normal 5 2.5
  if v < 0 [ set v 0 ]
  if v > 9.9 [ set v 9.9]
  report round v
end

to place-initial-population
  update-objective-land-values
 
  ;show date-and-time
  repeat initial-population [
   add-new-citizen-to-region 
  ]
  ;show date-and-time
end

to settle
  let cc my-center-of-city
  let candidates non-riverbeds with [ my-city-center = cc and pycor <= foothill-y and count citizens-here < max-patch-pop]
  let homeless-destination min-one-of candidates [value] 
  let inc income
  let choices candidates with [ value <= inc ]
  ifelse any? choices [ 
    let dfs desire-for-safety
    let dfp desire-for-proximity
    let goal max-one-of choices  [ safe-value * dfs  + prox-value * dfp - population-value-penalty ]
    move-to goal
    set low-income-housed? false
  ]
  [ 
    ;show (word "Homeless:  Income = " income " and min value of candidates = " min [value] of candidates ". Moving to homeless destination, with value = " [value] of homeless-destination )
    set low-income-housed? true
    move-to homeless-destination 
  ]
end


to add-new-citizen-to-region 
  create-citizens 1 [ 
    set my-center-of-city one-of city-centers
    set income one-of income-distribution
    set desire-for-proximity choose-desire-for-proximity
    set desire-for-safety choose-desire-for-safety
    set size .65
    set color gray
    settle
  ]
end

to update-objective-land-values 
  if count citizens >= initial-population
   [  update-collective-value ]
  ask non-riverbeds [
      calculate-patch-merits-and-value
  ]
  let max-safe-val max [ safe-value ] of patches
  ask patches [ set safe-value 10 * safe-value / max-safe-val ]
  ask patches [ set value value-function ]
end

to update-collective-value
  set pop-assess-proximity mean [ desire-for-proximity ] of citizens
  set pop-assess-safety mean [ desire-for-safety ] of citizens 
end

to calculate-patch-merits-and-value
  ifelse  ( city-center? = true ) 
  [ set prox-value 10 ]
  [
    let ceiling-distance 10
    let pval (min (list (distance my-city-center) ceiling-distance))
    set prox-value 10 * (ceiling-distance - pval) / ceiling-distance
  ]
  
  set safe-value safe-value-function 
  
  ifelse count citizens < initial-population 
  [
    set value value-function - population-value-penalty
  ]
  [
    set value pop-assess-proximity * prox-value + pop-assess-safety * safe-value - population-value-penalty
  ]
end

to-report population-value-penalty
  report 2 * (count citizens-here / max-patch-pop)
end
to-report choose-desire-for-proximity
  report .2 + random-float 8
end

to-report choose-desire-for-safety
  report 1 - desire-for-proximity
end

to-report safe-value-function
  let bankpatch riverbank with [ pxcor = [pxcor] of myself ]
  let dist-factor ( pycor - ( min-pycor + river-width ) ) * .08
  let sval 2 * (max (list (altitude + dist-factor) [altitude] of bankpatch) - normal-depth) 
  if item 3 floodplane-results = true [ set sval (4 * sval / 5) ]
  if ( devalue-land-based-on-recent-flooding ) [
    if (max-depth-this-flood > .6) [ set sval (4 * sval / 5) ] 
  ]
  report  sval
  
end

to-report value-function
  report (safe-value + prox-value) / 2
end

to reload-my-alt
  let index 0 
  let keepgoing true
  while [ keepgoing and index < length bank-alt-list ]
  [
   let entry item index bank-alt-list
   if (item 0 entry = pxcor) [ set altitude (normal-depth + item 1 entry) set keepgoing false]
   set index index + 1 
  ]
end

to load-test-altitude
  let index 0 
  let keepgoing true
  while [ keepgoing and index < length bank-alt-list ]
  [
   let entry item index bank-alt-list
   if (item 0 entry = pxcor) [ set test-altitude (normal-depth + item 1 entry) set keepgoing false]
   set index index + 1 
  ]
end

to-report calculate-levee-cost [ which extent height center-policy]
  let ctr nobody
  let mybank nobody
  if (which = 1) [ 
    set mybank riverbank with [ member? self field1 ] 
    ifelse (center-policy = "highest land value") [ set ctr one-of f1cc ]
    [  set ctr min-one-of mybank [ altitude ] ]
    
  ]
  if (which = 2) [ 
    set mybank riverbank with [ member? self field2 ] 
    ifelse (center-policy = "highest land value") [ set ctr one-of f2cc ] 
    [  set ctr min-one-of mybank [ altitude ] ]
  ]
  if (which = 3) [ 
    set mybank riverbank with [ member? self field3 ] 
    ifelse (center-policy = "highest land value") [ set ctr one-of f3cc ]
    [  set ctr min-one-of mybank [ altitude ] ]
  ]
     
  ask mybank [ set test-altitude altitude set pcolor real-pcolor ] ;;put (back) to the actual altitude.
  let xc [pxcor] of ctr
  let wheretobuild mybank with [ abs (pxcor - xc) <= extent  ]
  ask wheretobuild [ load-test-altitude ]
  ;show ( word count wheretobuild " wheretobuilds ") 
  let hmin min [ test-altitude ] of wheretobuild
  let buildmaterialsneeded 0
  ask wheretobuild
  [
    let hadd  (height + hmin - test-altitude)
    ;show (word "WTB at x=" pxcor " contributed " hadd " to the build count ")
    if (hadd > 0) [
      set test-altitude test-altitude + hadd
      set pcolor red
      set buildmaterialsneeded buildmaterialsneeded + hadd 
    ]
  ]
  report buildmaterialsneeded * 75
end


to build-levee [ which extent height center-policy]
  let ctr nobody
  let mybank nobody
  if (which = 1) [ 
    set mybank riverbank with [ member? self field1 ] 
    ifelse (center-policy = "highest land value") [ set ctr one-of f1cc ]
    [ set ctr min-one-of mybank [ altitude ] ]
    
  ]
  if (which = 2) [ 
    set mybank riverbank with [ member? self field2 ] 
    ifelse (center-policy = "highest land value") [set ctr one-of f2cc ] 
    [ set ctr min-one-of mybank [ altitude ] ]
  ]
  if (which = 3) [ 
    set mybank riverbank with [ member? self field3 ] 
    ifelse (center-policy = "highest land value") [ set ctr one-of f3cc ]
    [ set ctr min-one-of mybank [ altitude ] ]
  ]
     
  let xc [pxcor] of ctr
  let wheretobuild mybank with [ abs (pxcor - xc) <= extent ]
  ask wheretobuild [ reload-my-alt ]
  let hmin min [ altitude ] of wheretobuild
  let buildmaterialsused 0
  ask wheretobuild
  [
    let hadd  (height + hmin - altitude)
    if (hadd > 0) [
      set buildmaterialsused buildmaterialsused + hadd 
      ;show (buildmaterialsused)
      set altitude height + hmin
    ]
    ifelse height = 0 [ set pcolor lime ]
    [ set pcolor brown + 1 
      set real-pcolor pcolor
    ]
  ]
  show (word "COST for building levee of height " height " in region " which " at extent " extent " = " (buildmaterialsused * 75) )
  display
end

to calculate-taxbases
  set taxbase1 sum [ value * count citizens-here / 5] of field1
  set taxbase2 sum [ value * count citizens-here / 5] of field2
  set taxbase3 sum [ value * count citizens-here / 5] of field3
end

to color-as-desired 
  if Color-By = "altitude" [ color-by-altitude ]
  if Color-By = "value" [ color-by-value ]
  if Color-By = "population" [  color-by-population ] 
  if Color-By = "depth" [ color-by-depth ] 
  if Color-By = "safe-value" [ color-by-safe-value ]
end

to color-by-altitude
  let mh max [altitude] of patches + 1
  ask non-rivers [ set pcolor scale-color green altitude mh normal-depth ]
  ask patches with [ city-center? = true ] [ set pcolor pink ]
end
;
to color-by-value
  let vmax max [value] of patches + 2
  let vmin min [ value] of patches - 1
  ask non-rivers [ set pcolor scale-color orange value vmax vmin ]
end

to color-by-safe-value
  let vmax max [safe-value] of patches + 2
  let vmin min [ safe-value] of patches - 1
  ask non-rivers [ set pcolor scale-color red safe-value vmax vmin ]
end

to color-by-population
  ask  non-rivers [ set pcolor scale-color violet (count citizens-here) -10 (max-patch-pop + 2) ]
end

to color-by-depth
  no-display
  ask non-rivers [ set pcolor white ]
  let tocolor non-rivers with [depth > .005] 
  if ( any? tocolor) [
    ;let maxdepth max [ depth ] of tocolor 
    ;if maxdepth < .25 [ set maxdepth .25 ]
    ;if maxdepth > 5 [ set maxdepth 5 ]
    ask tocolor [ set pcolor scale-color blue depth 2 0 ] ;maxdepth 0 ]
  ]
  display
end


to import-topography-from-file
  let f user-file 
  set bank-alt-list [] 
  if (f != false) [
   file-open f
   while [ not file-at-end? ] 
   [
     
     let data read-from-string ( file-read-line )
     let xc item 0 data
     let alt item 1 data
     set bank-alt-list lput (list xc alt) bank-alt-list
     
     let channel-top min-pycor + river-width
     ask riverbank with [ pxcor = xc ] [ set channel-top pycor set altitude alt + normal-depth]
    
     let yj min-pycor 
     while [ yj < channel-top ] [ ask patch xc yj [ set altitude 0] set yj yj + 1]
    
     let yi 0
     let slope (foothill-alt - (alt + normal-depth)) / (foothill-y - channel-top)
     ;show (word "for x = " xc ", slope = " slope)
     while [ yi + channel-top <= foothill-y ] [ ask patch xc (yi + channel-top) [ set altitude normal-depth + alt + (yi * slope) - .3 + random-float .6]  set yi yi + 1]
     while [ yi + channel-top <= max-pycor ] [ ask patch xc (yi + channel-top) [ set altitude foothill-alt + (yi + channel-top - foothill-y - 1) * .5  - .3 + random-float .6 ] set yi yi + 1]
   ]
   file-close-all 
  ]
  let len count riverbank
  set bank-mean-height mean [ altitude ] of riverbank
  let quart len / 4 
  let lowlands min-n-of quart riverbank [ altitude ]
  set bank-low-quartile-height max [ altitude ] of lowlands
  let highlands max-n-of quart riverbank  [ altitude ]
  set bank-high-quartile-height min [ altitude ] of highlands
  let sorted-bank-patches sort-on [ altitude ] riverbank
  set sorted-bank-altitudes []
  foreach sorted-bank-patches [ set sorted-bank-altitudes lput ([altitude] of ?) sorted-bank-altitudes ]
  show (word "STATS:  riverbank mean height = " bank-mean-height ", lower quartile ht = " bank-low-quartile-height ", high quartile ht = " bank-high-quartile-height )
end

to import-flood-proportions-from-file
  ;;this file is generated from TinkerPlots--representing a distribution of floods along a single parameter, which roughly runs from 0 to 10 with a one-tailed normal distribution 
  ;;NOTE: values may be greater than one (in my sample, there is one datapoint at 1.1*). TinkerPlots generating file also editable.
  let f user-file 
  set flood-proportions [] 
  if (f != false) [
   file-open f
   while [ not file-at-end? ] 
   [
     let entry read-from-string ( file-read-line )
     set flood-proportions lput entry flood-proportions
   ]
   show (word "Loaded up flood parameter data in list of length " length flood-proportions)
   file-close-all
  ]
end

to-report phase-were-in
  ifelse count citizens < initial-population  [ report "Setting up & Initializing Population" ]
  [
    ifelse doing-flood [  report "Simulating Flood Event" ]
    [ 
      ifelse stop-to-make-policy 
      [ report "Simulating Land Market Exchange" ]
      [ report "Formulating Policy Responses" ]
    ]
  ]
end

;;;==== HUBNET PROCEDURES ====

to listen-clients [allow-changes]
  while [ hubnet-message-waiting? ]
  [
    hubnet-fetch-message
    ifelse (hubnet-enter-message? ) [ handle-new-client-joined  ]
    [
      ifelse ( hubnet-exit-message? ) [ handle-client-left ]
      [
       let recalc-levee-cost false
       show (word "MSG: "  hubnet-message-source "-->" hubnet-message-tag "-message: " hubnet-message )
       
       if (hubnet-message-tag = "zoom-level") [ 
         ask players with [ user-id = hubnet-message-source] [ 
           let zval hubnet-message
           ifelse (zval > 55) [ hubnet-reset-perspective user-id ]
           [ hubnet-send-follow user-id my-center hubnet-message  ] 
         ]
       ]
       
       if ( allow-changes ) [
         if (hubnet-message-tag = "Construct This Levee") [ 
           let fa 0
           let lc 0
           ask players with [user-id = hubnet-message-source ] [ set fa funds-available set lc levee-cost ] 
           ;show (word "available: " fa  " needed: " lc)
           ifelse ( fa < lc ) 
           [ 
             ask players with [user-id = hubnet-message-source ] [ 
               show (word "Failed attempt to build in area " my-area-number ": INSUFFICIENT FUNDS TO BUILD THIS LEVEE")
               hubnet-send user-id "info" "INSUFFICIENT FUNDS TO BUILD THIS LEVEE" 
               ]
           ]
           [
             let which 0
             let hgt 0
             let ext 0
             let ctr-policy ""
             ask players with [user-id = hubnet-message-source ] [
               set hgt levee-height
               set ext levee-extent
               set which my-area-number
               set ctr-policy center-levee-at
               hubnet-send user-id "info" "CONSTRUCTED LEVEE"
               set total-funds-spent total-funds-spent + levee-cost
               set funds-available funds-available - levee-cost
               hubnet-send user-id "Funds Available" precision funds-available 2
               hubnet-send user-id "Total Funds Spent on Levees" precision total-funds-spent 2
             ]
             build-levee which ext hgt ctr-policy
             ;view2.5d:update-all-patch-views
           ]
         ]
       ]
       
       if (hubnet-message-tag = "levee-height") [ 
         ask players with [user-id = hubnet-message-source ] [ 
           set levee-height hubnet-message 
           let cmd (word "set levee-ht-" my-area-number " " levee-height)
           run cmd
           set recalc-levee-cost true
         ]
       ]
       
       if (hubnet-message-tag = "levee-extent") [ 
         ask players with [user-id = hubnet-message-source ] [ 
           set levee-extent hubnet-message 
           let cmd (word "set extent-" my-area-number " " levee-extent)
           run cmd
           set recalc-levee-cost true
         ]
       ]
       
       if (hubnet-message-tag = "center-levee-at") [
          ask players with [user-id = hubnet-message-source ] [ 
           set center-levee-at hubnet-message 
           let cmd (word "set center-levee-at-" my-area-number " \"" center-levee-at "\"")
           run cmd
           set recalc-levee-cost true
         ]
       ]
       
       if (recalc-levee-cost = true)  [ ask players with [ user-id = hubnet-message-source ] [ 
         let cost calculate-levee-cost my-area-number levee-extent levee-height center-levee-at
         set levee-cost cost
         hubnet-send user-id "Cost of This Levee" precision cost 2
       ]
      ]
    ]
  ]
      display
      view2.5d:update-all-patch-views
  ]
end

to update-player-info
  ask players [
   let tb runresult (word "taxbase" my-area-number)
   ;show (word "tax base for area " my-area-number ": " tb)
   let fc runresult (word "floodcost" my-area-number) 
   ;show (word "flood damage in area " my-area-number ": " fc) 
   hubnet-send user-id "Tax Base" precision tb 3
   hubnet-send user-id "Total Flood Damage (K$)" precision fc 3
   set funds-available get-funds-from-taxbase tb
   set maintenance-cost (total-funds-spent * .1)
   set funds-available (funds-available - maintenance-cost)
   hubnet-send user-id "Funds Available" precision funds-available 2
   hubnet-send user-id "Total Funds Spent on Levees" precision total-funds-spent 2
  ]
end

;;player procedure
to update-all-my-fields
  hubnet-send user-id "zoom-level" default-zoom-level
  ;hubnet-send user-id "levee-height" default-levee-height
  ;hubnet-send user-id "center-levee-at" default-center-levee-at
  let tb runresult (word "taxbase" my-area-number)
  hubnet-send user-id "Tax Base" precision tb 3
  set funds-available get-funds-from-taxbase tb
   hubnet-send user-id "Funds Available" funds-available
  hubnet-send user-id "Total Flood Damage (K$)" 0
  ;let cost calculate-levee-cost my-area-number levee-extent levee-height center-levee-at
  ;set levee-cost cost
  hubnet-send user-id "Cost of This Levee" "CHOOSE PARAMETERS" ;precision cost 2
end

to-report get-funds-from-taxbase [ tb ]
  report precision (500 + .35 * tb)  2
end

to setup-default-player-values
  set default-zoom-level 20
  set default-levee-height 1.5
  set default-levee-extent 5
  set initial-funds-available 0
  set default-center-levee-at "highest land value"
end


to handle-new-client-joined 
  ifelse length available-areas > 0
  [
    let newarea last available-areas
    set available-areas butlast available-areas
    create-players 1 [
      set user-id hubnet-message-source 
      set my-area-number newarea
      set my-center one-of citycenters with [ area-number = [my-area-number] of myself ]
      set levee-height default-levee-height
      set levee-extent default-levee-extent
      set center-levee-at default-center-levee-at
      set funds-available 0
      set maintenance-cost 0
      set total-funds-spent 0
      hubnet-send user-id "my-area-number" newarea
      hubnet-send-follow user-id my-city-center default-zoom-level
     
      ;;initialize other fields
      ;zoom-level
      ;levee-height
      ;Construct this Levee
      ;Cost of This Levee
      ;Funds Available
      ;center-levee-at
      ;Tax Base
      ;Total Flood Damage (K$)
      ;info
      ;my-area-number
     update-all-my-fields
    ] 
  ]
  [
    let the-message  "There are no open rivebank areas. Only three players may join the simulation"
    hubnet-send hubnet-message-source "info" the-message
    show the-message
  ]
end


to handle-client-left
  let the-player one-of players with [ user-id = hubnet-message-source ]
  ifelse (the-player = nobody ) [ show (word "UNEXPECTED ERROR ON CLIENT EXIT.  CLIENT = " hubnet-message-source ) ]
  [
    let free-area [ my-area-number ] of the-player
    set available-areas fput free-area available-areas
    ask the-player [ die ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
190
75
800
436
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-59
60
-23
42
1
1
1
ticks
30.0

BUTTON
15
10
148
64
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
15
110
150
156
go
every delay [ go ]
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
15
190
150
223
go(once)
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

PLOT
805
10
1124
210
income-distribution of new settlers
NIL
NIL
0.0
11.0
0.0
10.0
true
false
"" "set-plot-x-range 0 11"
PENS
"default" 1.0 1 -16777216 true "" "if is-list? income-distribution [histogram income-distribution]"

PLOT
805
215
1125
435
population level over time (pop in thousands)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range 0 100\nif (is-list? population-growth)\n[ \nclear-plot\nset-plot-y-range round (min population-growth - 5) round ( max population-growth + 5) \n]"
PENS
"default" 1.0 0 -16777216 true "" "if (is-list? population-growth)\n[\nlet i 0\nplot-pen-up\nplotxy 0 item 0 population-growth\nplot-pen-down\nwhile [ i < length population-growth ]\n[ plotxy i item i population-growth \n  set i i + 1\n  ]\n  ]"
"pen-1" 1.0 0 -7500403 true "" "plotxy land-market-year plot-y-min\nplotxy land-market-year plot-y-max"

MONITOR
660
10
800
83
population (k)
count citizens
17
1
18

MONITOR
200
575
335
628
Tax Base 1
taxbase1
1
1
13

MONITOR
430
575
565
628
Tax Base 2
taxbase2
1
1
13

MONITOR
655
575
790
628
Tax Base 3
taxbase3
1
1
13

CHOOSER
15
330
150
375
Color-By
Color-By
"altitude" "value" "population" "depth" "safe-value"
4

MONITOR
190
10
320
83
Land Year
land-market-year
1
1
18

SLIDER
200
435
335
468
levee-ht-1
levee-ht-1
0
10
0.5
.1
1
NIL
HORIZONTAL

SLIDER
430
435
565
468
levee-ht-2
levee-ht-2
0
10
1.5
.1
1
NIL
HORIZONTAL

SLIDER
655
435
790
468
levee-ht-3
levee-ht-3
0
10
1.4
.1
1
NIL
HORIZONTAL

SLIDER
200
470
335
503
extent-1
extent-1
1
15
3
1
1
NIL
HORIZONTAL

SLIDER
430
470
565
503
extent-2
extent-2
1
15
4
1
1
NIL
HORIZONTAL

SLIDER
655
470
790
503
extent-3
extent-3
1
15
10
1
1
NIL
HORIZONTAL

BUTTON
15
295
150
328
recolor land
color-as-desired
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
320
10
660
83
Currently....
phase-were-in
17
1
18

MONITOR
200
630
335
675
total flood damage (K$)
floodcost1
1
1
11

MONITOR
430
630
565
675
total flood damage (K$)
floodcost2
1
1
11

MONITOR
655
630
790
675
total flood damage (K$)
floodcost3
1
1
11

BUTTON
10
540
190
573
Setup Floodplane Trials
setup-floodplane-trials
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
10
575
190
608
Run Floodplane Trials
run-floodplane-trials
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
10
610
85
655
NIL
trials-index
17
1
11

MONITOR
110
610
190
655
NIL
flood-type
17
1
11

CHOOSER
430
505
565
550
center-levee-at-2
center-levee-at-2
"highest land value" "lowest bank altitude"
1

CHOOSER
655
505
790
550
center-levee-at-3
center-levee-at-3
"highest land value" "lowest bank altitude"
1

BUTTON
25
425
177
458
Open 3D Flood View
view2.5d:patch-view \"DEPTH\" [[altitude + depth] of ?1]
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
15
385
150
418
NIL
show-all-floodplanes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
25
495
157
528
Update 3D Views
view2.5d:update-all-patch-views
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
15
235
150
285
Make Policy Changes
every delay [ listen-clients true ]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
155
150
188
delay
delay
0
.02
0
.001
1
NIL
HORIZONTAL

BUTTON
15
65
150
98
LogIn (but no building)
listen-clients false
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
820
480
1127
513
devalue-land-based-on-recent-flooding
devalue-land-based-on-recent-flooding
0
1
-1000

CHOOSER
200
505
335
550
center-levee-at-1
center-levee-at-1
"highest land value" "lowest bank altitude"
1

BUTTON
25
460
180
493
Open 3D Plan View
view2.5d:patch-view \"PLANNING\" [[max (list (altitude + depth) (test-altitude + depth) ) ] of ?1]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
925
565
1090
670
Floodplain Color Key\norange = 50 \nmagenta = 100 \npink = 200 \nviolet = 500 \nyellow = 1000 
14
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
VIEW
0
10
600
340
0
0
0
1
1
1
1
1
0
1
1
1
-59
60
-23
42

SLIDER
20
395
195
428
levee-height
levee-height
0
10
1.5
0.1
1
NIL
HORIZONTAL

SLIDER
20
355
195
388
zoom-level
zoom-level
15
60
20
1
1
NIL
HORIZONTAL

CHOOSER
20
475
195
520
center-levee-at
center-levee-at
"highest land value" "lowest bank altitude"
0

MONITOR
20
540
195
589
Tax Base
NIL
3
1

MONITOR
265
405
410
454
Cost of This Levee
NIL
3
1

MONITOR
20
590
195
639
Total Flood Damage (K$)
NIL
3
1

MONITOR
415
405
565
454
Funds Available
NIL
3
1

BUTTON
265
460
570
505
Construct This Levee
NIL
NIL
1
T
OBSERVER
NIL
NIL

MONITOR
5
645
600
694
info
NIL
3
1

MONITOR
465
590
600
639
my-area-number
NIL
3
1

SLIDER
20
435
195
468
levee-extent
levee-extent
1
15
5
1
1
NIL
HORIZONTAL

MONITOR
210
590
405
639
Total Funds Spent on Levees
NIL
3
1

TEXTBOX
260
355
590
400
\"Available Funds\" are discretionary city funds that can be spent on infrastructure projects (new or renovated schools, roads, parks, or other facilities), or on levee construction.
11
0.0
1

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
