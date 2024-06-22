# Kiowa Integrated Overlay - Warrior Automatis

KIO-WA is an in-game clickable command overlay for the DCS OH-58D Kiowa Warrior that can use with your mouse or point device. 
It also frees up keybinds and HOTAS buttons. Download the most recent stable release here at [Releases](https://github.com/asherao/KIO-WA/releases). Join the conversation on the [ED Forums](https://forum.dcs.world/topic/351441-kiowa-integrated-overlay-warrior-automatis-kio-wa).

Init<br>
![KIO-WA v0 6_1](https://github.com/asherao/KIO-WA/assets/15984377/3dea572c-bc01-4322-9d0a-6c291f3452ee)

During Mission<br>
![KIO-WA v0 6_2](https://github.com/asherao/KIO-WA/assets/15984377/7ddc0d51-51de-4cf9-a301-1c4b5e54d39e)
<br>
## Layout
| Column 1| Column 2 | Column 3 | Column 4 | Column 5 |
|     :---:      |          :---: |   :---: |         :---: |         :---: |
| AI Pilot     | ORBIT    |TURN RATE     | HDG2FACE    | DRIFT     |
| HUD       | TAKEOFF      |ABS HDG     | HDG2MMS    | TURN REL     |
| HIDE    | HOVER    |ABS FEET     | BARO/RADALT    | ALTITUDE REL     |
|RESIZE       | LAND      |ABS KNOTS     | RTE/POINT    | KTS REL     |

## Buttons
**AI PILOT** - Toggles Barundus AI.<br>
**HUD** - Toggles HUD.<br>
**HIDE** - Hides the KIO-WA app.<br>
**RESIZE** - Toggles KIO-WA between Compact (3 columns), Full (4 columns), and Expanded (5 columns) sizes.<br>
<br>
**ORBIT** - Left click, orbit left. Right click, orbit right. Middle mouse click to cancel orbit.<br>
**TAKEOFF** - Takeoff.<br>
**HOVER** - Hover.<br>
**LAND** - Land.<br>
<br>
**TURN RATE** - Toggle between Fast, Medium, and Slow.<br>
**ABSOLUTE HEADING** - Turn this heading when clicked.<br>
**ABSOLUTE ALTITUDE** - Command this altitude when left clicked. Override Barundus when middle mouse clicked.<br>
**ABSOLUTE KNOTS** - Go this fast when left clicked.<br>
<br>
**HEADING 2 FACE** - When left clicked, turn the direction you are looking.<br>
**HEADING 2 MMS** - When left clicked, turn the direction of the Mast Mounted Sight.<br>
**BARO/RADALT** - Toggle between barometric flight and terrain following flight.<br>
**ROUTE/POINT** - Toggle between following the current route and going to the current active point.<br>
<br>
**DRIFT** - Scroll wheel to adjust offset. Left click to apply offset to the left. Right click to apply offset to the right. Middle Mouse Click to set drift to 0 and cancel drift flight.<br>
**TURN RELATIVE** - Scroll wheel to adjust offset. Left click to apply offset to the left. Right click to apply offset to the right. Middle mouse click to reset button.<br>
**ALTITUDE RELATIVE** - Scroll wheel to adjust offset. Left click to apply offset climb. Right click to apply offset descend. Middle mouse click to reset button.<br>
**KNOTS RELATIVE** - Scroll wheel to adjust offset. Left click to apply offset accelerate. Right click to apply offset decelerate. Middle mouse click to reset button.<br>
<br>
## Config
After launching DCS with KIO-WA installed, a configuration file will be generated in `DCS Saved Games Location\Config\KIO-WA\KIO-WAConfig.lua`. You can edit this file.
<br><br>
**hideToggleHotkey** - Defines the hotkey used to toggle KIO-WA visibility.<br>
**Head2FaceHotkey** - Defines the hotkey to use with the Heading 2 Face feature.<br>
**Head2FaceOffset** - Defines the number of degrees Heading 2 Face is offset. Negative numbers are Left.<br>
**hideOnLaunch** - When set to true, hides KIO-WA on launch.<br>
**windowPosition** - Where KIO-WA is on the screen. X is right, Y is down. Consider adjusting for VR.<br>
**avoidCFIT** - When set to true, Barundus will not listen to BARO Button commands that would result in Controlled Flight Into Terrain. Can be overridden with middle mouse click on the Altitude Button.<br>
**windowSize** - KIO-WA window size. Resist Adjusting.<br>
**driftStep** - Number of relative drift units per scroll wheel action for Drift Button.<br>
**turnStep** - Number of degrees per scroll wheel action for Relative Turn Button.<br>
**altitudeStep** - Number of feet per scroll wheel action for Relative Altitude Button.<br>
**knotsStep** - Number of knots per scroll wheel action for Relative Knots Button.<br>

I encourage adding your own innovations to this utility and sharing your creation and modifications with the community. 

Old Demo Video On YouTube (click)

[![KIO-WA Demo](https://img.youtube.com/vi/wVOmkaB1c6A/0.jpg)](https://www.youtube.com/watch?v=wVOmkaB1c6A)
