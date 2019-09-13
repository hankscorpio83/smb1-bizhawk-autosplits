--this script was written by hankscorpio and is based off of hubcapp's script which is based off of i_o_l's timer script
--increased functionality is thanks to memory addresses found at http://datacrystal.romhacking.net/wiki/Super_Mario_Bros.:RAM_map

--"personalBests" are stored as frames per level, separated by commas in the table above.

--levels are defined as the amount of frames between when mario first takes control (first frame after the black title screen of each level)
--  and the end of the title screen for the next level, up until 8-4 where the end of the level condition is shown in the code below (you hit the axe)

--If you're not sure how to find these, it's the number after the time in splits displayed by this script
--Leave levels that you are not using for the run equal to 0 (e.g., you could set only 1-1, 1-2, 4-1, 4-2, 8-1, 8-2, 8-3, and 8-4)

personalBests = {
{0,0,0,0}, -- W1, {1-1,1-2,1-3,1-4}
{0,0,0,0}, -- W2
{0,0,0,0}, -- W3
{0,0,0,0}, -- W4
{0,0,0,0}, -- W5
{0,0,0,0}, -- W6
{0,0,0,0}, -- W7
{0,0,0,0}  -- W8
};

--Here are some other variables you might want to change

displaySplits = true; --completely disables splits (at top left) if false
displayFrameOffset = true; --this shows how many framerules you're ahead/behind compared to your personal best on a single level
offsetSplitsUnits = "seconds"; --valid values are "frames", "framerules", or "seconds". This is what unit displayFrameOffset is in.
displayFrames = false; --Always show how many frames it takes you to complete a level, not just when you PB
framesUnits = "seconds"; --valid values are "frames", "framerules", or "seconds". This is what unit displayFrameOffset is in.
splitsToDisplay = 8; --how many splits to display on screen at once. Should be between 0 and 25 with default values for splitY and timerY to not overlap any other message boxes. 5 is a good value to not block very much on screen (other than score)
lineColour = "#440000"; --the colour of the seperator bars in splits
displayCoin2 = false; --display a second coin counter over the word "WORLD" whenever the coin counter is obscured by splits
displayFrameruleCounter = false; --this is the counter at the bottom left that shows how many framerules have elapsed since the console was turned on
displayFrameruleOffset = false; --display total framerule offset in the bottom right for pro players who are consistent enough to manipulate RNG
offsetUnits = "framerules"; --valid values are "frames", "framerules", or "seconds". This is what unit displayFrameruleOffset is in.
displayAllInfoOnWin = true; --even if you have splits, offsets, frames, etc disabled for the actual run, once you beat the game, we can display them. splitsToDisplay is also set to maxSplits
splitsToDisplay = 8; --how many splits to display on screen at once. Should be between 0 and 25 with default values for splitY and timerY to not overlap any other message boxes. 5 is a good value to not block very much on screen (other than score)


--if it matters to you, every split actually happens 5 frames after the framerule rolls over from 20 back to 0 (except for 8-4)

------------------------------------------------------------------------

timerX = 400; --pixels from the left that the time string should stop at
timerY = 8; --pixels from the top to draw frame counter and time string
totalSeconds = 0; seconds = 0; minutes = 0; hours = 0;
 
bowser8 = false;
hitAxe = false;
once = false; --this is used so we don't run the code for detecting the axe was hit more than once
finalSeconds = 0; finalMinutes = 0; finalHours = 0;
startFrame = -1;
gameOver = false;
noContinue = false;
levelChanged = false;
offScript = false;
lastWorld = 1;
lastLevel = 1;

splitY = 8; --y coordinate at which to put the first split. best if this is a multiple of 8 to overlap MARIO and SCORE cleanly
maxSplits = 25; --this is the maximum amount of splits that will fit on screen
splitArray = {}; --holds split times (and how wide they are in pixels)
frameArray = {}; --holds split times in "frames since start"
worldArray = {}; --holds the name of the world just completed

keyPressed = false; --used to prevent toggling multiple times if user doesn't do a frame perfect toggle
nesClockSpeed = (39375000/655171); --(39375000/655171) is ~60.098, the "true clock speed" of the NES
frameSecond = 1/nesClockSpeed; --how many seconds each frame takes (0.016 ish)

function sanityCheck()
    if offsetSplitsUnits ~= "framerules" and offsetSplitsUnits ~= "frames" and offsetSplitsUnits ~= "seconds" then
        return "offsetSplitsUnits is invalid";
    end;
    if framesUnits ~= "framerules" and framesUnits ~= "frames" and framesUnits ~= "seconds" then
        return "framesUnits is invalid";
    end;
    if offsetUnits ~= "framerules" and offsetUnits ~= "frames" and offsetUnits ~= "seconds" then
        return "offsetUnits is invalid";
    end;
    return "sane";
end;
sanityStatus = sanityCheck();

function personalBestsToFlat(personalBests) --converts "user friendly" personal best array to a flat array which is easier to work with
    local personalBestsFlat = {};
    for i=1,8 do
        for j=1,4 do
            if personalBests[i][j] ~= 0 then
                personalBestsFlat[#personalBestsFlat + 1] = personalBests[i][j];
            end;
        end;
    end;
    
    return personalBestsFlat;
end;

personalBestsFlat = personalBestsToFlat(personalBests);
personalBestsSet = true;
if #personalBestsFlat == 0 then --user has not configured any personal best times
    personalBestsSet = false;
end;

function round(num, idp)
    local mult = 10^(idp or 0);
    return math.floor(num * mult) / mult;
end;

function formatSplitString(split, unit, addPlus)
    local splitString = "";
    if (split >= 0) and addPlus then
        splitString = splitString .. "+";
    end;
	if unit == "frames" then
        splitString = splitString .. split;
    else
		if unit == "seconds" then
			splitString = splitString .. round2(split * frameSecond, 3);
		end;--seconds
	end;--frames
    return {["split"]=splitString};
end;

function round2(num, numDecimalPlaces)
  return string.format("%." .. (numDecimalPlaces or 0) .. "f", num)
end

function formatTimerString(hours, minutes, seconds)
	--console.log('formatting time: ' .. hours .. ':' .. minutes .. ':' .. seconds);
    timerString = "";

    --Hours
    if hours > 0 then --don't need to display hours at all if we're under 60 minutes
		--console.log('hours if');
        timerString = timerString .. round2(hours, 0);

        if minutes < 10 then
			--console.log('minutes < 10');
            timerString = timerString .. ":0";
        else
			--console.log('minutes >= 10');
            timerString = timerString .. ":";
        end;
    end;
	--console.log('formatted time: ' .. timerString);
    
    --Minutes
    timerString = timerString .. round2(minutes, 0);
	--console.log('formatted time: ' .. timerString);

    --Seconds
    if seconds < 10 then
		--console.log('seconds < 10');
        timerString = timerString .. ':0' .. round2(seconds, 3); --displaying the timer, we need a leading zero on the seconds
		--console.log('formatted time: ' .. timerString);
    else
		--console.log('seconds > 10');
        timerString = timerString .. ':'  .. round2(seconds, 3); --we do not need a leading zero on the seconds
		--console.log('formatted time: ' .. timerString);
    end;

    return {["timer"]=timerString};
end;

function resetEverything()
	--console.log('game reset');
	seconds = 0; minutes = 0; hours = 0;
	finalSeconds = 0; finalMinutes = 0; finalHours = 0;
	bowser8 = false;
	hitAxe = false;
	once = false;
	gameOver = false;
	noContinue = false;
	offScript = false;
	startFrame = -1;
	splitArray = {};
	worldArray = {};
	frameArray = {};
	gui.text(0,0,"");
end


while true do
------------------------------------------------------------------------

	
    --game related variables
    state = memory.readbyte(0x0770); --0 = title screen, 1 = playing the game, 2 = rescued toad/peach, 3 = game over
    frameruleCounter = math.floor(emu.framecount()/21.0);
    frameruleFraction = memory.readbyte(0x077F); --value between 0 and 20
    gameTimer = memory.readbyte(0x07F8)*100 + memory.readbyte(0x07F9)*10 + memory.readbyte(0x07FA);
    world = memory.readbyte(0x075F)+1;
    level = memory.readbyte(0x0760)+1;
	
    if (level > 2 and (world == 1 or world == 2 or world == 4 or world == 7)) then --the cute animation where you go into a pipe before starting the level counts as a level internally
        level = level - 1; --for worlds with that cutscene, we have to subtract off that cutscene level
    end;

    --player related variables
    xpos = memory.readbyte(0x03AD); --number of pixels between mario (or luigi...) and the left side of the screen
    lives = memory.readbyte(0x075A)+1;

    -- set timer start frame
    if startFrame == -1 and world == 1 and level == 1 and gameTimer == 400 then --on title screen, values are world 1-1, gameTimer 401. when timer goes to 400, we've started the timer and don't need to set it again until game over or console reset
        startFrame = emu.framecount();
    end;

    -- calculate hour:minute:second
    totalFrames =  emu.framecount() - startFrame -1;
    totalSeconds = totalFrames/nesClockSpeed;
    seconds = totalSeconds % 60;
    minutes = math.floor(totalSeconds / 60) % 60;
    hours = math.floor(totalSeconds / 3600);
    
    --warn the user about something they did wrong
    if state == 0 and startFrame == -1 then
        if personalBestsSet == false and displayFrameOffset == true then -- tell the user to set up their PBs if they want that feature to work...!
			--console.log('something is wrong.');
            gui.text(66,timerY,"personalBests not set!")
            gui.text(55,timerY+14,  "edit the script near line 12")
        end;
        if sanityStatus ~= "sane" then -- tell the user they made a typo in one of the settings
			--console.log('something else is wrong.');
            gui.text(80,100,sanityStatus);
            gui.text(66,114,"check your script settings");
        end;
    end;
    
    if state == 3 then --GAME OVER, also detectable if lives == 256
		--console.log('game over');
        gameOver = true;
    end;
    
    if gameOver and state == 1 and world == 1 and level == 1 then --the player gameOvered recently and then restarted on world 1-1, so they didn't choose to continue their run by pressing Start and A simultaneously
		--console.log('game restart after completed.');
        noContinue = true;
    end;
    
------------------------------------------------------------------------
    -- (player resets the console) or (player game overs and doesn't continue), need to reset
    if emu.framecount() == 0 or noContinue or state == 0 then
		resetEverything();
    end;
    
    -- stop timer
    ----detect if bowser is on the screen and you are in world 8
    if world == 8 then
        for i=0,5 do
            if memory.readbyte((0x0016)+i) == 0x2d then
				--console.log('bowser is on screen in world 8!');
                bowser8 = true;
            end;
        end;
    end;

    ----detect if you hit the axe on 8-4 and lock the timer's value
    if bowser8 and memory.readbyte(0x01ED) == 242 and xpos > 210 and once == false then
		--console.log('touched the axe!');
        hitAxe = true;
        once = true;
        finalSeconds = round(seconds, 2);
        finalMinutes = minutes;
        finalHours = hours;
        splitArray[#splitArray + 1] = formatTimerString(finalHours,finalMinutes,finalSeconds);
        worldArray[#worldArray + 1] = world .. "-" .. level;
        
        local levelFrames;
        local newPB;
        levelFrames = totalFrames-frameArray[#frameArray]["frame"]; --calculate how many frames 8-4 took
        newPB = (levelFrames < personalBests[splitWorld][splitLevel]) and not(offScript); --true if less frames were just taken in 8-4 than whatever is recorded in the personalBests table, and also the user has set up PB times
        frameArray[#frameArray + 1] = {["frame"]=totalFrames, ["newPB"]=newPB, ["pbFrameOffset"]=levelFrames - personalBests[splitWorld][splitLevel], ["offScript"]=offScript};
    end;

    ----display timer
	if hitAxe then
		--console.log('show the final time.');
        timerString = formatTimerString(finalHours,finalMinutes,finalSeconds);
        gui.text(timerX, timerY, timerString["timer"]);
    else
        if startFrame ~= -1 then
			--console.log('show the timer.');
            timerString = formatTimerString(hours,minutes,seconds);
            gui.text(timerX, timerY, timerString["timer"]);
        else
			--console.log('show the dummy timer.');
            gui.text(timerX, timerY, "0:00.000");
        end;
    end;

    -- detect split
    if levelChanged == false then
		--console.log('level changed.');
        levelChanged = (world ~= lastWorld or level ~= lastLevel); --true if just level changes basically, not aware of any warp zone that warps from x-z to y-z, and the ends of worlds always goes from x-4 to y-1
        splitWorld = lastWorld;
        splitLevel = lastLevel;
        splitState = lastState;
    end;
    if levelChanged and memory.readbyte(0x0772) == 2 then --0772 == 2 makes it split after the level's title screen when going into a warp pipe
		--console.log('level changed & 0772 = 2.');
        levelChanged = false;
        timerString = formatTimerString(hours,minutes,seconds);
        if state == 1 then
			--console.log('state = 1');
            splitArray[#splitArray + 1] = timerString;
            if splitState ~= 0 then --0 is demo screen
				--console.log('splitState ~= 0');
                worldArray[#worldArray + 1] = splitWorld .. "-" .. splitLevel;
                
                if personalBests[splitWorld][splitLevel] == 0 then --user has gone "off script" and has no PB for this level. This can happen if they have an incomplete PB table (never beat the game?) or their PB table is based off any% and they just went to 1-3 e.g.
                    offScript = true; --this will stop us from "!!set new pb!!" and displaying meaningless framerule offsets
                end;

                --calculate how many frames the last level took
                local levelFrames;
                local newPB;
                if #frameArray > 0 then
                    levelFrames = totalFrames-frameArray[#frameArray]["frame"];
                else
                    levelFrames = totalFrames;
                end;
                --check if this split qualifies as a personal best
                newPB = (levelFrames < personalBests[splitWorld][splitLevel]) and not(offScript); --true if less frames were just taken in the last level than whatever is recorded in the personalBests table, and also the user has set PB times

                frameArray[#frameArray + 1] = {["frame"]=totalFrames, ["newPB"]=newPB, ["pbFrameOffset"]=levelFrames - personalBests[splitWorld][splitLevel], ["offScript"]=offScript};
            else
				--console.log('splitState == 0');
                worldArray[#worldArray + 1] = world .. "-C"; --game continue
                local waldo = -1;
                for i=1,#worldArray do --find where in frameArray you were on "world-1" last to determine how much time you just lost from gameOvering vs never dying
                    if worldArray[i] == world .. "-1" then
                        waldo = i-1;
                        break; --got i, get out
                    end;
                end;
                if waldo == -1 then
                    waldo = #worldArray-1;
                end;

                frameArray[#frameArray + 1] = {["frame"]=totalFrames, ["newPB"]=false, ["pbFrameOffset"]=totalFrames - frameArray[waldo]["frame"], ["offScript"]=offScript}; --second part is whether or not it's a PB... I hope you're not trying to PB your game continues, and there's no place for them in the PB table anyway. the offset becomes how much time you've lost.
                gameOver = false; --game continues
            end;
        end;
    end;
    
    -- display splits and frame offsets
    if displaySplits and #splitArray > 0 then --display at least 8-1 00:00.00
		--console.log('there are splits and we should show them.');
        local iBegin;
        local iEnd = #splitArray;

        if #splitArray >= splitsToDisplay or splitsToDisplay > maxSplits then
			--console.log('too many splits to show');
            iBegin = #splitArray - splitsToDisplay; --we have more splits than we would like to display
            if hitAxe and #splitArray > maxSplits then
                --console.log('cycle splits to show them all');
                iBegin = ((math.floor((frameruleCounter - math.floor(frameArray[#frameArray]["frame"]/21.0))/9.0)+(#splitArray-maxSplits)) % #splitArray); --cycle through splits every 9 framerules so that all of them are eventually displayed. Even if you're really bad and game_over-continue 100 times.
                iEnd = iBegin+maxSplits;
            end;
        else
			--console.log('we can fit all the splits onscreen.');
            iBegin = 0; --we don't have a lot of splits yet, less than splitsToDisplay anyway.
        end;

        --fix iEnd in case user put a number greater than maxSplits
        if splitsToDisplay > maxSplits and not(hitAxe) then
			--console.log('fix maxsplits');
            iEnd = maxSplits;
        end;
		--console.log('draw splits loop');
        for i=iBegin,iEnd do --draw splitsToDisplay splits
            local index = ((i-1) % #splitArray)+1;

            gui.text(0, splitY+(i-iBegin)*14, worldArray[index]); --display 8-1
            gui.text(40, splitY+(i-iBegin)*14, splitArray[index]["timer"]); --display 00:00.00
            
            if (displayFrames or displayFrameOffset or frameArray[index]["newPB"]) then
				--console.log('there is something to show.');
                if sanityStatus ~= "sane" then
                    gui.text(80,100,sanityStatus);
                    gui.text(66,114,"check your script settings");
                end;

                --figure out what the frame text will look like. (2100 vs !!2100!!), and where to grab the 2100 from
                if (displayFrames or frameArray[index]["newPB"]) or (displayFrameruleOffset and frameArray[index]["offScript"]) then
					--console.log('displayFrames or a new PB.');
                    local curFrameSplit;
                    if index > 1 then --subtract old total from new total
                        curFrameSplit = frameArray[index]["frame"]-frameArray[index-1]["frame"];
                    else
                        curFrameSplit = frameArray[index]["frame"] --we're on the first item, so just return it
                    end;
                    if frameArray[index]["newPB"] then
						--console.log('new PB!');
                        frameText = "!!" .. curFrameSplit .. "!!"; --if it's a PB, wrap it in excitement
                        if framesUnits ~= "frames" and displayFrames then --need to display frame count anyway, so user can put it in their PB table
                            frameText = formatSplitString(curFrameSplit,framesUnits, false)["split"] .. " " .. frameText; --display the user's preferred split format in front of frames for PB
                        end;
                    else
                        if displayFrameruleOffset and frameArray[index]["offScript"] then
                            frameText = curFrameSplit; --display in frames no matter what for people trying to fill in their PB table
                        else
                            frameText = formatSplitString(curFrameSplit,framesUnits, false)["split"]; --else just normal amount of enthusiasm
                        end;
                    end;
                end;

                --display what we figured out about pbFrameOffset
                if displayFrameOffset then --displaying at least the frame offset. Timer will look like "8-1 00:00.00 +21" (so far)
                    if not(frameArray[index]["offScript"]) then
                        local formattedSplit = formatSplitString(frameArray[index]["pbFrameOffset"], offsetSplitsUnits, true);
                        gui.text(130, splitY+(i-iBegin)*14, formattedSplit["split"]);
                    else
                        gui.text(130, splitY+(i-iBegin)*14,"X"); --an X to indicate to users who have frameOffsets turned on that the frameOffset for this split has been deemed "invalid"
                    end;
                end;
                --display how many frames it took to complete the level, and PB frame number
                if (displayFrames or frameArray[index]["newPB"]) then --displaying frames. Timer looks like "8-1 00:00.00 +21 2100". Need to display frames
                    gui.text(130, splitY+(i-iBegin)*14, frameText);
                end;
            end; --displaying more than just 8-1 00:00.00
        end; --draw splits Loop
    end; --display splits

    lastWorld = world;
    lastLevel = level;
    lastState = state;
    emu.frameadvance();
end;
