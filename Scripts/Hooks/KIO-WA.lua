-- Kiowa Integrated Overlay - Warrior Automatis --

--[[ KIO-WA:
    This project adds an onscreen ingame GUI with which you
    can command the OH-58D Kiowa AI, aka, Barundus.
    Most button information comes from the inputTables.lua file.
--]]

--[[ Future Feature Goals:
    - Change the default hotkeys(?)
    - Make a minimum window size during resize
    - Add more commands such as
    -- Increase/Decrease speed
    -- Hover Drift Left/Right
    -- Increase/Decrease altitude
    -- Adjust heading left/right
    - research the possibility of using hardware buttons to toggle the GUI
    - Make everything "modular" (good luck) so that ppl can pick which "modules"
    they want to use. Would this feature go well in a Special Options menu? It is
    easy to make the modules, but having them tile properly may be the more difficult
    issue to solve.
    - Remove the margin gap at the top and sides of groups of buttons/controls
--]]

--[[Bugs:
    - When using the relative heading feature, it seems that turning
    right may result in 10 less expected degrees
--]]

--[[Change Notes:
    v0.4:
    - HDG2FACE - Barundus will turn the aircraft to the direction you are looking
    -- Default HDG2FACE hotkey is Shift+Ctrl+F10
    - Left click orbit button orbits left
    - Right click orbit button orbits right
    - Mouse wheel click orbit cancels orbit and flies straight
    - If an orbit is commanded from a hover, Barundus will orbit at 10 kts
    - Made a different button green
    - Added lots of notes and comments
    - Left/Right, Turn, and Drift are still nonfunctional

    v0.5
    - Hide on Launch option is available via the config file
    - App window will no longer automatically re-show itself after game is resumed
    - Heading 2 Face offset is available via the config file. Positive values are right, negative values are left, in degrees.
    - Aircraft will fly straight when Course/Route button middle mouse clicked (DCS-ism workaround)
    - Hotkeys cand be chnged via the config file
    - Fixed a condition where when 000/360 was commanded, Barundus would set heading to MMS instead
    - If you set the app window to be too big or small, it will be juuust right on the next restart
-]]

--[[Pretty pictures:
    Template:
    c = column, r = row
    ------------------------------------
    | c1r1 | c2r1 | c3r1 | c4r1 | c5r1 |
    | c1r2 | c2r2 | c3r2 | c4r2 | c5r2 |
    | c1r3 | c2r3 | c3r3 | c4r3 | c5r3 |
    | c1r4 | c2r4 | c3r4 | c4r4 | c5r4 |
    ------------------------------------

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
    local isBaroMode = false
    local isRightMode = false
    local isRouteMode = false
    local windowSize = 1   -- 0 compact;1 full;3 expanded. TODO have this be saved in the config file
    local turnRateMode = 2 -- 0 slow;1 medium;2 fast

    -- the show/hide hotkey text. beta. may change in future
    -- to be what the user set it as
    local hotkey = "Ctrl+Shift+F9"

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
                hideToggleHotkey = "Ctrl+Shift+F9",      -- show/hide
                windowPosition   = { x = 50, y = 50 },   -- default values should be on screen for any resolution
                windowSize       = { w = 253, h = 132 }, -- the window till I got something that looked ok
                hideOnLaunch     = false,
                Head2FaceHotkey  = "Ctrl+Shift+F10",     -- enables the function via hotkey
                Head2FaceOffset  = 30,                   -- this determines if the head2face features is offset by the user
                -- positve values are to the right, negatve values to the left. In degrees.
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

    -- button resize is dsiabled due to early development complexity
    local function handleResize(self)
        local w, h = self:getSize()

        panel:setBounds(0, 0, w, h - 20) -- TODO what is this -20 used for?

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

        -- determine the bounds of the minimum and maximum window width and height
        -- the minimum pair can be equal to the On/Off button
        -- the maximum pair can be equal to the most columns and rows
        local minHeight = 59
        local minWidth = 94
        local maxHeight = 132
        local maxWidth = 411
        if h < minHeight then h = minHeight end
        if w < minWidth then w = minWidth end
        if h > maxHeight then h = maxHeight end
        if w > maxWidth then w = maxWidth end

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

    local function hide()
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

        window                = DialogLoader.spawnDialogFromFile(
            lfs.writedir() .. "Scripts\\KIO-WA\\KIO-WA.dlg",
            cdata
        )

        windowDefaultSkin     = window:getSkin()
        panel                 = window.Box

        -- these are generically named so that a player/modder can
        -- change the positions of the buttons easily

        -- c1
        OnoffButton           = panel.c1r1Button
        HudButton             = panel.c1r2Button
        SizeButton            = panel.c1r3Button
        HideButton            = panel.c1r4Button

        -- c2
        OrbitButton           = panel.c2r1Button
        TakeoffButton         = panel.c2r2Button
        HoverButton           = panel.c2r3Button
        LandButton            = panel.c2r4Button

        -- c3
        NorthTrackButton      = panel.c3r1Button
        RelativeCrsButton     = panel.c3r2Button
        AltitudeButton        = panel.c3r3Button
        KnotsButton           = panel.c3r4Button

        -- c4
        Hdg2FaceButton        = panel.c4r1Button
        MmsButton             = panel.c4r2Button
        RouteButton           = panel.c4r3Button
        BaroButton            = panel.c4r4Button

        -- c5
        LeftRightToggleButton = panel.c5r1Button
        TurnButton            = panel.c5r2Button
        DriftHoverButton      = panel.c5r3Button
        TurnRateButton        = panel.c5r4Button

        -- random
        ParameterDial         = panel.ParameterDial

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
            config.hideToggleHotkey,
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

        -- Read the direction on the button and then
        -- fly that direction
        function NorthTrackButtonClicked()
            -- because we know what the text will be, we know that
            -- all of the directions end in 0, which means that
            -- they are already rounded
            local displayedDirection = NorthTrackButton:getText()
            -- strip out degree sign, leading 0s, and T (for True)
            displayedDirection = displayedDirection:gsub('°', '')  -- removes the degrees symbol
            displayedDirection = displayedDirection:gsub(' T', '') -- removes T for True
            displayedDirection = tonumber(displayedDirection)      -- removes the leading zero, if any
            -- this handes the case where the button may display 360, which is also 000
            -- it is needed for the then following commandButton math
            if displayedDirection == 360 then displayedDirection = 0 end
            if displayedDirection == 36 then displayedDirection = 0 end -- TODO remove this. unnecessary code
            local commandButton = 3000 + 66 + (displayedDirection / 10) -- divided by 10 for command calculation
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        -- This function gets the direction that the camera is facing, and then
        -- is able to tell the AI to fly that direction
        local function Hdg2FaceButtonClicked()
            -- Get the lat and long of the aircraft to calculate magnetic variation
            -- which is different based on location and date
            local selfData = Export.LoGetSelfData()
            local lat = selfData["LatLongAlt"]["Lat"]
            local long = selfData["LatLongAlt"]["Long"]

            local magvar = require('magvar')              -- necessary for the next line
            local magvar = magvar.get_mag_decl(lat, long) -- DCS magic
            -- the result is magvar in radians. Convert that
            -- to degrees. Then multiply by -1 beacause of how
            -- we later calculate that aginst the heading that the
            -- player is looking
            magvar = math.deg(magvar) * -1

            -- Get the heading of the direction that the player
            -- is looking. Thank you Grimes 2022.
            local cPos = Export.LoGetCameraPosition()
            local theta = math.atan2(cPos.x.z, cPos.x.x)
            local hdgDegTrue = math.deg(theta)

            -- the head2face offset will be added here because this is right before
            -- correcting for numbers less than or more than 360 degrees
            local result = hdgDegTrue + magvar + config.Head2FaceOffset -- the result in magnetic
            -- because we could be subtracting magvar, we dont want
            -- something line -7 degree when looking north. Add 360
            -- degrees for negative numbers to make them positive, yet
            -- still compass numbers.
            if result < 0 then result = result + 360 end
            -- making sure the result is within 0 and 360 in all situations
            if result > 360 then result = result - 360 end


            -- round the number to end in 0
            result = round10(result)
            -- this seems backwards, because if we command the resulting
            -- 36, that would be 35 + 1, which is out of the range of the
            -- commands as "Set heading MMS". TODO check this out
            if result == "360" then result = "0" end

            result = tonumber(result) / 10
            local commandButton = 3000 + 66 + (result)
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        -- When the AI is flying an orbit, sometimes you may
        -- want to stop the orbit and fly straing. In DCS the way
        -- that would normally be done is to either disengage the AI
        -- and reengage it. Or hover, then set your flying parameters
        -- after checking which course you want. This function leans
        -- off the HEAD2FACE function. The only difference is that
        -- it uses the headng of the aircraft, not the player face.
        local function stopOrbit()
            local selfData = Export.LoGetSelfData()
            local lat = selfData["LatLongAlt"]["Lat"]
            local long = selfData["LatLongAlt"]["Long"]

            local magvar = require('magvar')
            local magvar = magvar.get_mag_decl(lat, long)
            magvar = math.deg(magvar) * -1

            -- this is where we get the heading of the aircraft
            -- instead of the heading of the players faceing direction
            local aircraftHdg = Export.LoGetSelfData().Heading
            local hdgDegTrue = math.deg(aircraftHdg)

            local result = hdgDegTrue + magvar
            if result < 0 then result = result + 360 end

            result = round10(result)
            -- TODO, see if this makes sense for command
            -- button computation
            if result == "360" then result = "0" end

            result = tonumber(result) / 10
            local commandButton = 3000 + 66 + (result)
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        -- This function allows the player to turn a number of degrees
        -- relative to their current leading. Left or Right, up
        -- to 180 degrees.
        function TrackUpButtonClicked()
            -- Get the text of the button
            local displayedDirection = RelativeCrsButton:getText()
            -- if the turn is to the left, we will add negative to
            -- the positive
            local turnDirection = 0
            if string.find(displayedDirection, "L") then
                turnDirection = 1
            end

            -- These apparently have to go in this order. Tested in lua
            -- the goal is to strip the string down to its number only
            displayedDirection = displayedDirection:gsub('°', '')    -- removes the degrees symbol
            displayedDirection = displayedDirection:gsub(' REL', '') -- removes REL for relative
            displayedDirection = displayedDirection:gsub(' R', '')   -- removes R
            displayedDirection = displayedDirection:gsub(' L', '')   -- removes L
            displayedDirection = tonumber(displayedDirection)        -- removes the leading zero, if any

            -- this is how we calculate a turn to the left. If not used, you would
            -- get negative course numbers when turning left.
            if turnDirection == 1 then displayedDirection = math.abs(displayedDirection - 360) end

            local hdgRad = Export.LoGetMagneticYaw() -- this is magnetic yaw/hdg in radians
            -- radians to degrees. formula is xdeg = rad(180/pi)
            -- You should not have to math.abs this bc it should always be positive, TODO check this
            local hdgDeg = math.abs(math.deg(hdgRad))
            -- Now, make the button turn to relative. relative = absolute heading + arrow direction
            local hdgRelative = hdgDeg + displayedDirection
            if hdgRelative > 360 then hdgRelative = hdgRelative - 360 end -- account for numbers past 360 degrees
            -- TODO make sure this is ok for commandbutton for 350/0
            if hdgRelative == 360 then hdgRelative = 0 end
            -- divide by 10 to allow equation
            local commandButton = 3000 + 66 + (hdgRelative / 10)
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        -- generic function to press the requested button for the AI device (18)
        --AI press numbers are from inputTable.lua
        function AIpress(button) -- this function presses the appropiate AI button
            local commandButton = button + 3000
            Export.GetDevice(18):performClickableAction(commandButton, 1)
        end

        -- When the baro/radalt button is clicked the
        -- button will change. The status of the AI command
        -- is the same as the text that is shown.
        BaroButton:addMouseDownCallback(
            function(self)
                if isBaroMode == false then
                    AIpress(6) -- baro
                    isBaroMode = true
                    BaroButton:setText("BARO")
                else
                    AIpress(13) -- radalt
                    isBaroMode = false
                    BaroButton:setText("RADALT")
                end
            end
        )
        -- The resize button allwos the player to select the size
        -- of the app. The intent is that more commonly used items
        -- are on the smaller sizes, while the less used things
        -- are available on the larger sizes, and then can be
        -- re-resized afer their use.
        SizeButton:addMouseDownCallback(
            function(self)
                -- resizes the gui
                -- 0 compact;1 full;3 expanded
                -- TODO change this variable to "resize"
                if windowSize == 0 then -- if compact, change to full
                    -- TODO look into different arrow designs for this
                    -- and orbit
                    -- TODO look into making this button a left and right
                    -- click function. A left click makes it smaller. A
                    -- Right click makes it bigger. A middle click (if
                    -- the user chooses to do so), makes it full sized.
                    SizeButton:setText("RESIZE ▶")
                    window:setBounds(
                        config.windowPosition.x,
                        config.windowPosition.y,
                        333,                -- width,  4 columns
                        config.windowSize.h -- height, leave this alone
                    )
                    windowSize = 1
                elseif windowSize == 1 then -- if full, change to expanded
                    SizeButton:setText("◀ RESIZE")
                    window:setBounds(
                        config.windowPosition.x,
                        config.windowPosition.y,
                        411,                -- width, 5 columns
                        config.windowSize.h -- height, leave this alone
                    )
                    windowSize = 2
                else -- if expanded, change to compact
                    SizeButton:setText("RESIZE ▶")
                    window:setBounds(
                        config.windowPosition.x,
                        config.windowPosition.y,
                        253,                -- width, 3 columns
                        config.windowSize.h -- height, leave this alone
                    )
                    windowSize = 0
                end
            end
        )
        --[[
        LeftRightToggleButton:addMouseDownCallback(
            function(self)
                LeftRightToggleButton:setText("LEFT/RIGHT") -- ▶◀
                if isRightMode == false then
                    OrbitButton:setText("◀ Orbit ")
                    TurnButton:setText("◀ Turn ")
                    DriftHoverButton:setText("◀ Hover ")
                    isRightMode = true
                else
                    OrbitButton:setText(" Orbit ▶")
                    TurnButton:setText(" Turn ▶")
                    DriftHoverButton:setText(" Hover ▶")
                    isRightMode = false
                end
            end
        )
--]]
        -- Left click for orbit left.
        -- Right click for orbit right.
        -- Middle click for cancel orbit.
        -- TODO, find another design for orbit arrows
        OrbitButton:addMouseDownCallback(
            function(self, x, y, button)
                -- if the aircraft is in a hover and this is called, then the AI will execute the command
                -- but the aircraft will not move. To work around that DCS-ism, if the speed is less
                -- than 15 knots, command 10 knots and then command the orbit.
                if Export.LoGetIndicatedAirSpeed() < 13.5 then
                    local commandButton = 3000 + 20 + 1 --command 10 kts
                    Export.GetDevice(18):performClickableAction(commandButton, 1)
                end
                if button == 1 then     -- left click
                    AIpress(17)         -- orbit left
                elseif button == 3 then -- right click
                    AIpress(16)         -- orbit right
                elseif button == 2 then -- middle click
                    -- Stop the orbit, but continue flying in the direction
                    -- the aircraft was going when orbit stopped.
                    -- Similar to Heading2Face, but uses the aircraft heading.
                    stopOrbit()
                end
            end
        )

        -- WIP
        -- You have to figure out a way to command a continious turn without
        -- crashing DCS with a while loop
        TurnButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                --[[
                if isRightMode == false then
                    -- TODO heading left 103, -0.1
                    Export.GetDevice(18):performClickableAction(103, -1)
                else
                    -- TODO
                    Export.GetDevice(18):performClickableAction(103, 1)
                end
                --]]
            end
        )
        -- WIP
        -- Find a way to command drift left and right
        -- without crashing DCS with a while loop
        DriftHoverButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                if clicks == 1 then
                    if isRightMode == false then
                        -- TODO
                        -- left
                        Export.GetDevice(18):performClickableAction(107, 1)
                    else
                        -- TODO
                        -- right
                        Export.GetDevice(18):performClickableAction(106, 1)
                    end
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
        -- Due to a DCS-ism, when pressing land from forward flight, the command is not
        -- recognized. Here we command hover, then command land.
        LandButton:addMouseDownCallback(
            function(self)
                AIpress(8)  -- hover
                AIpress(60) -- land
            end
        )
        -- MMS to heading
        MmsButton:addMouseDownCallback(
            function(self)
                AIpress(102)
            end
        )
        -- hud toggle
        HudButton:addMouseDownCallback(
            function(self)
                AIpress(104)
            end
        )
        -- Toggles through all of the turn rates available
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
            function(self, x, y, button)
                if button == 2 then -- middle mouse click
                    stopOrbit()
                else                -- any other mouse butto
                    if isRouteMode == false then
                        isRouteMode = true
                        AIpress(14) -- route pt
                        RouteButton:setText("FLY2POINT")
                    else
                        isRouteMode = false
                        AIpress(15) -- flight plan
                        RouteButton:setText("FLT PLAN")
                    end
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

        HideButton:addMouseDownCallback( --testing
            function(self)
                hide()
                isHidden = true
            end
        )
        -- Turns the aircraft in the direction that
        -- the player is facing. Has a hotkey too
        Hdg2FaceButton:addMouseDownCallback( --testing
            function(self)
                Hdg2FaceButtonClicked()
            end
        )

        OnoffButton:addMouseDownCallback( -- original
            function(self)
                AIpress(7)
            end
        )

        -- A scrollable list of the altitudes available
        -- Left click the button for the altitude that is shown
        AltitudeButton:addMouseDownCallback(
            function(self)
                local alt = { "10 ft", "20 ft", "30 ft", "40 ft", "50 ft", "60 ft",
                    "70 ft", "80 ft", "90 ft", "100 ft", "200 ft", "300 ft", "400 ft", "500 ft", "600 ft",
                    "700 ft", "800 ft", "900 ft", "1000 ft", "2000 ft", "3000 ft", "4000 ft", "5000 ft", "6000 ft",
                    "7000 ft", "8000 ft", "9000 ft", "10000 ft" } -- 28 entries
                -- starting at 1, for the length of the array, at 1 at a time.
                -- Every time this for loop runs, i gets 1 bigger, and therefore
                -- moves to the next altitude in the string array
                for i = 1, #alt, 1 do
                    -- if the text of the button is the same as the array text
                    if AltitudeButton:getText() == alt[i] then
                        -- make i the number in the array
                        local commandButton = 3000 + 30 + i
                        -- press the button
                        Export.GetDevice(18):performClickableAction(commandButton, 1)
                    end
                end
            end
        )
        AltitudeButton:addMouseWheelCallback(
            function(self, x, y, clicks)
                -- create the string array. Apparently this is currently done every mouse
                -- wheel. Consider putting in a more accessable place. TODO
                local alt = { "10 ft", "20 ft", "30 ft", "40 ft", "50 ft", "60 ft",
                    "70 ft", "80 ft", "90 ft", "100 ft", "200 ft", "300 ft", "400 ft", "500 ft", "600 ft",
                    "700 ft", "800 ft", "900 ft", "1000 ft", "2000 ft", "3000 ft", "4000 ft", "5000 ft", "6000 ft",
                    "7000 ft", "8000 ft", "9000 ft", "10000 ft" } -- 28 entries
                -- store the text of the current altitude in the box
                -- I dont know why, but this is necessary for the logic that follows.
                local shownAltitude = AltitudeButton:getText()
                if clicks == 1 then -- scroll up on scroll wheel
                    -- The reason why you we stop 1 less than the end of the array is because if we evaluated at
                    -- end then the next string in the array is null, because it isnt there.
                    for i = 1, #alt - 1, 1 do -- starting at 1, do 27 times, in increments of 1
                        if alt[i] == shownAltitude then
                            -- set the text of the button as the next item in the array, because
                            -- the player wanted to get the next one
                            AltitudeButton:setText(alt[i + 1])
                        end
                    end
                    -- roll back to the start when getting to the end of the array.
                    -- if the altitude on the button equals the last entry of the array
                    if shownAltitude == alt[#alt] then
                        AltitudeButton:setText(alt[1])
                    end
                end

                -- the same as the above, but for scroll down
                -- The reason why you see a 2 is because if we evaluated at
                -- 1 then the next string in the array is null, because it
                -- isnt there. There is no 0th in the lua array.
                if clicks == -1 then
                    for i = #alt, 2, -1 do
                        if alt[i] == shownAltitude then
                            AltitudeButton:setText(alt[i - 1])
                        end
                    end
                    -- roll to "the end" when getting to the start of the array.
                    -- if the altitude on the button equals the first entry of the array
                    if shownAltitude == alt[1] then
                        AltitudeButton:setText(alt[#alt])
                    end
                end
            end
        )
        -- Scrollable and selectable Knots button. Notes are same as Altitude button
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
        -- Heading 2 face feature
        RelativeCrsButton:addMouseDownCallback(
            function(self)
                TrackUpButtonClicked()
            end
        )

        -- scrollable relative course. Notes similar to scrollable altitude
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

        -- The normal mode of commanding the ai though straight directions
        NorthTrackButton:addMouseDownCallback(
            function(self)
                NorthTrackButtonClicked()
            end
        )
        -- Scrollable button. Notes same as scrollable altitude
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
        --[[
        ParameterDial:addChangeCallback(
            function(self)
            end
        )
            --]]
        -- Hotkey for the heading 2 face feature. can
        -- can be changed by user in the config file
        window:addHotKeyCallback(
            config.Head2FaceHotkey,
            function()
                Hdg2FaceButtonClicked()
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

    -- sets the inital text for all of the buttons. Due to some lack of
    -- error checing, any acrollable button, like course, has to start
    -- with a value that is within the array.
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
        OnoffButton:setText("AI PILOT")
        AltitudeButton:setText("10 ft")
        KnotsButton:setText("10 kts")         -- or KTS
        RelativeCrsButton:setText("000° REL") -- 010° L or 010° R
        NorthTrackButton:setText("360° T")

        LeftRightToggleButton:setText("LEFT/RIGHT") -- TODO remove this feature
        OrbitButton:setText("◀ORBIT▶") -- TODO find new arrows. Maybe make them customizable
        TurnButton:setText("TURN")
        DriftHoverButton:setText("DRIFT")
        HideButton:setText("HIDE")
        Hdg2FaceButton:setText("HDG2FACE")
    end

    local function detectPlayerAircraft()
        -- the way that this is currently, it will stay on in kiowa, and after kiowa
        -- in the menus. when in a different aircraft it will dissapear.
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
    -- eg 45 will round to 50
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
            setAllText() -- sets the default button text for the app button
        end
    end

    function handler.onMissionLoadEnd()
        inMission = true
        setAllText()                       -- sets the default button text for the app
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
    end

    function handler.onSimulationStop()
        aircraft = DCS.getPlayerUnitType() -- get the player's aircraft, KW is "OH58D"
        logFile:write("|onSimulationStop = " .. aircraft .. "|")
        inMission = false
        hide() -- hides the app when returning to the main game menus
    end

    --[[
    function handler.onSimulationResume() --onSimulationPause is the opposite
        detectPlayerAircraft()
    end
--]]
    function handler.onPlayerChangeSlot() -- MP only
        detectPlayerAircraft()
    end

    --[[
    function handler.onShowBriefing()
        detectPlayerAircraft()
    end
--]]
    DCS.setUserCallbacks(handler)

    net.log("[KIO-WA] Loaded ...")
end

local status, err = pcall(loadKIOWAUI)
if not status then
    net.log("[KIO-WA] Load Error: " .. tostring(err))
end
