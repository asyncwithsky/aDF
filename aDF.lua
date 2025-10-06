--########### armor and Debuff Frame
--########### By Atreyyo @ Vanillagaming.org

local has_superwow = SetAutoloot and true or false

aDF = CreateFrame('Button', "aDF", UIParent); -- Event Frame
aDF.Options = CreateFrame("Frame",nil,UIParent) -- Options frame

--register events 
aDF:RegisterEvent("ADDON_LOADED")
aDF:RegisterEvent("UNIT_AURA")
aDF:RegisterEvent("PLAYER_TARGET_CHANGED")
aDF:RegisterEvent("UNIT_CASTEVENT")
aDF:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
aDF:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
aDF:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")

function aDF:SendChatMessage(msg,chan)
  if chan and chan ~= "None" and chan ~= "" then
		SendChatMessage(msg,chan)
	end
end

-- tables 
aDF_frames = {} -- we will put all debuff frames in here
aDF_guiframes = {} -- we wil put all gui frames here
gui_Options = gui_Options or {} -- checklist options
gui_Optionsxy = gui_Optionsxy or 1
gui_chantbl = {
	"None",
	"Say",
	"Yell",
	"Party",
	"Raid",
	"Raid_Warning"
 }

local last_target_change_time = GetTime()

-- translation table for debuff check on target

aDFTargetData = {}

aDFSpellConfig = {
    ["Sunder Armor"] = {
        duration = 30,
		name = "Sunder Armor",
		icon = "Interface\\Icons\\Ability_Warrior_Sunder"
    },
	["Armor Shatter"] = {
		duration = 45,
		name = "Annihilator",
		icon = "Interface\\Icons\\INV_Axe_12"
    },
    ["Expose Armor"] = {
        duration = 30,
		name = "Expose Armor",
		icon = "Interface\\Icons\\Ability_Warrior_Riposte"
    },
	["Faerie Fire"] = {
        duration = 40,
		name = "Faerie Fire",
		icon = "Interface\\Icons\\Spell_Nature_FaerieFire"
	},
	["Spell Vulnerability"] = {
		duration = 7,
		name = "Nightfall",
		icon = "Interface\\Icons\\Spell_Holy_ElunesGrace"
	},
	["Flame Buffet"] = {
		duration = 20,
		name = "Flame Buffet",
		icon = "Interface\\Icons\\Spell_Fire_Fireball"
	},
	["Fire Vulnerability"] = {
		duration = 30,
		name = "Scorch",
		icon = "Interface\\Icons\\Spell_Fire_SoulBurn"
	},
	["Curse of Recklessness"] = {
		duration = 120,
		name = "Curse of Recklessness",
		icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength"
	},
	["Curse of the Elements"] = {
		duration = 300,
		name = "Curse of the Elements",
		icon = "Interface\\Icons\\Spell_Shadow_ChillTouch"
	},
	["Curse of Shadow"] = {
		duration = 300,
		name = "Curse of Shadow",
		icon = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde"
	},
	["Shadow Bolt"] = {
		duration = 10,
		name = "Shadow Bolt",
		icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt"
	},
	["Curse of Tongue"] = {
		duration = 30,
		name = "Curse of Tongue",
		icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges"
	},
	["Shadow Weaving"] = {
		duration = 15,
		name = "Shadow Weaving",
		icon = "Interface\\Icons\\Spell_Shadow_BlackPlague"
	},
	["Feast of Hakkar"] = {
		duration = 10,
		name = "Feast of Hakkar",
		icon = "Interface\\Icons\\Spell_Shadow_BloodBoil"
	},
	["Freezing Cold"] = {
		duration = 10,
		name = "Freezing Cold",
		icon = "Interface\\Icons\\Spell_Frost_FrostShock"
	},
	["Holy Sunder"] = {
		duration = 60,
		name = "Holy Sunder",
		icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras"
	},
	["Corrosive Poison"] = {
		duration = 30,
		name = "The Ripper (-60 Armor)",
		icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath"
	},
}


local aDFDebuffAliases = {
    ["Faerie Fire (Feral)"] = "Faerie Fire",
    ["Faerie Fire"] = "Faerie Fire"
}

local aDFOtherPlayerPatterns = {
	"^(%S+)'s (.-) was",
	"^(%S+)'s (.-) missed"
}

local aDFPlayerPatterns = {
	"Your (.-) is parried by .*",
	"Your (.-) was", 
	"Your (.-) missed .*"
}

function aDF:GetTargetData(unit)
	local _, guid = UnitExists(unit)
	if not guid then return nil end
	
	if not UnitIsDead(guid) and aDFTargetData[guid] == nil then
		aDFTargetData[guid] = {
			timers = {},
			casters = {},
			armor = UnitResistance(guid, 0) or 0,
			lastSeen = GetTime()
		}
	end
	
	aDFTargetData[guid].lastSeen = GetTime()
	return aDFTargetData[guid]
end

function aDF:GetDebuffTimer(targetData, debuffName)
    if not targetData or not debuffName then return nil end
    
    local config = aDFSpellConfig[debuffName]
    if not config then return nil end
    
    if not targetData.timers[debuffName] then
        targetData.timers[debuffName] = {
            timer = 0,
            casters = {}
        }
    end
    
    return targetData.timers[debuffName]
end

function aDF:SetDebuffTimer(targetData, debuffName, time)
    local timerData = aDF:GetDebuffTimer(targetData, debuffName)
    if timerData then
        timerData.timer = time or GetTime()
        return true
    end
    return false
end

function aDF:HandleDebuffCast(unit, caster, debuffName)
    local targetData = aDF:GetTargetData(unit)
    if not targetData then return end
    
    local timerData = aDF:GetDebuffTimer(targetData, debuffName)
    if not timerData then return end
    
    if timerData.casters then
        timerData.casters[caster] = timerData.timer
    end
    
    timerData.timer = GetTime()
end

function aDF:HandleDebuffMiss(unit, caster, debuffName)
    local targetData = aDF:GetTargetData(unit)
    if not targetData then return end
    
    local timerData = aDF:GetDebuffTimer(targetData, debuffName)
    if not timerData or not timerData.casters then return end
    
    if timerData.casters[caster] then
        timerData.timer = timerData.casters[caster]
        timerData.casters[caster] = nil
    end
end

function aDF:CleanupTargetData()
    local currentTime = GetTime()
    local toRemove = {}
    
    for guid, data in pairs(aDFTargetData) do
        local hasActiveTimers = false
        for debuffName, timerData in pairs(data.timers) do
            if timerData.timer > 0 and (currentTime - timerData.timer) < 300 then
                hasActiveTimers = true
                break
            end
        end
        
        if currentTime - data.lastSeen > 300 and not hasActiveTimers then
            table.insert(toRemove, guid)
        end
    end
    
    for _, guid in ipairs(toRemove) do
        aDFTargetData[guid] = nil
    end
end


function aDF:ValidateConfiguration()
    local validOptions = {}
    
    for debuffName, value in pairs(guiOptions) do
        if aDFSpellConfig[debuffName] then
            validOptions[debuffName] = value
        else
            adfprint("Removing obsolete debuff from options: " .. debuffName)
            
            if aDF_frames[debuffName] then
                aDF_frames[debuffName]:Hide()
                aDF_frames[debuffName] = nil
            end
            
            if aDF_guiframes[debuffName] then
                aDF_guiframes[debuffName]:Hide()
                aDF_guiframes[debuffName] = nil
            end
        end
    end
    
    guiOptions = validOptions
end


aDFArmorVals = {
	[90]   = "Sunder Armor x1", -- r1 x1
	[180]  = "Sunder Armor",    -- r2 x1, or r1 x2
	[270]  = "Sunder Armor",    -- r3 x1, or r1 x3
	[540]  = "Sunder Armor",    -- r3 x2, or r2 x3
	[810]  = "Sunder Armor x3", -- r3 x3
	[360]  = "Sunder Armor",    -- r4 x1, or r1 x4 or r2 x2
	[720]  = "Sunder Armor",    -- r4 x2, or r2 x4
	[1080] = "Sunder Armor",    -- r4 x3, or r3 x4
	[1440] = "Sunder Armor x4", -- r4 x4
	[450]  = "Sunder Armor",    -- r5 x1, or r1 x5
	[900]  = "Sunder Armor",    -- r5 x2, or r2 x5
	[1350] = "Sunder Armor",    -- r5 x3, or r3 x5
	[1800] = "Sunder Armor",    -- r5 x4, or r4 x5
	[2250] = "Sunder Armor x5", -- r5 x5
--[600]  = "Improved Expose Armor",   -- r1 -- conflicts with anni/rivenspike
--[400]  = "Untalented Expose Armor", -- r1 -- conflicts with anni/rivenspike
-- 	[] = "Improved Expose Armor",  -- 5pt IEA r2 r3 r4 values unknown
	[725]  = "Untalented Expose Armor",
-- 	[] = "Improved Expose Armor",
	[1050] = "Untalented Expose Armor",
-- 	[] = "Improved Expose Armor",
	[1375] = "Untalented Expose Armor",
	[510]  = "Fucked up IEA?",
	[1020] = "Fucked up IEA?",
	[1530] = "Fucked up IEA?",
	[2040] = "Fucked up IEA?",
	[2550] = "Improved Expose Armor",
	[1700] = "Untalented Expose Armor",
	[505]  = "Faerie Fire",
	[395]  = "Faerie Fire R3",
	[285]  = "Faerie Fire R2",
	[175]  = "Faerie Fire R1",
	[640]  = "Curse of Recklessness",
	[465]  = "Curse of Recklessness R3",
	[290]  = "Curse of Recklessness R2",
	[140]  = "Curse of Recklessness R1",
	--[600]  = "Annihilator x3 ?", --
	--[400]  = "Annihilator x2 ?", -- Armor Shatter spell=16928, or Puncture Armor r2 spell=17315
	--[200]  = "Annihilator x1 ?", --
	[300]  = "Annihilator x3 ?", --
	[200]  = "Annihilator x2 ?", -- Armor Shatter spell=16928, or Puncture Armor r2 spell=17315
	[100]  = "Annihilator x1 ?", --
	[50]   = "Torch of Holy Flame", -- Can also be spell=13526, item=1434 but those conflict FF
	-- [100]  = "Weapon Proc Faerie Fire", -- non-stacking proc spell=13752, Puncture Armor r1 x1 spell=11791
	-- [300]  = "Weapon Proc Faerie Fire", -- Dark Iron Sunderer item=11607, Puncture Armor r1 x3
}

function aDF_Default()
    if guiOptions == nil then
        guiOptions = {}
        for k, v in pairs(aDFSpellConfig) do
            guiOptions[k] = 1
        end
    else
        aDF:ValidateConfiguration()
    end
end

-- the main frame

function aDF:Init()
	aDF.Drag = { }
	function aDF.Drag:StartMoving()
		if ( IsShiftKeyDown() ) then
			this:StartMoving()
		end
	end
	
	function aDF.Drag:StopMovingOrSizing()
		this:StopMovingOrSizing()
		local x, y = this:GetCenter()
		local ux, uy = UIParent:GetCenter()
		aDF_x, aDF_y = floor(x - ux + 0.5), floor(y - uy + 0.5)
	end
	
	local backdrop = {
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			tile="false",
			tileSize="8",
			edgeSize="8",
			insets={
				left="2",
				right="2",
				top="2",
				bottom="2"
			}
	}
	
	self:SetFrameStrata("BACKGROUND")
	self:SetWidth((24+gui_Optionsxy)*7) -- Set these to whatever height/width is needed 
	self:SetHeight(24+gui_Optionsxy) -- for your Texture
	self:SetPoint("CENTER",aDF_x,aDF_y)
	self:SetMovable(1)
	self:EnableMouse(1)
	self:RegisterForDrag("LeftButton")
	self:SetBackdrop(backdrop) --border around the frame
	self:SetBackdropColor(0,0,0,1)
	self:SetScript("OnDragStart", aDF.Drag.StartMoving)
	self:SetScript("OnDragStop", aDF.Drag.StopMovingOrSizing)
	self:SetScript("OnMouseDown", function()
		if (arg1 == "RightButton") then
			if aDF_target ~= nil then
				if UnitAffectingCombat(aDF_target) and UnitCanAttack("player", aDF_target) then	
					aDF:SendChatMessage(UnitName(aDF_target).." has ".. UnitResistance(aDF_target,0).." armor", gui_chan)
				end
			end
		end
	end)
	
	-- Armor text
	self.armor = self:CreateFontString(nil, "OVERLAY")
    self.armor:SetPoint("CENTER", self, "CENTER", 0, 0)
    self.armor:SetFont("Fonts\\FRIZQT__.TTF", 24+gui_Optionsxy)
	self.armor:SetShadowOffset(2,-2)
    self.armor:SetText("aDF")

	-- Resistance text
	self.res = self:CreateFontString(nil, "OVERLAY")
    self.res:SetPoint("CENTER", self, "CENTER", 0, 20+gui_Optionsxy)
    self.res:SetFont("Fonts\\FRIZQT__.TTF", 14+gui_Optionsxy)
	self.res:SetShadowOffset(2,-2)
    self.res:SetText("Resistance")
	
	-- for the debuff check function
	aDF_tooltip = CreateFrame("GAMETOOLTIP", "buffScan")
	aDF_tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	aDF_tooltipTextL = aDF_tooltip:CreateFontString()
	aDF_tooltipTextR = aDF_tooltip:CreateFontString()
	aDF_tooltip:AddFontStrings(aDF_tooltipTextL,aDF_tooltipTextR)
	--R = tip:CreateFontString()
	--
	
	f_ =  0
	-- for name,texture in pairs(aDFDebuffs) do
	for name,v in pairs(aDFSpellConfig) do
		aDFsize = 24+gui_Optionsxy
		aDF_frames[name] = aDF_frames[name] or aDF.Create_frame(name)
		local frame = aDF_frames[name]
		frame:SetWidth(aDFsize)
		frame:SetHeight(aDFsize)
		frame:SetPoint("BOTTOMLEFT",aDFsize*f_,-aDFsize)
		frame.icon:SetTexture(v.icon)
		frame:SetFrameLevel(2)
		frame:Show()
		frame:SetScript("OnEnter", function() 
			GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT");
			local displayName = aDFSpellConfig[this:GetName()].name
			if this:GetName() == "Faerie Fire" then
				displayName = "Faerie Fire / Faerie Fire (Feral)"
			end
			GameTooltip:SetText(displayName, 255, 255, 0, 1, 1);
			GameTooltip:Show()
		end)
		frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame:SetScript("OnMouseDown", function()
			if (arg1 == "RightButton") then
				tdb=this:GetName()
				if aDF_target ~= nil then
					if UnitAffectingCombat(aDF_target) and UnitCanAttack("player", aDF_target) and guiOptions[tdb] ~= nil then
						if not aDF:GetDebuff(aDF_target,tdb) then
							aDF:SendChatMessage("["..aDFSpellConfig[tdb].name.."] is not active on "..UnitName(aDF_target), gui_chan)
						else
							if aDF:GetDebuff(aDF_target,tdb,1) == 1 then
								s_ = "stack"
							elseif aDF:GetDebuff(aDF_target,tdb,1) > 1 then
								s_ = "stacks"
							end
							if aDF:GetDebuff(aDF_target,tdb,1) >= 1 and aDF:GetDebuff(aDF_target,tdb,1) < 5 and tdb ~= "Armor Shatter" then
								aDF:SendChatMessage(UnitName(aDF_target).." has "..aDF:GetDebuff(aDF_target,tdb,1).." ["..aDFSpellConfig[tdb].name.."] "..s_, gui_chan)
							end
							if tdb == "Armor Shatter" and aDF:GetDebuff(aDF_target,tdb,1) >= 1 and aDF:GetDebuff(aDF_target,tdb,1) <= 3 then
								aDF:SendChatMessage(UnitName(aDF_target).." has "..aDF:GetDebuff(aDF_target,tdb,1).." ["..aDFSpellConfig[tdb].name.."] "..s_, gui_chan)
							end
						end
					end
				end
			end
		end)
		f_ = f_+1
	end
end

-- creates the debuff frames on load

function aDF.Create_frame(name)
	local frame = CreateFrame('Button', name, aDF)
	frame:SetBackdrop({ bgFile=[[Interface/Tooltips/UI-Tooltip-Background]] })
	frame:SetBackdropColor(0,0,0,1)
	frame.icon = frame:CreateTexture(nil, 'ARTWORK')
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.icon:SetPoint('TOPLEFT', 1, -1)
	frame.icon:SetPoint('BOTTOMRIGHT', -1, 1)
	frame.dur = frame:CreateFontString(nil, "OVERLAY")
	frame.dur:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	frame.dur:SetFont("Fonts\\FRIZQT__.TTF", 10+gui_Optionsxy)
	frame.dur:SetTextColor(0, 255, 255, 1)
	frame.dur:SetShadowOffset(2,-2)
	frame.dur:SetText("0")
	frame.nr = frame:CreateFontString(nil, "OVERLAY")
	frame.nr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.nr:SetFont("Fonts\\FRIZQT__.TTF", 10+gui_Optionsxy)
	frame.nr:SetTextColor(0, 255, 255, 1)
	frame.nr:SetShadowOffset(2,-2)
	frame.nr:SetText("1")
	--DEFAULT_CHAT_FRAME:AddMessage("----- Adding new frame")
	return frame
end

-- creates gui checkboxes

function aDF.Create_guiframe(name)
	local frame = CreateFrame("CheckButton", name, aDF.Options, "UICheckButtonTemplate")
	frame:SetFrameStrata("LOW")
	frame:SetScript("OnClick", function () 
		if frame:GetChecked() == nil then 
			guiOptions[name] = nil
		elseif frame:GetChecked() == 1 then 
			guiOptions[name] = 1 
			table.sort(guiOptions)
		end
		aDF:Sort()
		aDF:Update()
		end)
	frame:SetScript("OnEnter", function() 
		GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT");
		local displayName = aDFSpellConfig[this:GetName()].name
		if this:GetName() == "Faerie Fire" then
			displayName = "Faerie Fire / Faerie Fire (Feral)"
		end
		GameTooltip:SetText(displayName, 255, 255, 0, 1, 1);
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame:SetChecked(guiOptions[name])
	frame.Icon = frame:CreateTexture(nil, 'ARTWORK')
	frame.Icon:SetTexture(aDFSpellConfig[name].icon)
	frame.Icon:SetWidth(25)
	frame.Icon:SetHeight(25)
	frame.Icon:SetPoint("CENTER",-30,0)
	--DEFAULT_CHAT_FRAME:AddMessage("----- Adding new gui checkbox")
	return frame
end

-- update function for the text/debuff frames
local anni_stacks_maxed = false

function aDF:Update()
    if aDF_target ~= nil and UnitExists(aDF_target) and not UnitIsDead(aDF_target) then
        if UnitIsUnit(aDF_target,'targettarget') and GetTime() < (last_target_change_time + 1.3) then
            return
        end
        
        local targetData = aDF:GetTargetData(aDF_target)
        if not targetData then return end
        
        local armorcurr = UnitResistance(aDF_target,0)
        aDF.armor:SetText(armorcurr)
        
        if armorcurr ~= targetData.armor then
            if armorcurr > targetData.armor and targetData.armor > 0 then
                local armordiff = armorcurr - targetData.armor
                local diffreason = ""
                if aDFArmorVals[armordiff] then
                    diffreason = " (Dropped " .. aDFArmorVals[armordiff] .. ")"
                end
                local msg = UnitName(aDF_target).."'s armor: "..targetData.armor.." -> "..armorcurr..diffreason
                if UnitIsUnit(aDF_target,'target') then
                    aDF:SendChatMessage(msg, gui_chan)
                end
            end
            targetData.armor = armorcurr
        end
		if true then
			aDF.res:SetText("|cffFF0000FR "..UnitResistance(aDF_target,2).." |cff00FF00NR "..UnitResistance(aDF_target,3).." |cff4AE8F5FrR "..UnitResistance(aDF_target,4).." |cff800080SR "..UnitResistance(aDF_target,5))
		else
			aDF.res:SetText("")
		end
		
        for debuffName, _ in pairs(guiOptions) do
            local isActive = aDF:GetDebuff(aDF_target, debuffName)
            
            if isActive then
                aDF_frames[debuffName]["icon"]:SetAlpha(1)
                
                local timerData = aDF:GetDebuffTimer(targetData, debuffName)
                
                local stacks = aDF:GetDebuff(aDF_target, debuffName, 1)
                if stacks and (debuffName == "Armor Shatter" or stacks > 1) then
                    aDF_frames[debuffName]["nr"]:SetText(stacks)
                else
                    aDF_frames[debuffName]["nr"]:SetText("")
                end
                local config = aDFSpellConfig[debuffName]
                if config and config.duration and timerData then
                    local elapsed = config.duration - (GetTime() - timerData.timer)
                    
                    if debuffName == "Armor Shatter" and elapsed < 0 then
                        timerData.timer = timerData.timer + 20
                        elapsed = config.duration - (GetTime() - timerData.timer)
                    end
                    if elapsed > 0 then
						aDF_frames[debuffName]["dur"]:SetText(format("%0.f", elapsed))
					end
                else
                    aDF_frames[debuffName]["dur"]:SetText("")
                end
            else
                aDF_frames[debuffName]["icon"]:SetAlpha(0.3)
                aDF_frames[debuffName]["nr"]:SetText("")
                aDF_frames[debuffName]["dur"]:SetText("")
            end        
        end
    else
        aDF.armor:SetText("")
        aDF.res:SetText("")
        for debuffName, _ in pairs(guiOptions) do
            aDF_frames[debuffName]["icon"]:SetAlpha(0.3)
            aDF_frames[debuffName]["nr"]:SetText("")
            aDF_frames[debuffName]["dur"]:SetText("")
        end
    end
end

function aDF:UpdateCheck()
	-- if utimer == nil or (GetTime() - utimer > 0.8) and UnitIsPlayer("target") then
	if utimer == nil or (GetTime() - utimer > 0.3) then
		utimer = GetTime()
		aDF:Update()
	end
end

-- Sort function to show/hide frames aswell as positioning them correctly

function aDF:Sort()
	-- for name,_ in pairs(aDFDebuffs) do
	for name,_ in pairs(aDFSpellConfig) do
		if guiOptions[name] == nil then
			aDF_frames[name]:Hide()
		else
			aDF_frames[name]:Show()
		end
	end
	
	local aDFTempTable = {}
	for dbf,_ in pairs(guiOptions) do
		table.insert(aDFTempTable,dbf)
	end
	table.sort(aDFTempTable, function(a,b) return a<b end)
	
	local maxPerRow = 7
	for n, v in pairs(aDFTempTable) do
		if v and aDF_frames[v] then
			local row = math.floor((n-1) / maxPerRow)
			local col = math.mod(n-1, maxPerRow)
			
			local x_ = (24 + gui_Optionsxy) * col
			local y_ = -(24 + gui_Optionsxy) * (row + 1)
			
			aDF_frames[v]:SetPoint('BOTTOMLEFT', x_, y_)
		end
	end
end

-- Options frame

function aDF.Options:Gui()

	aDF.Options.Drag = { }
	function aDF.Options.Drag:StartMoving()
		this:StartMoving()
	end
	
	function aDF.Options.Drag:StopMovingOrSizing()
		this:StopMovingOrSizing()
	end

	local backdrop = {
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			tile="false",
			tileSize="4",
			edgeSize="8",
			insets={
				left="2",
				right="2",
				top="2",
				bottom="2"
			}
	}
	
	self:SetFrameStrata("BACKGROUND")
	self:SetWidth(400) -- Set these to whatever height/width is needed 
	self:SetHeight(450) -- for your Texture
	self:SetPoint("CENTER",0,0)
	self:SetMovable(1)
	self:EnableMouse(1)
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", aDF.Options.Drag.StartMoving)
	self:SetScript("OnDragStop", aDF.Options.Drag.StopMovingOrSizing)
	self:SetBackdrop(backdrop) --border around the frame
	self:SetBackdropColor(0,0,0,1);
	
	-- Options text
	
	self.text = self:CreateFontString(nil, "OVERLAY")
    self.text:SetPoint("CENTER", self, "CENTER", 0, 180)
    self.text:SetFont("Fonts\\FRIZQT__.TTF", 25)
	self.text:SetTextColor(255, 255, 0, 1)
	self.text:SetShadowOffset(2,-2)
    self.text:SetText("Options")
	
	-- mid line
	
	self.left = self:CreateTexture(nil, "BORDER")
	self.left:SetWidth(125)
	self.left:SetHeight(2)
	self.left:SetPoint("CENTER", -62, 160)
	self.left:SetTexture(1, 1, 0, 1)
	self.left:SetGradientAlpha("Horizontal", 0, 0, 0, 0, 102, 102, 102, 0.6)

	self.right = self:CreateTexture(nil, "BORDER")
	self.right:SetWidth(125)
	self.right:SetHeight(2)
	self.right:SetPoint("CENTER", 63, 160)
	self.right:SetTexture(1, 1, 0, 1)
	self.right:SetGradientAlpha("Horizontal", 255, 255, 0, 0.6, 0, 0, 0, 0)
	
	-- slider

	self.Slider = CreateFrame("Slider", "aDF Slider", self, 'OptionsSliderTemplate')
	self.Slider:SetWidth(200)
	self.Slider:SetHeight(20)
	self.Slider:SetPoint("CENTER", self, "CENTER", 0, 140)
	self.Slider:SetMinMaxValues(1, 10)
	self.Slider:SetValue(gui_Optionsxy)
	self.Slider:SetValueStep(1)
	getglobal(self.Slider:GetName() .. 'Low'):SetText('1')
	getglobal(self.Slider:GetName() .. 'High'):SetText('10')
	--getglobal(self.Slider:GetName() .. 'Text'):SetText('Frame size')
	self.Slider:SetScript("OnValueChanged", function() 
		gui_Optionsxy = this:GetValue()
		for _, frame in pairs(aDF_frames) do
			frame:SetWidth(24+gui_Optionsxy)
			frame:SetHeight(24+gui_Optionsxy)
			frame.nr:SetFont("Fonts\\FRIZQT__.TTF", 16+gui_Optionsxy)
		end
		aDF:SetWidth((24+gui_Optionsxy)*7)
		aDF:SetHeight(24+gui_Optionsxy)
		aDF.armor:SetFont("Fonts\\FRIZQT__.TTF", 24+gui_Optionsxy)
		aDF.res:SetFont("Fonts\\FRIZQT__.TTF", 14+gui_Optionsxy)
		aDF.res:SetPoint("CENTER", aDF, "CENTER", 0, 20+gui_Optionsxy)
		aDF:Sort()
	end)
	self.Slider:Show()
	
	-- checkboxes

	local temptable = {}
	for tempn,_ in pairs(aDFSpellConfig) do
		table.insert(temptable,tempn)
	end
	table.sort(temptable, function(a,b) return a<b end)
	-- table.insert(temptable,"Resistances")
	
	local x,y=65,-80
	for _,name in pairs(temptable) do
		y=y-40
		if y < -360 then y=-120; x=x+140 end
		--DEFAULT_CHAT_FRAME:AddMessage("Name of frame: "..name.." ypos: "..y)
		aDF_guiframes[name] = aDF_guiframes[name] or aDF.Create_guiframe(name)
		local frame = aDF_guiframes[name]
		frame:SetPoint("TOPLEFT",x,y)
	end	

	-- drop down menu

	self.dropdown = CreateFrame('Button', 'chandropdown', self, 'UIDropDownMenuTemplate')
	self.dropdown:SetPoint("BOTTOM",-60,20)
	InitializeDropdown = function() 
		local info = {}
		for k,v in pairs(gui_chantbl) do
			info = {}
			info.text = v
			info.value = v
			info.func = function()
			UIDropDownMenu_SetSelectedValue(chandropdown, this.value)
			gui_chan = UIDropDownMenu_GetText(chandropdown)
			end
			info.checked = nil
			UIDropDownMenu_AddButton(info, 1)
			if gui_chan == nil then
				UIDropDownMenu_SetSelectedValue(chandropdown, "None")
			else
				UIDropDownMenu_SetSelectedValue(chandropdown, gui_chan)
			end
		end
	end
	UIDropDownMenu_Initialize(chandropdown, InitializeDropdown)
	
	-- -- resistance check
	
	-- self.resistance = aDF.Create_guiframe("Resistances")
	-- self.resistance:SetPoint("BOTTOM",60,20)

	-- done button
	
	self.dbutton = CreateFrame("Button",nil,self,"UIPanelButtonTemplate")
	self.dbutton:SetPoint("BOTTOM",0,10)
	self.dbutton:SetFrameStrata("LOW")
	self.dbutton:SetWidth(79)
	self.dbutton:SetHeight(18)
	self.dbutton:SetText("Done")
	self.dbutton:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); aDF:Sort(); aDF:Update(); aDF.Options:Hide() end)
	self:Hide()
end

-- function to check a unit for a certain debuff and/or number of stacks
function aDF:GetDebuff(name,buff,stacks)
    local normalizedBuff = aDFDebuffAliases[buff] or buff
    
    local a=1
    while UnitDebuff(name,a) do
        local _,s,_,id = UnitDebuff(name,a)
        local n = SpellInfo(id)
        local normalizedN = aDFDebuffAliases[n] or n
        
        if normalizedBuff == normalizedN then 
            if stacks == 1 then
                return s
            else
                return true 
            end
        end
        a=a+1
    end

    -- if not found, check buffs in case over the debuff limit
    a=1
    while UnitBuff(name,a) do
        local _,s,id = UnitBuff(name,a)
        local n = SpellInfo(id)
        local normalizedN = aDFDebuffAliases[n] or n
        
        if normalizedBuff == normalizedN then 
            if stacks == 1 then
                return s
            else
                return true 
            end
        end
        a=a+1
    end
    return false
end


local function extractSpellNameAndCaster(text, isPlayer)
    if isPlayer then
        for _, pattern in ipairs(aDFPlayerPatterns) do
            local _, _, spellName = string.find(text, pattern)
            if spellName then
                local normalizedSpellName = aDFDebuffAliases[spellName] or spellName
                return normalizedSpellName, UnitName("player")
            end
        end
        return nil, nil
    end
        
    for _, pattern in ipairs(aDFOtherPlayerPatterns) do
        local startPos, endPos, caster, spellName = string.find(text, pattern)
        if startPos then
            local normalizedSpellName = aDFDebuffAliases[spellName] or spellName
            return normalizedSpellName, caster
        end
    end 
    return nil, nil
end

-- event function, will load the frames we need
function aDF:OnEvent()
	if event == "ADDON_LOADED" and arg1 == "aDF" then
		aDF_Default()
		aDF_target = nil
		aDF_armorprev = 30000
		if gui_chan == nil then gui_chan = Say end
		aDF:Init()
		aDF.Options:Gui()
		aDF:Sort()
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r Loaded",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf show|r to show frame",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf hide|r to hide frame",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf options|r for options frame",1,1,1)
		     
    elseif event == "UNIT_AURA" and aDF_target ~= nil and arg1 ~= nil and UnitName(arg1) == UnitName(aDF_target) then
        local targetData = aDF:GetTargetData(aDF_target)
        if targetData then
            local anni_prev = tonumber(aDF_frames["Armor Shatter"]["nr"]:GetText()) or 0
            aDF:Update()
            local anni = tonumber(aDF_frames["Armor Shatter"]["nr"]:GetText()) or 0
            if anni_prev ~= anni then 
                aDF:SetDebuffTimer(targetData, "Armor Shatter", GetTime())
            end
            
            if anni_stacks_maxed and anni < 3 then anni_stacks_maxed = false end
            if not anni_stacks_maxed and anni >= 3 then
                UIErrorsFrame:AddMessage("Annihilator Stacks Maxxed",1,0.1,0.1,1)
                anni_stacks_maxed = true
            end
        end
	elseif event == "UNIT_CASTEVENT" and arg2 == aDF_target then
        local name = SpellInfo(arg4)
        local normalizedName = aDFDebuffAliases[name] or name
        aDF:HandleDebuffCast(aDF_target, UnitName(arg1), normalizedName)
	elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        local spellName, casterName = extractSpellNameAndCaster(arg1, true)
        if spellName then
            aDF:HandleDebuffMiss(aDF_target, casterName, spellName)
        end
	elseif event == "CHAT_MSG_SPELL_PARTY_DAMAGE" or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE" then
        local spellName, casterName = extractSpellNameAndCaster(arg1, false)
        if spellName then
            aDF:HandleDebuffMiss(aDF_target, casterName, spellName)
        end
	elseif event == "PLAYER_TARGET_CHANGED" then
		local aDF_target_old = aDF_target
		aDF_target = nil
		last_target_change_time = GetTime()
		if UnitIsPlayer("target") then
			aDF_target = "targettarget"
		end
		if UnitCanAttack("player", "target") then
			aDF_target = "target"
		end
		aDF_armorprev = 30000
		if has_superwow then
			_,aDF_target = UnitExists(aDF_target)
		end
		if aDF_target ~= aDF_target_old then
			anni_stacks_maxed = false
		end
		
		if random(100) < 25 then
            aDF:CleanupTargetData()
        end
		-- adfprint('PLAYER_TARGET_CHANGED ' .. tostring(aDF_target))
		aDF:Update()
	end
end

function aDF:PrintDataStats()
    local totalTargets = 0
    local totalTimers = 0
    
    for guid, data in pairs(aDFTargetData) do
        totalTargets = totalTargets + 1
        for debuffName, timerData in pairs(data.timers) do
            totalTimers = totalTimers + 1
        end
    end
    
    adfprint(string.format("Targets: %d, Active timers: %d", totalTargets, totalTimers))
end

-- update and onevent who will trigger the update and event functions

aDF:SetScript("OnEvent", aDF.OnEvent)
aDF:SetScript("OnUpdate", aDF.UpdateCheck)

-- slash commands

function aDF.slash(arg1,arg2,arg3)
	if arg1 == nil or arg1 == "" then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf show|r to show frame",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf hide|r to hide frame",1,1,1)
		DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf options|r for options frame",1,1,1)
		else
		if arg1 == "show" then
			aDF:Show()
		elseif arg1 == "hide" then
			aDF:Hide()
		elseif arg1 == "options" or arg1 == "opt" then
			aDF.Options:Show()
		elseif arg1 == "debug" then
			aDF:PrintDataStats()
		else
			DEFAULT_CHAT_FRAME:AddMessage(arg1)
			DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r unknown command",1,0.3,0.3);
		end
	end
end

SlashCmdList['ADF_SLASH'] = aDF.slash
SLASH_ADF_SLASH1 = '/adf'
SLASH_ADF_SLASH2 = '/ADF'

-- debug

function adfprint(arg1)
	DEFAULT_CHAT_FRAME:AddMessage("|cffCC121D adf debug|r "..arg1)
end
