--!native
--!optimize 2

local ECS = require(game.ReplicatedStorage.RoECS)

local function assertEquals(actual, expected, msg)
    if actual ~= expected then
        error(msg .. " | Expected: " .. tostring(expected) .. ", got: " .. tostring(actual), 2)
    end
end

local function assertTrue(cond, msg)
    if not cond then
        error(msg or "Expected condition to be true", 2)
    end
end

local function bitIsSet(mask: buffer, componentId: number): boolean
    local chunk = componentId // 32
    local bitIndex = componentId % 32
    local bits = buffer.readu32(mask, chunk)
    return bit32.extract(bits, bitIndex) == 1
end

local function countArchetypes(world)
    return #world.archetypes
end

local function getArchetypeByMask(world, mask: buffer)
    local hash = buffer.tostring(mask)
    local idx = world.archetype_hash_to_index[hash]
    if idx then
        return world.archetypes[idx], idx
    end
    return nil, nil
end

local function archetypeHasComponent(archetype, componentId)
    return archetype.component_id_to_cache_index[componentId] ~= nil
end

local function runTests()
    print("Starting ECS Unit Tests")

	local testWorldCounter = 0

	local function newWorldAndComponents()
		testWorldCounter += 1
		local world = ECS.world("testWorld_" .. tostring(testWorldCounter), false)
		local cVelocity = world:component({0, 0, 0})
		local cPart = world:component(Instance.new("Part"))
		local cGravity = world:component({-150, -90000})
		return world, cVelocity, cPart, cGravity
	end

    -- Test 1: Spawn entity with no components
    do
        local world, _, _, _ = newWorldAndComponents()
        local e = world:spawn()
        assertTrue(e > 0, "Entity ID should be > 0")
        local mask = world.entities_masks[e]
        for i = 0, ECS.utils.chunks_zeroed do
            assertEquals(buffer.readu32(mask, i), 0, "Mask should be empty for entity with no components")
        end
        local archetypeCount = countArchetypes(world)
        assertEquals(archetypeCount, 1, "Should create exactly 1 archetype for empty mask")
        print("Test 1 Passed: Spawn entity without components and archetype check")
    end

    -- Test 2: Spawn entity with one component
    do
        local world, cVelocity, _, _ = newWorldAndComponents()
        local e = world:spawn(cVelocity)
        local mask = world.entities_masks[e]
        assertTrue(bitIsSet(mask, cVelocity), "Velocity bit should be set")

        local archetypeCount = countArchetypes(world)
        assertEquals(archetypeCount, 1, "One archetype expected for single component")

        local archetype, idx = getArchetypeByMask(world, mask)
        assertTrue(archetypeHasComponent(archetype, cVelocity), "Archetype must include velocity component")
        assertEquals(archetype.entity_count, 1, "Archetype entity count should be 1")

        print("Test 2 Passed: Spawn entity with one component and archetype checks")
    end

    -- Test 3: Spawn entity with multiple components
    do
        local world, cVelocity, cPart, cGravity = newWorldAndComponents()
        local e = world:spawn(cVelocity, cPart, cGravity)
        local mask = world.entities_masks[e]
        assertTrue(bitIsSet(mask, cVelocity), "Velocity bit should be set")
        assertTrue(bitIsSet(mask, cPart), "Part bit should be set")
        assertTrue(bitIsSet(mask, cGravity), "Gravity bit should be set")

        local archetypeCount = countArchetypes(world)
        assertEquals(archetypeCount, 1, "One archetype expected for these components")

        local archetype, idx = getArchetypeByMask(world, mask)
        assertTrue(archetypeHasComponent(archetype, cVelocity), "Archetype must include velocity component")
        assertTrue(archetypeHasComponent(archetype, cPart), "Archetype must include part component")
        assertTrue(archetypeHasComponent(archetype, cGravity), "Archetype must include gravity component")
        assertEquals(archetype.entity_count, 1, "Archetype entity count should be 1")

        print("Test 3 Passed: Spawn entity with multiple components and archetype checks")
    end

    -- Test 4: Attach component and archetype transition
    do
        local world, cVelocity, cPart, _ = newWorldAndComponents()
        local e = world:spawn(cVelocity)

        local oldMask = world.entities_masks[e]
        local oldArchetypeCount = countArchetypes(world)

        world:attach(e, cPart, Instance.new("Part"))

        local newMask = world.entities_masks[e]
        assertTrue(bitIsSet(newMask, cVelocity), "Velocity bit should remain set after attach")
        assertTrue(bitIsSet(newMask, cPart), "Part bit should be set after attach")
        assertTrue(buffer.tostring(newMask) ~= buffer.tostring(oldMask), "Mask should change after attach")

        local archetypeCount = countArchetypes(world)
        assertTrue(archetypeCount >= oldArchetypeCount, "Archetype count should increase or remain same after attach")

        local newArchetype, _ = getArchetypeByMask(world, newMask)
        local oldArchetype, _ = getArchetypeByMask(world, oldMask)

        assertTrue(newArchetype.entity_count == 1, "New archetype should have 1 entity")
        assertTrue(oldArchetype.entity_count == 0, "Old archetype should have 0 entities after transition")

        -- Confirm cache position mappings
        local cachePos = newArchetype.entity_id_to_cache_position[e]
        assertTrue(cachePos ~= nil, "Entity cache position should be set in new archetype")

        print("Test 4 Passed: Attach component with archetype transition checks")
    end

    -- Test 5: Detach component and archetype transition
    do
        local world, cVelocity, cPart, _ = newWorldAndComponents()
        local e = world:spawn(cVelocity, cPart)

        local oldMask = world.entities_masks[e]
        local oldArchetypeCount = countArchetypes(world)

        world:detach(e, cPart)

        local newMask = world.entities_masks[e]
        assertTrue(bitIsSet(newMask, cVelocity), "Velocity bit should remain after detach")
        assertTrue(not bitIsSet(newMask, cPart), "Part bit should be cleared after detach")
        assertTrue(buffer.tostring(newMask) ~= buffer.tostring(oldMask), "Mask should change after detach")

        local archetypeCount = countArchetypes(world)
        assertTrue(archetypeCount >= oldArchetypeCount, "Archetype count should increase or remain same after detach")

        local newArchetype, _ = getArchetypeByMask(world, newMask)
        local oldArchetype, _ = getArchetypeByMask(world, oldMask)

        assertTrue(newArchetype.entity_count == 1, "New archetype should have 1 entity")
        assertTrue(oldArchetype.entity_count == 0, "Old archetype should have 0 entities after transition")

        local cachePos = newArchetype.entity_id_to_cache_position[e]
        assertTrue(cachePos ~= nil, "Entity cache position should be set in new archetype")

        print("Test 5 Passed: Detach component with archetype transition checks")
    end

    -- Test 6: Despawn entity frees ID
    do
        local world, cVelocity, _, _ = newWorldAndComponents()
        local e = world:spawn(cVelocity)
        world:despawn(e)
        local newE = world:spawn(cVelocity)
        assertEquals(e, newE, "Entity IDs should be reused after despawn")

        local archetype = getArchetypeByMask(world, world.entities_masks[newE])
        assertTrue(archetype ~= nil, "Entity should be in a valid archetype after respawn")
        print("Test 6 Passed: Despawn entity frees ID and archetype remains valid")
    end

    -- Test 7: Query matches entities correctly with fresh world
    do
        local world, cVelocity, cPart, _ = newWorldAndComponents()
        local e1 = world:spawn(cVelocity)
        local e2 = world:spawn(cVelocity, cPart)

        local q1 = world:query(cVelocity)
        local found = 0
        q1.view_all(function(count, velocities)
            found = found + count
        end)
        assertEquals(found, 2, "Query for velocity should find exactly 2 entities")

        local q2 = world:query(cVelocity, cPart)
        found = 0
        q2.view_all(function(count2, velocities, parts)
            found += count2
        end)
        assertEquals(found, 1, "Query for velocity + part should find exactly 1 entity")

        print("Test 7 Passed: Query matches entities correctly on fresh world")
    end

    -- Test 8: Attaching already attached component doesn't change mask or archetype
    do
        local world, cVelocity, _, _ = newWorldAndComponents()
        local e = world:spawn(cVelocity)
        local oldMaskStr = buffer.tostring(world.entities_masks[e])
        local oldArchetypeCount = countArchetypes(world)

        world:attach(e, cVelocity, {1, 2, 3})

        local newMaskStr = buffer.tostring(world.entities_masks[e])
        local newArchetypeCount = countArchetypes(world)

        assertEquals(newMaskStr, oldMaskStr, "Mask should be unchanged when attaching existing component")
        assertEquals(newArchetypeCount, oldArchetypeCount, "Archetype count should be unchanged")

        print("Test 8 Passed: Attaching existing component does not change mask or archetypes")
    end

    -- Test 9: Detaching non-existent component is no-op (mask and archetype unchanged)
    do
        local world, cVelocity, cPart, _ = newWorldAndComponents()
        local e = world:spawn(cVelocity)
        local oldMaskStr = buffer.tostring(world.entities_masks[e])
        local oldArchetypeCount = countArchetypes(world)

        world:detach(e, cPart)

        local newMaskStr = buffer.tostring(world.entities_masks[e])
        local newArchetypeCount = countArchetypes(world)

        assertEquals(newMaskStr, oldMaskStr, "Mask should be unchanged when detaching non-existent component")
        assertEquals(newArchetypeCount, oldArchetypeCount, "Archetype count should be unchanged")

        print("Test 9 Passed: Detaching non-existent component is no-op")
    end

    -- Test 10: Detaching last component leaves entity in empty archetype
    do
        local world, cVelocity, _, _ = newWorldAndComponents()
        local e = world:spawn(cVelocity)
        world:detach(e, cVelocity)

        local mask = world.entities_masks[e]
        for i = 0, ECS.utils.chunks_zeroed do
            assertEquals(buffer.readu32(mask, i), 0, "Mask should be empty after detaching last component")
        end

        local archetypeCount = countArchetypes(world)
        assertEquals(archetypeCount, 2, "Two archetypes expected: empty + no-component archetype")

        local emptyArchetype, _ = getArchetypeByMask(world, mask)
        assertEquals(emptyArchetype.entity_count, 1, "Empty archetype should have 1 entity after last detach")

        print("Test 10 Passed: Detaching last component leaves entity in empty archetype")
    end

        -- Test 11: Spawn entity with duplicate components (should ignore duplicates safely)
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity, cPart, cVelocity, cPart)
    local mask = world.entities_masks[e]
    assertTrue(bitIsSet(mask, cVelocity), "Velocity bit should be set")
    assertTrue(bitIsSet(mask, cPart), "Part bit should be set")
    local archetypeCount = countArchetypes(world)
    assertEquals(archetypeCount, 1, "Duplicate components should not create extra archetypes")
    print("Test 11 Passed: Spawn entity with duplicate components handled safely")
end

-- Test 12: Repeated attach and detach on same entity
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    for i = 1, 3 do
        world:attach(e, cPart, Instance.new("Part"))
        local mask = world.entities_masks[e]
        assertTrue(bitIsSet(mask, cPart), "Part bit should be set after attach")
        world:detach(e, cPart)
        mask = world.entities_masks[e]
        assertTrue(not bitIsSet(mask, cPart), "Part bit should be cleared after detach")
    end
    print("Test 12 Passed: Multiple attach/detach cycles are consistent")
end

-- Test 13: Attach component to despawned entity (should error or ignore gracefully)
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    world:despawn(e)
    local success, err = pcall(function()
        world:attach(e, cPart, Instance.new("Part"))
    end)
    assertTrue(not success, "Attaching to despawned entity should fail or error")
    print("Test 13 Passed: Attach to despawned entity is prevented")
end

-- Test 14: Attach component with table default clones independently
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    world:attach(e, cPart, Instance.new("Part"))
    local archetype, _ = getArchetypeByMask(world, world.entities_masks[e])
    local cacheIndex = archetype.component_id_to_cache_index[cPart]
    local partCache = archetype.cache[cacheIndex]
    local instance1 = partCache[archetype.entity_id_to_cache_position[e]]
    instance1.Name = "ModifiedPart"

    local e2 = world:spawn(cVelocity)
    world:attach(e2, cPart, Instance.new("Part"))
    local archetype2, _ = getArchetypeByMask(world, world.entities_masks[e2])
    local partCache2 = archetype2.cache[cacheIndex]
    local instance2 = partCache2[archetype2.entity_id_to_cache_position[e2]]

    assertTrue(instance2.Name ~= "ModifiedPart", "Attached component instances should be unique clones")
    print("Test 14 Passed: Attach component clones defaults independently")
end

-- Test 15: Query with no components returns all entities (or none consistently)
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e1 = world:spawn()
    local e2 = world:spawn(cVelocity)
    local q = world:query()
    local count = 0
    q.view_all(function(cnt, ...)
        count += cnt
    end)
    assertTrue(count == 0 or count == 2, "Query with no components should return consistent results")
    print("Test 15 Passed: Query with no components behaves consistently")
end

-- Test 16: Spawn many entities and query rare component
do
    local world, cVelocity, cPart, cGravity = newWorldAndComponents()
    local rareCount = 0
    for i = 1, 1000 do
        if i % 100 == 0 then
            world:spawn(cVelocity, cPart, cGravity)
            rareCount += 1
        else
            world:spawn(cVelocity)
        end
    end
    local q = world:query(cVelocity, cPart, cGravity)
    local found = 0
    q.view_all(function(cnt, ...)
        found += cnt
    end)
    assertEquals(found, rareCount, "Query should find exactly the rare component entities")
    print("Test 16 Passed: Query with rare component matches expected count")
end

-- Test 17: Rapid attach/detach on many entities to check for cache leaks
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local entities = {}
    for i = 1, 100 do
        entities[i] = world:spawn(cVelocity)
    end
    for i = 1, 100 do
        world:attach(entities[i], cPart, Instance.new("Part"))
    end
    for i = 1, 100 do
        world:detach(entities[i], cPart)
    end
    local archetypeCount = countArchetypes(world)
    local mask = world.entities_masks[entities[1]]
    local archetype, _ = getArchetypeByMask(world, mask)
    assertEquals(archetype.entity_count, 100, "All entities remain in original archetype after attach/detach cycles")
    assertEquals(archetypeCount >= 2, true, "Archetype count should reflect attach/detach transitions")
    print("Test 17 Passed: Mass attach/detach cycles stable")
end

-- Test 18: Spawn with all components, detach all in random order, then reattach
do
    local world, cVelocity, cPart, cGravity = newWorldAndComponents()
    local e = world:spawn(cVelocity, cPart, cGravity)

    local toDetach = {cPart, cGravity, cVelocity}
    for _, comp in ipairs(toDetach) do
        world:detach(e, comp)
    end

    local mask = world.entities_masks[e]
    for i = 0, ECS.utils.chunks_zeroed do
        assertEquals(buffer.readu32(mask, i), 0, "Mask should be empty after detaching all components")
    end

    for _, comp in ipairs(toDetach) do
        world:attach(e, comp, comp == cPart and Instance.new("Part") or {0})
    end

    local mask2 = world.entities_masks[e]
    for _, comp in ipairs(toDetach) do
        assertTrue(bitIsSet(mask2, comp), "Component bit should be set after reattach")
    end

    print("Test 18 Passed: Detach all and reattach components correctly transitions archetypes")
end

-- Test 19: Entity cache positions are stable after multiple transitions
do
    local world, cVelocity, cPart, cGravity = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    local positions = {}

    for i = 1, 5 do
        world:attach(e, cPart, Instance.new("Part"))
        local archetype = getArchetypeByMask(world, world.entities_masks[e])
        positions[#positions+1] = archetype.entity_id_to_cache_position[e]
        world:attach(e, cGravity, {0})
        local archetype2 = getArchetypeByMask(world, world.entities_masks[e])
        positions[#positions+1] = archetype2.entity_id_to_cache_position[e]
        world:detach(e, cPart)
        local archetype3 = getArchetypeByMask(world, world.entities_masks[e])
        positions[#positions+1] = archetype3.entity_id_to_cache_position[e]
        world:detach(e, cGravity)
        local archetype4 = getArchetypeByMask(world, world.entities_masks[e])
        positions[#positions+1] = archetype4.entity_id_to_cache_position[e]
    end

    for i = 1, #positions do
        assertTrue(positions[i] > 0, "Cache positions should always be valid and > 0")
    end
    print("Test 19 Passed: Cache positions remain valid after repeated transitions")
end

-- Test 20: Attaching component with identical value does not cause archetype transition
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    world:attach(e, cPart, Instance.new("Part"))
    local maskBefore = buffer.tostring(world.entities_masks[e])
    world:attach(e, cPart, Instance.new("Part")) -- attach again with different instance (should transition or not?)
    local maskAfter = buffer.tostring(world.entities_masks[e])
    assertEquals(maskAfter, maskBefore, "Re-attaching same component type should not cause archetype change")
    print("Test 20 Passed: Re-attaching same component type with different instance does not change archetype")
end

-- Test 21: Spawn and despawn in large batches to ensure no ID or cache leaks
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local ids = {}
    for i = 1, 500 do
        ids[i] = world:spawn(cVelocity)
    end
    for i = 1, 500 do
        world:despawn(ids[i])
    end
    for i = 1, 500 do
        local e = world:spawn(cVelocity)
        assertTrue(e <= 500, "Entity IDs should be reused efficiently in bulk")
    end
    print("Test 21 Passed: Bulk spawn/despawn cycles do not leak IDs")
end

-- Test 22: Query caching returns same results across multiple calls without world mutation
do
    local world, cVelocity, _, _ = newWorldAndComponents()
    world:spawn(cVelocity)
    world:spawn(cVelocity)
    local q = world:query(cVelocity)
    local firstCount = 0
    q.view_all(function(cnt) firstCount += cnt end)
    local secondCount = 0
    q.view_all(function(cnt) secondCount += cnt end)
    assertEquals(firstCount, secondCount, "Query results should be consistent without mutation")
    print("Test 22 Passed: Query cache returns consistent results")
end

-- Test 23: Ensure queries are isolated between worlds
do
    local world1, cVelocity1, _, _ = newWorldAndComponents()
    local world2, cVelocity2, _, _ = newWorldAndComponents()
    world1:spawn(cVelocity1)
    world2:spawn(cVelocity2)
    local q1 = world1:query(cVelocity1)
    local q2 = world2:query(cVelocity2)
    local count1 = 0
    q1.view_all(function(cnt) count1 += cnt end)
    local count2 = 0
    q2.view_all(function(cnt) count2 += cnt end)
    assertEquals(count1, 1, "World1 query should not see World2 entities")
    assertEquals(count2, 1, "World2 query should not see World1 entities")
    print("Test 23 Passed: Queries are world-scoped")
end

-- Test 24: Entities with identical masks share archetype
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e1 = world:spawn(cVelocity, cPart)
    local e2 = world:spawn(cVelocity, cPart)
    local a1 = getArchetypeByMask(world, world.entities_masks[e1])
    local a2 = getArchetypeByMask(world, world.entities_masks[e2])
    assertTrue(a1 == a2, "Entities with identical masks must share archetype")
    assertEquals(a1.entity_count, 2, "Archetype should track correct entity count")
    print("Test 24 Passed: Entities with identical masks share archetype")
end

-- Test 25: Component default values are deeply cloned for tables
do
    local world, _, _, _ = newWorldAndComponents()
    local cCustom = world:component({ nested = { val = 1 } })
    local e1 = world:spawn(cCustom)
    local e2 = world:spawn(cCustom)
    local a1 = getArchetypeByMask(world, world.entities_masks[e1])
    local cacheIndex = a1.component_id_to_cache_index[cCustom]
    local c1 = a1.cache[cacheIndex][a1.entity_id_to_cache_position[e1]]
    c1.nested.val = 999
    local c2 = a1.cache[cacheIndex][a1.entity_id_to_cache_position[e2]]
    assertTrue(c2.nested.val ~= 999, "Table default should be deep cloned")
    print("Test 25 Passed: Component table defaults are deep cloned")
end

-- Test 26: Query with components not present in any entity returns zero
do
    local world, cVelocity, _, _ = newWorldAndComponents()
    local cUnused = world:component(123)
    world:spawn(cVelocity)
    local q = world:query(cUnused)
    local found = 0
    q.view_all(function(cnt) found += cnt end)
    assertEquals(found, 0, "Unused component queries should return zero entities")
    print("Test 26 Passed: Unused component query returns zero results")
end

-- Test 27: Mask buffers with identical bits but different instances still match archetype
do
    local world, cVelocity, _, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    local maskCopy = buffer.create(buffer.len(world.entities_masks[e]))
    buffer.copy(maskCopy, 0, world.entities_masks[e], 0, buffer.len(maskCopy))
    local archetype, _ = getArchetypeByMask(world, maskCopy)
    assertTrue(archetype ~= nil, "Archetype lookup should work with identical mask copy")
    print("Test 27 Passed: Mask buffer copies match archetype")
end

-- Test 28: Ensure despawn removes entity from queries immediately
do
    local world, cVelocity, _, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    local q = world:query(cVelocity)
    world:despawn(e)
    local found = 0
    q.view_all(function(cnt) found += cnt end)
    assertEquals(found, 0, "Despawned entity should not be in queries")
    print("Test 28 Passed: Despawn removes entity from query results")
end

-- Test 29: Large number of archetypes are handled without error
do
    local world, _, _, _ = newWorldAndComponents()
    local components = {}
    for i = 1, 20 do
        components[i] = world:component(false)
    end
    for i = 1, #components do
        local subset = {}
        for j = 1, i do
            subset[j] = components[j]
        end
        world:spawn(table.unpack(subset))
    end
    assertTrue(countArchetypes(world) >= 20, "Should handle many archetypes without failure")
    print("Test 29 Passed: Large archetype counts handled correctly")
end

-- Test 30: Attaching then detaching same component in same frame reverts to original archetype
do
    local world, cVelocity, cPart, _ = newWorldAndComponents()
    local e = world:spawn(cVelocity)
    local maskBefore = buffer.tostring(world.entities_masks[e])
    world:attach(e, cPart, Instance.new("Part"))
    world:detach(e, cPart)
    local maskAfter = buffer.tostring(world.entities_masks[e])
    assertEquals(maskAfter, maskBefore, "Mask should revert after attach+detach in same frame")
    print("Test 30 Passed: Attach+detach in same frame restores original mask")
end

    print("All ECS unit tests completed successfully.")
end

-- Run all tests
local success, err = pcall(runTests)
if not success then
    warn("ECS Unit Tests failed:", err)
else
    print("ECS Unit Tests passed without errors.")
end

return 0
