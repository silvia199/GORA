function DP(                                                                                                   # Ora conosco per ogni settimana i valori di inflow e prezzo (calcolati con il modello di Markov) - risolvo il problema come "DETERMINISTICO"
  InputParameters::InputParam,
  Battery::BatteryParam,
  state_variables::states,
  runMode::runModeParam,
  Power_prices,
  PV_production,
  Battery_prices,
  )

  @unpack (NYears,NMonths, NHoursStep, NSteps, NStages, NStates, NHoursStage, Big)= InputParameters;
  @unpack (grid_Capacity, min_SOC, energy_Capacity, power_Capacity, Eff_charge, Eff_discharge) = Battery;      # MAXCharge, MAXDischarge,
  @unpack (maximumGrid, productionPV, battery_replacement) = runMode
  @unpack (seg) = state_variables;

  battery_cost=zeros(NSteps);
  pv_prod = zeros(NSteps);
  gridMax = grid_Capacity;

  bat_Cost=" "
  if battery_replacement                                           # if true -> evaluating with cell -replacement , give the cost
    bat_Cost="_WITHBatRep"
    for j=1:NStages
      battery_cost[(j-1)*NHoursStage+1:j*NHoursStage].= Battery_prices[j]
    end
  else
    bat_Cost="_WITHOUTBatRep"
    battery_cost=zeros(NSteps)
  end

  modePV=""
  if productionPV
    modePV= "_withPV"
    pv_prod = PV_production[1:NSteps]
  else
    modePV= "_withoutPV"
  end

  modeGrid=""
  if maximumGrid
    modeGrid= "_withMaxGrid"
  else
    modeGrid= "_withoutMaxGrid"
  end

  modeFinal = bat_Cost*modePV*modeGrid                                                  # full name of the problem solving
  println(modeFinal)
  
  optimalValueStates = zeros(NSteps+1,NStates)                                 # Final Optimal value for each State of the t-stage -> considers the max among all combinations ex: ValueStates[23,5] = 124€ -> if we are in day 23 at stage 5, the value I would have is of 124€
  optimalValueStates[end,:] = seg * Power_prices[NSteps]                     # Initialize the Values of NStages+1 (starting point DP)
  optimalfromState = zeros(NSteps,NStates)                                     # Indicates the optimal state from which we are coming from ex: fromState[23,5] =2 -> if we are at day 23 in state 5 (0% of energy), we are comiing from state 2 in day 24
  val = zeros(NSteps,NStates,NStates)                                          # Per ogni stato del sistema, calcolo tutte le transizioni e poi ne prendo la massima                                                              # ex: Val[35,1,4] = indicates the value of being in state 1 in day 35, id coming from state 4 in stage 36
 

  # VECTORS FOR EVERY POSSIBLE COMBINATION
  charge = zeros(NSteps,NStates,NStates)                                       # power needed to charge the battery
  discharge = zeros(NSteps,NStates,NStates)                                    # power discharged by the battery
  discharge_grid = zeros(NSteps,NStates,NStates)                               # effective power needed from the grid
  charge_grid =zeros(NSteps,NStates,NStates)                                   # effective power sold to the grid

  degradation = zeros(NSteps,NStates,NStates)                                  # accounts for the %of battery degradated beacuse of the use
  optimalPath = []

  gain = zeros(NSteps,NStates,NStates)
  replacementCost = zeros(NSteps,NStates,NStates)

  @timeit to "Solve dynamic programming" begin

    for t = NSteps:-1:1                                                        # Calcolo per ogni mezz'ora partendo dall'ultimo
      
      soc_start = 0
      soc_final = 0

      println("STEP:", t, " battery cost:",battery_cost[t])

      for iState=1:NStates                                                      # Considero gg=365gg*24h*2 tutti i possibili stati

        soc_start = seg[iState]

          for jState=1:NStates                                                  # Considero tutti gli stati allo stagesuccessivo

            #CALCULATES THE CHARGE/DISCHARGE FROM ONE STAGE TO ANOTHER CONSIDERING ALL POSSIBLE STATE TRANSITIONS PER EACH STAGE

            soc_final = seg[jState]
            penaltyExport = 0
            penaltySOC = 0

            if soc_final > soc_start          #CHARGING PHASE
                
                charge[t,iState,jState] = abs((soc_final-soc_start)/(NHoursStep*Eff_charge))         #calculates how much power is needed to charge the battery from one stato to another
                discharge[t,iState,jState] = 0
                degradation[t,iState,jState] =0.5*abs(1/NCycles[iState]-1/NCycles[jState])
                #degradation[t,iState,jState] = abs(soc_start^2/energy_Capacity-soc_final^2/energy_Capacity+2*(soc_final-soc_start))/(2*10000)

                charge_grid[t,iState,jState] = charge[t,iState,jState]-pv_prod[t]
                discharge_grid[t,iState,jState] = 0        #discharge[t,iState,jState] + pv_prod[t]
                
                # INFEASIBILITIES FOR CHARGING - if true add penalty, otherwise leave 
                if charge[t,iState,jState]>power_Capacity
                  penaltySOC = Big
                else
                  penaltySOC = 0
                end
                
                if maximumGrid && charge_grid[t,iState,jState] >= 0
                  penaltyExport = Big
                elseif maximumGrid && charge_grid[t,iState,jState] < 0    #Ho caricato la batteria ma ho un surplus di PV, lo vendo
                  penaltyExport = 0
                  charge_grid[t,iState,jState] = 0
                  a = pv_prod[t]-charge[t,iState,jState]
                  if a > gridMax;
                    discharge_grid[t,iState,jState] = gridMax
                  else
                    discharge_grid[t,iState,jState] = pv_prod[t]-charge[t,iState,jState]
                  end
                else
                  penaltyExport=0
                  if charge_grid[t,iState,jState] >= 0
                    charge_grid[t,iState,jState] = charge[t,iState,jState]-pv_prod[t]
                    discharge_grid[t,iState,jState] = 0    
                  else
                    charge_grid[t,iState,jState] = 0
                    discharge_grid[t,iState,jState] = pv_prod[t]-charge[t,iState,jState]
                  end
                end
                  

            elseif soc_final < soc_start       #DISCHARGING PHASE
              
              charge[t,iState,jState] = 0
              discharge[t,iState,jState] = abs((soc_final-soc_start)*Eff_discharge/NHoursStep)       #discharge from battery       
              #degradation[t,iState,jState] = abs(soc_start^2/energy_Capacity-soc_final^2/energy_Capacity+2*(soc_final-soc_start))/(2*10000)
              degradation[t,iState,jState]=0.5*abs(1/NCycles[iState]-1/NCycles[jState])

              charge_grid[t,iState,jState] = 0
              discharge_grid[t,iState,jState] = discharge[t,iState,jState]+pv_prod[t]
                 
              if maximumGrid && discharge_grid[t,iState,jState]>=gridMax
                discharge_grid[t,iState,jState] = gridMax;
                #penaltyExport = 10 ??
              else
                discharge_grid[t,iState,jState] = discharge[t,iState,jState]+pv_prod[t]
              end


            else                               #IDLING PHASE -> cal only sell power from PV to the grid (if any)
                
              charge[t,iState,jState] = 0
              discharge[t,iState,jState] = 0
              degradation[t,iState,jState] = 0

              charge_grid[t,iState,jState] = 0
              discharge_grid[t,iState,jState] = pv_prod[t]

              if maximumGrid && discharge_grid[t,iState,jState] >= gridMax #se vi è un limite su potenza massima nella rete e la potenza da PV è maggiore della capacità di rete)
                discharge_grid[t,iState,jState] = gridMax
              else
                discharge_grid[t,iState,jState]= pv_prod[t]
              end

      
            end

            val[t,iState,jState] = Power_prices[t]*NHoursStep*(discharge_grid[t,iState,jState]-charge_grid[t,iState,jState]) - degradation[t,iState,jState]*battery_cost[t]*energy_Capacity -penaltyExport -penaltySOC + optimalValueStates[t+1,jState]      #/10E5
            gain[t,iState,jState] = Power_prices[t]*NHoursStep*(discharge_grid[t,iState,jState]-charge_grid[t,iState,jState])
            replacementCost[t,iState,jState] = degradation[t,iState,jState]*battery_cost[t]*energy_Capacity      
            

          end # end jStates=1:5

        optimalValueStates[t,iState] = findmax(val[t,iState,:])[1]             # Trovo il massimo del Valore funzione obiettivo : transizioni + valore stato precedente 
        optimalfromState[t,iState] = findmax(val[t,iState,:])[2]               # Mi dice da quale stato al giorno precedente (o futuro) arrivo

        println("Optimal Val at stage t: $t and state x $iState: ",optimalValueStates[t,iState], " coming from state: ",optimalfromState[t,iState])
        println()

      end

    end   # end Steps

    # RACCOLGO I RISULTATI DEL PERCORSO MIGLIORE

    a = findmax(optimalValueStates[1,:])[2]            # Mi inidica in quale stato per NStage=1 ho il massimo valore
    netOverallRevenues = 0 
    overallCost = 0

    let startingFrom =a, comingFrom=0
      for t=1:NSteps
        
        comingFrom = Int(optimalfromState[t,startingFrom])                        # Inidca da quale stato presedente sono arrivato
      
        #optValue = findmax(optimalValueStates[t,startingFrom])[1]
        optValue = optimalValueStates[t,startingFrom]
        charge_bat = charge[t,startingFrom,comingFrom]
        dis_bat = discharge[t,startingFrom,comingFrom]
        char_grid = charge_grid[t,startingFrom,comingFrom]
        dis_grid = discharge_grid[t,startingFrom,comingFrom]
        degMWh= degradation[t,startingFrom,comingFrom]
        pv = pv_prod[t]
        price = Power_prices[t]
        bat=battery_cost[t]

        net_revenues = gain[t,startingFrom,comingFrom] - replacementCost[t,startingFrom,comingFrom]
        batCost = replacementCost[t,startingFrom,comingFrom]  

        overallCost = overallCost + batCost
        netOverallRevenues = netOverallRevenues + net_revenues

        push!(optimalPath,saveOptimalValues(t,optValue,price,startingFrom,comingFrom,seg,charge_bat,char_grid,dis_bat,dis_grid,degMWh,pv,net_revenues,batCost,bat))
        
        startingFrom=comingFrom

      end
    end
    
    error = []
    for t=1:NSteps
      if optimalPath[t].charge> energy_Capacity
        push!(error,optimalPath[t])
      end
    end

  end

  return Results_dp(
    Power_prices,
    battery_cost,
    pv_prod,
    charge,
    charge_grid,
    discharge,
    discharge_grid,
    degradation,
    gain,
    replacementCost,
    val,
    optimalValueStates,
    optimalfromState,
    optimalPath,
    overallCost,
    netOverallRevenues,
    error,
    modeFinal,
   )

end


show(io::IO,x::optimalStage) = print(io,"Stage:",x.stage," -> opVal = ",x.optimalValue," price = ",x.price," curSOC = ",x.currentSOC,", nextSOC = ",x.nextSOC,", charge = ",x.charge, ", fromGrid = ",x.fromGrid,", discharge = ",x.discharge ,", toGrid = ",x.toGrid,", PV = ", x.PV ,", netRevenues = ",x.netRev, ", batCost = ",x.batteryCost)

function saveOptimalValues(stage::Int64,optimalValue::Float64,price::Float64, curSt::Int64, nextSt::Int64, seg::Any, charge::Float64,fromGrid::Float64,discharge::Float64, toGrid::Float64, deg::Float64, PV::Float64, netRev::Float64 , batteryCost::Float64 , bat::Float64)
  optimalStage(stage, optimalValue, price, seg[curSt], seg[nextSt], charge, fromGrid, discharge,toGrid,deg, PV,netRev, batteryCost, bat)
end


function PV_revenues(PV_production,Power_prices)

  a=length(PV_production);
  pv_revenues=zeros(a);

  for i=1:a
    pv_revenues[i] = PV_production[i].*Power_prices[i]
  end

  return pv_revenues

end
