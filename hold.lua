local note = require 'note'
local hold = {}
hold.__index = hold
setmetatable(hold, note)

function hold.new(lane, startTime, releaseTime)
	local self = note.new(lane, startTime)
	self.ReleaseTime = releaseTime 
	self.Type = "hold"
	return self
end

return hold