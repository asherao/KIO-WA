--[[
    -- Kiowa Integrated Overlay - Warrior Automatis --

    This project adds an onscreen ingame GUI with which you
    can command the OH-58D Kiowa AI, aka, Barundus.
    Most button information comes from the inputTables.lua file.
--]]

--[[
    Future Feature Goals:
    - Change the default hotkey.
    - Show/Hide keybinds
    - Make a minimum window size
    - Add more commands such as
    -- Increase/Decrease speed
    -- Hover Drift Left/Right
    -- Increase/Decrease altitude
    -- Adjust heading left/right
    -- may want to split on/off into 2 smaller buttons
    - research the possibility of using hardware buttons to toggle the GUI
    - If orbit is pressed and the aircraft is going slower than 10 kts,
    -- then order 10 kts and then order orbit.

    - Make everything "modular" (good luck) so that ppl can pick which "modules"
    they want to use. Would this feature go well in a Special Options menu? It is
    easy to make the modules, but having them tile properly may be the more difficult
    issue to solve.
    - Remove the margin gap at the top and sides of groups of buttons/controls
--]]

--[[
    TODO:
    - Cleanup scroll wheel version
--]]

--[[
    Bugs:
--]]

--[[
Pretty pictures:
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
        RelativeCrsButton = panel.c2r1Button
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

        function NorthTrackButtonClicked()
            local displayedDirection = NorthTrackButton:getText()
            -- TODO make a catch for someone pressing it before the dial used
            -- strip out degree sign and leading 0s
            displayedDirection = displayedDirection:gsub('°', '')  -- removes the degrees symbol
            displayedDirection = displayedDirection:gsub(' T', '') -- removes T for True
            displayedDirection = tonumber(displayedDirection)      -- removes the leading zero, if any
            -- this handes the case where the button may display 360, which is actually 000
            -- it is needed for the then following commandButton math
            if displayedDirection == 360 then displayedDirection = 0 end
            if displayedDirection == 36 then displayedDirection = 0 end
            local commandButton = 3000 + 66 + displayedDirection / 10 -- divided by 10 because reasons
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        function TrackUpButtonClicked()
            local displayedDirection = RelativeCrsButton:getText()
            -- TODO make a catch for someone pressing it before the dial used
            -- strip out degree sign and leading 0s
            local turnDirection = 0
            if string.find(displayedDirection, "L") then
                turnDirection = 1
            end


            displayedDirection = displayedDirection:gsub('°', '')    -- removes the degrees symbol
            displayedDirection = displayedDirection:gsub(' REL', '') -- removes REL for relative
            displayedDirection = displayedDirection:gsub(' R', '')   -- removes REL for relative
            displayedDirection = displayedDirection:gsub(' L', '')   -- removes REL for relative
            displayedDirection = tonumber(displayedDirection)        -- removes the leading zero, if any

            if turnDirection == 1 then displayedDirection = math.abs(displayedDirection - 360) end

            local hdgRad = Export.LoGetMagneticYaw()  -- this is magnetic yaw/hdg in radians TOOO: may have to movethis
            -- to every fram
            local hdgDeg = math.abs(math.deg(hdgRad)) -- radians to degrees. formula is xdeg = rad(180/pi)
            -- Now, make thte button turn to relative. relative = absolute heading + arrow direction
            local hdgRelative = hdgDeg + displayedDirection
            if hdgRelative > 360 then hdgRelative = hdgRelative - 360 end -- account for numbers past 360 degrees
            if hdgRelative == 0 then hdgRelative = 360 end                -- just here bc Barundus says 360
            local commandButton = 3000 + 66 + (hdgRelative / 10)          -- divided by 10 to allow equation
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

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

        TurnButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                --[[ -- WIP
                if isRightMode == 0 then
                    -- TODO heading left 103, -0.1
                    Export.GetDevice(18):performClickableAction(103, -1)
                else
                    -- TODO
                    Export.GetDevice(18):performClickableAction(103, 1)
                end
                --]]
            end
        )
        DriftHoverButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                --[[ -- WIP
                if isRightMode == 0 then
                    -- TODO
                    -- left
                    Export.GetDevice(18):performClickableAction(107, 1)
                else
                    -- TODO
                    -- right
                    Export.GetDevice(18):performClickableAction(106, 1)
                end
                --]]
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

        RouteButton:addMouseDownCallback( -- TODO check if logic correct, testing
            function(self)
                if isRouteMode == 0 then
                    isRouteMode = 1
                    AIpress(14) -- route pt
                    RouteButton:setText("FLY2POINT")
                else
                    isRouteMode = 0
                    AIpress(15) -- flight plan
                    RouteButton:setText("FLT PLAN")
                end
            end
        )
        --[[
        OnoffButton:addMouseDownCallback( --testing
            function(self, x, y, button)
                if button == 1 then
                    logFile:write("Button01 pressed|") -- left click
                elseif button == 2 then
                    logFile:write("Button02 pressed|") -- middle click
                elseif button == 3 then
                    logFile:write("Button03 pressed|") -- right click
                else
                    logFile:write("Buttonelse pressed|")
                end
            end
        )
            --]]

        OnoffButton:addMouseDownCallback( --testing
            function(self)
                AIpress(7)
            end
        )

        AltitudeButton:addMouseDownCallback(
            function(self)
                local alt = { "10 ft", "20 ft", "30 ft", "40 ft", "50 ft", "60 ft",
                    "70 ft", "80 ft", "90 ft", "100 ft", "200 ft", "300 ft", "400 ft", "500 ft", "600 ft",
                    "700 ft", "800 ft", "900 ft", "1000 ft", "2000 ft", "3000 ft", "4000 ft", "5000 ft", "6000 ft",
                    "7000 ft", "8000 ft", "9000 ft", "10000 ft" } -- 28 entries
                for i = 1, #alt, 1 do
                    if AltitudeButton:getText() == alt[i] then
                        local commandButton = 3000 + 30 + i
                        Export.GetDevice(18):performClickableAction(commandButton, 1)
                    end
                end
            end
        )
        AltitudeButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                --create array to type less
                local alt = { "10 ft", "20 ft", "30 ft", "40 ft", "50 ft", "60 ft",
                    "70 ft", "80 ft", "90 ft", "100 ft", "200 ft", "300 ft", "400 ft", "500 ft", "600 ft",
                    "700 ft", "800 ft", "900 ft", "1000 ft", "2000 ft", "3000 ft", "4000 ft", "5000 ft", "6000 ft",
                    "7000 ft", "8000 ft", "9000 ft", "10000 ft" } -- 28 entries
                local shownAltitude = AltitudeButton:getText()
                if clicks == 1 then
                    for i = 1, #alt - 1, 1 do -- starting at 1, do 27 times, in increments of 1
                        if alt[i] == shownAltitude then
                            AltitudeButton:setText(alt[i + 1])
                        end
                    end
                    -- roll to the start
                    if shownAltitude == alt[#alt] then
                        AltitudeButton:setText(alt[1])
                    end
                end

                if clicks == -1 then
                    for i = #alt, 2, -1 do
                        if alt[i] == shownAltitude then
                            AltitudeButton:setText(alt[i - 1])
                        end
                    end
                    -- roll to the start
                    if shownAltitude == alt[1] then
                        AltitudeButton:setText(alt[#alt])
                    end
                end
            end
        )
        KnotsButton:addMouseDownCallback(
            function(self)
                local speeds = { "10 kts", "20 kts", "30 kts", "40 kts", "50 kts", "60 kts",
                    "70 kts", "80 kts", "90 kts", "100 kts", "110 kts" } -- 11 entries

                for i = 1, #speeds, 1 do
                    if KnotsButton:getText() == speeds[i] then
                        if speeds[i] == "110 kts" then i = 41 end
                        local commandButton = 3000 + 20 + i
                        Export.GetDevice(18):performClickableAction(commandButton, 1)
                    end
                end
            end
        )
        KnotsButton:addMouseWheelCallback( -- TODO check if logic correct, testing
            function(self, x, y, clicks)
                --create array to type less
                local kts = { "10 kts", "20 kts", "30 kts", "40 kts", "50 kts", "60 kts",
                    "70 kts", "80 kts", "90 kts", "100 kts", "110 kts" } -- 11 entries

                local shownKts = KnotsButton:getText()
                if clicks == 1 then
                    for i = 1, #kts - 1, 1 do -- starting at 1, do 27 times, in increments of 1
                        if kts[i] == shownKts then
                            KnotsButton:setText(kts[i + 1])
                        end
                    end
                    -- roll to the start
                    if shownKts == kts[#kts] then
                        KnotsButton:setText(kts[1])
                    end
                end

                if clicks == -1 then
                    for i = #kts, 2, -1 do
                        if kts[i] == shownKts then
                            KnotsButton:setText(kts[i - 1])
                        end
                    end
                    -- roll to the start
                    if shownKts == kts[1] then
                        KnotsButton:setText(kts[#kts])
                    end
                end
            end
        )
        RelativeCrsButton:addMouseDownCallback(
            function(self)
                TrackUpButtonClicked()
            end
        )

        RelativeCrsButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                local crs = { "000° REL", "010° R", "020° R", "030° R", "040° R", "050° R", "060° R", "070° R", "080° R",
                    "090° R",
                    "100° R", "110° R",
                    "120° R", "130° R", "140° R", "150° R", "160° R", "170° R", "180° REL", "170° L", "160° L",
                    "150° L", "140° L", "130° L", "120° L", "110° L", "100° L", "090° L", "080° L", "070° L", "060° L",
                    "050° L", "040° L", "030° L", "020° L", "010° L" }


                local shownCrs = RelativeCrsButton:getText()
                if clicks == 1 then
                    for i = 1, #crs - 1, 1 do -- starting at 1, do 27 times, in increments of 1
                        if crs[i] == shownCrs then
                            RelativeCrsButton:setText(crs[i + 1])
                        end
                    end
                    -- roll to the start
                    if shownCrs == crs[#crs] then
                        RelativeCrsButton:setText(crs[1])
                    end
                end

                if clicks == -1 then
                    for i = #crs, 2, -1 do
                        if crs[i] == shownCrs then
                            RelativeCrsButton:setText(crs[i - 1])
                        end
                    end
                    -- roll to the start
                    if shownCrs == crs[1] then
                        RelativeCrsButton:setText(crs[#crs])
                    end
                end
            end
        )

        NorthTrackButton:addMouseDownCallback(
            function(self)
                NorthTrackButtonClicked()
            end
        )
        NorthTrackButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                local crs = { "010° T", "020° T", "030° T", "040° T", "050° T", "060° T", "070° T", "080° T", "090° T",
                    "100° T", "110° T",
                    "120° T", "130° T", "140° T", "150° T", "160° T", "170° T", "180° T", "190° T", "200° T", "210° T",
                    "220° T", "230° T",
                    "240° T", "250° T",
                    "260° T", "270° T", "280° T", "290° T", "300° T", "310° T", "320° T", "330° T", "340° T", "350° T",
                    "360° T" }

                local shownCrs = NorthTrackButton:getText()
                if clicks == 1 then
                    for i = 1, #crs - 1, 1 do -- starting at 1, do 27 times, in increments of 1
                        if crs[i] == shownCrs then
                            NorthTrackButton:setText(crs[i + 1])
                        end
                    end
                    -- roll to the start
                    if shownCrs == crs[#crs] then
                        NorthTrackButton:setText(crs[1])
                    end
                end

                if clicks == -1 then
                    for i = #crs, 2, -1 do
                        if crs[i] == shownCrs then
                            NorthTrackButton:setText(crs[i - 1])
                        end
                    end
                    -- roll to the start
                    if shownCrs == crs[1] then
                        NorthTrackButton:setText(crs[#crs])
                    end
                end
            end
        )

        ParameterDial:addChangeCallback(
            function(self)
                --UpdateAlt()
                --UpdateCrs() -- testing change to course buttin behaviour
                --UpdateKts()
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
        RouteButton:setText("RTE/POINT")
        TurnRateButton:setText("TURN RATE")
        BaroButton:setText("BARO/RAD")
        SizeButton:setText("RESIZE")
        TakeoffButton:setText("TAKEOFF")
        HoverButton:setText("HOVER")
        LandButton:setText("LAND")
        MmsButton:setText("HDG2MMS")

        HudButton:setText("HUD")
        OnoffButton:setText("ON/OFF")
        AltitudeButton:setText("10 ft")
        KnotsButton:setText("10 kts")         -- or KTS
        RelativeCrsButton:setText("000° REL") -- 010° L or 010° R
        NorthTrackButton:setText("360° T")    -- having this say CRS is breaking things

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
            setAllText() -- sets the default button text for the app
        end

        -- dont update for NORTH UP
        -- update for TRACK UP
        --UpdateCrs() -- testing for a scrool wheel course
    end

    function handler.onMissionLoadEnd()
        inMission = true
        setAllText() -- sets the default button text for the app
        -- Configure North/Track up button text
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
