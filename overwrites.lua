local AHCC = LibStub("AceAddon-3.0"):GetAddon("AHCC")
local L, _ = AHCC:GetLibs()


local MaxNumAuctionHouseSortTypes = 2

local function AddSortType(searchContext, newSortType)
    if not g_auctionHouseSortsBySearchContext[searchContext] then
        g_auctionHouseSortsBySearchContext[searchContext] = {};
    end

    local sorts = g_auctionHouseSortsBySearchContext[searchContext];
    for i, sortType in ipairs(sorts) do
        if sortType.sortOrder == newSortType.sortOrder then
            if (i == 1) and sortType.reverseSort == newSortType.reverseSort then
                newSortType.reverseSort = not newSortType.reverseSort;
            end

            table.remove(sorts, i);
            break;
        end
    end

    table.insert(sorts, 1, newSortType);

    if #sorts > MaxNumAuctionHouseSortTypes then
        sorts[#sorts] = nil;
    end
end





--return to BrowseResultsFrame on category select 
local AuctionHouseCategoriesListMixin_OnFilterClicked =  AuctionHouseFrame.CategoriesList.OnFilterClicked
function AuctionHouseFrame.CategoriesList:OnFilterClicked(button, buttonName)
    local displaymode =  _.last(AuctionHouseFrame:GetDisplayMode())

    if displaymode ~= "BrowseResultsFrame" then 
        local check = false
        local selectedCategoryIndex, selectedSubCategoryIndex, selectedSubSubCategoryIndex = self:GetSelectedCategory();
        if ( button.type == "category" ) then
            if ( selectedCategoryIndex ~= button.categoryIndex ) then
                check = true
            end
        elseif ( button.type == "subCategory" ) then
            if ( selectedSubCategoryIndex ~= button.subCategoryIndex ) then
                check = true
            end
        elseif ( button.type ~= "subSubCategory" ) then
            if ( selectedSubSubCategoryIndex == button.subSubCategoryIndex ) then
                check = true
            end
        end

        if AHCC.isInCustomCategory then
            AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy);
            if check then 
                AuctionHouseCategoriesListMixin_OnFilterClicked(self, button, buttonName)
            end
        else
            AuctionHouseCategoriesListMixin_OnFilterClicked(self, button, buttonName)
            AuctionHouseFrame.SearchBar:StartSearch()

        end
    else
        AuctionHouseCategoriesListMixin_OnFilterClicked(self, button, buttonName)
    end
end



-- overwrites
hooksecurefunc("AuctionFrameFilters_UpdateCategories", function(categoriesList, forceSelectionIntoView)
    local cdata = categoriesList:GetCategoryData()

    if AHCC.isInCustomCategory and ( cdata == nil or not cdata:HasFlag("AHCC")) then
        AHCC:Reset()
    end

    if cdata and cdata:HasFlag("AHCC") then
        AHCC.Nav = cdata.AHCC_NAV
        AHCC.isInCustomCategory = true
        AHCCQualitySelectFrame:Show()
        AHCCReplicateButton:check()
        AuctionHouseFrame.SearchBar.FilterButton:Hide()
        -- prevent double execution
        if not forceSelectionIntoView then 
            AuctionHouseFrame.BrowseResultsFrame:Hide()
            AHCCBrowseResultsFrame:Show()
            AHCC:performSearch()
        end
    else
        AHCC.isInCustomCategory = false
        AHCCQualitySelectFrame:Hide()
        AHCCReplicateButton:Hide()
        AHCCBrowseResultsFrame:Hide()
        AuctionHouseFrame.SearchBar.FilterButton:Show()

        if cdata and cdata:HasFlag("WOW_TOKEN_FLAG") then return end
        AuctionHouseFrame.BrowseResultsFrame:Show()
    end
end)



AuctionHouseFrame.CommoditiesBuyFrame.BackButton:HookScript("OnClick" , function()
    if AHCC.isInCustomCategory then
        AuctionHouseFrame.BrowseResultsFrame:Hide()
        AHCCBrowseResultsFrame:Show()
    end
end)


-- overwrites
local AuctionHouseSearchBarMixin_StartSearch = AuctionHouseFrame.SearchBar.StartSearch
function AuctionHouseFrame.SearchBar:StartSearch()
    if AHCC.isInCustomCategory then
        AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy);
        AHCC:performSearch()
    else
        AuctionHouseSearchBarMixin_StartSearch(self)
    end
end

g_auctionHouseSortsBySearchContext[300] = g_auctionHouseSortsBySearchContext[300] or {{ sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false }}

local AuctionHouseUtil_ConvertCategoryToSearchContext = AuctionHouseUtil.ConvertCategoryToSearchContext
function AuctionHouseUtil.ConvertCategoryToSearchContext(selectedCategoryIndex)
    if selectedCategoryIndex then 
        if AuctionCategories[selectedCategoryIndex] then 
            return 300
        end
    end
    return AuctionHouseUtil_ConvertCategoryToSearchContext(selectedCategoryIndex)
end



local AuctionHouseFrame_SetSortOrder = AuctionHouseFrame.SetSortOrder
function AuctionHouseFrame:SetSortOrder(searchContext, sortOrder)
    if AHCC.isInCustomCategory then 
        searchContext = AuctionHouseFrame:GetCategorySearchContext();
        local sortType = { sortOrder = sortOrder, reverseSort = false };
        AddSortType(searchContext, sortType);
        AHCC:Sort(sortOrder)
    else -- blizzard org func
        AuctionHouseFrame_SetSortOrder(self, searchContext, sortOrder)
    end
end


-- make sure blizz sortOrder is not broken
local AuctionHouseFrame_SendBrowseQueryInternal = AuctionHouseFrame.SendBrowseQueryInternal
function AuctionHouseFrame:SendBrowseQueryInternal(browseSearchContext, searchString, minLevel, maxLevel, filtersArray)
    if not AHCC.isInCustomCategory then
        g_auctionHouseSortsBySearchContext[browseSearchContext] = _.map(g_auctionHouseSortsBySearchContext[browseSearchContext], function(sort) 
            sort.sortOrder = (sort.sortOrder >= 90) and 0 or sort.sortOrder
            return sort
        end)
    end
    AuctionHouseFrame_SendBrowseQueryInternal(self, browseSearchContext, searchString, minLevel, maxLevel, filtersArray)
end