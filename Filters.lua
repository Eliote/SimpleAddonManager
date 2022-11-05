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

local function GetOrCreateAddonTableWithFilter(
		pool,
		key,
		filteredCache,
		createChildren,
		filterLower,
		inCategoriesFunc,
		addUnknownDep,
		exposeBlizzardDep
)
	local node = filteredCache[key]
	if (node) then
		return nil
	end

	node = pool[key]
	if (node) then
		return node
	end

	if (pool[key] == nil) then
		local _, title, _, _, _, security = GetAddOnInfo(key)
		local exposeAddon = (exposeBlizzardDep) or security ~= "SECURE"
		if (exposeAddon and AddonMatchFilter(key, filterLower, inCategoriesFunc)) then
			node = {
				dep = {},
				children = {},
				exists = frame:IsAddonInstalled(key),
				index = key,
				key = strtrim(key),
				name = key:lower(),
				smartName = key:gsub(".-([%w].*)", "%1"):gsub("[_-]", " "):lower(),
				title = (title or key):lower()
			}
			pool[key] = node
			if (createChildren and node.exists) then
				local deps = { GetAddOnDependencies(key) }
				for _, depName in ipairs(deps) do
					depName = strtrim(depName)
					if (addUnknownDep or frame:IsAddonInstalled(depName)) then
						local depNode = GetOrCreateAddonTableWithFilter(
								pool,
								depName,
								filteredCache,
								createChildren,
								filterLower,
								inCategoriesFunc,
								addUnknownDep,
								exposeBlizzardDep
						)
						if (depNode) then
							depNode.children[key] = node
						end
					end
				end
			end
			return node
		else
			filteredCache[key] = true
			return nil
		end
	end
end

local rootKey = " *:/root/:* " -- Just add some invalid characters for folders name, to avoid collision with real addons

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

local function CreateSortedAddonsTreeAsList(tree, out, dept, parentKey)
	local list = {}
	for _, v in pairs(tree) do
		local newTable = {}
		MergeTable(newTable, v)
		newTable.dept = dept
		newTable.parentKey = parentKey
		table.insert(list, newTable)
	end

	SortAddons(list)

	for _, v in ipairs(list) do
		table.insert(out, v)
		if (not frame:IsAddonCollapsed(v.key, parentKey)) then
			CreateSortedAddonsTreeAsList(v.children, out, dept + 1, v.key)
		end
	end
end

local function CreateAddonListAsTable(filterLower, inCategoriesFunc)
	local showSecureAddons = frame:GetDb().config.showSecureAddons
	local nodesPool = {}
	local filteredCache = {}
	local count = GetNumAddOns()
	for addonIndex = 1, count do
		local name = GetAddOnInfo(addonIndex)
		GetOrCreateAddonTableWithFilter(
				nodesPool,
				name,
				filteredCache,
				true,
				filterLower,
				inCategoriesFunc,
				true,
				showSecureAddons
		)
	end

	local function removeFromParents(node, k)
		if (node) then
			if (node.isRemovingFromParents) then
				return true
			end
			node.isRemovingFromParents = true
			node.children[k] = nil
			local cycleFound = false
			if (node.parent) then
				cycleFound = removeFromParents(node.parent, k)
				if (cycleFound) then
					node.warning = C.red:WrapText(L["Circular dependency detected!"])
				end
			end
			node.isRemovingFromParents = false
			return cycleFound
		end
	end

	local function visit(node)
		if (node.isVisiting) then
			-- cycle detected!
			return
		end
		node.isVisiting = true
		for k, child in pairs(node.children) do
			child.parent = node
			removeFromParents(node.parent, k)
			visit(child)
		end
		node.isVisiting = false
	end

	local root = {
		key = "root",
		children = nodesPool
	}

	visit(root)

	local addonsList = {}
	CreateSortedAddonsTreeAsList(root.children, addonsList, 0)

	return addonsList
end

local function CreateAddonListAsList(filterLower, inCategoriesFunc)
	local addons = {}
	local showSecureAddons = frame:GetDb().config.showSecureAddons
	local nodesPool = {}
	local filteredCache = {}
	local count = GetNumAddOns()
	for addonIndex = 1, count do
		local name = GetAddOnInfo(addonIndex)
		local addon = GetOrCreateAddonTableWithFilter(
				nodesPool,
				name,
				filteredCache,
				false,
				filterLower,
				inCategoriesFunc,
				false,
				showSecureAddons
		)
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
