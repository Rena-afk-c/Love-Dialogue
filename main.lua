local LoveDialogue = require "LoveDialogue"

local myDialogue
local isFullscreen = false

function love.load()
    if love.system.getOS() == "Windows" then
        love._openConsole()
    end
    love.window.setMode(800, 600, {resizable=true, minwidth=400, minheight=300})
    myDialogue = LoveDialogue.play("exampleDialogue.ld", {
        enableFadeIn = true,
        enableFadeOut = true,
    })
    Parser.printDebugInfo(myDialogue.lines, myDialogue.characters)
end

function love.update(dt)
    if myDialogue then
        myDialogue:update(dt)
    end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Press SPACE to advance dialogue", 10, 10)
    love.graphics.print("Press F to toggle fullscreen", 10, 30)
    love.graphics.print("Current window size: " .. love.graphics.getWidth() .. "x" .. love.graphics.getHeight(), 10, 50)
    
    if myDialogue then
        myDialogue:draw()
    end
end

function love.keypressed(key)
    if key == "space" or key == "up" or key == "down" or key == "return" then
        if myDialogue then
            myDialogue:keypressed(key)
        end
    elseif key == "f" then
        toggleFullscreen()
    end
end

function toggleFullscreen()
    isFullscreen = not isFullscreen
    love.window.setFullscreen(isFullscreen)
    if myDialogue and myDialogue.autoLayoutEnabled then
        myDialogue:adjustLayout()
    end
end

function love.resize(w, h)
    if myDialogue and myDialogue.autoLayoutEnabled then
        myDialogue:adjustLayout()
    end
end