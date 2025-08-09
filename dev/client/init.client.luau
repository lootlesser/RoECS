--!strict
--!native
--!optimize 2

local ECS = require(game.ReplicatedStorage.RoECS)
local world = ECS.world("benchmark", true)

local HttpService = game:GetService("HttpService")

local function ms(delta: number)
	return math.floor(delta * 1000 * 1000) / 1000 -- 3 decimal places in ms
end

-- ========== CONFIG ==========
local NUM_COMPONENTS = 256
local NUM_ARCHETYPES = 100
local NUM_QUERY_ARCHES = 20
local ENTITIES_PER_ARCH = 500 -- n spread across 20 archetypes → total = n * 20
-- ============================

print("=== RoECS Benchmark ===")

-- 1️⃣ Benchmark: Create 256 components
local t0 = os.clock()
local components = table.create(NUM_COMPONENTS)
for i = 1, NUM_COMPONENTS do
	components[i] = world:component("C"..i)
end
local t1 = os.clock()
print("Created "..NUM_COMPONENTS.." components in", ms(t1 - t0), "ms")

-- 2️⃣ Benchmark: Create 100 random archetypes
-- We'll do this by spawning one entity for each archetype with a unique random set of components
local function random_component_set(count)
	local chosen = {}
	local picked = {}
	while #chosen < count do
		local comp = components[math.random(1, NUM_COMPONENTS)]
		if not picked[comp] then
			picked[comp] = true
			table.insert(chosen, comp)
		end
	end
	return chosen
end

local t2 = os.clock()
local archetype_entities = {}
for i = 1, NUM_ARCHETYPES do
	local comps = random_component_set(math.random(1, 8))
	local entity = world:spawn(table.unpack(comps))
	archetype_entities[i] = entity
end
local t3 = os.clock()
print("Created "..NUM_ARCHETYPES.." archetypes in", ms(t3 - t2), "ms")

-- 3️⃣ Benchmark: Create a query that matches exactly 20 archetypes
-- Pick a set of components that we know will match 20 archetypes
-- We'll ensure by spawning those archetypes now
local query_comps = { components[1], components[2] } -- required for query

-- Create exactly 20 archetypes that match {C1, C2}
for i = 1, NUM_QUERY_ARCHES do
	local extra = {}
	if math.random() < 0.5 then
		table.insert(extra, components[3])
	end
	table.insert(extra, components[math.random(4, NUM_COMPONENTS)])
	world:spawn(query_comps[1], query_comps[2], table.unpack(extra))
end

local t4 = os.clock()
local query = world:query(query_comps[1], query_comps[2])
local t5 = os.clock()
print("Created query with "..NUM_QUERY_ARCHES.." matching archetypes in", ms(t5 - t4), "ms")

-- 4️⃣ Benchmark: Iterate query with n entities spread across 20 archetypes
-- We'll ensure entities exist across these archetypes
for i = 1, NUM_QUERY_ARCHES do
	for _ = 1, ENTITIES_PER_ARCH - 1 do
		world:spawn(query_comps[1], query_comps[2], components[math.random(4, NUM_COMPONENTS)])
	end
end

local t6 = os.clock()
query.view_all(function(count, c1, c2)
	for i = 1, count do
		local _ = c1[i]
		local _2 = c2[i]
	end
end)
local t7 = os.clock()
print("Iterated query over "..(NUM_QUERY_ARCHES * ENTITIES_PER_ARCH).." entities in", ms(t7 - t6), "ms")

print("=== Benchmark Done ===")
