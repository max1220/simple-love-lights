-- This library is a slight modification to a trivial implementation of raycasting point lights for love2d/LÖVE, in module form.
-- It is basically just packaging dylhunn's simple-love-lights in a module. Original:
--  https://github.com/dylhunn/simple-love-lights
-- Which is heavily based on mattdesl's libGDX implementation, described here:
--  https://github.com/mattdesl/lwjgl-basics/wiki/2D-Pixel-Perfect-Shadows

-- The API works now like this:
--  world = Lights.newLightWorld() --> world
--  world:addLight(lx,ly,lsize,lr,lg,lb) --> Light
--  world:drawLights(drawOccludersFn, coordTransX, coordTransY)
--  world:clearLights()
-- internal workings:
--  world:drawLight(drawOccludersFn, lightInfo, coordTransX, coordTransY)
--  world.LightInfos
--  world.shadowMapShader
--  world.lightRenderShader

local Lights = {}
function Lights.newLightWorld()
	local LightWorld = {}

	LightWorld.LightInfos = {}

	LightWorld.shadowMapShader = love.graphics.newShader([[
		#define PI 3.14159265359
		extern number yresolution;
		const float ALPHA_THRESHOLD = 0.01;

		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			number distance = 1.0;

			// Iterate through the occluder map's y-axis.
			for (number y = 0.0; y < yresolution; y++) {
				// Rectangular to polar
				vec2 norm = vec2(texture_coords.s, y / yresolution) * 2.0 - 1.0;
				number theta = PI * 1.5 + norm.x * PI;
				number r = (1.0 + norm.y) * 0.5;

				//coord which we will sample from occlude map
				vec2 coord = vec2(-r * sin(theta), -r * cos(theta)) / 2.0 + 0.5;

				//sample the occlusion map
				vec4 data = Texel(texture, coord);

				//the current distance is how far from the top we've come
				number dst = y / yresolution;

				//if we've hit an opaque fragment (occluder), then get new distance
				//if the new distance is below the current, then we'll use that for our ray
				number caster = data.a;
				if (caster > ALPHA_THRESHOLD) {
					distance = min(distance, dst);
					break;
				}

			}
			return vec4(vec3(distance), 1.0);
		}
	]])
	LightWorld.lightRenderShader = love.graphics.newShader([[
		#define PI 3.14159265359
		extern number xresolution;

		//sample from the 1D distance map
		number dist_sample(vec2 coord, number r, Image u_texture) {
			return step(r, Texel(u_texture, coord).r);
		}

		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			// Transform rectangular to polar coordinates.
			vec2 norm = texture_coords.st * 2.0 - 1.0;
			number theta = atan(norm.y, norm.x);
			number r = length(norm);
			number coord = (theta + PI) / (2.0 * PI);

			// The tex coordinate to sample our 1D lookup texture.
			//always 0.0 on y axis
			vec2 tc = vec2(coord, 0.0);

			// The center tex coord, which gives us hard shadows.
			number center = dist_sample(tc, r, texture);

			// Multiply the blur amount by our distance from center.
			//this leads to more blurriness as the shadow "fades away"
			number blur = (1./xresolution)  * smoothstep(0., 1., r);

			// Use a simple gaussian blur.
			number sum = 0.0;
			sum += dist_sample(vec2(tc.x - 4.0*blur, tc.y), r, texture) * 0.05;
			sum += dist_sample(vec2(tc.x - 3.0*blur, tc.y), r, texture) * 0.09;
			sum += dist_sample(vec2(tc.x - 2.0*blur, tc.y), r, texture) * 0.12;
			sum += dist_sample(vec2(tc.x - 1.0*blur, tc.y), r, texture) * 0.15;

			sum += center * 0.16;
			sum += dist_sample(vec2(tc.x + 1.0*blur, tc.y), r, texture) * 0.15;
			sum += dist_sample(vec2(tc.x + 2.0*blur, tc.y), r, texture) * 0.12;
			sum += dist_sample(vec2(tc.x + 3.0*blur, tc.y), r, texture) * 0.09;
			sum += dist_sample(vec2(tc.x + 4.0*blur, tc.y), r, texture) * 0.05;

			// Sum of 1.0 -> in light, 0.0 -> in shadow.
		 	// Multiply the summed amount by our distance, which gives us a radial falloff.
		 	return vec4(vec3(1.0), sum * smoothstep(1.0, 0.0, r));
			//return vec4(vec3(1.0), center*smoothstep(1.0, 0.0, r));
		}
	]])

	function LightWorld:addLight(lx,ly,lsize,lr,lg,lb)
		local lightInfo = {
			x=lx,
			y=ly,
			size=lsize,
			r=lr, g=lg, b=lb,
			occludersCanvas = love.graphics.newCanvas(lsize, lsize),
			shadowMapCanvas = love.graphics.newCanvas(lsize, 1),
			lightRenderCanvas = love.graphics.newCanvas(lsize, lsize),
		}

		table.insert(self.LightInfos, lightInfo)
		return lightInfo
	end

	function LightWorld:removeLight(light)
		for i, lightInfo in ipairs(self.LightInfos) do
			if lightInfo == light then
				table.remove(self.LightInfos, i)
				return
			end
		end
	end

	function LightWorld:clearLights()
		self.LightInfos = {}
	end

	function LightWorld:drawLights(coordTransX, coordTransY)
		for _, lightInfo in ipairs(self.LightInfos) do
			self:drawLight(lightInfo, coordTransX, coordTransY)
		end
	end

	function LightWorld:updateLights(drawOccludersFn, coordTransX, coordTransY)
		for _, lightInfo in ipairs(self.LightInfos) do
			self:updateLight(drawOccludersFn, lightInfo, coordTransX, coordTransY)
		end
	end

	function LightWorld:updateLight(drawOccludersFn, lightInfo, coordTransX, coordTransY)
		lightInfo.occludersCanvas:renderTo(love.graphics.clear)
		lightInfo.shadowMapCanvas:renderTo(love.graphics.clear)
		lightInfo.lightRenderCanvas:renderTo(love.graphics.clear)

		self.lightRenderShader:send("xresolution", lightInfo.size);
		self.shadowMapShader:send("yresolution", lightInfo.size);

		-- Upper-left corner of light-casting box.
		local x = lightInfo.x - (lightInfo.size / 2) + coordTransX
		local y = lightInfo.y - (lightInfo.size / 2) + coordTransY

		-- Translating the occluders by the position of the light-casting
		-- box causes only occluders in the box to appear on the canvas.
		love.graphics.push()
		love.graphics.translate(-x, -y)

		lightInfo.occludersCanvas:renderTo(drawOccludersFn)

		love.graphics.pop()


		-- We need to un-apply any scrolling coordinate translation, because
		-- we want to draw the light/shadow effect canvas (and helpers) literally at
		-- (0, 0) on the screen. This didn't apply to the occluders because occluders
		-- on screen should be affected by scrolling translation.
		love.graphics.push()
		love.graphics.translate(-coordTransX, -coordTransY)

		-- draw to shadowMapCanvas from occluderCanvas
		love.graphics.setShader(self.shadowMapShader)
		love.graphics.setCanvas(lightInfo.shadowMapCanvas)
		love.graphics.draw(lightInfo.occludersCanvas, 0, 0)
		love.graphics.setCanvas()
		love.graphics.setShader()

		-- draw to lightRenderCanvas from shadowMapCanvas
		love.graphics.setShader(self.lightRenderShader)
		love.graphics.setCanvas(lightInfo.lightRenderCanvas)
		love.graphics.draw(lightInfo.shadowMapCanvas, 0, 0, 0, 1, lightInfo.size)
		love.graphics.setCanvas()
		love.graphics.setShader()

		love.graphics.pop()
	end

	function LightWorld:drawLight(lightInfo, coordTransX, coordTransY)
		-- Upper-left corner of light-casting box.
		local x = lightInfo.x - (lightInfo.size / 2) + coordTransX
		local y = lightInfo.y - (lightInfo.size / 2) + coordTransY

		love.graphics.push()
		love.graphics.translate(-coordTransX, -coordTransY)

		-- draw the pre-calculated lightRenderCanvas to the screen
		love.graphics.setBlendMode("add")
		love.graphics.setColor(lightInfo.r, lightInfo.g, lightInfo.b, 1)
		love.graphics.draw(lightInfo.lightRenderCanvas, x, y + lightInfo.size, 0, 1, -1)
		love.graphics.setBlendMode("alpha")

		love.graphics.pop()
	end

	return LightWorld
end
return Lights
