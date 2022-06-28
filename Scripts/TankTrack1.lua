--[[
Old instructions...
Must use a Tank Engine to control tracks.
If a seat is already on the vehicle, then tracks will auto-detect mode when placed.
To manually set mode 'Press [E] to use' for GUI.
Stacked tracks can be connected to the track with the engine to sync animation
(modes still needs to match for correct movement).
For Half-track or Mono-track builds, use the 'Mono-Track' modes for fwd/rev only.
If a track goes the wrong way, try a 'Reversed' mode.
--]]
dofile "Utility.lua"
TankTrack1 = class()
TankTrack1.maxParentCount = 1
TankTrack1.maxChildCount = -1
TankTrack1.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power + sm.interactable.connectionType.bearing
TankTrack1.connectionOutput = sm.interactable.connectionType.bearing
TankTrack1.colorNormal = sm.color.new( 0x0000deff )
TankTrack1.colorHighlight = sm.color.new( 0x3737ffff )

TankTrack1.modes = {"Left Reversed", "Right", "Left", "Right Reversed", "MonoTrack", "MonoTrack Reversed"}
TankTrack1.lowFrictionUuid = sm.uuid.new("b9f0d277-daca-49e4-9771-c16f721c8bcc")
TankTrack1.highFrictionUuid = sm.uuid.new("d6b12a47-c2df-46d3-a67f-4ef7c64802c8")
TankTrack1.parkingFrictionUuid = sm.uuid.new("1b4e8d47-8360-4c9f-bd02-77576d4cac0a")

-- Default Values
TankTrack1.defaultSpeed = 600 -- default speed
TankTrack1.defaultTurnMult = 0.4 -- default turn multiplier
TankTrack1.defaultDrag = 200 -- default drag

-- Behavior
TankTrack1.maxImpulse = 5000 -- clamp insane speeds
TankTrack1.animLoopPerDistance = 4 -- to time animation to movement
TankTrack1.animTypeSpeedThreshold = 0.001 -- threshold to switch to animation type
TankTrack1.inputAnimGroundedStep = 0.05 -- input based animation step per tick when grounded
TankTrack1.speedOfMaxAnim = 1200 -- speed at which input animation should max out
TankTrack1.animCountdownTicks = 30 -- how many ticks to keep animating when no input

-- Raycast table
TankTrack1.raycasts = {
	--{right,startX, startY, endX, endY, impulseX, impulseY},
	-- bottom
	{0.125,-2.063,-0.595,0,-0.23,1,0},--1
	{-0.125,-2.063,-0.595,0,-0.23,1,0},--2
	{0,-2.063,-0.825,1.325,0,1,0},--3
	{0,-0.738,-0.625,0,-0.2,1,0},--4
	{0,-0.738,-0.825,1.475,0,1,0},--5
	{0.125,2.063,-0.595,0,-0.23,1,0},--6
	{-0.125,2.063,-0.595,0,-0.23,1,0},--7
	{0,2.063,-0.825,-1.325,0,1,0},--8
	-- top
	{0.125,-2.698,0.365,0,0.373,-1,0},--9
	{-0.125,-2.698,0.365,0,0.373,-1,0},--10
	{0,-2.698,0.738,1.96,0,-1,0},--11
	{0,0.738,0.538,0,0.2,-1,0},--12
	{0,0.738,0.738,-1.475,0,-1,0},--13
	{0.125,2.698,0.365,0,0.373,-1,0},--14
	{-0.125,2.698,0.365,0,0.373,-1,0},--15
	{0,2.698,0.738,-1.96,0,-1,0},--16
	-- front
	{0,2.62,0.518,0.23,0.095,-0.095,0.225},--17
	{0,2.853,0.613,0.155,-0.378,-0.095,0.225},--18
	{0,2.18,-0.565,0.148,-0.135,0.17,0.185},--19
	{0,2.328,-0.7,0.68,0.74,0.17,0.185},--20
	-- back
	{0,-2.62,0.518,-0.23,0.095,-0.095,-0.225},--21
	{0,-2.853,0.613,-0.155,-0.378,-0.095,-0.225},--22
	{0,-2.18,-0.565,-0.148,-0.135,0.17,-0.185},--23
	{0,-2.328,-0.7,-0.68,0.74,0.17,-0.185}--24
	-- sides
}
TankTrack1.raycastsSide = {
	--{fwd, right},
	{1,0.375},
	{1,-0.375},
	{-1,0.375},
	{-1,-0.375}
}

-- ____________________________________ Server ____________________________________

function TankTrack1.server_onCreate( self ) -- Server setup
	self.sData = {[0] = 0}
	self.loaded = self.storage:load()
	if self.loaded then
		self.sData.mode = tonumber(self.loaded.mode) or 1
	else
		self.sData.mode = self:server_detectMode()
	end
end
function TankTrack1.server_onRefresh( self )
	print(" * * * TankTrack 1 REFRESH * * * ")
	self:server_onCreate()
end

function TankTrack1.server_detectMode( self )
	local mode = 1
	for k,shape in pairs(self.shape.body:getCreationShapes()) do
		if shape.interactable and shape.interactable:hasOutputType(sm.interactable.connectionType.seated) then
			local side = shape.right:dot(self.shape.worldPosition - shape.worldPosition)
			local reversed = shape.right:dot(self.shape.right)
			if side > 0 then -- left
				if reversed > 0 then -- is reversed
					mode = 1 -- "Left Reversed"
				else -- not reversed
					mode = 3 -- "Left"
				end
			else -- right
				if reversed > 0 then -- is reversed
					mode = 4 -- "Right Reversed"
				else -- not reversed
					mode = 2 -- "Right"
				end
			end
			break
		end
	end
	return mode
end

function TankTrack1.server_saveMode( self, mode )
	self.sData.mode = mode
	self.storage:save(self.sData) 
	self.network:sendToClients('client_setData', self.sData)
end

function TankTrack1.server_getData( self )
	self.network:sendToClients('client_setData', self.sData)
end

function TankTrack1.server_onFixedUpdate( self, dt ) -- Server Fixed Update ----------
	-- server gets data from host client instead of network calls
	if self.clientReady then
		local mode = self.modes[self.mode]
		local inputFwd = self.cgData.inputFwd
		local fwdSpeed = inputFwd * self.cgData.rampedSpeed
		local inputRight = self.cgData.inputRight
		local turnSpeed = (inputRight * self.cgData.speed * self.cgData.turnMult) + self.cgData.steeringSpeed
		local steeringSpeed = self.cgData.steeringSpeed
		
		local localFront = self.shape.at
		if self.modes[self.mode] == "Left Reversed" or self.modes[self.mode] == "Right Reversed" then
			localFront = localFront * -1
		end
		local localUp = self.shape.up
		local worldUp = sm.vec3.new(0,0,1)
		
		-- Movement vector
		local movementVec = self.movementVec or sm.vec3.new(0,1,0) -- direction to apply force
		if mode == "Left" or mode == "Left Reversed" then
			movementVec = movementVec * (fwdSpeed + turnSpeed)
		elseif mode == "Right" or mode == "Right Reversed" then
			movementVec = movementVec * (fwdSpeed - turnSpeed)
		else
			movementVec = movementVec * fwdSpeed
		end
		if mode == "Left Reversed" or mode == "Right Reversed" or mode == "MonoTrack Reversed" then
			movementVec = movementVec * -1
		end
		
		-- Offset for movement vector
		local offset = self.impulseOffset or sm.vec3.zero()
		if self.movement then
			local mvAmt = math.abs(self.movement)
			if mvAmt > 0.1 then
				offset = sm.vec3.zero()
			end
		end
		
		-- calculate drag force
		local vel = self.shape:getVelocity()
		if vel:length() < 0.001 then -- filter out noise
			vel = sm.vec3.zero()
		end
		vel.z = 0
		local momentum = toLocal(self.shape, (vel * self.cgData.drag)) * -1
		local adjY = momentum.y * math.abs(self.movementVec.y)
		local adjZ = momentum.z * math.abs(self.movementVec.z)
		local dragVec = sm.vec3.new(momentum.x, adjY, adjZ)
		
		-- calculare orientation
		local angle = math.deg(math.acos(sm.util.clamp(localUp.z,-1,1)))
		if localFront.z < 0 then
			angle = angle * -1
		end
		
		-- apply forces
		-- if user giving input
		if fwdSpeed ~= 0 or turnSpeed ~= 0 then
			-- try removing friction part
			if self.frictionOn then
				self:removeFriction()
			end
			-- if grounded, apply drag forces + movement forces
			if self.grounded then
				--print("Drag + Movement")
				
				-- attempt to improve climbing by mixing ratios of movement vector
				local ang = 25
				if (angle > ang and angle < (180 - ang)) or (angle < (ang * -1) and angle > (180 - ang) * -1) then
					offset = sm.vec3.zero()
				end
				local impulse = clampVec((dragVec + movementVec), self.maxImpulse)
				sm.physics.applyImpulse( self.shape, impulse, false, offset )
			end
			
		elseif self.grounded then -- no input
			--print("Drag Only")
			-- if neutral or not connected, filter drag forces to X axis only
			if self.cgData.neutral or not self.hasParents then
				dragVec.y = 0
				dragVec.z = 0
				local impulse = clampVec(dragVec, self.maxImpulse)
				sm.physics.applyImpulse( self.shape, impulse, false, nil )
			else
				--spawn friction part
				if not self.frictionOn then
					self.frictionOn = true
					self.parkingFrictionOn = false
					self.shape:replaceShape(self.highFrictionUuid)
				end
			end
		end
		
		-- check if friction need to be removed
		if (not self.hasParents or self.cgData.neutral) and self.frictionOn then
			self:removeFriction()
		end
		
		-- check if parking friction needs to be applies
		if self.frictionOn and not self.parkingFrictionOn then
			if vel:length() < 0.01 then
				self.parkingFrictionOn = true
				self.shape:replaceShape(self.parkingFrictionUuid)
			end
		end
	end
end

function TankTrack1.removeFriction( self )
	self.frictionOn = false
	self.parkingFrictionOn = false
	self.shape:replaceShape(self.lowFrictionUuid)
end

-- ____________________________________ Client ____________________________________

function TankTrack1.client_onCreate( self )
	-- Setup
	_G[tostring(self.interactable.id) .. "data"] = {}
	self.cgData = _G[tostring(self.interactable.id) .. "data"]
	self.cgData.type = "TankTrack"
	self.cgData.mode = "Left"
	self.cgData.inputFwd = 0
	self.cgData.inputRight = 0
	self.cgData.steeringSpeed = 0
	self.cgData.neutral = false
	self.cgData.speed = self.defaultSpeed
	self.cgData.rampedSpeed = self.cgData.speed
	self.cgData.turnMult = self.defaultTurnMult
	self.cgData.drag = self.defaultDrag
	self.mode = 1
	self.interactable:setAnimEnabled( "drive", true )
	self.animProgress = 0.0
	self.prevPosition = self.shape.worldPosition
	self.prevPitch = 0
	self.prevNoInput = true
	self.animCountdown = 0
	self.movement = nil
	self.hasParents = false
	self.hasEngine = false
	self.effectTrusterDust = sm.effect.createEffect("ModThrusterDust",self.interactable)
	self.soundSpeed = 0
	self.network:sendToServer('server_getData')
end
function TankTrack1.client_onRefresh( self )
	self.clientReady = false
	self:client_onCreate()
end

function TankTrack1.client_setData( self, data )
	self.mode = data.mode
	self.cgData.mode = self.modes[self.mode]
end

function TankTrack1.client_onInteract(self, character, lookAt)
    if not lookAt then return end
	self.mode = ((self.mode % #self.modes) + 1) 
	self.network:sendToServer('server_saveMode', self.mode)
	local message = self.modes[self.mode]
	-- For Tank Track 1, I'm switching names for "Left" and "Left Reversed"
	if message == "Left" then
		message = "Left Reversed" 
	elseif message == "Left Reversed" then
		message = "Left" 
	end
	sm.gui.displayAlertText(message)
end

function TankTrack1.client_canInteract( self )
	return not self.hasParents
end

function TankTrack1.client_onFixedUpdate( self, dt ) -- Client Fixed Update ----------
	self.clientReady = true
	
	-- default values
	self.cgData.inputFwd = 0
	self.cgData.inputRight = 0
	self.cgData.steeringSpeed = 0
	self.cgData.neutral = false
	self.cgData.speed = self.defaultSpeed
	self.cgData.rampedSpeed = self.cgData.speed
	self.cgData.turnMult = self.defaultTurnMult
	self.cgData.drag = self.defaultDrag
	self.grounded = false
	self.hasParents = false
	self.hasEngine = false
	local animSync = false
	local mode = self.modes[self.mode]
	
	local localRight = self.shape.right
	local localFront = self.shape.at
	local localUp = self.shape.up
	local worldUp = sm.vec3.new(0,0,1)
	
	-- get input values 
	for k,parent in pairs(self.interactable:getParents()) do
		self.hasParents = true
		local pData = _G[tostring(parent.id) .. "data"]
		if pData and (pData.type == "TankEngine" or pData.type == "TankTrack") then
			if pData.type == "TankEngine" then
				self.hasEngine = true
				self.cgData.inputFwd = pData.rampedInputFwd or 0
			else--pData.type == "TankTrack" then
				self.cgData.inputFwd = pData.inputFwd or 0
			end
			self.cgData.speed = pData.speed or self.defaultSpeed
			self.cgData.rampedSpeed = pData.rampedSpeed or self.defaultSpeed
			self.cgData.inputRight = pData.inputRight or 0
			self.cgData.steeringSpeed = pData.steeringSpeed or 0
			self.cgData.neutral = pData.neutral or false
			self.cgData.turnMult = pData.turnMult or self.defaultTurnMult
			--self.cgData.drag = pData.drag or self.defaultDrag
			if pData.type == "TankTrack" then
				animSync = true
			end
		end
	end
	
	if not self.hasParents then
		self.cgData.neutral = true
	end
	
	-- Raycasts
	do
		local offsetVecCount = 0
		local offsetSUM = sm.vec3.zero()
		local movementVecCount = 0
		local movementVecSUM = sm.vec3.zero()
		local localWorldPos = self.shape.worldPosition
		for k,v in pairs(self.raycasts) do
			local castStart = localWorldPos + (localRight * v[1]) + (localFront * v[2]) + (localUp * v[3])
			local castEnd = castStart + (localFront * v[4]) + (localUp * v[5])
			local hit, result = sm.physics.raycast(castStart, castEnd)
			if hit and result.type ~= "character" then
				local notSameCreation = true
				for k,body in pairs(self.shape.body:getCreationBodies()) do
					if body == result:getBody() then
						notSameCreation = false
						break
					end
				end
				if notSameCreation then
					self.grounded = true
					movementVecCount = movementVecCount + 1
					local mv = (sm.vec3.new(0,v[6],0) + sm.vec3.new(0,0,v[7]))
					if mv:length() ~= 0 then
						mv = mv:normalize()
					end
					offsetVecCount = offsetVecCount + 1
					movementVecSUM = movementVecSUM + mv
					local ov = sm.vec3.new(0,v[2],0) + sm.vec3.new(0,0,v[3])
					offsetSUM = offsetSUM + ov
				end
			end
		end
		
		-- when tipping on side, enable side raycasts checking if grounded
		local roll = math.abs(localRight:dot(worldUp))
		if roll > 0.75 then
			for k,v in pairs(self.raycastsSide) do
				local castStart = localWorldPos + (localFront * v[1])
				local castEnd = castStart + (localRight * v[2])
				local hit, result = sm.physics.raycast(castStart, castEnd)
				if hit and result.type ~= "character" then
					local notSameCreation = true
					for k,body in pairs(self.shape.body:getCreationBodies()) do
						if body == result:getBody() then
							notSameCreation = false
							break
						end
					end
					if notSameCreation then
						self.grounded = true
						break
					end
				end
			end
		end
		
		-- average the direction and offset of movement force vectors
		if offsetVecCount > 0 then
			self.impulseOffset = offsetSUM / offsetVecCount
		else
			self.impulseOffset = sm.vec3.zero()
		end
		if movementVecCount > 0 then
			self.movementVec = (movementVecSUM / movementVecCount)
			if self.movementVec:length() ~= 0 then
				self.movementVec = self.movementVec:normalize()
			else
				self.movementVec = sm.vec3.new(0,1,0)
			end

		else
			self.movementVec = sm.vec3.new(0,1,0) -- default movement vec
		end
		
	end
	
	-- animations
	if not animSync then -- if not syncing animation to another track
		
		-- determine type of animation to do
		self.movement = nil
		local doMovementAnim = false
		local doInputAnim = false
		
		-- if not connected to anything
		if not self.hasParents then
			doMovementAnim = true
		else
			-- if inpit
			if self.cgData.inputFwd ~= 0 or self.cgData.inputRight ~= 0 or self.cgData.steeringSpeed ~= 0 then
			
				-- calculate movement
				self.movement = self:calcMovement()

				-- if grounded + moving enough: do movement animation
				if self.grounded and math.abs(self.movement) > self.animTypeSpeedThreshold then
					doMovementAnim = true
				else -- else(in air or not moving enough): do input animation
					doInputAnim = true
				end
				
				self.animCountdown = -1
				self.prevNoInput = false
			-- else no input
			else
				-- if in neutral and grounded: do movement animation
				--print(self.cgData.neutral)
				if self.cgData.neutral and self.grounded then
					doMovementAnim = true
					self.animCountdown = -1
					self.prevNoInput = false
				-- else check for animation countdown (~no animation)
				else
					-- if not prevNoInput, then set animation countdown
					if not self.prevNoInput then
						self.prevNoInput = true
						self.animCountdown = self.animCountdownTicks
						doMovementAnim = true
					-- else prevNoInput, decriment countdown or do nothing if expired
					else
						if self.animCountdown > 0 then
							self.animCountdown = self.animCountdown -1
							doMovementAnim = true
						end
					end
				end
			end
		end
		
		-- calculate animation step
		local animStep = 0
		if doMovementAnim then
			--print(self.modes[self.mode] .. ": " .. " MOVEMENT animation")
			-- calculate movement
			if not self.movement then
				self.movement = self:calcMovement()
			end
			-- calculate animation step
			animStep = self.movement * self.animLoopPerDistance
		elseif doInputAnim then
			--print(self.modes[self.mode] .. ": " .. " INPUT animation")
			animStep = self.cgData.inputFwd
			
			
			if mode == "Left" or mode == "Left Reversed" then
				animStep = animStep + self.cgData.inputRight
			elseif mode == "Right" or mode == "Right Reversed" then
				animStep = animStep - self.cgData.inputRight
				self.cgData.steeringSpeed = self.cgData.steeringSpeed * -1
			end
			
			
			animStep = animStep * (self.cgData.speed / self.speedOfMaxAnim / 2)
			if self.cgData.steeringSpeed ~= 0 then
				animStep = animStep + (self.cgData.steeringSpeed / self.speedOfMaxAnim / 2)
			end
			if self.grounded then
				if animStep < 0 then
					animStep = math.max(animStep, (self.inputAnimGroundedStep * -1))
				else
					animStep = math.min(animStep, self.inputAnimGroundedStep)
				end
			end
			if mode == "Left Reversed" or mode == "Right Reversed" or mode == "MonoTrack Reversed" then
				animStep = animStep * -1
			end
		else
			--print(self.modes[self.mode] .. ": " .. " NO animation")
		end
		
		-- do animation
		if doMovementAnim or doInputAnim then
			-- avoids tracks appearing to go wrong way when moving fast
			self.soundSpeed = math.abs(animStep)
			animStep = sm.util.clamp( animStep, -0.53, 0.53 )
			-- make on a scale of 0-1
			local newAnimProgress = tonumber(string.format("%0.2f", (self.animProgress + animStep)))
			if newAnimProgress > 1 then
				newAnimProgress = newAnimProgress - 1
			elseif newAnimProgress < 0 then
				newAnimProgress = newAnimProgress + 1
			end
			self.animProgress = newAnimProgress
			self.interactable:setAnimProgress( "drive", newAnimProgress)
		else
			self.soundSpeed = 0
		end
	end
	
	-- sync any child tracks animations
	if self.hasEngine or self.cgData.neutral then
		self:animSync(self.interactable)
	end
	
	-- sound effects
	if self.grounded and self.soundSpeed > 0.01 then
		local soundVelocity = (self.soundSpeed / 1.5)
		--print(soundVelocity)
		self.effectTrusterDust:setParameter("Velocity", soundVelocity)
		if not self.effectTrusterDust:isPlaying() then 
			self.effectTrusterDust:start()
		end
	else
		if self.effectTrusterDust:isPlaying() then
			self.effectTrusterDust:stop()
		end
	end
	
end

function TankTrack1.calcMovement( self )
	-- calculate movement
	local localOut = self.shape.right -- improves animation on narrow builds
	if mode == "Left" or mode == "Right Reversed" then
		localOut = localOut * -1
	end
	local position = self.shape.worldPosition + localOut
	-- check if need to reset flag for prevNoInput
	if self.prevNoInput and (self.cgData.inputFwd ~= 0 or self.cgData.inputRight ~= 0 or self.cgData.steeringSpeed ~= 0) then
		self.prevPosition = position
	end
	local positionChange = self.movementVec:dot(toLocal(self.shape, (position - self.prevPosition)))
	self.prevPosition = position
	local pitchChange = 0
	--if math.abs(positionChange) < 0.02 then
	if math.abs(positionChange) < 0.02 and self.animCountdown <= 0 then
		local pitch = math.deg(math.acos(sm.util.clamp(self.shape.at.z,-1,1)))
		if not self.prevPitch then
			self.prevPitch = pitch
		end
		pitchChange = (pitch - self.prevPitch) * -0.04
		self.prevPitch = pitch
		if self.shape.up.z < 0 then
			pitchChange = pitchChange * -1
		end
	else
	--print(self.animCountdown)
		self.prevPitch = nil
	end
	return positionChange + pitchChange
end

-- animSync crawls child connections and sets animation progress to match
function TankTrack1.animSync( self, interactable ) -- Gui setup
	for k,child in pairs(interactable:getChildren()) do
		cData = _G[tostring(child.id) .. "data"]
		-- if child is a tank track
		if cData and cData.type == "TankTrack" then
			-- stop if connections loop back into self
			if child.id == self.interactable.id then
				return
			else
				local animProg = self.animProgress
				-- if self and child are reversed of each other, invert animation step
				if self.cgData.mode == "Left" or self.cgData.mode == "Right" then
					if cData.mode == "Left Reversed" or cData.mode == "Right Reversed" then
						animProg = 1 - animProg
					end
				else
					if cData.mode == "Left" or cData.mode == "Right" then
						animProg = 1 - animProg
					end
				end
				-- set child track's animation
				child:setAnimProgress( "drive", animProg)
				-- recursive crawl of connections
				self:animSync(child)
			end
		end
	end
end
