local _, T = ...
local L = T.L
local C = T.Color

--- @type SimpleAddonManager
local frame = T.AddonFrame
local module = frame:RegisterModule("Filter")

local function AddonsInCategoriesFunc(categories)
	if categories == nil or next(categories) == nil then
		return function()
			return true
		end
	end
	local m = {}
	local fixedCategories = {}
	for categoryName, _ in pairs(categories) do
		local userTable, tocTable, fixedTable = frame:GetCategoryTable(categoryName)
		if (userTable) then
			for name, _ in pairs(userTable.addons) do
				m[name] = true
			end
		end
		if (tocTable) then
			for name, _ in pairs(tocTable.addons) do
				m[name] = true
			end
		end
		if (fixedTable) then
			fixedCategories[categoryName] = fixedTable.addons
		end
	end

	return function(name)
		if (m[name]) then
			return true
		end
		for _, func in pairs(fixedCategories) do
			if (func(name)) then
				return true
			end
		end
	end
end

local sortingFunctionMap = {
	["name"] = function(a, b)
		return a.name < b.name
	end,
	["title"] = function(a, b)
		return a.title < b.title
	end,
	["smart"] = function(a, b)
		return a.smartName < b.smartName
	end
}

local function SortAddons(list)
	local db = frame:GetDb()
	local sortFunc = sortingFunctionMap[db.config.sorting]
	if (sortFunc) then
		table.sort(list, sortFunc)
	end
end

local function AddonMatchFilter(addonIndex, filterLower, inCategoriesFunc)
	local name, title = GetAddOnInfo(addonIndex)
	if (not inCategoriesFunc(name)) then
		return false
	end

	local searchBy = frame:GetDb().config.searchBy
	if (searchBy.name and name:lower():find(filterLower, 0, true)) then
		return true
	end
	if (searchBy.title and title and title:lower():find(filterLower, 0, true)) then
		return true
	end
	if (searchBy.author) then
		local author = GetAddOnMetadata(addonIndex, "Author")
		if (author and author:lower():find(filterLower, 0, true)) then
			return true
		end
	end
end

local function GetOrCreateAddonTableWithFilter(pool, addonIndex, filterLower, inCategoriesFunc, addUnknownDep, exposeBlizzardDep)
	local name, title, _, _, _, security = GetAddOnInfo(addonIndex)
	if (pool[name] == nil) then
		local exposeAddon = (exposeBlizzardDep) or security ~= "SECURE"
		if (exposeAddon and AddonMatchFilter(addonIndex, filterLower, inCategoriesFunc)) then
			pool[name] = {
				dep = {},
				children = {},
				exists = frame:IsAddonInstalled(addonIndex),
				index = addonIndex,
				key = strtrim(name),
				name = name:lower(),
				smartName = name:gsub(".-([%w].*)", "%1"):gsub("[_-]", " "):lower(),
				title = (title or name):lower()
			}
			local deps = { GetAddOnDependencies(addonIndex) }
			if (#deps > 0) then
				for _, depName in ipairs(deps) do
					depName = strtrim(depName)
					if (addUnknownDep or frame:IsAddonInstalled(depName)) then
						local addon = GetOrCreateAddonTableWithFilter(pool, depName, filterLower, inCategoriesFunc, addUnknownDep, exposeBlizzardDep)
						if (addon) then
							pool[name].dep[depName] = addon
						end
					end
				end
			end
		else
			-- Add it to the table to avoid filtering the same addon multiple times
			pool[name] = false
		end
	end
	return pool[name]
end

local function InvertTreeInPlace(pool, name, table, parentName, parentTable, cycle)
	cycle = cycle or {}
	if (table.dep and next(table.dep)) then
		for n, t in pairs(table.dep) do
			local lCycle = setmetatable({}, { __index = cycle })
			if (not lCycle[name]) then
				lCycle[name] = table
				InvertTreeInPlace(pool, n, t, name, table, lCycle)
			else
				pool[name] = false
				table.warning = C.red:WrapText(L["Circular dependency: "]) .. n .. " <--> " .. name
				lCycle[n].warning = C.red:WrapText(L["Circular dependency: "]) .. name .. " <--> " .. n
			end
		end
	end
	if (parentName and parentTable) then
		table.children[parentName] = parentTable
		parentTable.dep[name] = nil
		if (pool[parentName] == nil) then
			pool[parentName] = true
		elseif (pool[parentName] == false) then
			table.children[parentName] = nil
		end
		return true
	end
end

local rootKey = " *:root:* " -- Just add some invalid characters for folders name, avoiding colliding with real addons

function frame:SetAddonCollapsed(addonKey, parentKey, isCollapsed)
	parentKey = parentKey or rootKey
	local collapsedAddons = frame:GetDb().collapsedAddons
	collapsedAddons[addonKey] = collapsedAddons[addonKey] or { parent = {} }
	collapsedAddons[addonKey].parent[parentKey] = isCollapsed
end

function frame:IsAddonCollapsed(addonKey, parentKey)
	local collapsedAddons = frame:GetDb().collapsedAddons
	return collapsedAddons[addonKey] and collapsedAddons[addonKey].parent[parentKey or rootKey]
end

function frame:ToggleAddonCollapsed(addonKey, parentKey)
	frame:SetAddonCollapsed(addonKey, parentKey, not frame:IsAddonCollapsed(addonKey, parentKey))
end

local function PopulateAddonsTreeFast(tree, addedChildren)
	for n, v in pairs(tree) do
		addedChildren[n] = true
		PopulateAddonsTreeFast(v.children, addedChildren)
	end
end

local function PopulateAndSortAddonsTree(tree, out, dept, parentKey, parentAddedChildren)
	local list = {}
	for _, v in pairs(tree) do
		local newTable = {}
		MergeTable(newTable, v)
		newTable.dept = dept
		newTable.parentKey = parentKey
		table.insert(list, newTable)
	end

	SortAddons(list)

	local addedHere = {}
	local addedChildren = {}
	for _, v in ipairs(list) do
		if (not addedChildren[v.key]) then
			if (out) then
				table.insert(out, v)
				table.insert(addedHere, { i = #out, n = v.key })
			else
				table.insert(addedHere, { n = v.key })
			end
			if (not frame:IsAddonCollapsed(v.key, parentKey)) then
				PopulateAndSortAddonsTree(v.children, out, dept + 1, v.key, addedChildren)
			else
				-- we need to to populate [addedChildren] even if its collapsed
				PopulateAddonsTreeFast(v.children, addedChildren)
			end
		end
		if (parentAddedChildren) then
			parentAddedChildren[v.key] = true
		end
	end

	-- remove duplicated AddOns added to the list before they were added to [addedChildren]
	for i = #addedHere, 1, -1 do
		local t = addedHere[i]
		if (addedChildren[t.n] and t.i) then
			table.remove(out, t.i)
		end
		addedChildren[t.n] = true
	end
end

local function CreateAddonListAsTable(filterLower, inCategoriesFunc)
	local pool = {}
	local addonsTree = {}
	local count = GetNumAddOns()
	local showSecureAddons = frame:GetDb().config.showSecureAddons
	local addedAsChildTable = {}
	for addonIndex = 1, count do
		local addon = GetOrCreateAddonTableWithFilter(pool, addonIndex, filterLower, inCategoriesFunc, true, showSecureAddons)
		-- [GetOrCreateAddonTableWithFilter] returns 'false' if the addon didn't match the filter
		if (addon) then
			InvertTreeInPlace(addedAsChildTable, addon.key, addon)
		end
	end

	for name, v in pairs(pool) do
		if (not addedAsChildTable[name] and v) then
			addonsTree[name] = v
		end
	end

	local addons = {}
	PopulateAndSortAddonsTree(addonsTree, addons, 0)
	return addons
end

local function CreateAddonListAsList(filterLower, inCategoriesFunc)
	local addons = {}
	local pool = {}
	local count = GetNumAddOns()
	local showSecureAddons = frame:GetDb().config.showSecureAddons
	for addonIndex = 1, count do
		local addon = GetOrCreateAddonTableWithFilter(pool, addonIndex, filterLower, inCategoriesFunc, false, showSecureAddons)
		-- [GetOrCreateAddonTableWithFilter] returns 'false' if the addon didn't match the filter
		if (addon) then
			table.insert(addons, addon)
		end
	end
	SortAddons(addons)
	return addons
end

local addons = {}
local function CreateList(filter, categories)
	local inCategoriesFunc = AddonsInCategoriesFunc(categories)
	local filterLower = filter:lower()
	local listStyle = frame:GetDb().config.addonListStyle

	if (listStyle == "tree") then
		addons = CreateAddonListAsTable(filterLower, inCategoriesFunc)
	else
		addons = CreateAddonListAsList(filterLower, inCategoriesFunc)
	end
end

function frame:GetAddonsList()
	return addons
end

function frame:UpdateListFilters()
	--local t = GetTimePreciseSec()
	CreateList(frame.SearchBox:GetText(), frame:SelectedCategories())
	frame.ScrollFrame.update()
	--print(GetTimePreciseSec() - t)
end

function module:OnLoad()
	local db = frame:GetDb()
	frame:CreateDefaultOptions(db, {
		collapsedAddons = {},
		config = {
			sorting = "smart",
			addonListStyle = "list", -- tree, list
			showSecureAddons = false,
			searchBy = { name = true, title = true, author = false }
		}
	})
end
