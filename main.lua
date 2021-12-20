local ReactorStatus = false
local i = 0.1
local burnTempature = 100_000_000
local burnRatio = 1
local plasmaHeatCapacity = 100
local caseHeatCapacity = 1
local inverseInsulation = 100_000
local plasmaCaseConductivity = 0.2
local ambient_temp = 300
local elevation_from_sea_level = 619
local default_heat_capacity = 1
local thermocoupleEfficiency = 0.0561
local default_inverse_conduction = 3.41 + thermocoupleEfficiency
local air_inverse_coeffiecient = 10_000 / elevation_from_sea_level * default_inverse_conduction * 24.44
local casingThermalConductivity = 0.001
local energyPerFusionFuel = 10_000_000
local criticalTemp = 500_000_000
local warningTemp = 400_000_000
local fuel = 50_000
local criticalFuel = 1_000
local warningFuel = 5_000
local criticalEnergy = 25_000
local warningEnergy = 20_000
local injectionRate = 4
local default_inverse_insulation = 0
local heattohandle = 0
local lastPlasmaTemperature = ambient_temp
local lastCaseTemperature = ambient_temp
local plasmaTemperature = ambient_temp
local caseTemperature = ambient_temp
local hohlraum = false
local burning = false
local energy = 0
local fuelCapacity = 10_000
local fuelCurrent = 0
local hotfix = 1
local timeAtCriticalTemp = 0

local function getPlasmaTemp()
   return plasmaTemperature
end

local function setBurning(Status)
   burning = Status
   ReactorStatus = Status
end

local function isBurning()
   return burning
end

local function hasHohlraum()
   return hohlraum
end

local function useHohlraum()
   if hohlraum then
      hohlraum = false
      setBurning(true)
   end
end

local function addHohlraum()
   hohlraum = true
end

local function getTemperature()
   return caseTemperature
end

local function setPlasmaTemp(temp)
   if plasmaTemperature ~= temp then
      plasmaTemperature = temp
   end
end

local function updateTemperatures()
   lastPlasmaTemperature = getPlasmaTemp();
   lastCaseTemperature = getTemperature();
end

local function handleHeat(heat)
   heattohandle += heat
end

local function insertEnergy(amount)
   energy += amount
end

local function getMaxPlasmaTemperature()
   local caseAirConductivity = casingThermalConductivity
   return injectionRate * energyPerFusionFuel / plasmaCaseConductivity * (plasmaCaseConductivity + caseAirConductivity) / caseAirConductivity
end

local function getMaxCasingTemperature()
   return energyPerFusionFuel * injectionRate / casingThermalConductivity
end

local function getPassiveGeneration()
   return thermocoupleEfficiency * casingThermalConductivity * lastCaseTemperature
end

local function addTemperatureFromEnergyInput(energyAdded)
   setPlasmaTemp(getPlasmaTemp() + energyAdded / plasmaHeatCapacity * 10);
end


local function getCodes()
   --[[
   ITER Fusion Reactor Handbook v 1.0
   Chapter 1. Codes
   The ITER Fusion Reactor status codes convey two types of information, the first character which is the severity and the second character which is the type of information.
   Severity
   0 = Functioning normally, may it be running or not running.
   1 = Warning, this can include but not limited to, running low on fuel, temperatures rising too high for safe operation, or stored energy in the reactor battery rising to unsafe levels. In the event of witnessing this code you should act immediately and signal code Orange.
   2 = Complete Failure, this can include but not limited to, completely exhausting fuel reserves, temperatues rising above critical operation levels, or stored energy in the reactor battery going above critical levels. In the event of witnessing this code you should act immediately and signal code Red.
   Information Type
   T = Temperature
   E = Energy
   F = Fuel
   B = Burning
   For example, the code 0xB would be a normal code to observe while the reactor is running at a stable pace and temperatures are stable.
   1xE would mean a warning for energy, in this case the person that observed this code would sound a code Orange and inspect the reactor energy capacitor.
   ]]
   local codes = {}

   if getPlasmaTemp() >= burnTempature and getPlasmaTemp() / 3.5 <= criticalTemp then
      codes["0xB"] = true
   end
   if getPlasmaTemp() / 3.5 >= criticalTemp then
      codes["2xT"] = true
   end
   if getPlasmaTemp() / 3.5 >= warningTemp and getPlasmaTemp() / 3.5 < criticalTemp then
      codes["1xT"] = true
   end
   if getPlasmaTemp() <= burnTempature then
      codes["0xT"] = true
   end
   if energy / 1e+6 >= criticalEnergy then
      codes["2xE"] = true
   end
   if energy / 1e+6 >= warningEnergy and energy / 1e+6 < criticalEnergy  then
      codes["1xE"] = true
   end
   if fuel <= criticalFuel then
      codes["2xF"] = true
   end
   if fuel <= warningFuel and fuel > criticalFuel then
      codes["1xF"] = true
   end

   return codes
end

local function injectFuel()
   local amountNeeded = fuelCapacity - fuelCurrent
   local amountToInject = math.min(amountNeeded, math.min(2 * fuel, injectionRate));
   amountToInject -= amountToInject % 2;
   fuel -= amountToInject
   fuelCurrent = amountToInject
end

local function burnFuel()
   local fuelBurned = math.min(fuel, math.max(0, lastPlasmaTemperature - burnTempature) * burnRatio)
   setPlasmaTemp(getPlasmaTemp() + energyPerFusionFuel * fuelBurned / plasmaHeatCapacity / air_inverse_coeffiecient)
   fuelCurrent -= injectionRate
   return fuelBurned
end

local function transferHeat()
   local plasmaCaseHeat = plasmaCaseConductivity * (lastPlasmaTemperature - lastCaseTemperature);
   setPlasmaTemp(getPlasmaTemp() - plasmaCaseHeat / plasmaHeatCapacity);
   handleHeat(plasmaCaseHeat)
   insertEnergy(plasmaCaseHeat * thermocoupleEfficiency)

   local caseAirHeat = casingThermalConductivity * (lastCaseTemperature - ambient_temp)
   handleHeat(caseAirHeat)
   insertEnergy(caseAirHeat * thermocoupleEfficiency)
end

local function getIgnitionTemperature()
   return burnTempature * energyPerFusionFuel * burnRatio * (plasmaCaseConductivity + casingThermalConductivity) / (energyPerFusionFuel * burnRatio * (plasmaCaseConductivity + casingThermalConductivity) - plasmaCaseConductivity * casingThermalConductivity)
end

local function autoInject()
   if plasmaTemperature <= 150000000 then
      if energy >= 1550000000 then
         energy -= 1550000000
         addTemperatureFromEnergyInput(1550000000)
      end
   end
end

local function startMeltdown()
   if timeAtCriticalTemp >= 20 then
      for i, v in next, workspace.Reactor:GetDescendants() do
         Instance.new("Explosion", v)
         setBurning(false)
      end
   end
end

script.Parent.ToggleReactor.OnServerEvent:Connect(function()
ReactorStatus = not ReactorStatus
if ReactorStatus == false then
   spawn(function()
   wait(6)
   setBurning(false)
   end)
else
   addHohlraum()
end
end)
script.Parent.InjectEnergy.OnServerEvent:Connect(function()
addTemperatureFromEnergyInput(1550000000)
end)
script.Parent.GetData.OnServerInvoke = function()
return {
   ["energy"] = energy / 1e+6, --// get MJ
   ["plasmaTemperature"] = plasmaTemperature,
   ["fuel"] = fuel,
   ["codes"] = getCodes(),
   ["hohlraum"] = hasHohlraum()
}
end
spawn(function()
while wait() do
if getPlasmaTemp() >= burnTempature then
   if not burning and hasHohlraum() then
      print'used hohlraum'
      useHohlraum()
   end
   if isBurning() then
      autoInject()
   end
else
   print'uh oh,,,, temps arent enough... lolllll'
   setBurning(false)
end
local codes = getCodes()
if codes["2xT"] or codes["2xE"] then
   startMeltdown()
end
if isBurning() then
   injectFuel()
   local fuelBurned = burnFuel()
   if fuelBurned <= 0 then
      if hotfix == 1 then
         hotfix += 1
      else
         print'stopped due to fuel exhaustion'
         setBurning(false)
      end
   end
end
transferHeat()
updateTemperatures()
end
end)

spawn(function()
while wait(1) do
if getCodes()["2xT"] then
   timeAtCriticalTemp = timeAtCriticalTemp + 1
   print(timeAtCriticalTemp)
else
   timeAtCriticalTemp = 0
end
end
end)

while wait() do
if ReactorStatus then
   script.Parent.Pressure:PivotTo(CFrame.new(script.Parent.Pressure:GetPivot().Position) * CFrame.fromEulerAnglesXYZ(0, i, 0))
   i = i * 1.05
end
end
