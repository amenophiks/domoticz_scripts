-- /!\ require Domoticz v3.5776 and after /!\

curl = '/usr/bin/curl ' -- don't forgot the final space

domoticzIP = '127.0.0.1'
domoticzPORT = '8080'
domoticzURL = 'http://'..domoticzIP..':'..domoticzPORT

-- switch On a device and set level if dimmmable
function switchOn(device, level)
   if level ~= nil then
      os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Set%20Level&level='..level..'" &')
   else   
      os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=On" &')
   end   
end

-- switch On a devive for x seconds
-- non compatible avec le script sendTwice
function switchOnFor(device, secs)
   switchOn(device)
   commandArray[device] = "Off AFTER "..secs
end

-- switch Off a device
function switchOff(device)
   os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Off" &')
end

-- Toggle a device
function switch(device)
   os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Toggle" &')
end

-- switch On a group or scene
function groupOn(device)
   os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchscene&idx='..otherdevices_scenesgroups_idx[device]..'&switchcmd=On" &')
end

-- switch Off a group
function groupOff(device)
   os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchscene&idx='..otherdevices_scenesgroups_idx[device]..'&switchcmd=Off" &')
end

-- Open a blind      
function blindOpen(device)
   switchOff(device)
end

-- Close a blind      
function blindClose(device)
   switchOn(device)
end

-- Stop a blind
function blindStop(device)
   switchOn(device,16)
end


