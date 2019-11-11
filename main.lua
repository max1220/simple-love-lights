local Lights = require("lights") -- no globals required

-- all the state for this example:
local light_world -- will keep a reference for adding lights etc.
local lights -- list of lights(so we can update the position of the cursor)
local occluders -- list of "occluders"(squares that will block light)
local w,h = (tonumber(arg[2]) or 800), (tonumber(arg[3]) or 600) -- resolution
local font
local obey -- draw the obey at the top of the screen if set(also reserve space while generating)



--[[ Utillity functions ]]
local function hsl_to_rgb(h, s, l)
	-- convert
	local r, g, b
	if s == 0 then
		return l,l,l -- achromatic
	else
		function hue2rgb(p, q, t)
			if t < 0   then t = t + 1 end
			if t > 1   then t = t - 1 end
			if t < 1/6 then return p + (q - p) * 6 * t end
			if t < 1/2 then return q end
			if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
			return p
		end
		local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
		local p = 2 * l - q
		return hue2rgb(p, q, h + 1/3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1/3)
	end
	return r, g, b
end
local function add_light(x,y,color)
	-- if color is set, generate random color. set white otherwise
	local r,g,b = 1,1,1
	if color then
		r,g,b = hsl_to_rgb(math.random(), 1, 0.5)
	end

	-- add light to light world
	local size = 300
	local light = light_world:addLight(x,y, size, r,g,b)

	-- keep reference to this light(To update/remove)
	table.insert(lights, light)
end
local function add_occluder(x,y)
	-- generate random color with maximum saturation
	local r,g,b = hsl_to_rgb(math.random(), 1, 0.3)
	local w = 40
	table.insert(occluders, {x=x-w/2,y=y-w/2, w=w, h=w, color={r,g,b,1}})
end
local function add_random_occluders()
	-- add random occluders
	for i=1, w*h*0.0002 do
		add_occluder(math.random(50, w-50), math.random(obey and 175 or 50 , h-50))
	end
end
local function draw_occluders()
	-- draw all occluders (for the light calculation, not visible)
	love.graphics.setColor(1,1,1,1)
	for _, occ in ipairs(occluders) do
		love.graphics.rectangle("fill", occ.x, occ.y, occ.w, occ.h)
	end
	if obey then
		love.graphics.push()
		love.graphics.scale(3,3)
		love.graphics.printf(obey, 0, 20, w*(1/3), "center")
		love.graphics.pop()
	end
end
local function clear()
	lights = {}
	occluders = {}
	light_world:clearLights()
	obey = nil
	add_light(w/2, h/2)
end



--[[ Love2d callbacks ]]
function love.load(arg)
	math.randomseed(love.timer.getTime())

	-- prepare window
	love.window.setMode(w,h, {
		vsync = false
	})

	-- create light world
	light_world = Lights.newLightWorld()

	clear()
	add_light(-100, 50)
	obey = "O B E Y !"
	add_random_occluders()

	-- set font scaling
	font = love.graphics.newFont(14, "mono")
	font:setFilter("linear", "nearest")
	love.graphics.setFont(font)
end
function love.mousepressed(x,y,btn)
	if btn == 1 then
		-- add light at cursor on left mouse button
		add_light(x,y, true)
	elseif btn == 2 then
		-- add square centered at cursor on right mouse button
		add_occluder(x,y)
	elseif btn == 3 then
		-- reset lights and occluders on middle mouse button
		clear()
	end
end
function love.keypressed(key)
	if key == "r" then
		clear()
		add_random_occluders()
	end
end
function love.update(dt)
	_dt = dt
	collectgarbage()

	-- update cursor light
	if lights[1] then
		lights[1].x = love.mouse.getX()
		lights[1].y = love.mouse.getY()
	end

	if obey then
		local light = lights[2]
		light.x = light.x+dt*400
		light.y = 125
		if light.x > w+100 then
			light.x = -200
			light.r, light.g, light.b = hsl_to_rgb(math.random(), 1, 0.5)
		end
	end
	-- update lights
	light_world:updateLights(draw_occluders, 0, 0)
end
function love.draw()
	love.graphics.clear(0.2,0.2,0.2,1)
	love.graphics.setColor(1,1,1,1)

	-- draw the light overlay
	light_world:drawLights(0, 0)

	-- draw the occluders to the screen
	if obey then
		love.graphics.setColor(0,0,0,0.2)
		love.graphics.push()
		love.graphics.scale(3,3)
		love.graphics.printf(obey, 0, 20, w*(1/3), "center")
		love.graphics.pop()
	end
	for _, occ in ipairs(occluders) do
		love.graphics.setColor(occ.color[1], occ.color[2], occ.color[3], 1)
		love.graphics.rectangle("fill", occ.x, occ.y, occ.w, occ.h)
	end

	-- draw statistics
	local h = font:getHeight() + 20
	love.graphics.setColor(0,0,0,0.2)
	love.graphics.rectangle("fill", 0,0, w, h)
	love.graphics.setColor(1,1,1,1)
	love.graphics.print(("FPS: %.1f   dt: %.5f   Lights: %d   GC: %d"):format(love.timer.getFPS(), love.timer.getDelta(), #lights, collectgarbage("count")), 10, 10)
	love.graphics.printf("R: Randomize   LMB: Add light   RM: Add Occluder   MMB:  Clear", 0, 10, w-10, "right")
end
