local noteClass = require 'note'
local holdClass = require 'hold'
local fileClass = require 'file'
local playerDataModule = require 'saveload'

local gameState = "n"

local mainFont, smallFont, smallBitFont, hugeFont, universalFont
local maxFps
maxFps = 120

local noteTime = 0
local pastTime = 0
local pauseCurrentTime, pauseStartTime

local drawf = {
	__menu = {};
	__results = {};
}

local updatef = drawf

local keypressf = {}
local formulaf = {}

formulaf.GetGrade = function(n)
	n = n or 0

	local get = "NO"

	if n >= 100 then
		get = "SS"
	elseif n >= 90 then
		get = "S"
	elseif n >= 80 then
		get = "A"
	elseif n >= 70 then
		get = "B"
	elseif n >= 60 then
		get = "C"
	else
		get = "D"
	end

	return get
end

local delayNextTime, delayMinimumDelta
delayMinimumDelta = 1 / maxFps

local songSourceObject
local judgeCount = {}
local notes = {}
local measureLines = {}
local maps = {}

local soundEffects = {
	HitClap = love.audio.newSource("Assets/clap.ogg", "stream");
	Select = love.audio.newSource("Assets/select.wav", "stream");
	Alert = love.audio.newSource("Assets/alert.mp3", "stream");
	Pause = love.audio.newSource("Assets/pause.wav", "stream")
}

local function playSound(name)
	local clone = soundEffects[name]:clone()
	love.audio.play(clone)
end

local gameSettings = {
	LaneStart = 300;
	LaneGap = 85 * 1.35;
	LaneFloat = 80;
	--ScrollSpeed = 0.1;
	ScrollSpeed = 7;
	NoteSize = 1.35;
	FancyScore = true;
	Autoplay = false;
	Keybinds = {"a", "s", "k", "l"};
	FPSCap = maxFps;
	IndicateFPS = true;
	MusicVolume = 1;
	HitVolume = 1;
	GlobalOffset = 0;
	RenderNoteBuffer = 100;
	Upscroll = false;
	ZoomVisualization = true;
	TimeBottomBar = true;
}

local allowedToSaveData = {"ScrollSpeed", "Autoplay", "Keybinds", "MusicVolume", "FancyScore", "MusicVolume", 
						   "HitVolume", "GlobalOffset", "FPSCap", "RenderNoteBuffer", "Upscroll", "IndicateFPS",
						   "ZoomVisualization", "TimeBottomBar", "LaneStart"
						  }

local isKeyDown = {false, false, false, false}
local inputDown = {false, false, false, false}

local score, combo, accuracy, globalDifference, scoreSmooth, isPlayingSong, paused, pauseSelection, pauseTime, songDone
local pauseCountdown, countdownEnabled, pauseInputDown, pauseMenuIndex, comboHoldDelay, transparentTime, lastNoteTime
local renderNoteBuffer

local constantAudioLeadIn = 2500

local hitWindows = {151*1.5;151;113;76;38;18;0;}

local hitWindowNames = {
	"nn";"ms";"bd";"gd";"gt";"pf";"mv";
}

local resultsSortedHitWindowNames = {
	"mv";"pf";"gt";"gd";"bd";"ms";
}

local hitWindowImage = love.graphics.newImage("Assets/Judges.png")

local hitWindowImages = {
	--[[mv = love.graphics.newQuad(73, 12, 364, 48, hitWindowImage:getDimensions());
	pf = love.graphics.newQuad(128, 79, 255, 48, hitWindowImage:getDimensions());
	gt = love.graphics.newQuad(159, 147, 195, 48, hitWindowImage:getDimensions());
	gd = love.graphics.newQuad(161, 213, 190, 48, hitWindowImage:getDimensions());
	bd = love.graphics.newQuad(190, 280, 129, 50, hitWindowImage:getDimensions());
	ms = love.graphics.newQuad(180, 349, 148, 51, hitWindowImage:getDimensions());]]--

	mv = love.graphics.newQuad(73, 12, 364, 48, hitWindowImage:getDimensions());
	pf = love.graphics.newQuad(73, 79, 364, 48, hitWindowImage:getDimensions());
	gt = love.graphics.newQuad(73, 147, 364, 48, hitWindowImage:getDimensions());
	gd = love.graphics.newQuad(73, 213, 364, 48, hitWindowImage:getDimensions());
	bd = love.graphics.newQuad(73, 280, 364, 50, hitWindowImage:getDimensions());
	ms = love.graphics.newQuad(73, 349, 364, 51, hitWindowImage:getDimensions());
	anythingelselol = love.graphics.newQuad(0, 0, 0, 0, hitWindowImage:getDimensions());
}

local scoringWindows = {
	mv = 600;
	pf = 500;
	gt = 450;
	gd = 250;
	bd = 50;
	ms = 0;
}

local properHitWindowNames = {
	mv = "Marvelous";
	pf = "Perfect";
	gt = "Great";
	gd = "Good";
	bd = "Bad";
	ms = "Miss"
}

local hitWindowColors = {
	mv = {0, 188, 242};
	pf = {255, 219, 46, 1};
	gt = {2, 217, 31, 1};
	gd = {7, 165, 224, 1};
	bd = {252, 30, 180};
	ms = {212, 12, 18};
}

for __, value in pairs(hitWindowColors) do
	for index = 1, 3 do
		local v = value[index]

		if v then
			value[index] = value[index] / 256
		end
	end
end


local hitWindowNameDisplay, hitWindowTimeDisplay
hitWindowTimeDisplay = 0

local comboPositionY

local menuConfig = {
	DisplayPageStart = 1;
	DisplayPageEnd = 15;
	DrawListMultiply = 0;
	RadiusMultiply = 0;
	Selected = 1;
	SongSelected = 1;
	SettingSelected = 1;
	InputDown = false;
	LastPlayed = "";
	IsParsing = false;
	InSettings = false;
	DoneZooming = false;

	CoolEffect = {
		{
			Objects = 8;
			Size = 20;
			Radius = 80;
			Rotation = 90;
		};
		{
			Objects = 10;
			Size = 30;
			Radius = 160;
			Rotation = -45;
		};
		{
			Objects = 12;
			Size = 10;
			Radius = 240;
			Rotation = 45 / 2;
		};
		{
			Objects = 14;
			Size = 20;
			Radius = 320;
			Rotation = -45 / 4;
		};
		{
			Objects = 6;
			Size = 20;
			Radius = 400;
			Rotation = 90;
		};
	};

	Settings = {
		{
			Target = "Autoplay";
			ProperName = "Autoplay";
			Description = "Watch the computer smashing the keys and stuff! (UNRANKED)"
		};
		{
			Target = "HitVolume";
			ProperName = "Clap Volume";
			Clamp = {min=0;max=1;by=0.1;};
			Render = {multiply=100;suffix="%";};
			Description = "Set how loud or quiet the claps will be."
		};
		{
			Target = "LaneStart";
			ProperName = "Lane X Position";
			Clamp={min=200;max=500;by=5};
			Description = "Sets the receptors' position by this setting."
		};
		{
			Target = "FancyScore";
			ProperName = "Fancy Score";
			Description = "See the score going up slowly if this enabled."
		};
		{
			Target = "FPSCap";
			ProperName = "FPS Cap";
			Description = "Enjoy smoother gameplay by setting the cap higher, don't let it burn your computer.";
			Clamp={min=15;max=240;by=5;};
		};
		{
			Target = "IndicateFPS";
			ProperName = "FPS Counter";
			Description = "Indicates how many FPS you are experiencing."
		};
		{
			Target = "GlobalOffset";
			ProperName = "Global Offset";
			Clamp = {min=-2000;max=2000;by=5;};
			Render={suffix="ms";};
			Description = "Most of time desync? Try to change this setting."
		};
		{
			Target = "Keybinds";
			ProperName = "Keybinds";
			Description = "Customize on how you press and smash the keys.";
			TableType = "KeyConstant";
		};
		{
			Target = "MusicVolume";
			ProperName = "Music Volume";
			Clamp = {min=0;max=1;by=0.1;};
			Render = {multiply = 100; suffix = "%";};
			Description = "Set how loud or quiet the music will be."
		};
		{
			Target = "RenderNoteBuffer";
			ProperName = "Render Note Buffer";
			Clamp = {min=0;max=200;by=5};
			Description = "Renders how many notes should render."
		};
		{
			Target = "ScrollSpeed";
			ProperName = "Scroll Speed";
			Clamp = {min=0;max=12;by=0.25;};
			Description = "Set how fast or slow the circles will fall down."
		};
		{
			Target = "Upscroll";
			ProperName = "Upscroll";
			Description = "Make your gameplay style DDR-like by enabling this!";
		};
		{
			Target = "ZoomVisualization";
			ProperName = "Zoom Visualization";
			Description = "See the orbiting circles zooming in to the beat! (may trigger epilepsy)"
		};
		{
			Target = "TimeBottomBar";
			ProperName = "Time Progress Bar";
			Description = "Display the progress bar on the bottom zone of the screen."
		}
	};

	Songs = {};
}

local responseKeep
local pausef = {}

pausef.unpause = function()
	pauseCountdown = 1
	countdownEnabled = true
end

pausef.restart = function()
	responseKeep = "restart"
	pauseSelection = 2
	pauseMenuIndex = 2
end

pausef.giveUp = function()
	responseKeep = "quit"
	pauseSelection = 2
	pauseMenuIndex = 2
end

pausef.no = function()
	pauseSelection = 1
	pauseMenuIndex = 1
end

local settingsArrayHold
--------------------------

-- local autoplayPointer = {nil, nil, nil, nil}

--------------------------

updatef.SetNoteTime = function()
	noteTime = ((((love.timer.getTime() - pauseTime) - pastTime) * 1000) - constantAudioLeadIn)
end

local previewBPMPoints = {}

local function playPreviewMusic()
	local song = menuConfig.Songs[menuConfig.SongSelected]

	if not song then
		return
	end

	local audioDirectory = song.FileDirectory .. "/" .. song.AudioFilename

	if audioDirectory == menuConfig.LastPlayed then
		return
	end


	if songSourceObject then
		songSourceObject:stop()
		songSourceObject = nil
	end

	local seekPreview = song.PreviewTime / 1000

	if seekPreview <= 0 then
		seekPreview = 0
	end

	songSourceObject = love.audio.newSource(audioDirectory, "stream")
	songSourceObject:seek(seekPreview)
	songSourceObject:play()

	menuConfig.LastPlayed = audioDirectory

	-- previewBPMPoints = song:NewMeasureLines({{Type="note";Time=(3600)*1000;}}, constantAudioLeadIn, 1)
	previewBPMPoints = song:GetNotes()

	if #previewBPMPoints <= 0 then
		return
	end

	local seekTime = song.PreviewTime

	repeat
		table.remove(previewBPMPoints, 1)
	until #previewBPMPoints <= 0 or previewBPMPoints[1].StartTime >= seekTime
end

local function menuSetup()
	menuConfig.LastPlayed = ""
	menuConfig.DrawListMultiply = 0
	menuConfig.RadiusMultiply = 0
	menuConfig.InSettings = false
	menuConfig.DoneZooming = false
	menuConfig.Selected = menuConfig.SongSelected
	playPreviewMusic()
	gameState = "menu"

	if not settingsArrayHold then
		settingsArrayHold = {}
		for name in pairs(gameSettings) do
			settingsArrayHold[name] = 1
		end
	end
end

local function gameSetup()
	noteTime = -60 * 1000
	accuracy = 100
	pastTime = love.timer.getTime()
	renderNoteBuffer = gameSettings.RenderNoteBuffer
	score, combo = 0, 0
	scoreSmooth = 0
	comboPositionY = 175
	isPlayingSong = false
	paused = false
	pauseSelection = 1
	pauseTime = 0
	pauseCountdown = 0
	pauseMenuIndex = 1
	transparentTime = 0
	songDone = false
	hitWindowNameDisplay = nil
	hitWindowTimeDisplay = 0
	comboHoldDelay = 0
	previewBPMPoints = {}
	countdownEnabled = false

	local finalNote = notes[#notes]

	if finalNote then
		lastNoteTime = ((finalNote.Type == "hold" and finalNote.ReleaseTime or finalNote.Time) or 0)
	end

	soundEffects.HitClap:setVolume(gameSettings.HitVolume)
	
	if songSourceObject then
		songSourceObject:setVolume(gameSettings.MusicVolume)
	end

	for __, windowName in pairs(hitWindowNames) do
		judgeCount[windowName] = 0
	end
end

local function clamp(x, lower, upper)
	if lower > upper then lower, upper = upper, lower end
    return math.max(lower, math.min(upper, x))
end

local function parseSong(song)
	if not song then
		love.event.quit()
		return
	end

	notes = {}
	-- smh the whole thing doesn't get removed
	-- who to fuck and blame? me or the lua interpreter

	local rawNotes = song:GetNotes()
	
	for __, rawNote in pairs(rawNotes) do
		local lane, startTime
		lane = rawNote.Lane
		startTime = rawNote.StartTime
		lane = clamp(lane, 1, 4)
		
		if rawNote.Type == "hold" then
			local releaseTime = rawNote.ReleaseTime
			table.insert(notes, holdClass.new(lane, startTime, releaseTime))
		else
			table.insert(notes, noteClass.new(lane, startTime))
		end
	end

	--[[for __, rawNote in pairs(rawNotes) do
		for _ = 1, math.random(1, 20) do
			local lane, startTime, noteType
			lane = math.random(-2500, 7500) / 1000
			startTime = rawNote.StartTime + math.random(-100, 100)
			noteType = math.random(1, 2) == 1 and "note" or "hold"
			-- lane = clamp(lane, 1, 4)
			
			if noteType == "hold" then
				local releaseTime = rawNote.ReleaseTime or 0
				table.insert(notes, holdClass.new(lane, startTime, releaseTime))
			else
				table.insert(notes, noteClass.new(lane, startTime))
			end
		end
	end]]--

	--[[for __, rawNote in pairs(rawNotes) do
		local lane, startTime, noteType
		lane = rawNote.Lane + (math.random(0, 950) / 1000)
		startTime = rawNote.StartTime
		noteType = rawNotes.Type
		-- lane = clamp(lane, 1, 4)
		
		if noteType == "hold" then
			local releaseTime = rawNote.ReleaseTime
			table.insert(notes, holdClass.new(lane, startTime, releaseTime))
		else
			table.insert(notes, noteClass.new(lane, startTime))
		end
	end]]--

	table.sort(notes, function(a, b)
		return b.Time > a.Time
	end)

	measureLines = song:NewMeasureLines(notes, constantAudioLeadIn)
end

local function selectSong()
	if menuConfig.IsParsing then
		return
	end

	menuConfig.IsParsing = true

	if songSourceObject then
		songSourceObject:stop()
		songSourceObject = nil
	end

	local index = menuConfig.SongSelected
	local song = menuConfig.Songs[index]
	local audioDirectory = song.FileDirectory .. "/" .. song.AudioFilename
	songSourceObject = love.audio.newSource(audioDirectory, "stream")
	parseSong(song)
	gameSetup()
	gameState = "game"
	menuConfig.IsParsing = false
end

local resultsf = {}

resultsf.retrySong = function()
	selectSong()
end

resultsf.goBack = function()
	menuSetup()
end

local resultsConfig = {
	InputDown = false;
	Selected = 1;
	Body = {
		{
			Text = "Retry this song";
			Trigger = resultsf.retrySong;
		};
		{
			Text = "Return back";
			Trigger = resultsf.goBack;
		};
	}
}

local constantResultsKeyDown = {"up", "down", "z", "return"}

local function resultsSetup()
	resultsConfig.Selected = 1
	gameState = "results"
end

pausef.yes = function(custom)
	custom = custom or responseKeep
	if custom == "restart" then
		selectSong()
	elseif custom == "quit" then
		menuSetup()
	elseif custom == "results" then
		resultsSetup()
	end
end

updatef.__results.UpdateInput = function()
	local resultsKeyDown = {}
	local anyOfItIsTrue = false

	for __, key in pairs(constantResultsKeyDown) do
		resultsKeyDown[key] = love.keyboard.isDown(key)

		if resultsKeyDown[key] and not anyOfItIsTrue then
			anyOfItIsTrue = true
		end
	end


	if anyOfItIsTrue then
		if not resultsConfig.InputDown then
			if resultsKeyDown.up or resultsKeyDown.down then
				resultsConfig.Selected = resultsConfig.Selected + ((resultsKeyDown.up and -1 or 0) + (resultsKeyDown.down and 1 or 0))
				if resultsConfig.Selected > #resultsConfig.Body then
					resultsConfig.Selected = 1
				end

				if resultsConfig.Selected < 1 then
					resultsConfig.Selected = #resultsConfig.Body
				end
			elseif resultsKeyDown.z or resultsKeyDown["return"] then
				local triggerCallback = resultsConfig.Body[resultsConfig.Selected].Trigger
				if triggerCallback then
					triggerCallback()
				end
			end
		end

		resultsConfig.InputDown = true
	else
		resultsConfig.InputDown = false
	end
end

drawf.__results.DrawSelection = function()
	local __, cwh = love.window.getMode()
	
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(smallBitFont)

	for index, item in pairs(resultsConfig.Body) do
		local color = index == resultsConfig.Selected and {1, 1, 1, 1} or {1, 1, 1, 0.4}
		local offset = (cwh - 75) + ((index - 1) * 30)
		love.graphics.setColor(color)
		love.graphics.print(item.Text , 25, offset)
	end
end

formulaf.SumTable = function(table)
	local sum = 0

	for __, value in pairs(table) do
		sum = sum + value
	end

	return sum
end

formulaf.LightDarkenHue = function(colorTable, by)
	local t = {}

	for index = 1, 3 do
		table.insert(t, colorTable[index] * by)
	end

	table.insert(t, 1)

	return t
end

drawf.__results.DrawResults = function()
	local cww, __ = love.window.getMode()
	local judgeBarOffset = 20
	local endOffset = cww - judgeBarOffset
	local modifiedEndOffset = endOffset - 140

	love.graphics.setFont(smallBitFont)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print("Score:", 40, 30)
	love.graphics.printf("Accuracy:", 40, 30, endOffset - 70, "right")
	love.graphics.setFont(hugeFont)
	love.graphics.print(tostring(score), 40, 60)
	
	local displayAccuracy = math.floor(accuracy * 1000) / 1000
	love.graphics.printf(displayAccuracy .. "%", 40, 60, endOffset - 65, "right")

	-- love.graphics.line(judgeBarOffset, 180, endOffset, 180)
	-- ^ placeholder

	local totalCount = formulaf.SumTable(judgeCount)
	love.graphics.setLineWidth(50)

	local y = 180
	local difference = modifiedEndOffset - judgeBarOffset
	
	for __, key in pairs(resultsSortedHitWindowNames) do
		if key and key ~= "nn" then
			local count = judgeCount[key]
			local color = hitWindowColors[key]
			local properName = properHitWindowNames[key]

			if count and color and properName then
				local darkenedColor = formulaf.LightDarkenHue(color, 0.6)
				local textColor = formulaf.LightDarkenHue(color, 0.8)

				local division = count / totalCount
				-- i can't do baby level math

				local calculatedXPos = judgeBarOffset + (division * (difference))

				love.graphics.setColor(darkenedColor)
				love.graphics.line(judgeBarOffset, y, modifiedEndOffset, y)
				love.graphics.setColor(color)
				love.graphics.line(judgeBarOffset, y, calculatedXPos, y)
				love.graphics.setColor(textColor)
				love.graphics.setFont(mainFont)
				love.graphics.print(properName, judgeBarOffset + 7.5, y - 25)
				love.graphics.setColor(1, 1, 1, 1)
				local countX = endOffset - 130
				-- love.graphics.line(countX, y, countX + (90), y)
				love.graphics.printf(count, countX, y - 25, 110, "center")

				y = y + 60
			end
		end
	end
end

local function updateResults()
	updatef.__results.UpdateInput()
end

local function drawResults()
	drawf.__results.DrawResults()
	drawf.__results.DrawSelection()
end

formulaf.GetNoteYPosition = function(targetY, selfTime)
	local difference = selfTime - noteTime
	local getY = targetY - (((difference / 5) * gameSettings.ScrollSpeed) * (gameSettings.Upscroll and -1 or 1))
	return getY
end

formulaf.GetPositionByLane = function(lane)
	local __, windowHeight = love.window.getMode()
	local getX, getY
	getX = gameSettings.LaneStart + ((lane - 1) * gameSettings.LaneGap)
	getY = gameSettings.Upscroll and gameSettings.LaneFloat or windowHeight - gameSettings.LaneFloat
	return getX, getY
end

drawf.DrawFPS = function()
	if not gameSettings.IndicateFPS then
		return
	end

	love.graphics.setColor(255, 255, 255, 1)
	love.graphics.setFont(smallFont)
	love.graphics.print("FPS: " .. love.timer.getFPS() .. " | Timer: " .. math.floor(noteTime), 10, 5)
end

-- note color: 

local function drawNote(x, y, color, size)
	size = size or 30
	love.graphics.setColor(110/256, 110/256, 110/256, 1)
	love.graphics.circle("fill", x, y, size * gameSettings.NoteSize, 360 / 2)
	love.graphics.setColor(color)
	love.graphics.circle("fill", x, y, (size - 3) * gameSettings.NoteSize, 360 / 2)
end

drawf.DrawMeasureLines = function()
	love.graphics.setColor(1, 1, 1, 0.65)
	love.graphics.setLineWidth(10)

	for renderBuffer = 1, 50 do
		local measureLine = measureLines[renderBuffer]

		if measureLine then
			local px, py = formulaf.GetPositionByLane(0.5)
			local endPx = formulaf.GetPositionByLane(4.5)
			py = formulaf.GetNoteYPosition(py, measureLine)
			love.graphics.line(px, py, endPx, py)
		end
	end
end

drawf.DrawLanes = function()
	for receptionLane = 1, 4 do
		local receptionColor = isKeyDown[receptionLane] and {1, 1, 1, 1} or {0, 0, 0, 1}
		local px, py = formulaf.GetPositionByLane(receptionLane)
		drawNote(px, py, receptionColor)
	end

	--[[local localBuffer = renderNoteBuffer

	if math.abs(gameSettings.ScrollSpeed) > 0 then
		localBuffer = renderNoteBuffer / ((gameSettings.ScrollSpeed / 7) * 0.333333333333)
	end]]--

	local __, chw = love.window.getMode()

	for index = 1, renderNoteBuffer do
		note = notes[index]

		if note then
			local px, constantpy = formulaf.GetPositionByLane(note.Lane)

			local py
			py = constantpy

			if note.Type == "hold" then
				local startPy = formulaf.GetNoteYPosition(constantpy, note.ReleaseTime)
				py = startPy

				if startPy < 0 and not gameSettings.Upscroll then
					startPy = 0
				elseif startPy <= chw and gameSettings.Upscroll then
					startPy = chw
				end
				
				local endpy = formulaf.GetNoteYPosition(constantpy, note.Time)

				love.graphics.setColor(1, 1, 1, 1)
				love.graphics.setLineWidth(37)
				love.graphics.line(px, endpy, px, py)

				if (py > 0 and not gameSettings.Upscroll) or (py < chw and gameSettings.Upscroll) then
					drawNote(px, py, {1, 1, 1, 1}, 27, {1, 1, 1, 1})
				end
			end

			py = formulaf.GetNoteYPosition(constantpy, note.Time)

			if (py > 0 and not gameSettings.Upscroll) or (py < chw and gameSettings.Upscroll) then
				drawNote(px, py, {24/256, 188/256, 242/256, 1})
			end
		end
	end
end

drawf.DrawHitWindowImage = function()
	local selectedWindowNameDisplay = hitWindowNameDisplay

	if hitWindowTimeDisplay <= 0 or not selectedWindowNameDisplay then
		selectedWindowNameDisplay = "anythingelselol"
	end

	local selectedQuad = hitWindowImages[selectedWindowNameDisplay]

	if not selectedQuad then
		selectedWindowNameDisplay = "anythingelselol"
		selectedQuad = hitWindowImages[selectedWindowNameDisplay]
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.scale(0.65, 0.65)

	--[[local dx, __, dw = selectedQuad:getViewport()
	local dtw = dx - dw
	px = dtw - (dw / 2)]]--
	px, __ = formulaf.GetPositionByLane(3.125)
	--px = px + addpx + 75

	local __, chw = love.window.getMode()
	local py = not gameSettings.Upscroll and 100 or chw / 2
	love.graphics.draw(hitWindowImage, selectedQuad, px, py)

	hitWindowTimeDisplay = hitWindowTimeDisplay - 1

	love.graphics.scale(1, 1)
end

drawf.DrawCombo = function()
	if not hitWindowNameDisplay then
		return
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(hugeFont)

	local text = combo
	local gd = globalDifference or 1
	local subText = math.floor(gd * 100) / 100 .. "ms"

	local px = formulaf.GetPositionByLane(3.75)
	local endx = formulaf.GetPositionByLane(5.75)
	local diff = endx - px

	local __ windowHeight = love.window.getMode()

	local y = comboPositionY
	y = y + (gameSettings.Upscroll and 220 or 0)

	love.graphics.printf(text, px, y, diff, "center")
	
	love.graphics.setFont(smallBitFont)
	love.graphics.printf(subText, px, y + 90, diff, "center")

	if not paused then
		comboPositionY = comboPositionY + ((175 - comboPositionY) / (maxFps / 10))
	end
end

drawf.DrawJudgeCount = function()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(smallBitFont)

	local drawIndex = 1

	for index, windowName in pairs(hitWindowNames) do
		local properName = properHitWindowNames[windowName] or "no"

		if properName ~= "no" then
			local yOffset = (drawIndex - 1) * 25

			local count = judgeCount[windowName] or 69 -- ahahahahahaha
			local text = properName .. ": " .. count

			love.graphics.print(text, 15, 90 + yOffset)

			drawIndex = drawIndex + 1
		end
	end
end

drawf.DrawBottomBar = function()
	if not gameSettings.TimeBottomBar then
		return
	end

	local cww, cwh = love.window.getMode()
	love.graphics.setColor(1, 1, 1, 0.65)
	love.graphics.setLineWidth(20)
	
	local y = (cwh * 1.5) - 10
	love.graphics.line(0, y, (noteTime / lastNoteTime) * (cww * 1.5), y)

	love.graphics.setColor(1, 1, 1, 1)
end

drawf.DrawScore = function()
	love.graphics.setFont(mainFont)

	local displayAccuracy = math.floor(accuracy * 1000) / 1000
	love.graphics.print(math.ceil(scoreSmooth), 25, 625)
	love.graphics.print(displayAccuracy .. "% | " .. formulaf.GetGrade(accuracy), 25, 565)

	if gameSettings.Autoplay then
		love.graphics.print("Autoplaying...", 25, 505)
	end

	if not paused then
		if gameSettings.FancyScore then
			scoreSmooth = scoreSmooth + ((score - scoreSmooth) / (maxFps / 5))
		else
			scoreSmooth = score
		end
	end
end

local pauseInfo = {}


drawf.DrawPauseMenu = function()
	love.graphics.setColor(0, 0, 0, 0.6)
	local cww, cwh = love.window.getMode()
	love.graphics.rectangle("fill", 0, 0, cww * 2, cwh * 2)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.setFont(hugeFont)

	if countdownEnabled then
		love.graphics.printf("Get ready...", cww / 4 , cwh / 1.5, cww, "center")
	else
		love.graphics.printf("Game Paused", cww / 4 , cwh / 2.5, cww, "center")

		local i = pauseInfo[pauseMenuIndex]
		for rindex, item in pairs(i.Body) do
			local offset = ((cwh / 2.5) + 135) + ((rindex - 1) * 75)
			local color = (pauseSelection == rindex or rindex < i.ClampMin) and {1, 1, 1, 1} or {1, 1, 1, 0.35}
			love.graphics.setColor(color)
			love.graphics.printf(item.Text, cww / 4 , offset, cww, "center")
		end
	end
end

drawf.SongDoneTransparency = function()
	local clamped = {0, 0, 0, clamp(transparentTime / 2, 0, 1)}
	love.graphics.setColor(clamped)
	
	local cww, cwh = love.window.getMode()
	love.graphics.rectangle("fill", 0, 0, cww * 2, cwh * 2)
end

local function displayHitWindowImage(imageString)
	hitWindowTimeDisplay = maxFps * 6
	hitWindowNameDisplay = imageString
end

local function getClosestNoteByLane(lane, returnType)
	lane = lane or 1
	local returnIndex, returnNote

	for index, note in pairs (notes) do
		if math.floor(note.Lane) == lane then
			returnNote = note
			returnIndex = index
			break
		end
	end

	if returnType == "index" then
		return returnIndex
	elseif returnType == "note" then
		return returnNote
	elseif returnType == "both" then
		return returnNote, returnIndex
	end
end

local function inputCheck(lane, inputType)
	if #notes <= 0 then
		return
	end

	local note = getClosestNoteByLane(lane, "note")

	if not note then
		return
	end

	local nt = inputType == "press" and note.Time or note.ReleaseTime

	if nt == nil then
		nt = -50 * 1000
	end

	--if note.Type == "hold" and inputType == "press" and note.Time >= noteTime - hitWindows[1] then
	--	nt = note.ReleaseTime
	--end

	local absDifference = math.abs(nt - noteTime)

	local rightTimeWindow

	for hitIndex, windowTarget in pairs(hitWindows) do
		if (windowTarget) <= absDifference and nt >= noteTime - hitWindows[1] then
			rightTimeWindow = hitWindowNames[hitIndex]
			break
		end
	end



	if not rightTimeWindow or rightTimeWindow == "nn" then
		return
	end

	--local cloneHitClapSound = soundEffects.HitClap:clone()
	--love.audio.play(cloneHitClapSound)

	playSound("Clap")
	

	if note.Type == "hold" and note.State == "active" and inputType == "press" then
		--if rightTimeWindow ~= "ms" and rightTimeWindow ~= "bd" and rightTimeWindow ~= "gd" then
		if rightTimeWindow ~= "ms" then
			note.State = "hold"
		end

		--end

		return
	end

	if note.State == "hold" and inputType == "release" then
		if noteTime - note.ReleaseTime >= 0.25 then
			note:Destroy()
			return
		end
	end

	note:Destroy()

	score = score + math.floor((scoringWindows[rightTimeWindow] * (combo + 1)) * (accuracy / 10))
	combo = rightTimeWindow ~= "ms" and combo + 1 or 0
	globalDifference = absDifference

	if rightTimeWindow ~= "ms" then
		comboPositionY = 235
	end

	judgeCount[rightTimeWindow] = judgeCount[rightTimeWindow] + 1
	displayHitWindowImage(rightTimeWindow)
end

updatef.Autoplay = function()
	for index, __ in pairs(inputDown) do
		inputDown[index] = false
	end

	for index = 1, 50 do
		local note = notes[index]

		if note then
			local lane = math.floor(note.Lane)

			if noteTime >= note.Time then
				if note.Type == "note" then
					inputDown[lane] = true
				elseif noteTime >= note.ReleaseTime then
					inputDown[lane] = false
				elseif note.State == "hold" or note.State == "active" then
					inputDown[lane] = true
				end
			end
		end
	end
end

updatef.UpdateBoolKeys = function()
	if gameSettings.Autoplay then
		updatef.Autoplay()
	end

	for index = 1, 4 do
		if not gameSettings.Autoplay then
			inputDown[index] = love.keyboard.isDown(gameSettings.Keybinds[index])
		end

		if inputDown[index] then
			if not isKeyDown[index] then
				inputCheck(index, "press")
			end

			isKeyDown[index] = true
		else
			if isKeyDown[index] then
				inputCheck(index, "release")
			end

			isKeyDown[index] = false
		end
	end
end

updatef.SetPauseTime = function(dt)
	pauseTime = pauseTime + dt
end

updatef.PauseCountdown = function(dt)
	if not countdownEnabled then
		return
	end

	pauseCountdown = pauseCountdown - dt

	if pauseCountdown < 0 then
		paused = false
		countdownEnabled = false
	end
end

updatef.HandleMeasureLines = function()
	for buffer = 1, 100 do
		local measureLine = measureLines[buffer]

		if measureLine then
			if measureLine <= noteTime - hitWindows[1] then
				table.remove(measureLines, buffer)
			end
		end
	end
end

updatef.HandleNotes = function(dt)
	-- cleanup and hold management and hold stuff counter combo thing idk:
	local holdCount = 0

	for index = 1, 100 do
		local note = notes[index]

		if note then
			if note.State == "hold" and note.Time <= noteTime and inputDown[note.Lane] then
				holdCount = holdCount + 1
				note.Time = noteTime
			end

			if (note.Type == "note" and note.Time - noteTime <= -hitWindows[1]) then
				combo = 0
				judgeCount["ms"] = judgeCount["ms"] + 1
				displayHitWindowImage("ms")
				note:Destroy()
			end

			if note.Type == "hold" and (note.ReleaseTime - noteTime <= -hitWindows[1]) then
				holdCount = holdCount - 1
				globalDifference = -hitWindows[1]
				note:Destroy()
			end

			if note.FlagClean then
				table.remove(notes, index)
			end
		end
	end

	if holdCount > 0 and comboHoldDelay < 0 then
		comboPositionY = 235
		combo = combo + holdCount
		comboHoldDelay = 0.05
	end

	comboHoldDelay = comboHoldDelay - dt
end

updatef.StartPlayMusic = function()
	if noteTime > gameSettings.GlobalOffset and not isPlayingSong then
		isPlayingSong = true
		love.audio.play(songSourceObject)
	end
end

updatef.UpdateAccuracy = function()
	local perfectCount, total
	perfectCount = 0
	otherCount = 0
	total = 0

	for name, count in pairs(judgeCount) do
		if name == "mv" or name == "pf" then
			perfectCount = perfectCount + count
		end

		total = total + count
	end

	accuracy = ((perfectCount + 1) / (total + 1)) * 100
end

updatef.UpdatePauseInput = function()
	local arrowKey = love.keyboard.isDown("up") or love.keyboard.isDown("down")
	local executeKey = love.keyboard.isDown("z") or love.keyboard.isDown("return")

	if arrowKey or executeKey and not countdownEnabled then
		if not pauseInputDown then
			if arrowKey then
				pauseSelection = pauseSelection + ((love.keyboard.isDown("up") and -1 or 0) + (love.keyboard.isDown("down") and 1 or 0))
		
				local i = pauseInfo[pauseMenuIndex]
				local length = #i.Body

				if pauseSelection < i.ClampMin then
					pauseSelection = length
				end
		
				if pauseSelection > length then
					pauseSelection = i.ClampMin
				end

				playSound("Select")
			else
				local cb = pauseInfo[pauseMenuIndex].Body[pauseSelection].Callback
				if cb then
					cb()
					playSound("Select")
				end
			end
		end

		pauseInputDown = true
	else
		pauseInputDown = false
	end
end

updatef.CheckIfSongDone = function()
	songDone = #notes <= 0

	if songDone then
		transparentTime = transparentTime + (delayMinimumDelta)

		if transparentTime > 2 then
			pausef.yes("results")
		end
	end
end

table.insert(pauseInfo, {
	ClampMin = 1;
	Body = 	{
		{
			Text = "Resume";
			Callback = pausef.unpause;
		};
		{
			Text = "Restart";
			Callback = pausef.restart;
		};
		{
			Text = "Give up";
			Callback = pausef.giveUp;
		};
	};
})

table.insert(pauseInfo, {
	ClampMin = 2;
	Body = 	{
		{
			Text = "Are you sure about that?";
		};
		{
			Text = "Yes";
			Callback = pausef.yes;
		};
		{
			Text = "No";
			Callback = pausef.no;
		};
	};
})

local function updateGame(dt)
	if paused then
		updatef.SetPauseTime(dt)
		updatef.PauseCountdown(dt)
		updatef.UpdatePauseInput()
		return
	end

	updatef.CheckIfSongDone()
	updatef.SetNoteTime()
	updatef.UpdateBoolKeys()
	updatef.HandleNotes(dt)
	updatef.HandleMeasureLines()
	updatef.StartPlayMusic()
	updatef.UpdateAccuracy()
end

local function drawGame()
	drawf.DrawFPS()
	drawf.DrawMeasureLines()
	drawf.DrawLanes()
	drawf.DrawHitWindowImage()
	drawf.DrawCombo()
	drawf.DrawJudgeCount()
	drawf.DrawBottomBar()
	drawf.DrawScore()
	drawf.SongDoneTransparency()

	if paused then
		drawf.DrawPauseMenu()
	end
end

keypressf.Pause = function(key)
	if songDone or key ~= "escape" then
		return
	end

	if not paused then
		soundEffects.Pause:play()
		paused = true
		isPlayingSong = false
		songSourceObject:pause()
	else
		pausef.unpause()
	end
end

local function enumerate(directory)
	print("Enumerating directory " .. directory .. "...")

	if not love.filesystem.getInfo(directory) then
		love.filesystem.createDirectory(directory)
	end

	local files = love.filesystem.getDirectoryItems(directory)
	local result = {}

	for number, file in pairs(files) do
		print("Loading file " .. file .. "...")

		local subfiles = love.filesystem.getDirectoryItems(directory .. "/" ..file)
		
		for __, subfile in pairs(subfiles) do
			if subfile:sub(-3, -1) == "osu" then
				table.insert(result, fileClass.load(directory .. "/" .. file .. "/" .. subfile, directory .. "/" ..file, true))
			end
		end
	end


	if #result <= 0 then
		playSound("Alert")
		print("ALERT: No songs in Songs Folder")
	end

	return result
end

local function setup()
	menuConfig.Songs = enumerate("Songs")

	mainFont = love.graphics.newFont("Assets/font.ttf", 48)
	smallFont = love.graphics.newFont("Assets/font.ttf", 16)
	smallBitFont = love.graphics.newFont("Assets/font.ttf", 24)
	hugeFont = love.graphics.newFont("Assets/font.ttf", 70)
end

local function loadGameData()
	gameSettings = playerDataModule:load(gameSettings)
end

local function saveGameData()
	playerDataModule:save(gameSettings, allowedToSaveData)
end

function love.load()
	love.window.setMode(1100, 650, {vsync=false; resizable=true; minwidth=1100; minheight=650;})
	love.window.setTitle("SMRGL (Some Mania Rhythm Game LOL)")

	playerDataModule.FileLocation = "playerData.smrgld"
	delayNextTime = love.timer.getTime()
	loadGameData()
	setup()
	gameSetup()
	menuSetup()
end

local function updateDelayDelta()
	maxFps = gameSettings.FPSCap
	delayMinimumDelta = 1 / maxFps
	delayNextTime = delayNextTime + delayMinimumDelta
end

local function sleepCap()
	local currentTime = love.timer.getTime()
	
	if delayNextTime <= currentTime then
		delayNextTime = currentTime
		return
	end

	love.timer.sleep(delayNextTime - currentTime)
end


updatef.__menu.SelectSong = function()
	selectSong()
end

local needsAnyPressingSetting = false

local setSettingF = {}

local constantMenuKeyDown = {"left", "right", "up", "down", "z", "return", "o"}

local menuKeyDown = {}

local keySetDelay = 0

keypressf.changeKeySetting = function(key)
	if needsAnyPressingSetting then
	
		keySetDelay = love.timer.getTime() + 0.05
		gameSettings.Keybinds[settingsArrayHold.Keybinds] = key
		needsAnyPressingSetting = false
	end
end

setSettingF.table = function(name, setting)
	if menuKeyDown.left or menuKeyDown.right then
		local currentIndex = settingsArrayHold[name]

		if not currentIndex then
			return
		end

		local m = menuKeyDown.left and -1 or 1
		settingsArrayHold[name] = clamp(settingsArrayHold[name] + m, 1, #gameSettings[name])
		return
	end

	if (menuKeyDown.z or menuKeyDown["return"]) and setting.TableType == "KeyConstant" and not needsAnyPressingSetting and love.timer.getTime() > keySetDelay then
		needsAnyPressingSetting = true
		gameSettings[name][settingsArrayHold.Keybinds] = ""
	end
end

setSettingF.number = function(name, setting)
	if not menuKeyDown.left and not menuKeyDown.right then
		return
	end

	local m = menuKeyDown.left and -1 or 1
	gameSettings[name] = clamp(gameSettings[name] + (setting.Clamp.by * m), setting.Clamp.min, setting.Clamp.max)
end

setSettingF.boolean = function(name)
	if not menuKeyDown.z and not menuKeyDown["return"] then
		return
	end

	gameSettings[name] = not gameSettings[name]
end

updatef.__menu.UpdateInput = function()
	local changeSong = false

	local anyOfItIsTrue = false

	for __, item in pairs(constantMenuKeyDown) do
		menuKeyDown[item] = love.keyboard.isDown(item)

		if menuKeyDown[item] and not anyOfItIsTrue then
			anyOfItIsTrue = true
		end
	end

	if anyOfItIsTrue then
		if not menuConfig.InputDown then
			if not needsAnyPressingSetting and love.timer.getTime() > keySetDelay then
				if menuKeyDown.up or menuKeyDown.down then
					menuConfig.Selected = menuConfig.Selected + ((menuKeyDown.up and -1 or 0) + (menuKeyDown.down and 1 or 0))
					playSound("Select")
					changeSong = true
				elseif menuKeyDown.z or menuKeyDown["return"] then
					if not menuConfig.InSettings then
						updatef.__menu.SelectSong()
					end
				elseif menuKeyDown.o then
					menuConfig.InSettings = not menuConfig.InSettings

					if menuConfig.InSettings then
						menuConfig.SongSelected = menuConfig.Selected
						menuConfig.Selected = menuConfig.SettingSelected
					else
						menuConfig.SettingSelected = menuConfig.Selected
						menuConfig.Selected = menuConfig.SongSelected
					end
				end
			end

			local setting = menuConfig.Settings[menuConfig.Selected]

			if menuConfig.InSettings and setting then
				local gameSettingValue = gameSettings[setting.Target]

				if setSettingF[type(gameSettingValue)] then
					setSettingF[type(gameSettingValue)](setting.Target, setting)
				end
			end
		end

		menuConfig.InputDown = true
	else
		menuConfig.InputDown = false
	end

	local focusTable = menuConfig.Settings

	if not menuConfig.InSettings then
		focusTable = menuConfig.Songs
	end

	if #focusTable <= 0 then
		return
	end

	if menuConfig.Selected <= 0 then
		menuConfig.Selected = #focusTable
		menuConfig.DisplayPageStart = #focusTable - 14
		menuConfig.DisplayPageEnd = #focusTable
	end

	if menuConfig.Selected > #focusTable then
		menuConfig.Selected = 1
		--menuConfig.DisplayPageStart = 1
		--menuConfig.DisplayPageEnd = 15
	end

	if menuConfig.DisplayPageStart > menuConfig.Selected then
		menuConfig.DisplayPageStart = menuConfig.Selected
		menuConfig.DisplayPageEnd = menuConfig.DisplayPageStart + 14
	end

	if menuConfig.Selected > menuConfig.DisplayPageEnd then
		menuConfig.DisplayPageEnd = menuConfig.Selected
		menuConfig.DisplayPageStart = menuConfig.DisplayPageEnd - 14
	end

	if menuConfig.DisplayPageStart <= 0 then
		menuConfig.DisplayPageStart = 1
	end

	if not menuConfig.InSettings then
		menuConfig.SongSelected = menuConfig.Selected
	else
		menuConfig.SettingSelected = menuConfig.Selected
	end

	if changeSong then
		playPreviewMusic()
	end

	if songSourceObject then
		songSourceObject:setVolume(gameSettings.MusicVolume)
	end
end

updatef.__menu.ToTheBeat = function()
	if #previewBPMPoints <= 0 or not songSourceObject then
		return
	end

	if songSourceObject:tell() * 1000 >= previewBPMPoints[1].StartTime then
		if menuConfig.DoneZooming and gameSettings.ZoomVisualization then
			menuConfig.RadiusMultiply = menuConfig.RadiusMultiply + 0.15
		end

		table.remove(previewBPMPoints, 1)
	end
end

--[[
	CoolEffect = {
		{
			Objects = 8;
			Size = 15;
			Radius = 20;
			Rotation = 1;
		};
	};	
]]--

drawf.__menu.DrawCoolEffect = function()
	menuConfig.RadiusMultiply = menuConfig.RadiusMultiply + ((1 - menuConfig.RadiusMultiply) / (maxFps / (menuConfig.DoneZooming and 12 or 2)))

	if menuConfig.RadiusMultiply >= 0.95 and not menuConfig.DoneZooming then
		menuConfig.DoneZooming = true
	end

	menuConfig.DrawListMultiply = menuConfig.DrawListMultiply + ((1 - menuConfig.DrawListMultiply) / (maxFps / 4))

	local ww, wh = love.window.getMode()
	ww = ww / 2
	wh = wh / 2

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.circle("fill", ww, wh, 25 * menuConfig.RadiusMultiply, 100)

	for __, item in pairs(menuConfig.CoolEffect) do
		local objects, individualSize, radius, rotation, sementry
		objects = item.Objects
		individualSize = item.Size
		radius = item.Radius
		rotation = item.Rotation
		sementry = 360 / objects

		if not item["Angle"] then
			item.Angle = 0
		end

		local currentAngle = item.Angle

		for __ = 1, objects do
			local cx, cy
			cx = math.sin(math.rad(currentAngle)) * (radius * menuConfig.RadiusMultiply)
			cy = math.cos(math.rad(currentAngle)) * (radius * menuConfig.RadiusMultiply)
			love.graphics.circle("fill", ww + cx, wh + cy, individualSize * menuConfig.RadiusMultiply, 100)
			currentAngle = currentAngle + sementry
		end
		
		item.Angle = item.Angle + (rotation * delayMinimumDelta)
	end
end

drawf.__menu.TopHeader = function()
	love.graphics.setColor(0, 0, 0, 0.9)
	local ww, wh = love.window.getMode()
	love.graphics.rectangle("fill", 0, 0, ww, wh)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(hugeFont)
	love.graphics.print("SMRGL", 25, 30)
	love.graphics.setFont(smallBitFont)
	love.graphics.print("up or down keys to navigate selection | z to select/play song", 25, 95)
	love.graphics.print("press o for options", 25, 115)

	if menuConfig.InSettings then
		return
	end

	local selectedText = #menuConfig.Songs <= 0 and "no songs detected" or "selecting " .. menuConfig.Selected .. " out of " .. #menuConfig.Songs
	love.graphics.print(selectedText, 25, 135)
end

local renderSettingsf = {}
local instructionSettingsf = {}

renderSettingsf.number = function(value, setting)
	local v = math.floor(value * 100) / 100
	local s = ""
	local suffix, multiply = "", 1

	if setting and setting.Render then
		suffix = setting.Render.suffix or ""
		multiply = setting.Render.multiply or 1
		v = v * multiply
		s = tostring(v) .. suffix
	else
		s = tostring(v)
	end

	return s
end

instructionSettingsf.boolean = function()
	return "Press Z/Enter to enable/disable this setting."
end

instructionSettingsf.number = function(setting)
	return "Press the left or right key to decrease or increase this setting by " .. renderSettingsf.number(setting.Clamp.by, setting) .. "."
end

instructionSettingsf.table = function(setting)
	local tableIndex = settingsArrayHold[setting.Target] or 1
	local tableType = setting.TableType
	local instruction = ""
	local selective = "Selected " .. tableIndex

	if tableType == "KeyConstant" then
		instruction = "Press Z to change the setting's item."
	end

	return instruction .. " | " .. selective
end

renderSettingsf.boolean = function(value)
	return value and "Enabled" or "Disabled"
end

local function selectedItemTableSetting(index, value, target, tableType)
	value = value or "why"
	if tableType == "KeyConstant" and value == "" then if needsAnyPressingSetting then value = "PRESS ANY KEY" else value = "No keybind in use" end end

	value = settingsArrayHold[target] == index and "[" .. value .. "]" or value
	return value
end

renderSettingsf.table = function(table, setting)
	local str = selectedItemTableSetting(1, table[1], setting.Target, setting.TableType)
	if #table == 1 then return str end

	for index = 2, #table do
		local value = selectedItemTableSetting(index, table[index], setting.Target, setting.TableType)
		if index == #table then
			str = str .. ", and " .. value
		else
			str = str .. ", " .. value
		end
	end

	return str
end

local function getSettingInformation(setting)
	local properName = setting.ProperName

	local value = gameSettings[setting.Target]

	if type(value) == nil then
		return "no"
	end

	local properValue = renderSettingsf[type(value)](value, setting)
	local display = properName .. ": " .. properValue
	local instruction = setting.Description or "No setting description"
	instruction = instruction .. " | " .. instructionSettingsf[type(value)](setting)
	return display, instruction
end

drawf.__menu.DrawWatermark = function(text, offset)
	-- congrats if you made you way stealing my piece of shit
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(smallFont)
	
	local __, wh = love.window.getMode()
	love.graphics.print(text, 25, wh - offset)
end

drawf.__menu.DrawSongSelection = function()
	if #menuConfig.Songs <= 0 and not menuConfig.InSettings then
		local ww, wh = love.window.getMode()
		local upperX, upperY = ((ww/2)-(600 / 2)) + 5, (wh/3.5) + 5
		love.graphics.setColor(1, 1, 1, 0.5)
		love.graphics.rectangle("fill", upperX, upperY, 600, 300)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.rectangle("fill", ((ww/2)-(600 / 2)) - 5, (wh/3.5) - 5, 600, 300)
		-- love.graphics.setFont(mainFont)
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.print("There are no songs in the directory to load.", upperX + 2, upperY + 2)
		love.graphics.print("Please read the README file on how to load songs\nand play them. \n\nPlease restart the game if you have your songs \nready. \n\nStill, you can access options before playing the game\nif you want to.", upperX + 2, upperY + 50)
		return
	end

	love.graphics.setFont(smallBitFont)

	local selectedInstruction
	local drawIndex = 1

	local focusTable = menuConfig.Settings

	if not menuConfig.InSettings then
		focusTable = menuConfig.Songs
	end

	for index = menuConfig.DisplayPageStart, menuConfig.DisplayPageEnd do
		local item = focusTable[index]

		if item then
			local yOffset = 165 + (((drawIndex - 1) * 20) * menuConfig.DrawListMultiply)
			local text, instruct

			if menuConfig.InSettings then
				text, instruct = getSettingInformation(item)
			else
				text = "(" .. item.DifficultyName .. ") " .. item.MapName .. " by " .. item.ArtistName
			end

			local color = index == menuConfig.Selected and {1, 1, 1, 1} or {1, 1, 1, 0.5}

			if instruct and index == menuConfig.Selected then
				selectedInstruction = instruct
			end

			love.graphics.setColor(color)
			love.graphics.print(text, 25, yOffset)
		end

		drawIndex = drawIndex + 1
	end

	if selectedInstruction then
		drawf.__menu.DrawWatermark(selectedInstruction, 75)
	end
end

drawf.__menu.PrintDetails = function()
	local songSelectedDetails = menuConfig.Songs[menuConfig.Selected]

	if not songSelectedDetails or menuConfig.InSettings then
		return
	end

	love.graphics.setFont(smallBitFont)
	love.graphics.setColor(1, 1, 1, 1)

	local properNames = {
		MapName = "Song Title";
		ArtistName = "Composed by";
		MapperName = "Mapped by";
		Source = "Source from";
		DifficultyName = "Difficulty Name"
	}

	local drawIndex = 1

	for key, value in pairs(properNames) do
		local detail = songSelectedDetails[key]

		if detail then
			local yOffset = 475 + ((drawIndex - 1) * 20)
			local text = value .. ": " .. detail
			love.graphics.print(text, 25, yOffset)
		end

		drawIndex = drawIndex + 1
	end
end

local function updateMenu()
	updatef.__menu.UpdateInput()
	updatef.SetNoteTime()
	updatef.__menu.ToTheBeat()
end

local function drawMenu()
	drawf.__menu.DrawCoolEffect()
	drawf.__menu.TopHeader()
	drawf.DrawFPS()
	drawf.__menu.DrawSongSelection()
	drawf.__menu.PrintDetails()
	drawf.__menu.DrawWatermark("Made by MitsumotoMedia with passion! | DNSSolver25#7991 (or try mishisu#7991) if you want to give feedback.", 50)
end

function love.update(dt)
	updateDelayDelta()

	if gameState == "menu" then
		updateMenu()
	elseif gameState == "game" then
		updateGame(dt)
	elseif gameState == "results" then
		updateResults(dt)
	end
end

function love.draw()
	if gameState == "menu" then
		drawMenu()
	elseif gameState == "game" then
		drawGame()
	elseif gameState == "results" then
		drawResults()
	end

	sleepCap()
end

local function whenQuit()
	saveGameData()
	return false
end

function love.quit()
	local bool = whenQuit()
	return bool
end

local function keyPressedGame(key)
	if gameState == "menu" then
		keypressf.changeKeySetting(key)
	end

	if gameState ~= "game" then
		return
	end

	if key == "escape" then
		keypressf.Pause(key)
	end
end

function love.keypressed(key)
	keyPressedGame(key)
end