local Parser = {}

-- Utility function to trim whitespace from both ends of a string
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

function Parser.parseFile(filePath)
    local lines = {}
    local characters = {}
    local currentSection = "start"
    local currentLine = 1

    lines[currentSection] = {}

    for line in love.filesystem.lines(filePath) do
        line = trim(line)
        
        if line:match("^#%s*(.+)$") then
            -- New section
            currentSection = line:match("^#%s*(.+)$")
            lines[currentSection] = {}
            currentLine = 1
        elseif line:match("^(%S+):%s*(.+)$") then
            -- Dialogue line
            local character, text = line:match("^(%S+):%s*(.+)$")
            local parsedLine = {character = character, text = text, effects = {}}
            
            -- Parse text effects
            parsedLine.text, parsedLine.effects = Parser.parseEffects(text)
            
            table.insert(lines[currentSection], parsedLine)
            
            if not characters[character] then
                characters[character] = {r = love.math.random(), g = love.math.random(), b = love.math.random()}
            end
            
            currentLine = currentLine + 1
        elseif line:match("^%->%s*(.+)$") then
            -- Choice option
            local choiceText = line:match("^%->%s*(.+)$")
            if #lines[currentSection] == 0 then
                print("Warning: Choice found before any dialogue in section " .. currentSection)
                table.insert(lines[currentSection], {character = "", text = "", choices = {}})
            end
            if not lines[currentSection][#lines[currentSection]].choices then
                lines[currentSection][#lines[currentSection]].choices = {}
            end
            table.insert(lines[currentSection][#lines[currentSection]].choices, {text = choiceText})
        elseif line:match("^=>%s*(.+)$") then
            -- Choice action
            local action = line:match("^=>%s*(.+)$")
            if #lines[currentSection] == 0 or not lines[currentSection][#lines[currentSection]].choices then
                print("Warning: Action found before any choices in section " .. currentSection)
            else
                local lastChoice = lines[currentSection][#lines[currentSection]].choices[#lines[currentSection][#lines[currentSection]].choices]
                if action == "END" then
                    lastChoice.action = {type = "end"}
                elseif action:match("^GOTO%s+(.+)$") then
                    local target = action:match("^GOTO%s+(.+)$")
                    lastChoice.action = {type = "goto", target = target}
                end
            end
        end
    end

    return lines, characters
end

function Parser.parseEffects(text)
    local parsedText = ""
    local effects = {}
    local currentIndex = 1

    while true do
        local startTag, endTag, tag, content = text:find("<([^>]+)>([^<]+)</[^>]+>", currentIndex)

        if not startTag then
            -- No more tags found, add the rest of the text
            parsedText = parsedText .. text:sub(currentIndex)
            break
        end

        -- Add text before the tag
        parsedText = parsedText .. text:sub(currentIndex, startTag - 1)

        local effect = {
            type = tag,
            content = content,
            startIndex = #parsedText + 1,
            endIndex = #parsedText + #content
        }

        parsedText = parsedText .. content
        table.insert(effects, effect)

        currentIndex = endTag + 1
    end

    return parsedText, effects
end

return Parser