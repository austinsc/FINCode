--[[ Net-Boot Client ]]--


-- Configuration
local netBootProgramName = "smelters.lua"
local netBootPort = 8
local serverComputerAddress = "6E1A985E429FCE5CD14FD5999FA97F33"
local serverNetworkCardAddress = "BAC6A2D64F316A767B50A487E9EF113E"

function printRouterCfg(router)    
    computer.log(0, "Addresses: ")
    local al = router:getAddrList()
    local pl = router:getPortList()
    for x in al do
	    --computer.log(0, x)
	end
	computer.log(0, "Ports: ")
    for x in pl do
	    --computer.log(0, x)
	end
    computer.log(0, "IsWhitelist: " .. tostring(router.isWhitelist))
end

-- Setup Network
local net = computer.getPCIDevices(classes.NetworkCard)[1]
if not net then
    error("Net-Boot: Failed to Start: No Network Card available!")
end

-- Disable firewall
computer.log(0, "Looking for router...")
local router = component.proxy(component.findComponent("factory router"))[1]
if not router then
    warning("No factory router found... skipping firewall modification")
else
    computer.log(0, "Router found...)

    --printRouterCfg(router)

	router.isWhitelist = true
    router:addPortList(netBootPort)
    router.isAddrWhitelist = true
    router:addAddrList(serverComputerAddress)
    router:addAddrList(serverNetworkCardAddress)
    --printRouterCfg(router)

end

net:open(netBootPort)
event.listen(net)

-- Wrap event.pull() and filter Net-Boot messages
local og_event_pull = event.pull
function event.pull(timeout)
    local args = {og_event_pull(timeout)}
    local e, _, s, p, cmd, programName = table.unpack(args)
    if e == "NetworkMessage" and p == netBootPort then
        if cmd == "reset" and programName == netBootProgramName then
            computer.log(2, "Net-Boot: Received reset command from Server \"" .. s .. "\"")
            if netBootReset then
                pcall(netBootReset)
            end
            computer.reset()
        end
    end
    return table.unpack(args)
end

-- Request Code from Net-Boot Server
local program = nil
while program == nil do
    print("Net-Boot: Request Net-Boot-Program \"" .. netBootProgramName .. "\" from Port " .. netBootPort)
    net:broadcast(netBootPort, "getEEPROM", netBootProgramName)
    while program == nil do
        local e, _, s, p, cmd, programName, code = event.pull(30)
        if e == "NetworkMessage" and p == netBootPort and cmd == "setEEPROM" and programName == netBootProgramName then
            print("Net-Boot: Got Code for Program \"" .. netBootProgramName .. "\" from Server \"" .. s .. "\"")
            program = load(code)
        elseif e == nil then
            computer.log(3, "Net-Boot: Request Timeout reached! Retry...")
            break
        end
    end
end

-- Execute Code got from Net-Boot Server
netBootReset = nil
local success, error = pcall(program)
if not success then
    computer.log(4, error)
    
    computer.reset()
end
