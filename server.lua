bootloader = {
    init = nil,
    port = 8,
    srv = "/srv",
    src = "/srv/factories",
    storageMounted = false,
    net = computer.getPCIDevices(classes.NetworkCard)[1]
}

local fs = filesystem

function bootloader:mountStorage(searchFile)
    if self.storageMounted then
        return
    end

    fs.initFileSystem("/dev")

    local devs = fs.children("/dev")
	for _, dev in pairs(devs) do
		local drive = filesystem.path("/dev", dev)
        fs.mount(drive, self.srv)
        if searchFile == nil or self:programExists(searchFile) then
            self.storageMounted = true
            computer.log(0, "Storage mounted (drive id: " .. dev .. ")")
            return true
        end
        self.storageMounted = false
        fs.unmount(drive)
	end

    return false
end

function bootloader:programExists(name)
    local path = fs.path(self.src, name)
    computer.log(0, "Checking for program on disk: " .. path)
    return fs.exists(path) and fs.isFile(path)
end

function bootloader:loadFromStorage(name)
    if not self.storageMounted then
        self:mountStorage()
    end

    if not self:programExists(name) then
        return nil
    end

    local path = fs.path(self.src, name)
    computer.log(0, "Opening path: " .. path)
	fd = fs.open(path, "r")
	content = ""
	while true do
		chunk = fd:read(1024)
		if chunk == nil or #chunk == 0 then
			break
		end
		content = content .. chunk
	end
	return content
end

function bootloader:loadCode(name)
    if not self.storageMounted then
        computer.log(0, "Mounting storage")
        self:mountStorage()
    end

    local content = nil
    if self.storageMounted then
        computer.log(0, "Loading " .. name .. " from storage")
        content = self:loadFromStorage(name)
    else
        computer.log(0, "No storage available")
    end
    return content
end

function bootloader:parseModule(name)
    local content = self:loadCode(name)
    if content then
        computer.log(0, "Parsing loaded content")
        local code, error = load(content)
        if not code then
            computer.log(4, "Failed to parse " .. name .. ": " .. tostring(error))
            event.pull(2)
            computer.reset()
        end
        return content
    else
        computer.log(3, "Could not load " .. name .. ": Not found.")
        return nil
    end
end

function bootloader:loadModule(name)
    computer.log(0, "Loading " .. name .. " through the bootloader")
    local code = self:parseModule(name)
    if code then
        -- We don't really expect this to return
        computer.log(0, "Starting " .. name)
        local success, error = pcall(code)
        if not success then
            computer.log(3, error)
            event.pull(2)
            computer.reset()
        end
    else
        computer.log(4, "Failed to load module " .. name)
    end
end

function bootloader:listen()
    if not self.net then
        error("Failed to start Net-Boot-Server: No network card found!")
    end
    self.net:open(self.port)
    event.listen(self.net)
    computer.log(0, "Listening for net-boot file requests on port " .. self.port)
end

function bootloader:resetAll()
    -- Reset all related Programs
    -- for programName in pairs(netBootPrograms) do
    --     self.net:broadcast(self.port, "reset", programName)
    --     print("Broadcasted reset for Program \"" .. programName .. "\"")
    -- end
end

local netBootFallbackProgram = [[
    print("Invalid Net-Boot-Program: Program not found!")
    event.pull(5)
    computer.reset()
]]

function bootloader:main()
    while true do
        local e, _, s, p, cmd, arg1 = event.pull()
        if e == "NetworkMessage" and p == self.port then
            computer.log(0, "Received a network message with cmd: " .. cmd)
            if cmd == "getEEPROM" then
                computer.log(1, "Program Request for \"" .. arg1 .. "\" from \"" .. s .. "\"")
                local code = self:parseModule(arg1) or netBootFallbackProgram
                self.net:send(s, self.port, "setEEPROM", arg1, code)
            end
        end
    end
end

bootloader:listen()
bootloader:main()
