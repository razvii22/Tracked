--[[ 
********** Utility by MJM ********** 

My utility functions to use in my other scriptes.

***********************************
--]]

if not utility then
	utility = true
	
	-- Returns if interactable is one of the defined logic types
	function isLogic( interactable )
		local t = interactable.type
		local id = tostring(interactable.shape.shapeUuid)
		local mpTick = "6f2dd83e-bc0d-43f3-8ba5-d5209eb03d07" --Modpack Tick Button
		local seatLogic = "6f64d36d-5e23-4f6b-bcb5-e0057ba43fce" --Scifi Seat Logic
		return t == "logic" or t == "button" or t == "lever" or t == "sensor" or t == "timer" or id == mpTick or id == seatLogic
	end
	
	-- Returns the sign of the number
	function sign( num )
		if num >= 0 then
			return 1
		else
			return -1
		end
	end
	
	-- Returns a local vector to a shape from a world vector.
	function toLocal( shape, globalVec )
		if globalVec:length() < 0.000001 then
			return sm.vec3.zero()
		else
			return sm.vec3.new(shape.right:dot(globalVec), shape.at:dot(globalVec), shape.up:dot(globalVec))
		end
	end
	
	-- Returns a global vector from a shape's local vector
	function toGlobal( shape, localVec )
		if localVec:length() < 0.000001 then
			return sm.vec3.zero()
		else
			return (shape.right * localVec.x) + (shape.at * localVec.y) + (shape.up * localVec.z)
		end
	end
	
	-- Returns true if not empty. Returns false if empty or nil.
	function hasData(table)
		if table == nil then
			return false
		end
		for k,v in pairs(table) do
			return true
		end
		return false
	end
	
	--[[ 
	Returns vector clamped to a max length. 
	Filters out extreemly small lengths that cause normalization errors.
	Turns nil into zero length.
	--]]
	function clampVec( impulse, maxLength )
		if impulse == nil then
			return sm.vec3.zero()
		else
			local l = impulse:length()
			local maxL = math.abs(maxLength)
			if l < 0.000001 then
				return sm.vec3.zero()
			elseif l > maxL then
				return impulse:normalize() * maxL
			else
				return impulse
			end
		end
	end
	
end