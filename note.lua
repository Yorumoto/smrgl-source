local note = {}
note.__index = note

function note:Destroy()
	self.FlagClean = true
end

function note.new(lane, time)
	lane = lane or 1
	time = time or 0

	local self = setmetatable({}, note)
	self.FlagClean = false
	self.Time = time
	-- self.ReleaseTime = time
	self.Lane = lane
	self.Type = "note"
	self.State = "active"

	return self
end

return note