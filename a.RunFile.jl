#RUN FILE

# Calls the Packages used for the optimization problem
using Printf
using MathOptInterface
using JLD
using TimerOutputs
using DataFrames
using XLSX
using Parameters
using Dates
using CSV
using Plots
using Base

import Base.show

# Calls the other Julia files
include("Structures.jl")
include("SetInputParameters.jl")
#include("dynamicProgramming_OLD.jl")
include("dynamicProgramming_NEW.jl")
include("Saving in xlsx.jl")
include("Plots.jl")

date = string(today())

# PREPARE INPUT DATA
to = TimerOutput()

@timeit to "Set input data" begin

  #Set run case - indirizzi delle cartelle di input ed output
  case = set_runCase()
  @unpack (DataPath,InputPath,ResultPath,CaseName) = case;

  # Set run mode (how and what to run) and Input parameters
  runMode = read_runMode_file()
  InputParameters = set_parameters(runMode, case)
  @unpack (NYears,NMonths, NHoursStep, NSteps, NStages, NStates, NHoursStage, Big)= InputParameters;

  # Set solver parameters (Cplex etc)
  SolverParameters = set_solverParameters()

  # Read cost fo ceel replacements from a file [€/MWh]
  Battery_prices = read_csv("Battery_decreasing_prices_mid.csv",case.DataPath)

 # Read power prices for 10 years
  Pp14 = read_csv("prices_2014_8760.csv", case.DataPath);
  Pp15 = read_csv("prices_2015_8760.csv", case.DataPath);
  Pp16 = read_csv("prices_2016_8760.csv", case.DataPath);
  Pp17 = read_csv("prices_2017_8760.csv", case.DataPath);
  Pp18 = read_csv("prices_2018_8760.csv", case.DataPath);
  Pp19 = read_csv("prices_2019_8760.csv", case.DataPath);
  Pp20 = read_csv("prices_2020_8760.csv", case.DataPath);
  Pp21 = read_csv("prices_2021_8760.csv", case.DataPath);
  Pp22 = read_csv("prices_2022_8760_new.csv", case.DataPath);
  Pp23 = read_csv("prices_2023_8760.csv", case.DataPath);
  Power_prices = vcat(Pp14,Pp15,Pp16,Pp17,Pp18,Pp19,Pp20,Pp21,Pp22,Pp23); 

  PV = read_csv("PV_1MWh.csv",case.DataPath);                            # potenza da PV (0.75MW)         
  PV_production =vcat(PV,PV,PV,PV,PV,PV,PV,PV,PV,PV);

  # Upload battery's characteristics
  Battery = set_battery_system(runMode, case);
  @unpack (grid_Capacity, min_SOC, energy_Capacity, power_Capacity, Eff_charge, Eff_discharge, DoD, NCycles) = Battery; 

  # DEFINE STATE VARIABLES - STATE OF CHARGES SOC [MWh]
  state_variables = define_state_variables(InputParameters, Battery)

  # Where and how to save the results
  FinalResPath= set_run_name(case, ResultPath, InputParameters)

end

#save input data
@timeit to "Save input" begin
    save(joinpath(FinalResPath,"CaseDetails.jld"), "case" ,case)
    save(joinpath(FinalResPath,"SolverParameters.jld"), "SolverParameters" ,SolverParameters)
    save(joinpath(FinalResPath,"InputParameters.jld"), "InputParameters" ,InputParameters)
    save(joinpath(FinalResPath,"BatteryCharacteristics.jld"), "BatteryCharacteristics" ,Battery)
    save(joinpath(FinalResPath,"PowerPrices.jld"),"PowerPrices",Power_prices)
    save(joinpath(FinalResPath,"PVproduction.jld"),"PVprod",PV_production)
end

#ONLY PV EVALUATION
OnlyPV = PV_revenues(PV_production,Power_prices)

# DYNAMIC PROGRAMMING
if runMode.dynamicProgramming
    println("Solving Dynamic Pogramming")
    ResultsDP = DP(InputParameters, Battery, state_variables, runMode, Power_prices, PV_production, Battery_prices)   #configurations
    save(joinpath(FinalResPath, "dp_Results.jld"), "dp_Results", ResultsDP) 
    else
    println("Solved without dynamic programming.")
end

# SAVE OTIMAL-PATH DATA IN EXCEL FILES
if runMode.excel_savings
  cartella = "C:\\GitSource-Batteries\\Batteries-greedy-aproach\\Results"
  cd(cartella)
  data_saving(InputParameters,ResultsDP)
  println("Results saved")
else
  println("Solved without saving results in xlsx format.")
end

# SAVE PLOTS IN THE CORRESPONDING FOLDER
if runMode.plot_savings
  cartella = "C:\\GitSource-Batteries\\Batteries-greedy-aproach\\Plots"
  cd(cartella)
  plotPath(InputParameters,ResultsDP,state_variables)
end



print(to)




