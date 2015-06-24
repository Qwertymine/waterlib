	--this code is extremely inefficient
	--check for flowing water (This is insane)

--calculate correct water height
local function get_mod_node_param2(pos)
	local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = node.param2
	-- 8 = water above or source, 8 > flowing, negative = flowing down
	if node.name == "default:water_source" then
		param2 = 8
	elseif node.name == "default:water_flowing" then
	--water above
		if minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y+1,z=pos.z}).name, "water") ~= 0 then
			param2 = 8
		--water below 	--MODIFY THE PARAM2 IF NODE IS FLOWING WATER WITH FLOWING WATER BELOW IT (NEEDS TO SUBTRACT 8)
		elseif minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name, "water") ~= 0  then
			param2 = param2 - 8
		-- else keep default
		end
	else
	--if not water
	param2 = nil
	end
	return param2
end

-- direction should be 1 or -1
-- returns axis aligned direction the boat would flow based on the single node
local function water_flow_logic(param2,pos_testing,direction)
	local param2_testing = get_mod_node_param2(pos_testing)
	if param2_testing and param2 then
		if param2_testing < param2 then
			return direction
		elseif param2_testing > param2 then
			return (0 - direction)
		else
			return 0
		end
	else
		return 0
	end
end

--full 16 directions + 0 --matches rendered directions
--returns values between -2 and 2
function water_flow(pos)
	local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = get_mod_node_param2(pos)
	local is_source = false
	local x = 0
	local z = 0
	
	-- water flow logic
	x = x + water_flow_logic(param2,{x=pos.x-1,y=pos.y,z=pos.z},-1)
	x = x + water_flow_logic(param2,{x=pos.x+1,y=pos.y,z=pos.z}, 1)
	z = z + water_flow_logic(param2,{x=pos.x,y=pos.y,z=pos.z-1},-1)
	z = z + water_flow_logic(param2,{x=pos.x,y=pos.y,z=pos.z+1}, 1)
	
	return to_unit_vector({x=x,y=0,z=z})
end

--sum of direction vectors must match an array index
local function to_unit_vector(dir_vector)
	--(sum,root)
	-- (0,1), (1,1+0=1), (2,1+1=2), (3,1+2^2=5), (4,2^2+2^2=8)
	local inv_roots = {[0] = 1, [1] = 1, [2] = 0.70710678118655, [4] = 0.5, [5] = 0.44721359549996, [8] = 0.35355339059327}
	local sum = dir_vector.x*dir_vector.x + dir_vector.z*dir_vector.z
	return {x=dir_vector.x*inv_roots[sum],y=dir_vector.y,z=dir_vector.z*inv_roots[sum]}
end

function is_touching(realpos,nodepos,radius)
	local boarder = 0.5 - radius
	return (math.abs(realpos - nodepos) > (boarder))
end

function is_water(pos)
	return (minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y,z=pos.z}).name, "water") ~= 0)
end

function node_is_water(node)
	if node.name == "default:water_source" or node.name == "default:water_flowing" then
		return true
	else
		return false
	end
end

--This code is more efficient
local function quick_flow_logic(node,pos_testing,direction)
	local name = node.name
	if minetest.registered_nodes[name].liquidtype == "source" then
		local node_testing = minetest.get_node(pos_testing)
		local param2_testing = node_testing.param2
		if minetest.registered_nodes[node_testing.name].liquidtype ~= "flowing" then
			return 0
		else
			return direction
		end
	elseif minetest.registered_nodes[name].liquidtype == "flowing" then
		local node_testing = minetest.get_node(pos_testing)
		local param2_testing = node_testing.param2
		if minetest.registered_nodes[node_testing.name].liquidtype == "source" then
			return -direction
		elseif minetest.registered_nodes[node_testing.name].liquidtype == "flowing" then
			if param2_testing < node.param2 then
				if (node.param2 - param2_testing) > 6 then
					return -direction
				else
					return direction
				end
			elseif param2_testing > node.param2 then
				if (param2_testing - node.param2) > 6 then
					return direction
				else
					return -direction
				end
			end
		end
	end
	return 0
end

function quick_flow(pos,node)
	local x = 0
	local z = 0
	
	if not minetest.get_item_group(node.name, "liquid") ~= 0  then
		return {x=0,y=0,z=0}
	end
	
	x = x + quick_flow_logic(node,{x=pos.x-1,y=pos.y,z=pos.z},-1)
	x = x + quick_flow_logic(node,{x=pos.x+1,y=pos.y,z=pos.z}, 1)
	z = z + quick_flow_logic(node,{x=pos.x,y=pos.y,z=pos.z-1},-1)
	z = z + quick_flow_logic(node,{x=pos.x,y=pos.y,z=pos.z+1}, 1)
	
	return to_unit_vector({x=x,y=0,z=z})
end


	--if not in water but touching, move centre to touching block
	--x has higher precedence than z
	--if pos changes with x, it affects z
function move_centre(pos,realpos,node,radius)
	if is_touching(realpos.x,pos.x,radius) then
		if is_water({x=pos.x-1,y=pos.y,z=pos.z}) then
			node = minetest.get_node({x=pos.x-1,y=pos.y,z=pos.z})
			pos = {x=pos.x-1,y=pos.y,z=pos.z}
		elseif is_water({x=pos.x+1,y=pos.y,z=pos.z}) then
			node = minetest.get_node({x=pos.x+1,y=pos.y,z=pos.z})
			pos = {x=pos.x+1,y=pos.y,z=pos.z}
		end
	end
	if is_touching(realpos.z,pos.z,radius) then
		if is_water({x=pos.x,y=pos.y,z=pos.z-1}) then
			node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z-1})
			pos = {x=pos.x,y=pos.y,z=pos.z-1}
		elseif is_water({x=pos.x,y=pos.y,z=pos.z+1}) then
			node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z+1})
			pos = {x=pos.x,y=pos.y,z=pos.z+1}
		end
	end
	return pos,node
end
