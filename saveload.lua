local fileClass = require 'file'
local module = {}
module.FileLocation = ""

local individualSeperator = '"'
local __lines = {}
local __typeException = {}

__typeException.number = {}
__typeException.boolean = {}
__typeException.table = {}

__typeException.number.load = function(raw)
    local result = tonumber(raw) or 1
    return result
end

__typeException.boolean.load = function(raw)
    local result = raw == "true" and true or false
    return result
end

__typeException.table.load = function(rawt, file)
    local t = {}
    local split = file:__commaExtract(rawt, individualSeperator)
    print(unpack(split))
    return split
end

__typeException.boolean.save = function(value)
    return tostring(value)
end

__typeException.table.save = function(table)
    local str = table[1] .. individualSeperator
    
    for index = 2, #table do
        local item = table[index]        

        if item then
            str = str .. item .. individualSeperator
        end
    end

    return str
end

local function nl(str)
    table.insert(__lines, str)
end

local function cl(str)
    __lines = {}
end

local function intoString()
    local str = ""

    for index, line in pairs(__lines) do
        local newLine = index == #__lines and "" or "\r\n"
        str = str .. (line .. newLine)
    end

    return str
end

function module:load(ct)
    local changedIndividials = {}

	if love.filesystem.getInfo(module.FileLocation) then
		local file = fileClass.load("playerData.smrgld")
        file:__jumpTo("start_operation")
        file.InLine = file.InLine + 1
        
        repeat
            if file.Contents[file.InLine] ~= "end_operation" then
                local line = file.Contents[file.InLine]
                local extract = file:__colonExtract(line, nil, nil, nil, "table")
                local typeNameExtract = file:__colonExtract(extract[1], nil, nil, "_", "table")

                local typ, name, value, resultValue
                typ = typeNameExtract[1]
                name = typeNameExtract[2]
                value = extract[2]

                if __typeException[typ] and __typeException[typ].load then
                    resultValue = __typeException[typ].load(value, file)
                    changedIndividials[name] = resultValue
                end

                file.InLine = file.InLine + 1
            end
        until file.Contents[file.InLine] == "end_operation"

        file = nil
	end

    for key, value in pairs(changedIndividials) do
        ct[key] = value
    end

    return ct
end

function module:save(t, allowed)
    cl()
    nl("# This is your data file, this contains")
    nl("# the game's settings/options you've changed.")
    nl("")
    nl("start_operation")

    local dAllowed = {}

    for __, name in pairs(allowed) do
        dAllowed[name] = true
    end
    
    for name, value in pairs(t) do
        if dAllowed[name] then
            local typ, saveValue, saveName, line
            typ = type(value)

            saveName = typ .. "_" .. name .. ":"

            if __typeException[typ] and __typeException[typ].save then
                saveValue = __typeException[typ].save(value)
            else
                saveValue = tostring(value)
            end
            
            line = saveName .. saveValue
            nl(line)
        end
    end

    nl("end_operation")

    local writeString = intoString()
    love.filesystem.remove(module.FileLocation)
    love.filesystem.write(module.FileLocation, writeString)
end

return module