--[[
Old instructions:
	"--------------------------------------Seat signal-----------------------------------------------\n"..
	"        W : Forward     S : Reverse     A : Left     D : Right\n"..
    "-------------Number signals------------    -------------------Output-------------------\n"..
    "Pink 1      : +/- Forward/Reverse     Pink 4      : Speed value\n"..
	"Orange 1 : +/- Left/Right                Red 4       : Turn-ratio value    \n"..
	"Pink 4      : Speed                          Brown 4   : Steering value\n"..
	"Red 4      : Turn-ratio                     Other...  : Current Gear\n"..
    "-------------------------------------Logic signal-----------------------------------------------\n"..
	"Red 1      : Forward                        White        : Speed +5\n"..
	"Red 2      : Neutral (free rolling)     Light Grey : Speed +1\n"..
	"Red 3      : Reverse                        Dark Grey  : Speed -1\n"..
	"Pink 2      : Left                              Black        : Speed -5\n"..
	"Orange 2 : Right                            Yellow 1     : TurnRatio +5\n"..
	"Green 1   : Shift to Highest Gear    Yellow 2     : TurnRatio +1\n"..
	"Green 2   : Shift Up 1 Gear            Yellow 3     : TurnRatio -1\n"..
	"Green 3   : Shift Down 1 Gear        Yellow 4     : TurnRatio -5\n"..
	"Green 4   : Shift to Lowest Gear     Cyan Blue 1 : Save current Gear \n"..
    "------------------------------------------------------------------------------------------------------"
--]]
dofile "Utility.lua"
TankEngine = class()
TankEngine.maxParentCount = -1
TankEngine.maxChildCount = -1
TankEngine.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
TankEngine.connectionOutput = sm.interactable.connectionType.power
TankEngine.colorNormal = sm.color.new( 0xff8000ff )
TankEngine.colorHighlight = sm.color.new( 0xff9f3aff )

TankEngine.rampedAccelStepSize = 80
TankEngine.rampedDecelStepSize = 160

TankEngine.defaultGears = {
--Settings	 GEAR	MPH in test tank
{300, 0.70},--	1	2.5
{500, 0.60},--	2	8
{850, 0.46},--	3	16
{1350, 0.35},--	4	25
{1850, 0.29},--	5	35
{2350, 0.22},--	6	45
{3150, 0.18},--	7	55
{3700, 0.16},--	8	70
{4450, 0.14},--	9	85
{5250, 0.13}--	10	100
}

-- ____________________________________ Server ____________________________________

function TankEngine.server_onCreate( self ) -- Server setup
	self.sData = {[0] = 0}
	self.loaded = self.storage:load()
	--if false then
	if self.loaded then
		self.sData.speed = tonumber(self.loaded.speed) or self.defaultGears[1][1]
		self.sData.turnMult = tonumber(self.loaded.turnMult) or self.defaultGears[1][2]
		self.sData.gear = tonumber(self.loaded.gear) or 1
		self.sData.gears = self.loaded.gears or self.defaultGears
	else
		self.sData.gear = 2
		self.sData.gears = self.defaultGears
		self.sData.speed = self.defaultGears[self.sData.gear][1]
		self.sData.turnMult = self.defaultGears[self.sData.gear][2]
		self.storage:save(self.sData)
	end
	self.prevSpeed = self.sData.speed
	self.prevTurnMult = self.sData.turnMult
end
function TankEngine.server_onRefresh( self )
	print(" * * * TankTrack REFRESH * * * ")
	self:server_onCreate()
end

function TankEngine.server_onFixedUpdate( self, dt ) --- Server Fixed Update
	-- output values
	if self.cgData then
		local color = tostring(self.shape.color)
		if self.cgData.speed and color == "520653ff" then -- SPEED (dark pink)
			self.shape.interactable:setPower(self.cgData.speed / 100)
		elseif self.cgData.turnMult and color == "560202ff" then -- TURN-MULT (dark red)
			self.shape.interactable:setPower(self.cgData.turnMult * 100)
		elseif self.cgData.turnMult and color == "472800ff" then -- TURN L/R(dark brown)
			self.shape.interactable:setPower(self.cgData.steeringSpeed / 100)
		elseif self.sData.gear then
			self.shape.interactable:setPower(self.sData.gear) -- GEAR
		end

		-- save values
		local doSave = false
		if self.cgData.speed and self.cgData.speed ~= self.prevSpeed then
			self.prevSpeed = self.cgData.speed
			self.sData.speed = self.cgData.speed
			doSave = true
		end
		if self.cgData.turnMult and self.cgData.turnMult ~= self.prevTurnMult then
			self.prevTurnMult = self.cgData.turnMult
			self.sData.turnMult = self.cgData.turnMult
			doSave = true
		end
		if doSave then
			self.storage:save(self.sData)
		end

		-- get shift button inputs
		for k,parent in pairs(self.interactable:getParents()) do
			local parentColor = tostring(parent.shape.color)
			-- colored shifter inputs
			if parentColor == "68ff88ff" then -- Shift Top (light green)
				if parent:isActive() then
					if not self.ShiftTopDown then
						self.ShiftTopDown = true
						self:server_shift(10)
					end
				else
					self.ShiftTopDown = false
				end
			elseif parentColor == "19e753ff" then -- Shift Up (green)
				if parent:isActive() then
					if not self.ShiftUpDown then
						self.ShiftUpDown = true
						self:server_shift(1)
					end
				else
					self.ShiftUpDown = false
				end
			elseif parentColor == "0e8031ff" then -- Shift Down (med-dark green)
				if parent:isActive() then
					if not self.ShiftDownDown then
						self.ShiftDownDown = true
						self:server_shift(-1)
					end
				else
					self.ShiftDownDown = false
				end
			elseif parentColor == "064023ff" then -- Shift Bottom (dark green)
				if parent:isActive() then
					if not self.ShiftBottomDown then
						self.ShiftBottomDown = true
						self:server_shift(-10)
					end
				else
					self.ShiftBottomDown = false
				end
			elseif parentColor == "7eededff" then -- Save Gear (light cyan blue)
				if parent:isActive() then
					if not self.SaveGearDown then
						self.SaveGearDown = true
						self:server_saveGear()
					end
				else
					self.SaveGearDown = false
				end
			end
		end
	end
end

function TankEngine.server_getData( self )
	local cData = {gear = self.sData.gear, speed = self.sData.speed, turnMult = self.sData.turnMult}
	self.network:sendToClients('client_setData', cData)
end

function TankEngine.server_shift( self, shiftDir )
	self.sData.gear = sm.util.clamp(self.sData.gear + shiftDir, 1, #self.defaultGears)
	self.sData.speed = self.sData.gears[self.sData.gear][1]
	self.prevSpeed = self.sData.speed
	self.sData.turnMult = self.sData.gears[self.sData.gear][2]
	self.prevTurnMult = self.sData.turnMult
	self.storage:save(self.sData)
	local cData = {gear = self.sData.gear, speed = self.sData.speed, turnMult = self.sData.turnMult}
	self.network:sendToClients('client_setData', cData)
end

function TankEngine.server_saveGear( self )
	self.sData.gears[self.sData.gear] = {self.cgData.speed, self.cgData.turnMult}
	self.storage:save(self.sData)
end

-- ____________________________________ Client ____________________________________

function TankEngine.client_onCreate( self ) -- Client setup
	_G[tostring(self.interactable.id) .. "data"] = {}
	self.cgData = _G[tostring(self.interactable.id) .. "data"]
	self.cgData.type = "TankEngine"
	self.cgData.inputFwd = 0
	self.cgData.rampedInputFwd = 0
	self.cgData.speed = self.defaultGears[1][1]
	self.cgData.rampedSpeed = self.cgData.speed
	self.cgData.inputRight = 0
	self.cgData.gear = 1
	self.cgData.turnMult = self.defaultGears[1][2]
	self.cgData.steeringSpeed = 0
	self.cgData.neutral = false
	self.rampedInput = 0.0
	self.prevDirection = 1
	self.soundCountdown = 0
	self.network:sendToServer('server_getData')

	self.effectEngine = sm.effect.createEffect( "GasEngine - Level 3", self.interactable )
end
function TankEngine.client_onRefresh( self )
	print("* * * REFRESH: Tank Engine * * *")
	self:client_onCreate()
end

function TankEngine.client_setData( self, data )
	self.cgData.gear = data.gear
	self.cgData.speed = data.speed
	self.cgData.turnMult = data.turnMult
end

function TankEngine.client_onFixedUpdate( self, dt ) ----- Client Fixed Update

	-- default values
	self.cgData.inputFwd = 0
	self.cgData.inputRight = 0
	self.cgData.neutral = false
	self.cgData.steeringSpeed = 0

	local hasDriver = false
	-- get seat and button inputs
	for k,parent in pairs(self.interactable:getParents()) do
		if parent:hasOutputType(sm.interactable.connectionType.seated) then
			if parent:isActive() then
				hasDriver = true
			end
			self.cgData.inputFwd = self.cgData.inputFwd + parent:getPower()
			self.cgData.inputRight = self.cgData.inputRight + parent:getSteeringAngle()
		else
			local parentColor = tostring(parent.shape.color)
			-- colored power settings
			if parentColor == "520653ff" then -- SPEED (dark pink)
				self.cgData.speed = parent:getPower() * 100
			elseif parentColor == "560202ff" then -- TURN-MULT(dark red)
				self.cgData.turnMult = parent:getPower() / 100
			elseif parentColor == "472800ff" then -- TURN-MULT(dark brown)
				self.cgData.turnMult = parent:getPower() / 100

			-- colored movement inputs
			elseif parentColor == "f06767ff" and parent:isActive() then -- FORWARD (light red)
				self.cgData.inputFwd = self.cgData.inputFwd + 1
			elseif parentColor == "7c0000ff" and parent:isActive() then -- REVERSE (mid-dark red)
				 self.cgData.inputFwd = self.cgData.inputFwd - 1
			elseif parentColor == "cf11d2ff" and parent:isActive() then -- LEFT (pink)
				 self.cgData.inputRight = self.cgData.inputRight - 1
			elseif parentColor == "df7f00ff" and parent:isActive() then -- RIGHT (orange)
				self.cgData.inputRight = self.cgData.inputRight + 1
			elseif parentColor == "d02525ff" and parent:isActive() then -- NEUTRAL (red)
				self.cgData.neutral = true

			-- colored power inputs
			elseif parentColor == "eeeeeeff" then -- Speed +5 (white)
				if parent:isActive() then
					if not self.whiteDown then
						self.whiteDown = true
						self.cgData.speed = self.cgData.speed + 500
						print(self.cgData.speed)
					end
				else
					self.whiteDown = false
				end
			elseif parentColor == "7f7f7fff" then -- Speed +1 (light grey)
				if parent:isActive() then
					if not self.ltgreyDown then
						self.ltgreyDown = true
						self.cgData.speed = self.cgData.speed + 100
					end
				else
					self.ltgreyDown = false
				end
			elseif parentColor == "4a4a4aff" then -- Speed -1 (dark grey)
				if parent:isActive() then
					if not self.dkgreyDown then
						self.dkgreyDown = true
						self.cgData.speed = self.cgData.speed - 100
						if self.cgData.speed < 0 then self.cgData.speed = 0 end
					end
				else
					self.dkgreyDown = false
				end
			elseif parentColor == "222222ff" then -- Speed -5 (black)
				if parent:isActive() then
					if not self.blackDown then
						self.blackDown = true
						self.cgData.speed = self.cgData.speed - 500
						print(self.cgData.speed)
						if self.cgData.speed < 0 then self.cgData.speed = 0 end
					end
				else
					self.blackDown = false
				end
			elseif parentColor == "f5f071ff" then -- Turn +10 (light yellow)
				if parent:isActive() then
					if not self.ltyellowDown then
						self.ltyellowDown = true
						self.cgData.turnMult = self.cgData.turnMult + 0.05
					end
				else
					self.ltyellowDown = false
				end
			elseif parentColor == "e2db13ff" then -- Turn +1 (yellow)
				if parent:isActive() then
					if not self.yellowDown then
						self.yellowDown = true
						self.cgData.turnMult = self.cgData.turnMult + 0.01
					end
				else
					self.yellowDown = false
				end
			elseif parentColor == "817c00ff" then -- Turn -1 (medium yellow)
				if parent:isActive() then
					if not self.mdyellowDown then
						self.mdyellowDown = true
						self.cgData.turnMult = self.cgData.turnMult - 0.01
						if self.cgData.turnMult < 0 then self.cgData.turnMult = 0 end
					end
				else
					self.mdyellowDown = false
				end
			elseif parentColor == "323000ff" then -- Turn -10 (dark yellow)
				if parent:isActive() then
					if not self.dkyellowDown then
						self.dkyellowDown = true
						self.cgData.turnMult = self.cgData.turnMult - 0.05
						if self.cgData.turnMult < 0 then self.cgData.turnMult = 0 end
					end
				else
					self.dkyellowDown = false
				end
			end

			-- colored math movement inputs
			if parentColor == "ee7bf0ff" then -- FWD/REV +/- (light pink)
				self.cgData.inputFwd = self.cgData.inputFwd + parent:getPower()
				self.cgData.speed = math.abs(parent:getPower()) * 100
			elseif parentColor == "eeaf5cff" then -- LEFT/RIGHT +/- (light orange)
				--self.cgData.inputRight = self.cgData.inputRight + parent:getPower()
				self.cgData.steeringSpeed = parent:getPower() * 100
				--self.cgData.turnMult = 0
			end

		end
	end
 if self.cgData.speed > 2500 then self.cgData.speed = 2500 end
	-- Values debug
	--[[
	print()
	print("\tCURRENT VALUES")
	--print("\tSpeed: "..self.cgData.speed)
	print("\tSpeed: "..(self.cgData.speed / 100))
	--print("\tTurn: "..self.cgData.turnMult)
	print("\tTurn: "..string.format("%i", self.cgData.turnMult * 100))
	print("\tGear: "..self.sData.gear)
	print("GEARS   SPEED  TURN")
	for k,v in pairs(self.sData.gears) do
		local line = string.format("%-8s %5i        %2i", ("Gear "..k..":"),(self.sData.gears[k][1] / 100),(self.sData.gears[k][2] * 100))
		--local line = string.format("%-8s %5i    %3.2f", ("Gear "..k..":"),self.sData.gears[k][1],self.sData.gears[k][2])
		print(line)
	end
	--]]

	self.cgData.inputFwd = sm.util.clamp(self.cgData.inputFwd,-1,1)
	self.cgData.inputRight = sm.util.clamp(self.cgData.inputRight,-1,1)

	-- ramped input
	self.cgData.rampedSpeed = self.cgData.speed
	self.cgData.rampedInputFwd = self.cgData.inputFwd
	if self.cgData.inputFwd ~= 0 then
		if self.cgData.speed > 0 and (self.rampedInput < self.cgData.speed) then
			self.rampedInput = self.rampedInput + self.rampedAccelStepSize
			self.cgData.rampedSpeed = self.rampedInput
		elseif self.cgData.speed < 0 and (self.rampedInput > self.cgData.speed) then
			self.rampedInput = self.rampedInput - self.rampedAccelStepSize
			self.cgData.rampedSpeed = self.rampedInput
		end
		if self.cgData.inputFwd > 0 then
			if self.prevDirection < 0 then
				self.cgData.rampedInputFwd = 0
				self.rampedInput = 0
				self.cgData.rampedSpeed = 0
			end
			self.prevDirection = 1
		else--self.cgData.inputFwd < 0 then
			if self.prevDirection > 0 then
				self.cgData.rampedInputFwd = 0
				self.rampedInput = 0
				self.cgData.rampedSpeed = 0
			end
			self.prevDirection = -1
		end
	else --ramp down
		if self.rampedInput ~= 0 then
			if self.rampedInput > 0 then
				self.rampedInput = self.rampedInput - self.rampedDecelStepSize
				if self.rampedInput < 0 then
					self.rampedInput = 0
				end
			else--self.rampedInput < 0 then
				self.rampedInput = self.rampedInput + self.rampedDecelStepSize
				if self.rampedInput > 0 then
					self.rampedInput = 0
				end
			end
			self.cgData.rampedSpeed = self.rampedInput
			self.cgData.rampedInputFwd = self.prevDirection
		else
			self.cgData.rampedSpeed = 0
		end
	end

	-- sound effects
	--self.effectEngine:setParameter("gas", 1.0 ) --what does this do???

	local maxVelocity = 30
	local forwardVelocity = self.shape:getVelocity():length() -- this should really come from the track animation speeds
	forwardVelocity = math.min(forwardVelocity, maxVelocity)
	if forwardVelocity < 2 then
		forwardVelocity = 0
	elseif forwardVelocity < 5 then
		forwardVelocity = 5
	end

	local rpm = forwardVelocity / maxVelocity

	local engineLoad = 0
	if self.cgData.inputFwd ~= 0 or self.cgData.inputRight ~= 0 then
		local velocityFraction = self.cgData.rampedSpeed / math.max(self.cgData.speed, 1)
		velocityFraction = velocityFraction * 0.65
		engineLoad = engineLoad + velocityFraction
	end


	--print("------------------DEBUG-------------------")
	--print("Gear: "..self.cgData.gear)
	--print("Speed: "..self.cgData.speed)
	--print("Velocity: "..forwardVelocity) --debug
	--print("rmp: "..rpm) --debug
	--print("engineLoad: "..engineLoad) --debug

	if hasDriver or self.cgData.inputFwd ~= 0 or self.cgData.inputRight ~= 0 then
		if not self.effectEngine:isPlaying() then
			self.effectEngine:start()
		end
	else
		if self.effectEngine:isPlaying() then
			self.effectEngine:setParameter( "load", 0.1 )
			self.effectEngine:setParameter( "rpm", 0 )
			print(self.cgData.inputFwd)
			print(self.cgData.inputRight)
			if self.cgData.inputFwd == 0 and self.cgData.inputRight == 0 and rpm == 0 then
				self.effectEngine:stop()
			end
		end
	end
	if self.effectEngine:isPlaying() then
		--self.effectEngine:setParameter("rpm", 0.0 )
		--self.effectEngine:setParameter("load", 0.1 )
		self.effectEngine:setParameter("rpm", rpm)
		self.effectEngine:setParameter("load", engineLoad)
	end

	--[[W
	local soundSpeed = (math.abs(self.cgData.rampedSpeed) + math.abs(self.cgData.inputRight * self.cgData.speed) + math.abs(self.cgData.steeringSpeed)) / 3
	if soundSpeed ~=0 then
		self.soundCountdown = 20
		local soundVelocity = (soundSpeed / 1000)
		--print(soundVelocity)
		self.effectController:setParameter("Velocity", soundVelocity)
		--self.effectTrusterDust:setParameter("Velocity", soundVelocity)
		if not self.effectController:isPlaying() then
			self.effectController:start()
			--self.effectTrusterDust:start()
		end
	else
		if self.soundCountdown > 0 then
			self.soundCountdown  = self.soundCountdown - 1
			self.effectController:setParameter("Velocity", 0)
			--if self.effectTrusterDust:isPlaying() then
			--	self.effectTrusterDust:stop()
			--end
		else
			if self.effectController:isPlaying() then
				self.effectController:stop()
				--self.effectTrusterDust:stop()
			end
		end
	end
	--]]
end

function TankEngine.client_onDestroy( self )
	self.effectEngine:destroy()

	if self.gui then
		self.gui:close()
		self.gui:destroy()
		self.gui = nil
	end
end
