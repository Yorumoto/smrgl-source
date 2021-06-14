local file = {}
file.__index = file

function split(str, split)
	if not split then
		split = "%s"
	end

	local t = {}

	for str in string.gmatch(str, "([^".. split .."]+)") do
		table.insert(t, str)
	end

	return t
end

function file:__convertContentsFunction()
	local result = {}
	for line in self.Contents do
		table.insert(result, line)
	end

	return result
end

function file:__contents(callback)
	for index, line in pairs(self.Contents) do
		callback(line, index)
	end
end

function file:__jumpTo(targetString)
	self:__contents(function(l, i) 
		if l == targetString then
			self.InLine = i
			return
		end
	end)
end

function file:__colonExtract(line, typeof, noFirstSpace, customCharacter, returnType)
	returnType = returnType or "second"
	customCharacter = customCharacter or ":"

	if type(line) == "number" then
		line = self.Contents[line]
	end

	local result
	local split = split(line, customCharacter)

	if returnType == "second" then
		result = split[2]

		if not noFirstSpace then
			result = result:sub(2, -1)
		end

		if not typeof or not result then
			return result
		end

		if typeof == "number" then
			return tonumber(result)
		else
			return result
		end
	elseif returnType == "table" then
		return split
	end
end

function file:__quoteExtract(line)
	return line:sub(2, -2)
end

function file:__commaExtract(line, customSplitter, endWith)
	customSplitter = customSplitter or ","

	if type(line) == "number" then
		line = self.Contents[line]
	end

	local newLine = ""

	if endWith then
		local index = 1

		repeat
			index = index + 1
		until line:sub(index, index) == endWith

		newLine = string.sub(line, 1, index - 1) .. customSplitter
		line = newLine
	end

	local split = split(line, customSplitter)
	return split
end

function file:DumpLines()
	self:__contents(function(l, i)
		print(i .. ". | " .. l)
	end)
end

function file:GetDurationPoints(firstStartTime, measureBy)
	measureBy = measureBy or 2
	local durationPoints = {}

	self:__jumpTo("[TimingPoints]")
	self.InLine = self.InLine + 1

	repeat
		local line = self.Contents[self.InLine] .. ","
		local split = self:__commaExtract(self.InLine)

		if split[7] == "1" then
			local startTime, beatDuration, bpm
			startTime = tonumber(split[1]) or 0
			beatDuration = tonumber(split[2]) or 1000
			bpm = 60 / (beatDuration / 1000)
			bpm = bpm / measureBy
			beatDuration = 60000 / bpm

			if startTime > firstStartTime then
				table.insert(durationPoints, {
					Duration = beatDuration;
					Time = startTime;
				})
			end
		end

 		self.InLine = self.InLine + 1
	until not self.Contents[self.InLine] or self.Contents[self.InLine] == ""

	return durationPoints
end

function file:NewMeasureLines(hitObjects, audioLeadIn, by)
	by = by or 2

	local lines = {}
	local finalTime = (hitObjects[#hitObjects].Type == "hold" and hitObjects[#hitObjects].ReleaseTime or hitObjects[#hitObjects].Time) + (5 * 1000)
	local points = self:GetDurationPoints(0, by, "miliseconds")

	local time, currentDuration
	time = -audioLeadIn
	currentDuration = 1000

	repeat
		table.insert(lines, time)
		time = time + currentDuration

		if points[1] and time >= points[1].Time then
			currentDuration = points[1].Duration
			table.remove(points, 1)
		end
	until time >= finalTime

	return lines
end

function file:GetNotes()
	local notes = {}

	self:__jumpTo("[HitObjects]")
	self.InLine = self.InLine + 1

	repeat
		--if self.Contents[self.Inline] then
			local split = self:__commaExtract(self.InLine, nil, ":")

			for index, value in pairs(split) do
				split[index] = tonumber(value) or 0
			end

			local noteType, lane, startTime, releaseTime
			lane = math.ceil(split[1] * (4 / 512))
			startTime = split[3]
			noteType = split[4] == 128 and "hold" or "note"
			releaseTime = split[6]

			table.insert(notes, {
				Lane = lane;
				ReleaseTime = releaseTime;
				StartTime = startTime;
				Type = noteType;
			})
		--end

		self.InLine = self.InLine + 1
	until not self.Contents[self.InLine]

	return notes
end

function file.load(dir, fileDir, initialize)
	local self = setmetatable({}, file)
	self.ArtistName = ""
	self.AudioLeadIn = 0
	self.MapName = ""
	self.MapperName = ""
	self.Source = ""
	self.DifficultyName = ""
	self.AudioFilename = ""
	self.BackgroundFilename = ""
	self.PreviewTime = 0
	-- self.BPMPoints = {}

	self.InLine = 1
	self.Directory = dir
	self.FileDirectory = fileDir

	self.Contents = love.filesystem.lines(dir)
	self.Contents = self:__convertContentsFunction()
	
	if initialize then
		self:__jumpTo("[General]")
		self.AudioFilename = self:__colonExtract(self.InLine + 1)
		self.Audio = self:__colonExtract(self.InLine + 2, "number")
		self.PreviewTime = self:__colonExtract(self.InLine + 3, "number")
		-- self.BPMPoints = self:GetDurationPoints(self.PreviewTime, 1)
		self:__jumpTo("[Metadata]")
		self.MapName = self:__colonExtract(self.InLine + 1, nil, true)
		self.ArtistName = self:__colonExtract(self.InLine + 3, nil, true)
		self.MapperName = self:__colonExtract(self.InLine + 5, nil, true)
		self.DifficultyName = self:__colonExtract(self.InLine + 6, nil, true)
		self.Source = self:__colonExtract(self.InLine + 7, nil, true)
		self:__jumpTo("[Events]")

		pcall(function()
			self.BackgroundFilename = self:__quoteExtract(self:__commaExtract(self.InLine + 2)[3])
		end)
	end


	return self
end

return file