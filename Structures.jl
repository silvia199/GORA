# STRUCTURES USED IN THE PROBLEM

# Input data
#-----------------------------------------------

# Input parameters 
@with_kw struct InputParam{F<:Float64,I<:Int}
    NYears::F
    NMonths::I
    NHoursStep::I
    NSteps::I
    NStages::I                                    #Number of stages in the problem FORMULATION
    NStates::I                                    #Number of possible states for each stage
    NHoursStage::I                                #Number of hours in one stage
    Big::F                                        #A big number
end

# Battery's characteristics
@with_kw struct BatteryParam{F<:Float64}
    grid_Capacity::F
    min_SOC::F                                   # Batter's maximum capacity
    energy_Capacity::F                                  # Battery's maximum energy storage capacity
    power_Capacity::F
    Eff_charge::F
    Eff_discharge::F
    DoD::Any
    NCycles::Any
end
  
# solver parameters
@with_kw struct SolverParam{F<:Float64,I<:Int}
    CPX_PARAM_SCRIND::I = 0
    CPX_PARAM_PREIND::I = 0
    CPXPARAM_MIP_Tolerances_MIPGap::F = 1e-10
    CPX_PARAM_TILIM::I = 120
    CPX_PARAM_THREADS ::I = 1
end
  
# Indirizzi cartelle
@with_kw struct caseData{S<:String}
    DataPath::S
    InputPath::S
    ResultPath::S
    CaseName::S
end

# runMode Parameters
@with_kw mutable struct runModeParam{B<:Bool}

    #runMode self defined reading of input 
    setInputParameters::B = true            #from .in file

    batterySystemFromFile::B = true
    productionPV::B = true
    maximumGrid::B = true
    #onlyExport::B = true
   
    battery_replacement::B = true           
    excel_savings::B = false
    plot_savings::B = true

    # SIM settings
    dynamicProgramming::B= true
    simulate::B = true
    parallellSim::B = false
   
end

struct Results_dp
    Power_prices::Any
    battery_cost::Any
    pv_prod::Any
    charge::Any
    charge_grid::Any
    discharge::Any
    discharge_grid::Any
    degradation::Any
    gain::Any
    replacementCost::Any
    val::Any
    optimalValueStates::Any
    optimalfromState::Any
    optimalPath::Any
    overallCost::Any
    netOverallRevenues::Any
    error::Any
    modeFinal::Any
end

struct states
    seg::Any
end

struct optimalStage
    stage::Any
    optimalValue::Any
    price::Any
    #currentState::Any
    #nextState::Any
    currentSOC::Any
    nextSOC::Any
    charge::Any
    fromGrid::Any
    discharge::Any
    toGrid::Any
    deg::Any
    PV::Any
    netRev::Any
    batteryCost::Any
    bat::Any
end



#show(io::IO,x::optimalStage) = print(io, "Stage:",x.stage," -> optimal Value = ",x.optimalValue," ,current State = ",x.currentState," ,next State = ",x.nextState," ,current SOC = ",x.currentSOC," ,next SOC = ",x.nextSOC," ,action = ",x.action, " , net gain =",x.gain, "battery Cost =",x.batteryCost)
