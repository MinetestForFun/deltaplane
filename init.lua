
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
	if self.driver and clicker == self.driver then
		self.driver = nil
		clicker:set_detach()
		default.player_attached[name] = false
		default.player_set_animation(clicker, "stand" , 30)
		local pos = clicker:getpos()
		pos = {x = pos.x, y = pos.y + 0.2, z = pos.z}
		minetest.after(0.1, function()
			clicker:setpos(pos)
		end)
	elseif not self.driver then
		local attach = clicker:get_attach()
		if attach and attach:get_luaentity() then
			local luaentity = attach:get_luaentity()
			if luaentity.driver then
				luaentity.driver = nil
			end
		end
		clicker:set_detach()
	end
	self.driver = clicker
	clicker:set_attach(self.object, "", {x = 0, y = 11, z = -3}, {x = 0, y = 0, z = 0})
	default.player_attached[name] = true
	minetest.after(0.2, function()
		default.player_set_animation(clicker, "sit" , 30)
	end)
	self.object:setyaw(clicker:get_look_yaw() - math.pi / 2)
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
	if not puncher or not puncher:is_player() or self.removed then
		return
	end
	if self.driver and puncher == self.driver then
		self.driver = nil
		puncher:set_detach()
		default.player_attached[puncher:get_player_name()] = false
	end
	if not self.driver then
		self.removed = true
		-- delay remove to ensure player is detached
		minetest.after(0.1, function()
			self.object:remove()
		end)
		if not minetest.setting_getbool("creative_mode") then
			local inv = puncher:get_inventory()
			if inv:room_for_item("main", "deltaplane:" .. self.parameters.name) then
				inv:add_item("main", "deltaplane:" .. self.parameters.name)
			else
				minetest.add_item(self.object:getpos(), "deltaplane:" .. self.parameters.name)
			end
		end
	end
end

function deltaplane.on_step(self, dtime)
	self.v = deltaplane.get_v(self.object:getvelocity()) * deltaplane.get_sign(self.v)
	local pos = self.object:getpos()
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
			default.player_attached[self.driver:get_player_name()] = false
			self.driver = nil
		end
		minetest.after(0.1, function()
			self.object:remove()
		end)		
	end
	if self.driver then
		local ctrl = self.driver:get_player_control()
		local yaw = self.object:getyaw()
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
		end
		if ctrl.left then
			self.object:setyaw(yaw + (1 + dtime) * (0.08 * (self.parameters.controls.rotate or 1)))
		elseif ctrl.right then
			self.object:setyaw(yaw - (1 + dtime) * (0.08 * (self.parameters.controls.rotate or 1)))
		end
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
	self.object:setvelocity(deltaplane.get_velocity(self.v, self.object:getyaw(), climb))
end

deltaplane.register_deltaplane = function(parameters)
	minetest.register_entity("deltaplane:" .. parameters.name, {
		physical = true,
		collisionbox = {-0.5, -0.35, -0.5, 0.5, 0.3, 0.5},
		visual = "mesh",
			
		-- New model -- 2017.02.19 --
		mesh = "delta.x",
		animation = {
		stand_start = 0,
		stand_end = 80,
		},
		textures = {parameters.texture or "deltaplane.png"},	
		
		--textures = {parameters.texture or "default_wood.png"},
		parameters = parameters,
		driver = nil,
		v = 0,
		last_v = 0,
		removed = false,
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
	
			pointed_thing.under.y = pos.y + 0.5
			minetest.add_entity(pos, "deltaplane:"..parameters.name)
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		end,
	})
end



deltaplane.register_deltaplane({
	name = "deltaplane1",
	--texture = "default_wood.png",
	-- il semblerai que ce soit pas necessaire vue qu'elle est déclarée dans le register ?
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


