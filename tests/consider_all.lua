-- Run from the repository root with lua5.1 tests/consider_all.lua.
local function noop() end
max = math.max
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 2, 1
NUM_BAG_SLOTS, NUM_REAGENTBAG_SLOTS = 0, 0
LE_ITEM_CLASS_CONSUMABLE = 0
Enum = {ItemBind={Quest=4}}
DEFAULT = 'Default'
table.wipe = function(t) for key in pairs(t) do t[key] = nil end end
function UnitLevel() return 30 end
local items = {
    {id=1001,quality=0,value=2,count=2},
    {id=1002,quality=2,value=20,count=1},
    {id=1003,quality=1,value=0,count=1,quest=true},
    {id=1004,quality=1,value=0,count=1},
    {id=1005,quality=1,value=10,count=1,bound=true},
    {id=36812,quality=0,value=1,count=1}, -- built-in protected item
    {id=1007,quality=1,value=10,count=1,unknown=true},
}
local byID = {}
for _, item in ipairs(items) do byID[item.id] = item end
local function itemFor(value)
    return byID[tonumber(value) or tonumber(tostring(value):match('item:(%d+)'))]
end
C_Item = {}
function C_Item.GetItemInfo(value)
    local item = itemFor(value)
    if not item or item.unknown then return end
    return 'Item', 'item:'..item.id, item.quality, 10, 1, '', '', 20, '', '', item.value, 1, 1, item.quest and 4 or 0
end
function C_Item.IsBound(location) return items[location.slot].bound or false end
ItemLocation = {CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
C_Container = {}
function C_Container.GetContainerNumSlots() return #items end
function C_Container.GetContainerItemLink(_, slot) return 'item:'..items[slot].id end
function C_Container.GetContainerItemInfo(_, slot)
    local item = items[slot]
    return {stackCount=item.count,quality=item.quality,hyperlink='item:'..item.id,hasNoValue=item.value==0}
end
C_Container.PickupContainerItem = function() error('scan must not pick up an item') end
C_Container.UseContainerItem = function() error('scan must not sell an item') end
local core = {RegisterBucketEvent=noop,RegisterEvent=noop}
local libraries = {
    ['AceAddon-3.0']={NewAddon=function() return core end,GetAddon=function() return core end},
    ['CallbackHandler-1.0']={New=function() return {Fire=noop} end},
    ['AceDB-3.0']={New=function(_,_,defaults) return defaults end},
}
function LibStub(name) return assert(libraries[name],name) end
assert(loadfile('addon.lua'))('DropTheCheapestThing',{})
core:OnInitialize()
local profile = core.db.profile
local checked = 0
local function check(value, message) assert(value,message); checked=checked+1 end
check(profile.consider_all==false,'inclusive mode must be opt-in')
core:BAG_UPDATE_DELAYED()
check(#core.drop_slots==1 and core.drop_slots[1]==1,'default drop filter remains grey-only')
check(#core.sell_slots==1 and core.sell_slots[1]==1,'default sell filter remains grey-only')
profile.consider_all=true
core:BAG_UPDATE_DELAYED()
check(#core.drop_slots==5,'inclusive mode includes known nonjunk and valueless items')
check(core.drop_slots[1]==3 and core.drop_slots[2]==4,'zero-value candidates sort first')
check(#core.sell_slots==1 and core.sell_slots[1]==1,'inclusive mode does not broaden automatic selling')
check(not core.slot_junk[2] and not core.slot_junk[3] and not core.slot_junk[4] and not core.slot_junk[5],
    'inclusive candidates remain separate from bag junk markers')
check(not core.slot_contents[6],'built-in protected items remain excluded')
check(not core.slot_contents[7],'unloaded item data is excluded')
profile.never_consider[1003]=true
profile.always_consider[1003]=true
core:BAG_UPDATE_DELAYED()
check(not core.slot_contents[3],'Never Consider wins even over Always Consider')
profile.consider_all=false
profile.always_consider[1004]=true
core:BAG_UPDATE_DELAYED()
check(core.slot_junk[4] and #core.drop_slots==2,'Always Consider still includes a valueless item')
profile.always_consider[1004]=nil
profile.sell_threshold=2
core:BAG_UPDATE_DELAYED()
check(#core.drop_slots==1 and #core.sell_slots==2,'drop and sell quality thresholds remain independent')
profile.consider_all=true
core:BAG_UPDATE_DELAYED()
local junkPlugin
function CreateFrame() return {SetScript=noop,RegisterEvent=noop} end
C_AddOns = {GetAddOnMetadata=function() return 'DropTheCheapestThing' end,
    IsAddOnLoaded=function(name) return name=='Baganator' end}
Baganator = {API={RegisterJunkPlugin=function(_,_,fn) junkPlugin=fn end}}
core.RegisterCallback=noop
assert(loadfile('integration.lua'))('DropTheCheapestThing',{})
check(junkPlugin(0,1)==true,'Baganator still marks ordinary junk')
check(junkPlugin(0,4)==false,'Baganator does not mark an inclusive-only candidate as junk')
profile.mark_in_bags=false
check(junkPlugin(0,1)==false,'bag marking switch still works')
print('consider_all: '..checked..' behavior checks passed')
