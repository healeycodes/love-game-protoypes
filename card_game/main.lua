-- Game configuration
local Config = {
    window = {
        title = "untitled card game"
    },
    cards = {
        count = 8,
        spacing = 60,
        width = 80,
        height = 120,
        hoverRise = 155,
        hoverScale = 1.8,
        manaCostSize = 20,
        manaCostPadding = 2,
        manaCostFontSize = 12,
        border = 2,
        imageHeight = 42, -- 35% of card height
        titleFontSize = 10,
        titleYOffset = 35,
        textFontSize = 8,
        textPadding = 4,
        textYOffset = 65
    },
    slots = {
        count = 7,
        spacing = 20,
        dashLength = 5,
        dashGap = 5
    },
    resources = {
        barWidth = 100,
        barHeight = 20,
        spacing = 10,
        border = 2,
        maxHealth = 30,
        maxMana = 10
    },
    ui = {
        roundFontSize = 16,
        buttonWidth = 100,
        buttonHeight = 30,
        buttonMargin = 10
    }
}

love.window.setTitle(Config.window.title)

-- Core game state
local State = {
    cards = {},
    opponentCards = {},
    hoveredCard = nil,
    draggedCard = nil,
    dragStart = {x = 0, y = 0},
    resources = {
        player = {
            health = Config.resources.maxHealth, 
            mana = 1,
            maxMana = 1
        },
        opponent = {
            health = Config.resources.maxHealth, 
            mana = 1,
            maxMana = 1
        }
    },
    round = {
        current = 1,
        isPlayerTurn = true
    },
    slots = {
        player = {},
        opponent = {}
    },
    hoveredSlot = nil,
    ui = {
        endTurnHovered = false
    }
}

-- Creates a new card with visual properties based on its position in hand
local function createCard(index, total, isOpponent)
    local rotation = (isOpponent and 0.2 or -0.2) + 
                    (isOpponent and -1 or 1) * (0.4 * (index-1)/(total-1))
    
    local heightOffset = (isOpponent and -1 or 1) * 
                        math.abs(index - (total + 1)/2) * 10

    -- Generate rainbow color based on card index
    local hue = (index-1)/total
    local r, g, b = 0, 0, 0
    
    if hue < 1/6 then
        r, g = 1, hue * 6
    elseif hue < 2/6 then
        r, g = 1 - (hue-1/6) * 6, 1
    elseif hue < 3/6 then
        g, b = 1, (hue-2/6) * 6
    elseif hue < 4/6 then
        g, b = 1 - (hue-3/6) * 6, 1
    elseif hue < 5/6 then
        r, b = (hue-4/6) * 6, 1
    else
        r, b = 1, 1 - (hue-5/6) * 6
    end
    
    return {
        color = {r*0.7, g*0.7, b*0.7, 1},
        rotation = rotation,
        heightOffset = heightOffset,
        currentRise = 0,
        currentScale = 1,
        dragOffset = {x = 0, y = 0},
        manaCost = index,
        title = "Card " .. index,
        text = "This card does *something* cool when played."
    }
end

local function getCardPosition(index, startX, baseY)
    return startX + (index-1) * Config.cards.spacing, baseY or 520
end

local function updateCardAnimation(card, targetRise, targetScale, dt)
    local speed = 10
    card.currentRise = card.currentRise + (targetRise - card.currentRise) * dt * speed
    card.currentScale = card.currentScale + (targetScale - card.currentScale) * dt * speed
end

local function updateCardDrag(card, dt)
    if not State.draggedCard then
        local speed = 10
        card.dragOffset.x = card.dragOffset.x + (0 - card.dragOffset.x) * dt * speed
        card.dragOffset.y = card.dragOffset.y + (0 - card.dragOffset.y) * dt * speed
    end
end

local function isPointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

local function drawDottedRect(x, y, width, height, isHighlighted)
    love.graphics.setLineWidth(1)
    love.graphics.setLineStyle("rough")
    
    if isHighlighted then
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.rectangle("fill", x, y, width, height)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    end
    
    -- Draw dotted border lines
    local function drawDottedLine(startX, startY, endX, endY)
        local dx = endX - startX
        local dy = endY - startY
        local length = math.sqrt(dx * dx + dy * dy)
        local segments = math.floor(length / (Config.slots.dashLength + Config.slots.dashGap))
        
        for i = 0, segments do
            local start = i * (Config.slots.dashLength + Config.slots.dashGap)
            local finish = math.min(start + Config.slots.dashLength, length)
            if finish > start then
                local x1 = startX + dx * start / length
                local y1 = startY + dy * start / length
                local x2 = startX + dx * finish / length
                local y2 = startY + dy * finish / length
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    end
    
    drawDottedLine(x, y, x + width, y)
    drawDottedLine(x + width, y, x + width, y + height)
    drawDottedLine(x + width, y + height, x, y + height)
    drawDottedLine(x, y + height, x, y)
end

local function drawCardSlots()
    local totalWidth = Config.slots.count * (Config.cards.width + Config.slots.spacing) - Config.slots.spacing
    local startX = love.graphics.getWidth()/2 - totalWidth/2
    local centerY = love.graphics.getHeight()/2
    local slotSpacing = Config.cards.height + Config.slots.spacing
    
    love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    
    -- Draw opponent slots
    for i = 1, Config.slots.count do
        local x = startX + (i-1) * (Config.cards.width + Config.slots.spacing)
        local y = centerY - slotSpacing
        if not State.slots.opponent[i] then
            drawDottedRect(x, y, Config.cards.width, Config.cards.height)
        end
    end
    
    -- Draw player slots
    for i = 1, Config.slots.count do
        local x = startX + (i-1) * (Config.cards.width + Config.slots.spacing)
        local y = centerY + Config.slots.spacing
        if not State.slots.player[i] then
            local isHighlighted = State.draggedCard and State.hoveredSlot == i and State.round.isPlayerTurn
            drawDottedRect(x, y, Config.cards.width, Config.cards.height, isHighlighted)
        end
    end
end

local function drawCard(card, x, y, rotation, isFaceDown)
    love.graphics.push()
    love.graphics.translate(x, y)
    
    if rotation then
        love.graphics.rotate(card.rotation + (isFaceDown and math.pi or 0))
    end
    love.graphics.scale(card.currentScale)
    
    if isFaceDown then
        -- Draw card back
        love.graphics.setColor(0.2, 0.2, 0.3, 1)
        love.graphics.rectangle("fill", -Config.cards.width/2, 0, Config.cards.width, Config.cards.height)
        
        love.graphics.setColor(0.3, 0.3, 0.4, 1)
        love.graphics.rectangle("line", -Config.cards.width/2 + 5, 5, Config.cards.width - 10, Config.cards.height - 10)
    else
        -- Draw card border (background)
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", -Config.cards.width/2, 0, Config.cards.width, Config.cards.height)
        
        -- Draw card front
        love.graphics.setColor(card.color)
        love.graphics.rectangle("fill", 
            -Config.cards.width/2 + Config.cards.border, 
            Config.cards.border, 
            Config.cards.width - Config.cards.border*2, 
            Config.cards.height - Config.cards.border*2
        )
        
        -- Draw card image area
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle("fill",
            -Config.cards.width/2 + Config.cards.border,
            Config.cards.border,
            Config.cards.width - Config.cards.border*2,
            Config.cards.imageHeight
        )
        
        -- Draw card title
        love.graphics.setColor(0, 0, 0)
        local titleFont = love.graphics.newFont(Config.cards.titleFontSize)
        love.graphics.setFont(titleFont)
        local titleWidth = titleFont:getWidth(card.title)
        love.graphics.print(
            card.title,
            -titleWidth/2,
            Config.cards.titleYOffset
        )
        
        -- Draw card text
        love.graphics.setColor(0, 0, 0)
        local textFont = love.graphics.newFont(Config.cards.textFontSize)
        love.graphics.setFont(textFont)
        love.graphics.printf(
            card.text,
            -Config.cards.width/2 + Config.cards.textPadding,
            Config.cards.textYOffset,
            Config.cards.width - Config.cards.textPadding*2,
            "center"
        )
        
        -- Draw mana cost
        love.graphics.setColor(0.2, 0.2, 0.8, 0.8)
        love.graphics.circle(
            "fill",
            Config.cards.width/2,
            0,
            Config.cards.manaCostSize/2
        )
        
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.newFont(Config.cards.manaCostFontSize)
        love.graphics.setFont(font)
        local text = tostring(card.manaCost)
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(
            text,
            Config.cards.width/2 - textWidth/2,
            -textHeight/2
        )
    end
    
    love.graphics.pop()
end

local function drawResourceBar(x, y, currentValue, maxValue, color)
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, Config.resources.barWidth, Config.resources.barHeight)
    
    -- Fill
    local fillWidth = (currentValue / maxValue) * Config.resources.barWidth
    love.graphics.setColor(color[1], color[2], color[3], 0.8)
    love.graphics.rectangle("fill", x, y, fillWidth, Config.resources.barHeight)
    
    -- Border
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.setLineWidth(Config.resources.border)
    love.graphics.rectangle("line", x, y, Config.resources.barWidth, Config.resources.barHeight)
    
    -- Value text
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.newFont(12)
    love.graphics.setFont(font)
    local text = string.format("%d/%d", currentValue, maxValue)
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    love.graphics.print(text, 
        x + Config.resources.barWidth/2 - textWidth/2, 
        y + Config.resources.barHeight/2 - textHeight/2
    )
end

local function drawResourceBars(resources, isOpponent)
    local margin = 20
    local y = isOpponent and margin or 
              love.graphics.getHeight() - margin - Config.resources.barHeight * 2 - Config.resources.spacing
    
    drawResourceBar(margin, y, resources.health, Config.resources.maxHealth, {0.8, 0.2, 0.2})
    drawResourceBar(margin, y + Config.resources.barHeight + Config.resources.spacing, 
                   resources.mana, resources.maxMana, {0.2, 0.2, 0.8})
end

local function drawRoundInfo()
    local text = string.format("Round %d\n%s's Turn", 
        State.round.current,
        State.round.isPlayerTurn and "Player" or "Opponent"
    )
    
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.newFont(Config.ui.roundFontSize)
    love.graphics.setFont(font)
    
    local margin = Config.ui.buttonMargin
    local x = love.graphics.getWidth() - font:getWidth("Opponent's Turn") - margin
    local y = love.graphics.getHeight() - margin - font:getHeight() * 2 - Config.ui.buttonHeight - margin
    
    love.graphics.print(text, x, y)
    
    -- Only show End Turn button during player's turn
    if State.round.isPlayerTurn then
        -- Draw End Turn button
        local buttonX = x
        local buttonY = y + font:getHeight() * 2 + margin
        
        if State.ui.endTurnHovered then
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
        end
        
        love.graphics.rectangle("fill", buttonX, buttonY, 
            Config.ui.buttonWidth, Config.ui.buttonHeight)
        
        love.graphics.setColor(1, 1, 1)
        local buttonText = "End Turn"
        local textWidth = font:getWidth(buttonText)
        local textHeight = font:getHeight()
        love.graphics.print(buttonText,
            buttonX + (Config.ui.buttonWidth - textWidth)/2,
            buttonY + (Config.ui.buttonHeight - textHeight)/2
        )
    end
end

-- Initialize starting hands
for i = 1, Config.cards.count do
    table.insert(State.cards, createCard(i, Config.cards.count, false))
    table.insert(State.opponentCards, createCard(i, Config.cards.count, true))
end

local function recalculateCardPositions()
    local total = #State.cards
    for i = 1, total do
        local card = State.cards[i]
        card.rotation = -0.2 + (0.4 * (i-1)/(total-1))
        card.heightOffset = math.abs(i - (total + 1)/2) * 10
    end
end

local function endTurn()
    State.round.isPlayerTurn = not State.round.isPlayerTurn
    if not State.round.isPlayerTurn then
        -- Opponent's turn starts
    else
        -- Player's turn starts
        State.round.current = State.round.current + 1
        -- Increase max mana for both players at the start of player's turn
        local newMaxMana = math.min(State.round.current, Config.resources.maxMana)
        State.resources.player.maxMana = newMaxMana
        State.resources.player.mana = newMaxMana
        State.resources.opponent.maxMana = newMaxMana
        State.resources.opponent.mana = newMaxMana
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Check End Turn button (only during player's turn)
        if State.round.isPlayerTurn then
            local font = love.graphics.newFont(Config.ui.roundFontSize)
            local buttonX = love.graphics.getWidth() - Config.ui.buttonWidth - Config.ui.buttonMargin
            local buttonY = love.graphics.getHeight() - Config.ui.buttonHeight - Config.ui.buttonMargin
            
            if isPointInRect(x, y, buttonX, buttonY, Config.ui.buttonWidth, Config.ui.buttonHeight) then
                endTurn()
                return
            end
        end
        
        -- Allow dragging cards on any turn
        if State.hoveredCard then
            State.draggedCard = State.hoveredCard
            local totalWidth = (Config.cards.count - 1) * Config.cards.spacing
            local startX = love.graphics.getWidth()/2 - totalWidth/2
            local card = State.cards[State.hoveredCard]
            State.dragStart.x = startX + (State.hoveredCard-1) * Config.cards.spacing
            State.dragStart.y = 520 + card.heightOffset
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and State.draggedCard then
        if State.hoveredSlot and not State.slots.player[State.hoveredSlot] and State.round.isPlayerTurn then
            -- Place card in slot and reset its animation values
            local card = table.remove(State.cards, State.draggedCard)
            card.currentRise = 0
            card.currentScale = 1
            card.dragOffset = {x = 0, y = 0}
            State.slots.player[State.hoveredSlot] = card
            
            if State.hoveredCard and State.hoveredCard > State.draggedCard then
                State.hoveredCard = State.hoveredCard - 1
            end
            recalculateCardPositions()
        end
        State.draggedCard = nil
    end
end

function love.update(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    local totalWidth = (Config.cards.count - 1) * Config.cards.spacing
    local startX = love.graphics.getWidth()/2 - totalWidth/2
    
    State.hoveredCard = nil
    State.hoveredSlot = nil
    
    -- Check End Turn button hover (only during player's turn)
    if State.round.isPlayerTurn then
        local buttonX = love.graphics.getWidth() - Config.ui.buttonWidth - Config.ui.buttonMargin
        local buttonY = love.graphics.getHeight() - Config.ui.buttonHeight - Config.ui.buttonMargin
        State.ui.endTurnHovered = isPointInRect(mouseX, mouseY, buttonX, buttonY, 
            Config.ui.buttonWidth, Config.ui.buttonHeight)
    else
        State.ui.endTurnHovered = false
    end
    
    -- Check for slot hover when dragging
    if State.draggedCard then
        local totalSlotWidth = Config.slots.count * (Config.cards.width + Config.slots.spacing) - Config.slots.spacing
        local slotStartX = love.graphics.getWidth()/2 - totalSlotWidth/2
        local centerY = love.graphics.getHeight()/2
        local slotY = centerY + Config.slots.spacing
        
        for i = 1, Config.slots.count do
            local slotX = slotStartX + (i-1) * (Config.cards.width + Config.slots.spacing)
            if isPointInRect(mouseX, mouseY, slotX, slotY, Config.cards.width, Config.cards.height) then
                State.hoveredSlot = i
                break
            end
        end
    end
    
    -- Update dragged card position
    if State.draggedCard then
        local card = State.cards[State.draggedCard]
        card.dragOffset.x = mouseX - State.dragStart.x
        card.dragOffset.y = mouseY - (State.dragStart.y + Config.cards.height/2)
    end
    
    -- Check for card hover when not dragging
    if not State.draggedCard then
        for i = 1, #State.cards do
            local card = State.cards[i]
            local x, y = getCardPosition(i, startX)
            y = y + card.heightOffset
            
            local dx = mouseX - x
            local dy = mouseY - y
            local rotatedX = dx * math.cos(-card.rotation) - dy * math.sin(-card.rotation)
            local rotatedY = dx * math.sin(-card.rotation) + dy * math.cos(-card.rotation)
            
            if rotatedX >= -Config.cards.width/2 and rotatedX <= Config.cards.width/2 and
               rotatedY >= 0 and rotatedY <= Config.cards.height then
                State.hoveredCard = i
                break
            end
        end
    end
    
    -- Update card animations
    for i = 1, #State.cards do
        local card = State.cards[i]
        if i == State.hoveredCard and not State.draggedCard then
            updateCardAnimation(card, Config.cards.hoverRise, Config.cards.hoverScale, dt)
        else
            updateCardAnimation(card, 0, 1, dt)
        end
        updateCardDrag(card, dt)
    end
end

function love.draw()
    local totalWidth = (Config.cards.count - 1) * Config.cards.spacing
    local startX = love.graphics.getWidth()/2 - totalWidth/2
    
    drawCardSlots()
    
    -- Draw cards in slots
    local totalSlotWidth = Config.slots.count * (Config.cards.width + Config.slots.spacing) - Config.slots.spacing
    local slotStartX = love.graphics.getWidth()/2 - totalSlotWidth/2
    local centerY = love.graphics.getHeight()/2
    
    -- Draw opponent's cards in slots
    for i = 1, Config.slots.count do
        if State.slots.opponent[i] then
            local x = slotStartX + (i-1) * (Config.cards.width + Config.slots.spacing) + Config.cards.width/2
            local y = centerY - Config.cards.height - Config.slots.spacing
            drawCard(State.slots.opponent[i], x, y, false, true)
        end
    end
    
    -- Draw player's cards in slots
    for i = 1, Config.slots.count do
        if State.slots.player[i] then
            local x = slotStartX + (i-1) * (Config.cards.width + Config.slots.spacing) + Config.cards.width/2
            local y = centerY + Config.slots.spacing
            drawCard(State.slots.player[i], x, y, false, false)
        end
    end
    
    -- Draw opponent's hand
    for i = 1, Config.cards.count do
        local card = State.opponentCards[i]
        local x = startX + (i-1) * Config.cards.spacing
        local y = 80 + card.heightOffset
        drawCard(card, x, y, true, true)
    end
    
    -- Draw player's non-active cards
    for i = #State.cards, 1, -1 do
        if i ~= State.hoveredCard and i ~= State.draggedCard then
            local card = State.cards[i]
            local x = startX + (i-1) * Config.cards.spacing + card.dragOffset.x
            local y = 520 + card.heightOffset - card.currentRise + card.dragOffset.y
            drawCard(card, x, y, true, false)
        end
    end
    
    -- Draw player's active card last for proper layering
    local activeCard = State.draggedCard or State.hoveredCard
    if activeCard then
        local card = State.cards[activeCard]
        local x = startX + (activeCard-1) * Config.cards.spacing + card.dragOffset.x
        local y = 520 + card.heightOffset - card.currentRise + card.dragOffset.y
        drawCard(card, x, y, activeCard ~= State.draggedCard, false)
    end
    
    drawResourceBars(State.resources.player, false)
    drawResourceBars(State.resources.opponent, true)
    drawRoundInfo()
end

-- Debug controls
function love.keypressed(key)
    if key == "h" then
        State.resources.player.health = math.max(0, State.resources.player.health - 10)
    elseif key == "j" then
        State.resources.player.health = math.min(Config.resources.maxHealth, State.resources.player.health + 10)
    elseif key == "n" then
        State.resources.player.mana = math.max(0, State.resources.player.mana - 1)
    elseif key == "m" then
        State.resources.player.mana = math.min(State.resources.player.maxMana, State.resources.player.mana + 1)
    elseif key == "space" then
        endTurn()
    elseif key == "o" then -- Debug key to end opponent's turn
        if not State.round.isPlayerTurn then
            endTurn()
        end
    end
end
