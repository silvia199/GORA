# EXCEL SAVINGS
using DataFrames
using XLSX

function data_saving(InputParameters::InputParam,ResultsDP::Results_dp)

    @unpack (NYears,NMonths, NHoursStep, NSteps, NStages, NStates, NHoursStage, Big)= InputParameters;
    @unpack (optimalPath,modeFinal) = ResultsDP;

    hour=string(now())
    a=replace(hour,':'=> '-')

    nameF= "$modeFinal,min SOC 0.2 $a kp=2.1"
    mkdir(nameF)
    cd(nameF)
    main=pwd()

    #optimalState=zeros(NStages+1)
    optimalSOC=zeros(NSteps+1);
    optimalChargeBattery=zeros(NSteps+1);
    optimalDischargeBattery=zeros(NSteps+1);
    optimalChargeGrid =zeros(NSteps+1);
    optimalDischargeGrid=zeros(NSteps+1);
    optimalDegradation=zeros(NSteps+1);
    PV=zeros(NSteps+1);
    price=zeros(NSteps+1);
    cost=zeros(NSteps+1);
    degradationCost=zeros(NSteps+1);
    netRevenues=zeros(NSteps+1);

    for t=1:NSteps
        optimalSOC[t]=optimalPath[t].currentSOC
        optimalChargeBattery[t]=optimalPath[t].charge
        optimalDischargeBattery[t]=optimalPath[t].discharge
        optimalChargeGrid[t]=optimalPath[t].fromGrid
        optimalDischargeGrid[t]=optimalPath[t].toGrid
        optimalDegradation[t]=optimalPath[t].deg
        PV[t]=optimalPath[t].PV
        price[t]=optimalPath[t].price
        cost[t]=optimalPath[t].bat
        degradationCost[t]=optimalPath[t].batteryCost
        netRevenues[t]=optimalPath[t].netRev
    end

    optimalSOC[end]=optimalPath[end].nextSOC;

    for t=1:NStages-1
        table=DataFrame()
        table[!,"Steps"]= (t-1)*NHoursStage+1:t*NHoursStage
        table[!,"Energy price €/MWh"] = price[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"SOC MWh"] = optimalSOC[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Charge Battery MW"] = optimalChargeBattery[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Discharge Battery MW"]= optimalDischargeBattery[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"PV production MW"] = PV[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Charge from Grid MW"] = optimalChargeGrid[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Discharge to Grid MW"] = optimalDischargeGrid[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Degradation MWh"] = optimalDegradation[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Cost battery €/MWh"] = cost[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Revamping Cost €"] = degradationCost[(t-1)*NHoursStage+1:t*NHoursStage]
        table[!,"Net Revenues €"] = netRevenues[(t-1)*NHoursStage+1:t*NHoursStage]

        XLSX.writetable("Stage $t.xlsx", overwrite=true,
        results = (collect(DataFrames.eachcol(table)),DataFrames.names(table))
        )

    end

    table=DataFrame()
    table[!,"Steps"]= ((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)
    table[!,"Energy price €/MWh"] = price[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"SOC MWh"] = optimalSOC[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"Charge Battery MW"] = optimalChargeBattery[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"Discharge Battery MW"]= optimalDischargeBattery[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"PV production MW"] = PV[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"Charge from Grid MW"] = optimalChargeGrid[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"Discharge to Grid MW"] = optimalDischargeGrid[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"Degradation MWh"] = optimalDegradation[(NStages-1)*NHoursStage+1:NStages*NHoursStage+1]
    table[!,"Cost battery €/MWh"] = cost[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"Degradation Cost €"] = degradationCost[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]
    table[!,"Net Revenues €"] = netRevenues[((NStages-1)*NHoursStage+1):(NStages*NHoursStage+1)]

    XLSX.writetable("Stage $NStages.xlsx", overwrite=true,
    results = (collect(DataFrames.eachcol(table)),DataFrames.names(table))
    )

    net_revenues=zeros(NStages);
    Battery_cost=zeros(NStages);
    bat_deg =zeros(NStages);
    for t=1:NStages
        net_revenues[t]=sum(netRevenues[(t-1)*NHoursStage+1:t*NHoursStage])
        Battery_cost[t]=sum(degradationCost[(t-1)*NHoursStage+1:t*NHoursStage])
        bat_deg[t]= sum(optimalDegradation[(t-1)*NHoursStage+1:t*NHoursStage])
    end

    table1=DataFrame()
    table1[!,"Stage"]=1:NStages
    table1[!,"Net revenues €"]=net_revenues[:]
    table1[!,"Cost replacement €"]=Battery_cost[:]
    table1[!, "Battery degradation MWh"] =bat_deg[:]

    XLSX.writetable("Final values.xlsx", overwrite=true,
        results = (collect(DataFrames.eachcol(table1)),DataFrames.names(table1))
    )

    cd(main)



end






