-- Authors
-- v1.0 Fabrice L. - first attempt

dofile('/home/pi/domoticz/scripts/lua/includes/modules.lua')

-- Get data from domoticz
commandArray = {}

-- Local indexes
local tempExt   = 'Exterieur:Temp'             -- Exterior temperature
local tempRoom1 = 'Chambre1:Temp'              -- Room 1
local lux       = 'Lux'
local idxRoom1  = 'Chambre1:Volet'
local idxRoom2  = 'Chambre2:Volet'

-- Main loop
time = os.date("*t")
-- Between 10h and 18h, every 15 minutes
if  (time.hour >= 10 
     and time.hour <=18
     and (time.min % 1)==0)  then

    print('==============  Start of script ==================')
    -- Get data
    vTempExt = otherdevices_svalues[tempExt]:match("([^;]+);[^;]+")
    vTempRoom1 = otherdevices_svalues[tempRoom1]:match("([^;]+);[^;]+")
    vLux = otherdevices_svalues[lux]
    
    print('vTempExt'..vTempExt)
    print('vTempRoom1'..vTempRoom1)
    print('vLux'..vLux)

    -- Close the blind if
    --  - lux is greater than 30000
    --  - temperature outside is greater than inside 
    if ((tonumber(vLux) > 30000)
        or (tonumber(vTempExt)>tonumber(vTempRoom1))) then
        print('Need to close blind')
        blindStop(idxRoom1)
        blindStop(idxRoom2)
    else
        blindOpen(idxRoom1)
        blindOpen(idxRoom2)
    end    

    print('==============  End of script ==================')
end

-- Exit point
return commandArray
