--[[
    -- Kiowa Integrated Overlay - Warrior Automatis --

    This project adds an onscreen ingame GUI with which you
    can command the OH-58D Kiowa AI, aka, Barundus.
    Most button information comes from the inputTables.lua file.
--]]

--[[
    Future Feature Goals:
    - Have NORTH UP or TRACK UP be displayed on spawn instead of having to click it once
    - Change the default hotkey. Cpuld have that in the window title or title tooltip
    - Show/Hide keybinds
    - Make a minimum window size
    - Have the "land" command bypass polychop's requirement to hover then land.
    - experement using one contril (the dial) for speed, alt, and course
    - talk about the config file for adjustments
    - Add more commands such as
    -- Increase/Decrease speed
    -- Hover Drift Left/Right
    -- Increase/Decrease altitude
    -- Adjust heading left/right
    -- may want to split on/off into 2 smaller buttons
    - research the possibility of using hardware buttons to toggle the GUI
    - If orbit is pressed and the aircraft is going slower than 10 kts,
    -- then order 10 kts and then order orbit.

    - Aircraft Detection - When the player is not flying the Kiowa, the
    GUI is hidden

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
    - Fix TRACK/NORTH up toggle
    - Fix altitude clicked
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
    |ON/OFF  |   HUD     |RESIZE|  HDG2MMS  | 🢀HOVER  |
    ----------------------------------------------------

    Full:
    -----------------------------------------
    |DIAL    |NORTH/TRACK|TAKEOFF|PLAN/ROUTE|
    |DIAL    |COURSE     |HOVER  |BARO/ALT  |
    |ALTITUDE|SPEED      |LAND   |TURN RATE |
    |ON/OFF  |   HUD     |HDG2MMS|  RESIZE  |
    -----------------------------------------

    Compact:
    ------------------------------
    |DIAL    |NORTH/TRACK|TAKEOFF|
    |DIAL    |COURSE     |HOVER  |
    |ALTITUDE|SPEED      |LAND   |
    |ON/OFF  |   HUD     |HDG2MMS|
    ------------------------------
--]]

local function loadKIOWAUI()
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
    local isBaroMode = 0
    local isRightMode = 0
    local isRouteMode = 0
    local windowSize = 1   -- 0 compact;1 full;3 expanded. TODO have this be saved in the config file
    local turnRateMode = 2 -- 0 slow;1 medium;2 fast
    local isNorthUp = 0    -- this determines if the default behaviour is TRACK UP or NORTH up
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

    local hotkey = "Ctrl+Shift+F9" --beta. may change in future

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
                hotkey         = "Ctrl+Shift+F9",      -- show/hide
                windowPosition = { x = 50, y = 50 },   -- these values were obtained by manually adjusting (original 430,754)
                windowSize     = { w = 253, h = 132 }, -- the window till I got something that looked ok
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
            local status, err = pcall(createKIOWAUIWindow)
            if not status then
                net.log("[KIO-WA] Error creating window: " .. tostring(err))
            end
        end

        window:setVisible(true)
        window:setSkin(windowDefaultSkin)
        panel:setVisible(true)
        window:setHasCursor(true)
        window:setText(' ' .. 'KIO-WA by Bailey (' .. hotkey .. ')')

        isHidden = false
    end

    local function hide() -- consider hiding when not in a mission
        window:setSkin(windowSkinHidden)
        panel:setVisible(false)
        window:setHasCursor(false)
        -- window.setVisible(false) -- if you make the window invisible, its destroyed
        isHidden = true
    end

    local function createKIOWAUIWindow()
        if window ~= nil then
            return
        end

        window = DialogLoader.spawnDialogFromFile(
            lfs.writedir() .. "Scripts\\KIO-WA\\KIO-WA.dlg",
            cdata
        )

        windowDefaultSkin = window:getSkin()
        panel = window.Box

        RouteButton = panel.c4r1Button
        TurnRateButton = panel.c4r3Button
        BaroButton = panel.c4r2Button
        SizeButton = panel.c3r4Button
        TakeoffButton = panel.c3r1Button
        HoverButton = panel.c3r2Button
        LandButton = panel.c3r3Button
        MmsButton = panel.c4r4Button

        HudButton = panel.c2r4Button
        OnoffButton = panel.c1r4Button
        AltitudeButton = panel.c1r3Button
        KnotsButton = panel.c2r3Button
        ParameterDial = panel.ParameterDial
        TrueRelToggleButton = panel.c2r1Button
        NorthTrackButton = panel.c2r2Button

        --new nomenclature format test for the 5th column
        LeftRightToggleButton = panel.c5r1Button
        OrbitButton = panel.c5r2Button
        TurnButton = panel.c5r3Button
        DriftHoverButton = panel.c5r4Button

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


        local function toggleNorthOrTrack()
            if isNorthUp == 1 then                      -- if calculating with True
                isNorthUp = 0                           -- change the bool, becuase we wanna toggle to relative
                TrueRelToggleButton:setText("TRACK UP") -- change the text to reflect the bool change
            else                                        -- if reference was 0
                isNorthUp = 1                           -- make it the opposite
                TrueRelToggleButton:setText("NORTH UP") -- set the text for the button
            end
        end

        function NorthTrackButtonClicked()
            local displayedDirection = NorthTrackButton:getText()
            -- TODO make a catch for someone pressing it before the dial used
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

        local function UpdateKts()
            -- there are 11 different speed commands. the dial is 0 to 360 degrees.
            -- each speed gets about 11/360th of the pie. That deterines what is shows
            -- on the button and which command is sent.
            local dialValue = ParameterDial:getValue()
            if dialValue < 33 then
                KnotsButton:setText("10 kts")
            elseif dialValue < (33 * 2) then
                KnotsButton:setText("20 kts")
            elseif dialValue < (33 * 3) then
                KnotsButton:setText("30 kts")
            elseif dialValue < (33 * 4) then
                KnotsButton:setText("40 kts")
            elseif dialValue < (33 * 5) then
                KnotsButton:setText("50 kts")
            elseif dialValue < (33 * 6) then
                KnotsButton:setText("60 kts")
            elseif dialValue < (33 * 7) then
                KnotsButton:setText("70 kts")
            elseif dialValue < (33 * 8) then
                KnotsButton:setText("80 kts")
            elseif dialValue < (33 * 9) then
                KnotsButton:setText("90 kts")
            elseif dialValue < (33 * 10) then
                KnotsButton:setText("100 kts")
            else
                KnotsButton:setText("110 kts")
            end
        end

        local function changeKts()
            -- there are 11 different speed commands. the dial is 0 to 360 degrees.
            -- each speed gets about 11/360th of the pie. That deterines what is shows
            -- on the button and which command is sent.
            local dialValue = ParameterDial:getValue()
            local sliderValue
            if dialValue < 33 then
                sliderValue = 0
            elseif dialValue < (33 * 2) then
                sliderValue = 1
            elseif dialValue < (33 * 3) then
                sliderValue = 2
            elseif dialValue < (33 * 4) then
                sliderValue = 3
            elseif dialValue < (33 * 5) then
                sliderValue = 4
            elseif dialValue < (33 * 6) then
                sliderValue = 5
            elseif dialValue < (33 * 7) then
                sliderValue = 6
            elseif dialValue < (33 * 8) then
                sliderValue = 7
            elseif dialValue < (33 * 9) then
                sliderValue = 8
            elseif dialValue < (33 * 10) then
                sliderValue = 9
            else
                sliderValue = 41
            end
            local commandButton = 3000 + 20 + sliderValue + 1 -- plus 1 bc oops.
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        function UpdateAlt() -- 28 entries
            if ParameterDial:getValue() < (13 * 1) then
                AltitudeButton:setText("10 ft")
            elseif ParameterDial:getValue() < (13 * 2) then
                AltitudeButton:setText("20 ft")
            elseif ParameterDial:getValue() < (13 * 3) then
                AltitudeButton:setText("30 ft")
            elseif ParameterDial:getValue() < (13 * 4) then
                AltitudeButton:setText("40 ft")
            elseif ParameterDial:getValue() < (13 * 5) then
                AltitudeButton:setText("50 ft")
            elseif ParameterDial:getValue() < (13 * 6) then
                AltitudeButton:setText("60 ft")
            elseif ParameterDial:getValue() < (13 * 7) then
                AltitudeButton:setText("70 ft")
            elseif ParameterDial:getValue() < (13 * 8) then
                AltitudeButton:setText("80 ft")
            elseif ParameterDial:getValue() < (13 * 9) then
                AltitudeButton:setText("90 ft")
            elseif ParameterDial:getValue() < (13 * 10) then
                AltitudeButton:setText("100 ft")
            elseif ParameterDial:getValue() < (13 * 11) then
                AltitudeButton:setText("200 ft")
            elseif ParameterDial:getValue() < (13 * 12) then
                AltitudeButton:setText("300 ft")
            elseif ParameterDial:getValue() < (13 * 13) then
                AltitudeButton:setText("400 ft")
            elseif ParameterDial:getValue() < (13 * 14) then
                AltitudeButton:setText("500 ft")
            elseif ParameterDial:getValue() < (13 * 15) then
                AltitudeButton:setText("600 ft")
            elseif ParameterDial:getValue() < (13 * 16) then
                AltitudeButton:setText("700 ft")
            elseif ParameterDial:getValue() < (13 * 17) then
                AltitudeButton:setText("800 ft")
            elseif ParameterDial:getValue() < (13 * 18) then
                AltitudeButton:setText("900 ft")
            elseif ParameterDial:getValue() < (13 * 19) then
                AltitudeButton:setText("1000 ft")
            elseif ParameterDial:getValue() < (13 * 20) then
                AltitudeButton:setText("2000 ft")
            elseif ParameterDial:getValue() < (13 * 21) then
                AltitudeButton:setText("3000 ft")
            elseif ParameterDial:getValue() < (13 * 22) then
                AltitudeButton:setText("4000 ft")
            elseif ParameterDial:getValue() < (13 * 23) then
                AltitudeButton:setText("5000 ft")
            elseif ParameterDial:getValue() < (13 * 24) then
                AltitudeButton:setText("6000 ft")
            elseif ParameterDial:getValue() < (13 * 25) then
                AltitudeButton:setText("7000 ft")
            elseif ParameterDial:getValue() < (13 * 26) then
                AltitudeButton:setText("8000 ft")
            elseif ParameterDial:getValue() < (13 * 27) then
                AltitudeButton:setText("9000 ft")
            else
                AltitudeButton:setText("10000 ft")
            end
        end

        function ChangeAlt()
            local value
            if ParameterDial:getValue() < (13 * 1) then
                value = 1
            elseif ParameterDial:getValue() < (13 * 2) then
                value = 2
            elseif ParameterDial:getValue() < (13 * 3) then
                value = 3
            elseif ParameterDial:getValue() < (13 * 4) then
                value = 4
            elseif ParameterDial:getValue() < (13 * 5) then
                value = 5
            elseif ParameterDial:getValue() < (13 * 6) then
                value = 6
            elseif ParameterDial:getValue() < (13 * 7) then
                value = 7
            elseif ParameterDial:getValue() < (13 * 8) then
                value = 8
            elseif ParameterDial:getValue() < (13 * 9) then
                value = 9
            elseif ParameterDial:getValue() < (13 * 10) then
                value = 10
            elseif ParameterDial:getValue() < (13 * 11) then
                value = 11
            elseif ParameterDial:getValue() < (13 * 12) then
                value = 12
            elseif ParameterDial:getValue() < (13 * 13) then
                value = 13
            elseif ParameterDial:getValue() < (13 * 14) then
                value = 14
            elseif ParameterDial:getValue() < (13 * 15) then
                value = 15
            elseif ParameterDial:getValue() < (13 * 16) then
                value = 16
            elseif ParameterDial:getValue() < (13 * 17) then
                value = 17
            elseif ParameterDial:getValue() < (13 * 18) then
                value = 18
            elseif ParameterDial:getValue() < (13 * 19) then
                value = 19
            elseif ParameterDial:getValue() < (13 * 20) then
                value = 20
            elseif ParameterDial:getValue() < (13 * 21) then
                value = 21
            elseif ParameterDial:getValue() < (13 * 22) then
                value = 22
            elseif ParameterDial:getValue() < (13 * 23) then
                value = 23
            elseif ParameterDial:getValue() < (13 * 24) then
                value = 24
            elseif ParameterDial:getValue() < (13 * 25) then
                value = 25
            elseif ParameterDial:getValue() < (13 * 26) then
                value = 26
            elseif ParameterDial:getValue() < (13 * 27) then
                value = 27
            else
                value = 28
            end
            local commandButton = 3000 + 30 + value
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        --[[
        function changeAltitude() -- to be updated to dial model
            local dialValue = ParameterDial:getValue()
            local commandButton = 3000 + 31 + dialValue
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end
        --]]



        function AIpress(button) -- this function presses the appropiate AI button
            local commandButton = button + 3000
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        --numbers from inputTable.lua
        BaroButton:addMouseDownCallback(
            function(self)
                if isBaroMode == 0 then
                    isBaroMode = 1
                    BaroButton:setText("BARO")
                    AIpress(6) -- baro
                else
                    isBaroMode = 0
                    AIpress(13) -- radalt
                    BaroButton:setText("RADALT")
                end
            end
        )
        SizeButton:addMouseDownCallback(
            function(self)
                -- empty
                -- resizes the gui
                -- 0 compact;1 full;3 expanded
                if windowSize == 0 then -- if compact, change to full
                    windowSize = 1
                    SizeButton:setText("RESIZE ▶")
                    window:setBounds(
                        config.windowPosition.x,
                        config.windowPosition.y,
                        333,                -- width,  4 columns
                        config.windowSize.h -- height, leave this alone
                    )
                elseif windowSize == 1 then -- if full, change to expanded
                    windowSize = 2
                    SizeButton:setText("◀ RESIZE")
                    window:setBounds(
                        config.windowPosition.x,
                        config.windowPosition.y,
                        411,                -- width, 5 columns
                        config.windowSize.h -- height, leave this alone
                    )
                else                        -- if expanded, change to compact
                    windowSize = 0
                    SizeButton:setText("RESIZE ▶")
                    window:setBounds(
                        config.windowPosition.x,
                        config.windowPosition.y,
                        253,                -- width, 3 columns
                        config.windowSize.h -- height, leave this alone
                    )
                end
            end
        )

        LeftRightToggleButton:addMouseDownCallback(
            function(self)
                LeftRightToggleButton:setText("LEFT/RIGHT") -- ▶◀
                if isRightMode == 0 then
                    OrbitButton:setText("◀ Orbit ")
                    TurnButton:setText("◀ Turn ")
                    DriftHoverButton:setText("◀ Hover ")
                    isRightMode = 1
                else
                    OrbitButton:setText(" Orbit ▶")
                    TurnButton:setText(" Turn ▶")
                    DriftHoverButton:setText(" Hover ▶")
                    isRightMode = 0
                end
            end
        )

        OrbitButton:addMouseDownCallback(
            function(self)
                if isRightMode == 0 then
                    AIpress(16) -- right
                else
                    AIpress(17) -- left
                end
            end
        )

        TurnButton:addMouseDownCallback(
            function(self)
                if isRightMode == 0 then
                    -- TODO
                else
                    -- TODO
                end
            end
        )
        DriftHoverButton:addMouseDownCallback(
            function(self)
                if isRightMode == 0 then
                    -- TODO
                else
                    -- TODO
                end
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
                -- When pressing land from forward flight, the command is not
                -- recognized. You would have to command hover, then command land.
                -- This is a workaround.
                AIpress(8)  -- hover
                AIpress(60) -- land
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
        TurnRateButton:addMouseDownCallback(
            function(self)
                if turnRateMode == 0 then -- slow, go medium
                    AIpress(64)           -- medium
                    TurnRateButton:setText("TURN MED")
                    turnRateMode = 1
                elseif turnRateMode == 1 then -- medium, go fast
                    AIpress(65)               -- fast
                    TurnRateButton:setText("TURN FAST")
                    turnRateMode = 2
                else            -- fast, go slow
                    AIpress(63) -- slow
                    TurnRateButton:setText("TURN SLOW")
                    turnRateMode = 0
                end
            end
        )
        RouteButton:addMouseDownCallback(
            function(self)
                if isRouteMode == 0 then
                    isRouteMode = 1
                    AIpress(14) -- route
                    RouteButton:setText("ROUTE")
                else
                    isRouteMode = 0
                    AIpress(15) -- flight plan
                    RouteButton:setText("PLAN")
                end
            end
        )
        OnoffButton:addMouseDownCallback(
            function(self)
                AIpress(7)
            end
        )
        AltitudeButton:addMouseDownCallback(
            function(self)
                ChangeAlt()
                --changeAltitude()
            end
        )
        KnotsButton:addMouseDownCallback(
            function(self)
                changeKts()
            end
        )



        TrueRelToggleButton:addMouseDownCallback(
            function(self)
                toggleNorthOrTrack()
            end
        )
        NorthTrackButton:addMouseDownCallback(
            function(self)
                NorthTrackButtonClicked()
            end
        )
        ParameterDial:addChangeCallback(
            function(self)
                UpdateAlt()
                UpdateCrs()
                UpdateKts()
                --OnoffButton:setText(ParameterDial:getValue()) -- debug  `
            end
        )




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

    function UpdateCrs()
        -- TODO: move all of this heading stuff to its own function
        --local pitchRad, bankRad, hdgRad = Export.LoGetADIPitchBankYaw() -- this is true yaw/hdg
        local hdgRad = Export.LoGetMagneticYaw()  -- this is magnetic yaw/hdg in radians TOOO: may have to movethis
        -- to every fram
        local hdgDeg = math.abs(math.deg(hdgRad)) -- radians to degrees. formula is xdeg = rad(180/pi)
        -- Now, make thte button turn to relative. relative = absolute heading + arrow direction
        local hdgRelative = hdgDeg + ParameterDial:getValue()
        if hdgRelative > 360 then hdgRelative = hdgRelative - 360 end -- account for numbers past 360 degrees
        if hdgRelative == 0 then hdgRelative = 360 end                -- just here bc Barundus says 360
        --CurrentHeadingButton:setText(string.format("%03.0f", round10(hdgRelative)) .. "N UP") -- change the name of this button to relative hdg
        -- after varifying this works, you need to round the displayed headings so that the user knows
        -- which heading they will be commanding. Go to the commanded heading.

        -- Logic for the heading button that is toggled
        if isNorthUp == 0 then
            if NorthTrackButton:getText() ~= "CRS" then -- TODO, should probs init this to 000 deg to prevent issues
                NorthTrackButton:setText(string.format("%03.0f", round10(hdgRelative)) .. "°")
            end
        else
            if NorthTrackButton:getText() ~= "CRS" then
                local direction = ParameterDial:getValue()
                if direction == 0 then direction = 360 end -- this will show 360 instead of 0

                NorthTrackButton:setText(string.format("%03.0f", round10(direction)) .. "°")
            end
        end
    end

    local function setAllText()
        RouteButton:setText("RTE/PLAN")
        TurnRateButton:setText("TURN RATE")
        BaroButton:setText("BARO/RAD")
        SizeButton:setText("RESIZE")
        TakeoffButton:setText("TAKEOFF")
        HoverButton:setText("HOVER")
        LandButton:setText("LAND")
        MmsButton:setText("HDG2MMS")

        HudButton:setText("HUD")
        OnoffButton:setText("ON/OFF")
        AltitudeButton:setText("ALT")
        KnotsButton:setText("KTS")
        TrueRelToggleButton:setText("TRK/NORTH")
        NorthTrackButton:setText("000") -- having this say CRS is breaking things

        --new nomenclature format test for the 5th column
        LeftRightToggleButton:setText("LEFT/RIGHT")
        OrbitButton:setText("ORBIT")
        TurnButton:setText("TURN")
        DriftHoverButton:setText("HOVER")
    end

    local function detectPlayerAircraft()
        -- the way that this is currently, it will stay on in kiowa, and after kiowa
        -- in the menus. when in a different aircraft it will dissapear. The hotkey
        -- cant turn it off in the kiowa because this checks the status every frame.
        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        if aircraft == "OH58D" then
            isHidden = false
            show()
        else
            isHidden = true
            hide()
        end
    end


    -- A generic rounding formula used for rounding course readouts
    function round10(num)
        return math.floor(num / 10 + 0.5) * 10
    end

    local handler = {}
    function handler.onSimulationFrame()
        if config == nil then
            loadConfiguration()
        end

        if not window then
            log("Creating KIO-WA window...")
            createKIOWAUIWindow()
        end

        UpdateCrs()
    end

    function handler.onMissionLoadEnd()
        inMission = true
        setAllText() -- sets the default button text for the app
        -- Configure North/Track up button text
        --toggleNorthOrTrack()
        -- TODO After testing, moveto own function
        --aircraftDetection()
        --function aircraftDetection()
        -- the way that this is currently, it will stay on in kiowa, and after kiowa
        -- in the menus. when in a different aircraft it will dissapear. The hotkey
        -- cant turn it off in the kiowa because this checks the status every frame.
        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        if aircraft == "OH58D" then
            isHidden = false
            show()
            --OnoffButton:setText(aircraft)
            --show()
            logFile:write(aircraft)
        else
            isHidden = true
            --OnoffButton:setText(aircraft)
            --hide()
            logFile:write(aircraft)
            hide()
        end
        --end
    end

    function handler.onSimulationStop()
        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        logFile:write("|onSimulationStop = " .. aircraft .. "|")
        inMission = false
        hide()
    end

    function handler.onSimulationResume() --onSimulationPause
        detectPlayerAircraft()
    end

    function handler.onPlayerChangeSlot() -- MP only
        detectPlayerAircraft()
    end

    function handler.onShowBriefing()
        detectPlayerAircraft()
    end

    DCS.setUserCallbacks(handler)

    net.log("[KIO-WA] Loaded ...")
end

local status, err = pcall(loadKIOWAUI)
if not status then
    net.log("[KIO-WA] Load Error: " .. tostring(err))
end
