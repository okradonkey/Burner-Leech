function init_globals()
    -- [re]build the list of burner/inserter entities
    global.burners = {}
    for _, surface in pairs(game.surfaces) do
        for _, burner in ipairs(surface.find_entities_filtered({type = 'inserter'})) do
            if burner.burner then
                table.insert(global.burners, {entity = burner, position = burner.position, force = burner.force, surface = burner.surface})
            end
        end
    end
    global.burner_index = nil
    -- [re]build the list of fuel items
    global.fuel_list = {}
    for _, proto in pairs(game.item_prototypes) do
        if proto.fuel_value > 0 then
            table.insert(global.fuel_list, proto.name)
        end
    end
end
local function position_to_tile_position(position)
    local x, y
    local ceil_x = math.ceil(position.x)
    local ceil_y = math.ceil(position.y)
    x = position.x >= 0 and math.floor(position.x) + 0.5 or (ceil_x == position.x and ceil_x + 0.5 or ceil_x - 0.5)
    y = position.y >= 0 and math.floor(position.y) + 0.5 or (ceil_y == position.y and ceil_y + 0.5 or ceil_y - 0.5)
    return {x, y}
end

local function add_burner(burner)
    if (burner.type == 'inserter' and burner.burner) then
        table.insert(global.burners, {entity = burner, position = burner.position, force = burner.force, surface = burner.surface})
    end
end

local function on_built(event)
    add_burner(event.created_entity)
end

local function on_cloned(event)
    add_burner(event.destination)
end

local function on_script_raised_built(event)
    add_burner(event.entity)
end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.on_entity_cloned, on_cloned)
script.on_event(defines.events.script_raised_built, on_script_raised_built)

--- check_burner
function check_burner()
    local data
    if global.burner_index and not global.burners[global.burner_index] then
        game.print('Invalid burner_index ' .. global.burner_index)
        global.burner_index = nil
    end
    global.burner_index, data = next(global.burners, global.burner_index)
    if data ~= nil then
        local burner = data.entity
        if burner then
            if burner.valid then
                if (burner.type == 'inserter' and burner.burner) then
                    --log(burner.name .. ' @ ' .. burner.position.x .. ', ' .. burner.position.y)
                    leech(burner)
                else
                    -- somehow a non-burner inserter is in the list - remove it
                    global.burners[global.burner_index] = nil
                    global.burner_index = nil
                    return
                end
            else
                -- burner has been removed
                -- check to see if there is a different burner inserter at that position - use that, else remove the reference
                local position = data.position
                local surface = data.surface
                -- check if surface still exists, with warptorio mod surfaces get removed after a warp
                if not surface.valid then
                    global.burners[global.burner_index] = nil
                    global.burner_index = nil
                    return
                end
                bc = surface.find_entities_filtered({position = data.position, force = data.force, surface = surface, type = 'inserter', limit = 1})
                if (next(bc) == nil) or (not bc.burner) then
                    -- NOTHING WAS FOUND
                    global.burners[global.burner_index] = nil
                    global.burner_index = nil
                    return
                else
                    -- replace the reference
                    global.burners[global.burner_index].entity = bc[1]
                    leech(bc[1])
                end
            end
        end
    end
end

--- leech(burner)
-- checks to see if the burner inserter can/should leech fuel from the entity at it's pickup position
function leech(burner)
    local surface, force, position = burner.surface, burner.force, burner.position

    local pickup_target, take_from_pickup_target_inventory = nil, false
    local drop_target, send_to_target = nil, false

    -- find and set pickup_target
    if burner.pickup_target == nil then
        pt = surface.find_entities_filtered({position = position_to_tile_position(burner.pickup_position), force = burner.force, surface = burner.surface, limit = 1})
        if pt[1] ~= nil then
            if pt[1].get_fuel_inventory() ~= nil then
                take_from_pickup_target_inventory = true
                pickup_target = pt[1]
            end
        end
    else
        pickup_target = burner.pickup_target
    end
    -- nothing to pickup from
    if pickup_target == nil then
        return
    end

    -- find and set drop_target
    -- if self fuel count < 1 fuel self before fueling others
    if burner.get_fuel_inventory().get_item_count() < 1 then
        drop_target = burner
    else
        dt = surface.find_entities_filtered({position = position_to_tile_position(burner.drop_position), force = burner.force, surface = burner.surface, limit = 1})
        drop_target = dt[1]
    end

    -- nothing to drop to
    if drop_target == nil then
        return
    end

    -- check drop_target for burner energy source
    if drop_target.burner == nil then
        return
    end

    if drop_target.get_fuel_inventory() ~= nil then
        if drop_target.get_fuel_inventory().get_item_count() < 5 then
            send_to_target = true
        else
            return
        end
    end

    if burner.held_stack.valid_for_read == false then
        for _, fuel in pairs(global.fuel_list) do
            if pickup_target.get_item_count(fuel) > 0 then
                burner.held_stack.set_stack({name = fuel, count = 1})
                pickup_target.remove_item({name = fuel, count = 1})
                return true
            end
        end
    end
end

script.on_nth_tick(1, check_burner)

script.on_init(init_globals)

script.on_configuration_changed(init_globals)
