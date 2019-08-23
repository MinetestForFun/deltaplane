
deltaplane = {}

function deltaplane.get_sign(i)
	if i == 0 then
		return 0
	else
		return i / math.abs(i)
	end
end

function deltaplane.get_velocity(v, yaw, y)
	local x = -math.sin(yaw) * v
	local z =  math.cos(yaw) * v
	return {x = x, y = y, z = z}
end

function deltaplane.get_v(v)
	return math.sqrt(v.x ^ 2 + v.z ^ 2)
end

function deltaplane.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	local ctrl = clicker:get_player_control()
	if self.driver and clicker == self.driver and ctrl.sneak then
		self.driver = nil
		clicker:set_detach()
		player_api.player_attached[name] = false
		player_api.set_animation(clicker, "stand" , 30)
		local pos = clicker:get_pos()
		pos = {x = pos.x, y = pos.y + 0.2, z = pos.z}
		minetest.after(0.1, function()
			clicker:set_pos(pos)
		end)
		return
	elseif not self.driver then
		local attach = clicker:get_attach()
		if attach and attach:get_luaentity() then
			local luaentity = attach:get_luaentity()
			if luaentity.driver then
				luaentity.driver = nil
			end
		end
		clicker:set_detach()
		self.driver = clicker
		clicker:set_attach(self.object, "", {x = 0, y = 11, z = -3}, {x = 0, y = 0, z = 0})
		player_api.player_attached[name] = true
		minetest.after(0.2, function()
			player_api.set_animation(clicker, "sit", 30)
		end)

		if clicker.set_look_horizontal then
			clicker:set_look_horizontal(self.object:get_yaw())
		else
			clicker:set_look_yaw(self.object:get_yaw())
		end
	end
end


function deltaplane.on_activate(self, staticdata, dtime_s)
	self.object:set_armor_groups({immortal = 1})
	if staticdata then
		self.v = tonumber(staticdata)
	end
	self.last_v = self.v
end


function deltaplane.get_staticdata(self)
	return tostring(self.v)
end


function deltaplane.on_punch(self, puncher)
	if not puncher or not puncher:is_player() then
		return
	end

	if not self.driver then
		self.object:remove()
		if not minetest.settings:get_bool("creative_mode") then
			local inv = puncher:get_inventory()
			if inv:room_for_item("main", "deltaplane:" .. self.parameters.name) then
				inv:add_item("main", "deltaplane:" .. self.parameters.name)
			else
				minetest.add_item(self.object:get_pos(), "deltaplane:" .. self.parameters.name)
			end
		end
	end
end

function deltaplane.on_step(self, dtime)
	self.v = deltaplane.get_v(self.object:get_velocity()) * deltaplane.get_sign(self.v)
	local pos = self.object:get_pos()
	local node = minetest.get_node_or_nil(pos)
	local climb = 0
	local in_water = false
	if node and node.name ~= "air" then
		self.v = 0
		if minetest.get_item_group(node.name, "water") ~= 0 then
			in_water = true
		end
		if minetest.get_item_group(node.name, "lava") ~= 0 then
			self.object:set_hp(self.object:get_hp()-1)
		end
	end
	if self.object:get_hp() <= 0 then
		if self.driver then
			self.driver:set_detach()
			player_api.player_attached[self.driver:get_player_name()] = false
			self.driver = nil
		end
		minetest.after(0.1, function()
			self.object:remove()
		end)		
	end
	if self.driver then
		local attach = self.driver:get_attach()
		if not attach or (attach:get_luaentity() and attach:get_luaentity() == self.object) then
			self.driver = nil
			self.stand = true
			return
		end

		local ctrl = self.driver:get_player_control()
		local yaw = self.object:get_yaw()
		if not self.stand then
			if ctrl.up and self.v < self.parameters.controls.speed then
				self.v = self.v + 0.4
			elseif ctrl.down then
				self.v = self.v - 0.4
			elseif ctrl.sneak then
				climb = -3
			end
		end
		if self.stand and self.v == 0 and ctrl["aux1"] then
			self.v = 4
			self.tclimb = 40
			self.stand = false
		--	self.object:set_animation({
		--		x = self.animation.stand_start,
		--		y = self.animation.stand_end},
		--		5, 0)
		end
		if ctrl.left then
			self.object:set_yaw(yaw + (1 + dtime) * (0.08 * (self.parameters.controls.rotate or 1)))
		elseif ctrl.right then
			self.object:set_yaw(yaw - (1 + dtime) * (0.08 * (self.parameters.controls.rotate or 1)))
		end
	else
		self.v = self.v - 0.5
	end
	
	if self.v > self.parameters.controls.speed then
		self.v = self.v - 0.5
	end

	if self.v <= 0 then
		self.v = 0
	end	
	
	if self.tclimb > 0 then
		climb = climb + ((self.tclimb/10)*(self.v/10))
		self.tclimb = self.tclimb - 1
	end
	if in_water then
		climb = -0.2
	else
		climb = climb + self.parameters.controls.down/self.v
	end
	
	
	if climb < -5 then climb = -5 end
	self.object:set_velocity(deltaplane.get_velocity(self.v, self.object:get_yaw(), climb))
end

deltaplane.register_deltaplane = function(parameters)
	minetest.register_entity("deltaplane:" .. parameters.name, {
		physical = true,
		collisionbox = {-0.5, 0, -1, 0.5, 2, 1.0},
		visual = "mesh",
			
		-- New model -- 2017.02.19 --
		mesh = "delta.b3d",
		animation = {
		stand_start = 0,
		stand_end = 8,
		},
		textures = {parameters.texture},
		parameters = parameters,
		driver = nil,
		v = 0,
		last_v = 0,
		stand = true,
		tclimb = 0,
		on_rightclick = deltaplane.on_rightclick,
		on_activate = deltaplane.on_activate,
		get_staticdata = deltaplane.get_staticdata,
		on_punch = deltaplane.on_punch,
		on_step = deltaplane.on_step
	})

	minetest.register_craftitem("deltaplane:" .. parameters.name, {
		description = parameters.description or "Deltaplane",
		inventory_image = "deltaplane_" .. parameters.name .. "_inventory.png",
		wield_image = "deltaplane_" .. parameters.name .. "_wield.png",
		wield_scale = {x = 2, y = 2, z = 1},
		liquids_pointable = false,

		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return
			end
			local pos = pointed_thing.above
			local node = minetest.get_node_or_nil(pos)
			if not node or node.name ~= "air" then return end
	
			minetest.add_entity(pos, "deltaplane:"..parameters.name)
			if not minetest.settings:get_bool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		end,
	})
end

deltaplane.register_deltaplane({
	name = "deltaplane1",
	texture = "deltaplane_deltaplane1.png",
	controls = {
		speed = 5,
		down = -1.3,
		rotate = 1
	},
	description = "Deltaplane"
})

-- Craft registrations
minetest.register_craft({
	output = "deltaplane:deltaplane1",
	recipe = {
		{"", "default:paper", ""},
		{"default:paper", "default:paper", "default:paper"},
		{"farming:string", "", "farming:string"},
	},
})
