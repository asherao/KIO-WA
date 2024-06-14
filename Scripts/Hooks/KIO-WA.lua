--[[
    -- Kiowa Integrated Overlay - Warrior Automatis --

    This project adds an onscreen ingame GUI with which you
    can command the OH-58D Kiowa AI, aka, Barundus.
    Most button information comes from the inputTables.lua file.
--]]

--[[
    Future Feature Goals:
    - Have NORTH UP or TRACK UP be displayed on spawn instead of having to click it once
    - Get the default window size dialed in
    - Change the default hotkey. Cpuld have that in the window title or title tooltip
    - Show/Hide keybinds
    - Make a minimum window size
    - Have the "land" command bypass polychop's requirement to hover then land.
    - experement using one contril (the dial) for speed, alt, and course
    - talk about the config file for adjustments
    - Add more commands such as
    -- Orbit Left/Right
    -- Increase/Decrease speed
    -- Hover Drift Left/Right
    -- Increase/Decrease altitude
    -- Adjust heading left/right
    -- AI turn rate Slo/Medium/Fast (can be one button)
    -- Baro and Radar can be 1 button
    -- can Plan and route be 1 button?
    -- may want to split on/off into 2 smaller buttons
    -- research the possibility of using hardware buttons to toggle the GUI

    - Aircraft Detection - When the player is not flying the Kiowa, the
    GUI is hidden
    - Compact vs Full mode with a toggle switch
    - For the left/right options, you can set a toggle and then
    -- single button for each, eg
    -----------------------------------------------
    |Left/Right|PLAN  |TAKEOFF|ALTITUDE|--SLIDER--|
    |🢀Orbit   |ROUTE |HOVER  |SPEED   |--SLIDER--|
    |🢀Heading |BARO  |LAND   |COURSE  |--SLIDER--|
    |🢀Hover   |RADALT|HDG2MMS|HUD     |  ON/OFF  |
    -----------------------------------------------
    -- The direction of the arrow changes when "Left/Right" is clicked
    -- This systems reduces the number of buttons from 6 to 4, not including
    -- another row/column for the labels. Overall, seems like a good idea.
    ------------
    |Left/Right| (shorten to L/R?)
    |Orbit🢂   |
    |Heading🢂 |
    |Hover🢂   |
    ------------
    - Make everything "modular" (good luck) so that ppl can pick which "modules"
    they want to use. Would this feature go well in a Special Options menu? It is
    easy to make the modules, but having them tile properly may be the more difficult
    issue to solve.
    - Remove the margin gap at the top and sides of groups of buttons/controls
    - Remove Barundus' name. Sorry.
--]]

--[[
    Bugs:
    - Fix the 000/360 twitch for the headings
    - Why does course 050 result in 050, but Barundus says "Heading 360"? (Polychop bug?)
--]]

--[[
Pretty pictures:
    -----------------------------------------------
    |Left/Right|PLAN  |TAKEOFF|ALTITUDE|--SLIDER--|
    |🢀Orbit   |ROUTE |HOVER  |SPEED   |--SLIDER--|
    |🢀Heading |BARO  |LAND   |COURSE  |--SLIDER--|
    |🢀Hover   |RADALT|HDG2MMS|HUD     |  ON/OFF  |
    -----------------------------------------------

    Expanded:
    ----------------------------------------------------
    |Left/Right|PLAN/ROUTE|TAKEOFF|NORTH/TRACK|DIAL    |
    |🢀Orbit   |BARO/ALT  |HOVER  |COURSE     |DIAL    |
    |🢀Heading |TURN RATE |LAND   |SPEED      |ALTITUDE|
    |🢀Hover   |   ???    |HDG2MMS|HUD        | ON|OFF |
    ----------------------------------------------------

    Full:
    -----------------------------------------
    |PLAN/ROUTE|TAKEOFF|NORTH/TRACK|DIAL    |
    |BARO/ALT  |HOVER  |COURSE     |DIAL    |
    |TURN RATE |LAND   |SPEED      |ALTITUDE|
    |   ???    |HDG2MMS|HUD        | ON|OFF |
    -----------------------------------------

     Compact:
    ------------------------------
    |TAKEOFF|NORTH/TRACK|DIAL    |
    |HOVER  |COURSE     |DIAL    |
    |LAND   |SPEED      |ALTITUDE|
    |HDG2MMS|HUD        | ON|OFF |
    ------------------------------

I guess that if flip everything, all I would have to do
to toggle between Expanded, Full, and Compact is to change the window size and/or make
the different elements visible. Therefore:

    Expanded:
    ----------------------------------------------------
    |DIAL    |NORTH/TRACK|TAKEOFF|PLAN/ROUTE|LEFT/RIGHT|
    |DIAL    |COURSE     |HOVER  |BARO/ALT  |🢀ORBIT   |
    |ALTITUDE|SPEED      |LAND   |TURN RATE |🢀HEADING |
    |ON/OFF  |   HUD     |HDG2MMS|  ???     | 🢀HOVER  |
    ----------------------------------------------------

    Full:
    -----------------------------------------
    |DIAL    |NORTH/TRACK|TAKEOFF|PLAN/ROUTE|
    |DIAL    |COURSE     |HOVER  |BARO/ALT  |
    |ALTITUDE|SPEED      |LAND   |TURN RATE |
    |ON/OFF  |   HUD     |HDG2MMS|  ???     |
    -----------------------------------------

    Compact:
    ------------------------------
    |DIAL    |NORTH/TRACK|TAKEOFF|
    |DIAL    |COURSE     |HOVER  |
    |ALTITUDE|SPEED      |LAND   |
    |ON/OFF  |   HUD     |HDG2MMS|
    ------------------------------

--]]

local function loadBarundusUI()
    package.path = package.path .. ";.\\Scripts\\?.lua;.\\Scripts\\UI\\?.lua;"

    local lfs = require("lfs")
    local U = require("me_utilities")
    local Skin = require("Skin")
    local DialogLoader = require("DialogLoader")
    local Tools = require("tools")

    -- KIO-WA resources
    local window = nil
    local windowDefaultSkin = nil
    local windowSkinHidden = Skin.windowSkinChatMin()
    local panel = nil
    local logFile = io.open(lfs.writedir() .. [[Logs\KIO-WA.log]], "w")
    local config = nil

    -- State
    local isHidden = true
    local inMission = false

    local buttonHeight = 25
    local buttonWidth = 50

    local columnSpacing = buttonWidth + 5

    local rowSpacing = buttonHeight * 0.8
    local row1 = 0
    local row2 = rowSpacing + row1
    -- when the app starts, it assumes that North is the reference vice relative
    -- relative is the special case.
    local isNorthUp = 0 -- this determines if the default behaviour is TRACK UP or NORTH up
    -- In North Up mode the top of the dial is always north
    -- In Track up mode the top of the dial is always the way the aircraft is pointing
    -- Use cases to each mode:
    -- TRACK UP:
    -- Hovering and you want to look to your right
    -- Flying Quick U-Turn
    -- You see something and want to turn to it. Point the arrow to it and click.
    -- NORTH UP:
    -- Hovering and you want to look 160 degrees, exactly
    -- Flying a route

    -- Use whichever method you prefer.

    local function log(str)
        if not str then
            return
        end

        if logFile then
            logFile:write("[" .. os.date("%H:%M:%S") .. "] " .. str .. "\r\n")
            logFile:flush()
        end
    end

    local function dump(o) -- for debug
        if type(o) == 'table' then
            local s = '{ '
            for k, v in pairs(o) do
                if type(k) ~= 'number' then k = '"' .. k .. '"' end
                s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
            end
            return s .. '} '
        else
            return tostring(o)
        end
    end

    local function loadConfiguration()
        log("Loading config file...")
        lfs.mkdir(lfs.writedir() .. [[Config\KIO-WA\]])
        local tbl = Tools.safeDoFile(lfs.writedir() .. "Config/KIO-WA/KIO-WAConfig.lua", false)
        if (tbl and tbl.config) then
            log("Configuration exists...")
            config = tbl.config

            -- move content into text file
            if config.content ~= nil then
                config.content = nil
                saveConfiguration()
            end
        else
            log("Configuration not found, creating defaults...")
            config = {
                hotkey         = "Ctrl+Shift+F9",       -- show/hide
                windowPosition = { x = 1430, y = 754 }, -- these values were obtained by manually adjusting
                windowSize     = { w = 344, h = 132 },  -- the window till I got something that looked ok
                hideOnLaunch   = false,
            }
            saveConfiguration()
        end
    end

    local function saveConfiguration()
        U.saveInFile(config, "config", lfs.writedir() .. "Config/KIO-WA/KIO-WAConfig.lua")
    end

    local function setVisible(b)
        window:setVisible(b)
    end

    -- resize is dsiabled due to early development complexity
    local function handleResize(self)
        local w, h = self:getSize()

        panel:setBounds(0, 0, w, h - 20)

        -- resize for Walkman
        -- can be adjusted for KIO-WA
        -- (xpos, ypos, width, height)
        --HeadingSlider:setBounds(0, row2, w, 25)
        --[[
        local numberOfButtons = 5
        local buttonSpacing = w / numberOfButtons * 0.02

        WalkmanStopButton:setBounds(w * (0 / numberOfButtons) + buttonSpacing / 2,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanPrevButton:setBounds(w * (1 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanPlayButton:setBounds(w * (2 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanNextButton:setBounds(w * (3 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
        WalkmanFolderButton:setBounds(w * (4 / numberOfButtons) + buttonSpacing,
            row1, w / numberOfButtons - buttonSpacing, buttonHeight)
--]]
        config.windowSize = { w = w, h = h }
        saveConfiguration()
    end


    local function handleMove(self)
        local x, y = self:getPosition()
        config.windowPosition = { x = x, y = y }
        saveConfiguration()
    end

    local function show()
        if window == nil then
            local status, err = pcall(createBarundusUIWindow)
            if not status then
                net.log("[KIO-WA] Error creating window: " .. tostring(err))
            end
        end

        window:setVisible(true)
        window:setSkin(windowDefaultSkin)
        panel:setVisible(true)
        window:setHasCursor(true)
        window:setText(' ' .. 'Kiowa Integrated Overlay - Warrior Automatis by Bailey')

        isHidden = false
    end

    local function hide() -- consider hiding when not in a mission
        window:setSkin(windowSkinHidden)
        panel:setVisible(false)
        window:setHasCursor(false)
        -- window.setVisible(false) -- if you make the window invisible, its destroyed
        isHidden = true
    end

    local function createBarundusUIWindow()
        if window ~= nil then
            return
        end

        window = DialogLoader.spawnDialogFromFile(
            lfs.writedir() .. "Scripts\\KIO-WA\\KIO-WA.dlg",
            cdata
        )

        windowDefaultSkin = window:getSkin()
        panel = window.Box

        RouteButton = panel.RouteButton
        BaroButton = panel.BaroButton
        RadaltButton = panel.RadaltButton
        TakeoffButton = panel.TakeoffButton
        HoverButton = panel.HoverButton
        LandButton = panel.LandButton
        MmsButton = panel.MmsButton
        FlightplanButton = panel.FlightplanButton
        HudButton = panel.HudButton
        OnoffButton = panel.OnoffButton
        AltitudeButton = panel.AltitudeButton
        KnotsButton = panel.KnotsButton
        CourseButton = panel.CourseButton
        AltitudeSlider = panel.AltitudeSlider
        KnotsSlider = panel.KnotsSlider
        CourseSlider = panel.CourseSlider
        SlideSlider = panel.SlideSlider
        CourseDial = panel.CourseDial
        TrueRelToggleButton = panel.TrueRelToggleButton
        TrueRelDisplayButton = panel.TrueRelDisplayButton

        -- setup window
        window:setBounds(
            config.windowPosition.x,
            config.windowPosition.y,
            config.windowSize.w,
            config.windowSize.h
        )
        window:setVisible(true)
        handleResize(window)
        handleMove(window)

        window:addHotKeyCallback(
            config.hotkey,
            function()
                if isHidden == true then
                    show()
                else
                    hide()
                end
            end
        )
        window:addSizeCallback(handleResize)
        window:addPositionCallback(handleMove)
        window:setVisible(true)

        local function changeSpeed()
            local sliderValue = KnotsSlider:getValue() -- 1 to 11 in the dlg to represent 10kts to 110kts
            -- 3000 + 20 + slider value
            -- ...unless, the slider value is 11 (110 kts), then the button is 3062...
            if sliderValue == 11 then
                Export.GetDevice(18):performClickableAction(3062, 1)
            else
                local commandButton = 3000 + 20 + sliderValue
                Export.GetDevice(18):performClickableAction(commandButton, 1)
            end
        end

        local function changeCourse(index)
            -- index is the direction that the player has selected, in 10s
            -- The slider goes from 0 to 350
            -- Head to 0 is button 66
            -- That means that the button can be generated by
            -- 3000 + 66 + index/10
            -- local commandButton = 3000 + 66 + (index/10)
            local sliderValue = CourseSlider:getValue()
            -- this handes the case where the button may display 360, which is actually 000
            if sliderValue == 36 then sliderValue = 0 end
            local commandButton = 3000 + 66 + sliderValue
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        local function toggleNorthOrTrack()
            if isNorthUp == 1 then                      -- if calculating with True
                isNorthUp = 0                           -- change the bool, becuase we wanna toggle to relative
                TrueRelToggleButton:setText("TRACK UP") -- change the text to reflect the bool change
            else                                        -- if reference was 0
                isNorthUp = 1                           -- make it the opposite
                TrueRelToggleButton:setText("NORTH UP") -- set the text for the button
            end
        end

        function TrueRelDisplayButtonClicked()
            local displayedDirection = TrueRelDisplayButton:getText()
            -- strip out degree sign and leading 0s
            displayedDirection = displayedDirection:gsub('°', '') -- removes the degrees symbol
            displayedDirection = tonumber(displayedDirection)     -- removes the leading zero, if any
            -- this handes the case where the button may display 360, which is actually 000
            -- it is needed for the then following commandButton math
            if displayedDirection == 360 then displayedDirection = 0 end
            if displayedDirection == 36 then displayedDirection = 0 end
            local commandButton = 3000 + 66 + displayedDirection / 10 -- divided by 10 because reasons
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        local function repeatTurn() -- testing...
            --[[
                if SlideSlider:getValue() == 0 then
                    while SlideSlider:getValue() == 0 do
                        Export.GetDevice(18):performClickableAction(3103, -1) -- 1 happens to only do it a bit
                    end
                elseif SlideSlider:getValue() == 2 then
                    while SlideSlider:getValue() == 2 do
                        Export.GetDevice(18):performClickableAction(3103, 1) -- right
                    end
                end
                --]]
        end

        function showAltitudeButtonValue()
            if AltitudeSlider:getValue() == 0 then
                AltitudeButton:setText("10 ft")
            elseif AltitudeSlider:getValue() == 1 then
                AltitudeButton:setText("20 ft")
            elseif AltitudeSlider:getValue() == 2 then
                AltitudeButton:setText("30 ft")
            elseif AltitudeSlider:getValue() == 3 then
                AltitudeButton:setText("40 ft")
            elseif AltitudeSlider:getValue() == 4 then
                AltitudeButton:setText("50 ft")
            elseif AltitudeSlider:getValue() == 5 then
                AltitudeButton:setText("60 ft")
            elseif AltitudeSlider:getValue() == 6 then
                AltitudeButton:setText("70 ft")
            elseif AltitudeSlider:getValue() == 7 then
                AltitudeButton:setText("80 ft")
            elseif AltitudeSlider:getValue() == 8 then
                AltitudeButton:setText("90 ft")
            elseif AltitudeSlider:getValue() == 9 then
                AltitudeButton:setText("100 ft")
            elseif AltitudeSlider:getValue() == 10 then
                AltitudeButton:setText("200 ft")
            elseif AltitudeSlider:getValue() == 11 then
                AltitudeButton:setText("300 ft")
            elseif AltitudeSlider:getValue() == 12 then
                AltitudeButton:setText("400 ft")
            elseif AltitudeSlider:getValue() == 13 then
                AltitudeButton:setText("500 ft")
            elseif AltitudeSlider:getValue() == 14 then
                AltitudeButton:setText("600 ft")
            elseif AltitudeSlider:getValue() == 15 then
                AltitudeButton:setText("700 ft")
            elseif AltitudeSlider:getValue() == 16 then
                AltitudeButton:setText("800 ft")
            elseif AltitudeSlider:getValue() == 17 then
                AltitudeButton:setText("900 ft")
            elseif AltitudeSlider:getValue() == 18 then
                AltitudeButton:setText("1000 ft")
            elseif AltitudeSlider:getValue() == 29 then
                AltitudeButton:setText("2000 ft")
            elseif AltitudeSlider:getValue() == 20 then
                AltitudeButton:setText("3000 ft")
            elseif AltitudeSlider:getValue() == 21 then
                AltitudeButton:setText("4000 ft")
            elseif AltitudeSlider:getValue() == 22 then
                AltitudeButton:setText("5000 ft")
            elseif AltitudeSlider:getValue() == 23 then
                AltitudeButton:setText("6000 ft")
            elseif AltitudeSlider:getValue() == 24 then
                AltitudeButton:setText("7000 ft")
            elseif AltitudeSlider:getValue() == 25 then
                AltitudeButton:setText("8000 ft")
            elseif AltitudeSlider:getValue() == 26 then
                AltitudeButton:setText("9000 ft")
            elseif AltitudeSlider:getValue() == 27 then
                AltitudeButton:setText("10000 ft")
            end
        end

        function changeAltitude()
            local sliderValue = AltitudeSlider:getValue()
            local commandButton = 3000 + 31 + sliderValue
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        function AIpress(button)
            local commandButton = button + 3000
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        --numbers from inputTable.lua
        RouteButton:addMouseDownCallback(
            function(self)
                AIpress(14)
            end
        )

        BaroButton:addMouseDownCallback(
            function(self)
                AIpress(6)
            end
        )
        RadaltButton:addMouseDownCallback(
            function(self)
                AIpress(13)
            end
        )
        TakeoffButton:addMouseDownCallback(
            function(self)
                AIpress(59)
            end
        )
        HoverButton:addMouseDownCallback(
            function(self)
                AIpress(8)
            end
        )
        LandButton:addMouseDownCallback(
            function(self)
                AIpress(60)
            end
        )
        MmsButton:addMouseDownCallback(
            function(self)
                AIpress(102)
            end
        )
        HudButton:addMouseDownCallback(
            function(self)
                AIpress(104)
            end
        )
        FlightplanButton:addMouseDownCallback(
            function(self)
                AIpress(15)
            end
        )
        OnoffButton:addMouseDownCallback(
            function(self)
                AIpress(7)
            end
        )
        AltitudeButton:addMouseDownCallback(
            function(self)
                changeAltitude()
            end
        )
        KnotsButton:addMouseDownCallback(
            function(self)
                changeSpeed()
            end
        )
        CourseButton:addMouseDownCallback(
            function(self)
                changeCourse()
            end
        )
        AltitudeSlider:addChangeCallback(
            function(self)
                showAltitudeButtonValue()
            end
        )
        KnotsSlider:addChangeCallback(
            function(self)
                KnotsButton:setText(KnotsSlider:getValue() * 10 .. " kts")
            end
        )
        TrueRelToggleButton:addMouseDownCallback(
            function(self)
                toggleNorthOrTrack()
            end
        )
        TrueRelDisplayButton:addMouseDownCallback(
            function(self)
                TrueRelDisplayButtonClicked()
            end
        )
        CourseSlider:addChangeCallback(
            function(self)
                local direction = CourseSlider:getValue() * 10
                if direction == 0 then direction = 360 end -- this will show 360 instead of 0
                CourseButton:setText(string.format("%03.0f", direction) .. "°")
                -- the format is so that directions less than 3 digits get leading 0s
            end
        )
        --[[
        -- Orbit Test
        SlideSlider:addChangeCallback( -- orbit left 17, right 16
            function(self)
                if SlideSlider:getValue() == 0 then
                    Export.GetDevice(18):performClickableAction(3017, 1)
                elseif SlideSlider:getValue() == 2 then
                    Export.GetDevice(18):performClickableAction(3016, 1)
                end
            end
        )
--]]
        -- Turn Test
        --[[
        SlideSlider:addChangeCallback( -- orbit left 17, right 16
            function(self)
                repeatTurn()
            end
        )
--]]
        --[[
--Example
        window:addHotKeyCallback(
            config.hotkeyVolUp,
            function()
                local newVolume = HeadingSlider:getValue() + 10
                if newVolume > 100 then newVolume = 100 end
                HeadingSlider:setValue(newVolume)
                setEffectsVolume(newVolume)
            end
        )
--]]

        if config.hideOnLaunch then
            hide()
            isHidden = true
        end

        lfs.mkdir(lfs.writedir() .. [[Config\KIO-WA\]])
        log("KIO-WA window created")
    end

    -- A generic rounding formula used for rounding course readouts
    function round10(num)
        return math.floor(num / 10 + 0.5) * 10
    end

    local handler = {}
    function handler.onSimulationFrame()
        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        if config == nil then
            loadConfiguration()
        end

        if not window then
            log("Creating KIO-WA window...")
            createBarundusUIWindow()
        end
        -- TODO: move all of this heading stuff to its own function
        -- Testing live heading. If you can get this you should be able to
        -- then calculate relative heading with the info from the course select dial.
        --local pitchRad, bankRad, hdgRad = Export.LoGetADIPitchBankYaw() -- this is true yaw/hdg
        local hdgRad = Export.LoGetMagneticYaw()  -- this is magnetic yaw/hdg
        local hdgDeg = math.abs(math.deg(hdgRad)) -- deg to rad formula is xdeg = rad(180/pi)
        --CurrentHeadingButton:setText(string.format("%03.0f", hdgDeg) .. "°") -- commented out to develop relative heading
        -- Now, make thte button turn to relative. relative = absolute heading + arrow direction
        local hdgRelative = hdgDeg + CourseDial:getValue()
        if hdgRelative > 360 then hdgRelative = hdgRelative - 360 end -- account for numbers past 360 degrees
        if hdgRelative == 0 then hdgRelative = 360 end                -- just here bc Barundus says 360
        --CurrentHeadingButton:setText(string.format("%03.0f", round10(hdgRelative)) .. "N UP") -- change the name of this button to relative hdg
        -- after varifying this works, you need to round the displayed headings so that the user knows
        -- which heading they will be commanding. Go to the commanded heading.

        -- Logic for the heading button that is toggled
        if isNorthUp == 0 then
            TrueRelDisplayButton:setText(string.format("%03.0f", round10(hdgRelative)) .. "°")
        else
            local direction = CourseDial:getValue()
            if direction == 0 then direction = 360 end -- this will show 360 instead of 0

            TrueRelDisplayButton:setText(string.format("%03.0f", round10(direction)) .. "°")
        end
    end

    function handler.onMissionLoadEnd()
        inMission = true
        -- Configure North/Track up button text
        toggleNorthOrTrack()
    end

    function handler.onSimulationResume()
        toggleNorthOrTrack()
    end

    function handler.onSimulationStop()
        inMission = false
    end

    DCS.setUserCallbacks(handler)

    net.log("[KIO-WA] Loaded ...")
end

local status, err = pcall(loadBarundusUI)
if not status then
    net.log("[KIO-WA] Load Error: " .. tostring(err))
end
