local Parser = require "LoveDialogueParser"
local Constants = require "DialogueConstants"
local TextEffects = require "TextEffects"

local LoveDialogue = {}
function LoveDialogue:new(config)
    local obj = {
        dialogue = {},
        characters = {},
        currentSection = "start",
        currentLineIndex = 1,
        isActive = false,
        font = love.graphics.newFont(config.fontSize or Constants.DEFAULT_FONT_SIZE),
        nameFont = love.graphics.newFont(config.nameFontSize or Constants.DEFAULT_NAME_FONT_SIZE),
        boxColor = config.boxColor or Constants.BOX_COLOR,
        textColor = config.textColor or Constants.TEXT_COLOR,
        nameColor = config.nameColor or Constants.NAME_COLOR,
        padding = config.padding or Constants.PADDING,
        boxHeight = config.boxHeight or Constants.BOX_HEIGHT,
        typingSpeed = config.typingSpeed or Constants.TYPING_SPEED,
        typewriterTimer = 0,
        displayedText = "",
        currentCharacter = "",
        boxOpacity = 0,
        fadeInDuration = config.fadeInDuration or Constants.FADE_IN_DURATION,
        fadeOutDuration = config.fadeOutDuration or Constants.FADE_OUT_DURATION,
        animationTimer = 0,
        state = "inactive", -- Can be "inactive", "fading_in", "active", "fading_out"
        enableFadeIn = config.enableFadeIn or true,
        enableFadeOut = config.enableFadeOut or true,
        effects = {},
        waitTimer = 0,
        autoLayoutEnabled = config.autoLayoutEnabled or true,
        selectedChoiceIndex = 1,
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function LoveDialogue:loadFromFile(filePath)
    self.dialogue, self.characters = Parser.parseFile(filePath)
end

function LoveDialogue:start()
    self.isActive = true
    self.currentSection = "start"
    self.currentLineIndex = 1
    self.state = self.enableFadeIn and "fading_in" or "active"
    self.animationTimer = 0
    self.boxOpacity = self.enableFadeIn and 0 or 1
    self:setCurrentDialogue()
end

function LoveDialogue:setCurrentDialogue()
    if not self.dialogue[self.currentSection] then
        self:endDialogue()
        return
    end

    local currentDialogue = self.dialogue[self.currentSection][self.currentLineIndex]
    if currentDialogue then
        self.currentCharacter = currentDialogue.character
        self.displayedText = ""
        self.typewriterTimer = 0
        self.effects = currentDialogue.effects or {}
        self.waitTimer = 0
        self.selectedChoiceIndex = 1
    else
        self:endDialogue()
    end
end


function LoveDialogue:endDialogue()
    self.state = self.enableFadeOut and "fading_out" or "inactive"
    self.animationTimer = 0
    if not self.enableFadeOut then
        self.isActive = false
    end
end

function LoveDialogue:update(dt)
    if not self.isActive then return end

    if self.state == "fading_in" then
        self.animationTimer = self.animationTimer + dt
        self.boxOpacity = math.min(self.animationTimer / self.fadeInDuration, 1)
        if self.animationTimer >= self.fadeInDuration then
            self.state = "active"
        end
    elseif self.state == "active" then
        local currentFullText = self.dialogue[self.currentSection][self.currentLineIndex].text
        if self.displayedText ~= currentFullText then
            if self.waitTimer > 0 then
                self.waitTimer = self.waitTimer - dt
            else
                self.typewriterTimer = self.typewriterTimer + dt
                if self.typewriterTimer >= self.typingSpeed then
                    self.typewriterTimer = 0
                    local nextCharIndex = #self.displayedText + 1
                    local nextChar = string.sub(currentFullText, nextCharIndex, nextCharIndex)
                    self.displayedText = self.displayedText .. nextChar

                    -- Check for wait effect
                    for _, effect in ipairs(self.effects) do
                        if effect.type == "wait" and effect.startIndex == nextCharIndex then
                            self.waitTimer = tonumber(effect.content) or 0
                            break
                        end
                    end
                end
            end
        end
    elseif self.state == "fading_out" then
        self.animationTimer = self.animationTimer + dt
        self.boxOpacity = 1 - math.min(self.animationTimer / self.fadeOutDuration, 1)
        if self.animationTimer >= self.fadeOutDuration then
            self.isActive = false
            self.state = "inactive"
        end
    end

    -- Update effect timers
    for _, effect in ipairs(self.effects) do
        effect.timer = (effect.timer or 0) + dt
    end

    -- Auto layout adjustment
    if self.autoLayoutEnabled then
        self:adjustLayout()
    end
end

function LoveDialogue:draw()
    if not self.isActive then return end

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local boxWidth = windowWidth - 2 * self.padding

    -- Draw dialogue box
    love.graphics.setColor(self.boxColor[1], self.boxColor[2], self.boxColor[3], self.boxColor[4] * self.boxOpacity)
    love.graphics.rectangle("fill", self.padding, windowHeight - self.boxHeight - self.padding, boxWidth, self.boxHeight)

    -- Draw character name and text only if there's a current dialogue
    local currentDialogue = self.dialogue[self.currentSection] and self.dialogue[self.currentSection][self.currentLineIndex]
    if currentDialogue then
        -- Draw character name
        love.graphics.setFont(self.nameFont)
        local nameColor = self.characters[self.currentCharacter]
        love.graphics.setColor(nameColor.r, nameColor.g, nameColor.b, self.boxOpacity)
        love.graphics.print(self.currentCharacter, self.padding * 2, windowHeight - self.boxHeight - self.padding + 10)

        -- Draw separator line
        love.graphics.setColor(1, 1, 1, 0.5 * self.boxOpacity)
        love.graphics.line(
            self.padding * 2, 
            windowHeight - self.boxHeight - self.padding + 35,
            boxWidth - self.padding * 2,
            windowHeight - self.boxHeight - self.padding + 35
        )

        -- Draw text or choices
        love.graphics.setFont(self.font)
        if currentDialogue.choices and #self.displayedText == #currentDialogue.text then
            -- Draw choices
            for i, choice in ipairs(currentDialogue.choices) do
                local prefix = (i == self.selectedChoiceIndex) and "-> " or "   "
                love.graphics.printf(prefix .. choice.text, self.padding * 2, windowHeight - self.boxHeight + self.padding + 20 + (i - 1) * 20, boxWidth - self.padding * 2, "left")
            end
        else
            -- Draw regular text
            local x = self.padding * 2
            local y = windowHeight - self.boxHeight + self.padding + 20
            local limit = boxWidth - self.padding * 2

            for i = 1, #self.displayedText do
                local char = self.displayedText:sub(i, i)
                local charWidth = self.font:getWidth(char)

                local color = {unpack(self.textColor)}
                local offset = {x = 0, y = 0}
                local scale = 1

                for _, effect in ipairs(self.effects) do
                    if i >= effect.startIndex and i <= effect.endIndex then
                        local effectFunc = TextEffects[effect.type]
                        if effectFunc then
                            local effectColor, effectOffset = effectFunc(effect, char, i, effect.timer)
                            if effectColor then color = effectColor end
                            offset.x = offset.x + (effectOffset.x or 0)
                            offset.y = offset.y + (effectOffset.y or 0)
                            scale = scale * (effectOffset.scale or 1)
                        end
                    end
                end

                love.graphics.setColor(color[1], color[2], color[3], self.boxOpacity)
                love.graphics.print(char, x + offset.x, y + offset.y, 0, scale, scale)
                x = x + charWidth * scale

                if x > limit then
                    x = self.padding * 2
                    y = y + self.font:getHeight() * scale
                end
            end
        end
    elseif self.state == "section_end" then
        -- Display a message when the section has ended
        love.graphics.setFont(self.font)
        love.graphics.setColor(1, 1, 1, self.boxOpacity)
        love.graphics.printf("End of section. Press space to continue.", self.padding * 2, windowHeight - self.boxHeight + self.padding + 20, boxWidth - self.padding * 2, "center")
    end
end

function LoveDialogue:adjustLayout()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    self.boxHeight = math.floor(windowHeight * 0.25) -- 25% of screen height
    self.padding = math.floor(windowWidth * 0.02) -- 2% of screen width
    self.font = love.graphics.newFont(math.floor(windowHeight * 0.025)) -- Font size relative to screen height
    self.nameFont = love.graphics.newFont(math.floor(windowHeight * 0.03))
end

function LoveDialogue:advance()
    if self.state == "active" then
        local currentDialogue = self.dialogue[self.currentSection][self.currentLineIndex]
        if currentDialogue.choices and #self.displayedText == #currentDialogue.text then
            local selectedChoice = currentDialogue.choices[self.selectedChoiceIndex]
            if selectedChoice.action.type == "goto" then
                self.currentSection = selectedChoice.action.target
                self.currentLineIndex = 1
                self:setCurrentDialogue()
            elseif selectedChoice.action.type == "end" then
                self:endDialogue()
            end
        else
            if self.displayedText ~= currentDialogue.text then
                self.displayedText = currentDialogue.text
            else
                self.currentLineIndex = self.currentLineIndex + 1
                if self.currentLineIndex > #self.dialogue[self.currentSection] then
                    self:endDialogue()
                else
                    self:setCurrentDialogue()
                end
            end
        end
    elseif self.state == "fading_in" then
        self.state = "active"
        self.boxOpacity = 1
    end
end

-- helper function
function table.indexOf(t, value)
    for i, v in ipairs(t) do
        if v == value then
            return i
        end
    end
    return nil
end


function LoveDialogue:keypressed(key)
    if self.state ~= "active" then return end

    local currentDialogue = self.dialogue[self.currentSection][self.currentLineIndex]
    if currentDialogue.choices and #self.displayedText == #currentDialogue.text then
        if key == "up" then
            self.selectedChoiceIndex = math.max(1, self.selectedChoiceIndex - 1)
        elseif key == "down" then
            self.selectedChoiceIndex = math.min(#currentDialogue.choices, self.selectedChoiceIndex + 1)
        elseif key == "return" or key == "space" then
            self:advance()
        end
    else
        if key == "return" or key == "space" then
            self:advance()
        end
    end
end

function LoveDialogue.play(filePath, config)
    local dialogue = LoveDialogue:new(config or {})
    dialogue:loadFromFile(filePath)
    dialogue:start()
    return dialogue
end

return LoveDialogue