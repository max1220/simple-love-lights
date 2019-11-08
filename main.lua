local Lights = require("lights")

local light_world = Lights.newLightWorld()
local lights = {}
local occluders = {}


function add_light(x,y)
	local size,r,g,b = 500, math.random(), math.random(), math.random()
	local light = light_world:addLight(x,y, size, r,g,b)
	table.insert(lights, light)
end

function add_occluder(x,y)
	local w, r,g,b = 40, math.random(), math.random(), math.random()
	table.insert(occluders, {x=x-w/2,y=y-w/2, w=w, h=w, color={r,g,b,1}})
end


function love.load(arg)
	local w,h = 800,600

	love.window.setMode(w,h, {
		vsync = false
	})

	-- add initial light
	add_light(w/2, h/2)

	-- add random occluders
	for i=1, 100 do
		add_occluder(math.random(1, w), math.random(1, w))
	end
end


function love.mousepressed(x,y,btn)
	if btn == 1 then
		add_light(x,y)
	elseif btn == 2 then
		add_occluder(x,y)
	else
		lights = {}
		occluders = {}
		light_world:clearLights()
	end
end


local _dt
function love.update(dt)
	_dt = dt
	if lights[1] then
		lights[1].x = love.mouse.getX()
		lights[1].y = love.mouse.getY()
	end
end


function draw_occluders()
	for _, occ in ipairs(occluders) do
		love.graphics.setColor(occ.color[1], occ.color[2], occ.color[3], 1)
		love.graphics.rectangle("fill", occ.x, occ.y, occ.w, occ.h)
	end
end
function love.draw()
	love.graphics.clear(0.5,0.5,0.5,1)
	love.graphics.setColor(1,1,1,1)
	light_world:drawLights(draw_occluders, 0, 0)
	draw_occluders()
	love.graphics.setColor(1,1,1,1)
	love.graphics.print(("Lights: %d  dt: %.5f  FPS: %.2f"):format(#lights, _dt, love.timer.getFPS()), 10, 10)
end
