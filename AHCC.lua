AHCC = LibStub("AceAddon-3.0"):NewAddon("AHCC", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("AHCC")
local _ = LibStub("Lodash"):Get()

function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end


AHCC.isInCustomCategory = false
AHCC.hasStatsColumn = false
AHCC.hasQualityColumn = false
AHCC.nav = {}
AHCC.nav.category = nil
AHCC.nav.subCategory = nil

AHCC.searchResultTable = nil
AHCC.searchButton = nil


function AHCC:OnInitialize()
   -- AHCC:initOptions()
end 

function AHCC:OnEnable()
    AHCC:loadData()
    AHCC:RegisterEvent("ADDON_LOADED", "AddonLoadedEvent")
end


local getResults = function()
    local searchString = AuctionHouseFrame.SearchBar.SearchBox:GetSearchString()
    searchString = string.lower(searchString:gsub("%s+", ""))
    local results =  AHCC.data.dataStore[AHCC.nav.category][AHCC.nav.subCategory] or {}

    if (searchString ~= "") then 
         -- set missing itemname    
        results = _.map(results, function(entry)
            if not entry.name then
                entry.name = GetItemInfo(entry.itemKey.itemID)
            end
            return entry
        end)
        results = _.filter(results, function(filterEntry)
            return filterEntry.name and string.find(string.lower(filterEntry.name), searchString,1, true)
        end)
    end

    return _.filter(results, function(entry)
        return AHCC.Config.ProfessionsQualityActive[entry.quality]
    end)
end

function AHCC:AddFixedWidthColumn(owner, tableBuilder, name, width, key)
    local column = tableBuilder:AddFixedWidthColumn(owner, 0, width, 14, 14, AHCC.Config.sortOrder[key], "AuctionHouseTableCell"..firstToUpper(key).."Template");
    column:GetHeaderFrame():SetText(name);
end


function GetBrowseListLayout(owner, itemList)
	local function LayoutBrowseListTableBuilder(tableBuilder)
		tableBuilder:SetColumnHeaderOverlap(2);
		tableBuilder:SetHeaderContainer(itemList:GetHeaderContainer());

		local nameColumn = tableBuilder:AddFillColumn(owner, 0, 1.0, 14, 14, AHCC.Config.sortOrder.name, "AuctionHouseTableCellItemDisplayTemplate");
		nameColumn:GetHeaderFrame():SetText(AUCTION_HOUSE_BROWSE_HEADER_NAME);

        if AHCC.hasStatsColumn then 
            if AHCC.nav.subCategory == 0 then 
                AHCC:AddFixedWidthColumn(owner, tableBuilder, L["TABLE_HEADER_STAT1"], 120, "stat1")
            end

            AHCC:AddFixedWidthColumn(owner, tableBuilder, L["TABLE_HEADER_STAT2"], 120, "stat2")
        end

        if AHCC.hasQualityColumn then 
            AHCC:AddFixedWidthColumn(owner, tableBuilder, L["TABLE_HEADER_QUALITY"], 84, "quality")
        end
	end

	return LayoutBrowseListTableBuilder;
end

local performSearch = function()
    local AHF = AuctionHouseFrame
    local CL = AuctionHouseFrame.CategoriesList
    local BRF = AuctionHouseFrame.BrowseResultsFrame

    AHCC.searchResultTable = AHCC.isInCustomCategory and getResults() or nil

    if AHCC.searchResultTable then
        BRF:Reset()
        BRF.searchStarted = true;
        BRF.ItemList:SetRefreshCallback(nil)
        BRF.tableBuilderLayoutDirty = true;
        local sortby = AHCC.hasStatsColumn and AHCC.Config.sortOrder.stat2 or AHCC.Config.sortOrder.name
        AHCC:sortResult(BRF, sortby, true)
        BRF.ItemList:SetTableBuilderLayout(GetBrowseListLayout(BRF, BRF.ItemList));
        AHF:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy);
    end
end


function AHCC:performSearch()
    local AHF = AuctionHouseFrame
    local CL = AuctionHouseFrame.CategoriesList
    local BRF = AuctionHouseFrame.BrowseResultsFrame
    performSearch()
    BRF.tableBuilderLayoutDirty = true;
end

function AHCC:Reset()
    local BRF = AuctionHouseFrame.BrowseResultsFrame
    BRF:Reset()
end

function AHCC:AddonLoadedEvent(event, name)
    if name == "Blizzard_AuctionHouseUI" then 

        AuctionHouseFrame.SearchBar.QualityFrame = CreateFrame ("Frame", nil, AuctionHouseFrame.SearchBar, "AHCCQualitySelectFrameTemplate")


        local categoriesTable = {}

        -- add Custon categories 
        _.forEach(AHCC.data.dataCategories, function(categoryEntry, categoryId) 
        
            local category = CreateFromMixins(AuctionCategoryMixin);
            categoriesTable[categoryId] = category
            category.name = categoryEntry.name
            category:SetFlag("AHCC");
            if categoryEntry.showStats then 
                category:SetFlag("AHCC_SHOWSTATS");
            end
            if categoryEntry.hideQuality then 
                category:SetFlag("AHCC_HIDEQUALITY");
            end
            category.AHCC_category = categoryEntry.id;
            category.AHCC_subCategory = 0;
            category.subCategories = {}

            _.forEach(categoryEntry["subCategories"], function(subCategoryEntry, subCategoryId) 
                local subCategory = CreateFromMixins(AuctionCategoryMixin);
                category.subCategories[subCategoryId] = subCategory;
                subCategory.name = subCategoryEntry.name;
                subCategory:SetFlag("AHCC");
                subCategory.AHCC_category = categoryEntry.id;
                subCategory.AHCC_subCategory = subCategoryEntry.id;
                if categoryEntry.showStats then 
                    subCategory:SetFlag("AHCC_SHOWSTATS");
                end
                if subCategoryEntry.hideQuality then 
                    subCategory:SetFlag("AHCC_HIDEQUALITY");
                end
            end)
        end)
       
        AuctionCategories = _.union(categoriesTable, {_.last(AuctionCategories)}, _.initial(AuctionCategories))


        hooksecurefunc("AuctionFrameFilters_UpdateCategories", function(categoriesList, forceSelectionIntoView)
            local cdata = categoriesList:GetCategoryData()
            if cdata and cdata:HasFlag("AHCC") then
                AHCC.nav.category = cdata.AHCC_category
                AHCC.nav.subCategory = cdata.AHCC_subCategory
                AHCC.isInCustomCategory = true
                AuctionHouseFrame.SearchBar.QualityFrame:Show()
                AuctionHouseFrame.SearchBar.FilterButton:Hide()
                AHCC.hasStatsColumn = cdata:HasFlag("AHCC_SHOWSTATS") and true or false
                if cdata:HasFlag("AHCC_HIDEQUALITY") then 
                    AHCC.hasQualityColumn = false
                else
                    AHCC.hasQualityColumn = true
                end
              
                performSearch()
            else
                AHCC.isInCustomCategory = false
                AuctionHouseFrame.SearchBar.QualityFrame:Hide()
                AuctionHouseFrame.SearchBar.FilterButton:Show()
            end
        end)


        -- overwrite the start search function 
        function AuctionHouseFrame.SearchBar:StartSearch()
            if AHCC.isInCustomCategory then
                performSearch()
            else
                local searchString = self.SearchBox:GetSearchString();
                local minLevel, maxLevel = self:GetLevelFilterRange();
                local filtersArray = AuctionHouseFrame.SearchBar.FilterButton:CalculateFiltersArray();
                AuctionHouseFrame:SendBrowseQuery(searchString, minLevel, maxLevel, filtersArray);
            end
        end

        AHCC:initSort()
    end
end