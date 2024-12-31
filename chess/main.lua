local inspect = require('lib.inspect')

-- Board configuration
local boardSize = {
    x = 4,
    y = 4
}
local squareSize = 100

-- Creates a new chess piece with movement and interaction behaviors
function create_piece(name, color, pos)
    -- Currently hardcoded diagonal movement pattern
    local validSquares = {{
        x = 0,
        y = 0
    }, {
        x = 1,
        y = 1
    }, {
        x = 2,
        y = 2
    }, {
        x = 3,
        y = 3
    }}

    return {
        name = name,
        color = color,
        pos = pos,
        -- Movement handling
        move = function(self, square)
            -- Only move if we're not dropping on the original position
            if self.pos.x ~= square.x or self.pos.y ~= square.y then
                self.pos.x = square.x
                self.pos.y = square.y
                self:unclick()
                self:undrag()
            end
        end,
        -- Click state management
        clicked = false,
        click = function(self, x, y)
            self.clicked = true
        end,
        unclick = function(self)
            self.clicked = false
        end,
        -- Drag state management
        dragging = false,
        drag = function(self)
            self.dragging = true
        end,
        undrag = function(self)
            self.dragging = false
        end,
        -- Move validation
        validSquare = function(self, square)
            if square.x == self.pos.x and square.y == self.pos.y then
                return false
            end
            for _, validSquare in ipairs(validSquares) do
                if square.x == validSquare.x and square.y == validSquare.y then
                    return true
                end
            end
            return false
        end,
        validSquares = function(self)
            return validSquares
        end
    }
end

-- Initial game pieces
local pieces = {create_piece("bishop", "black", {
    x = 1,
    y = 1
}), create_piece("pawn", "white", {
    x = 3,
    y = 2
})}

-- LÖVE callbacks
function love.load()
    love.window.setTitle("Chess UI")
    love.window.setMode(400, 400)
    love.graphics.setDefaultFilter("nearest", "nearest")
end

function love.update(dt)
end

-- Converts screen coordinates to game board coordinates
function xyToGame(x, y)
    local squareSize = 100
    local boardX = math.floor(x / squareSize)
    local boardY = math.floor(y / squareSize)

    -- Check if click is within board bounds
    if boardX >= 0 and boardX < boardSize.x and boardY >= 0 and boardY < boardSize.y then

        -- Check if square contains a piece
        for _, piece in ipairs(pieces) do
            if piece.pos.x == boardX and piece.pos.y == boardY then
                return {
                    square = {
                        x = boardX,
                        y = boardY
                    },
                    piece = piece
                }
            end
        end

        -- Square is valid but no piece found
        return {
            square = {
                x = boardX,
                y = boardY
            },
            piece = nil
        }
    end

    -- Click was outside board bounds
    return {
        square = nil,
        piece = nil
    }
end

-- Mouse interaction handlers
function love.mousereleased(x, y, button)
    -- When mouse released, undrag all pieces
    for _, piece in ipairs(pieces) do
        piece:undrag()
    end

    -- Check if we've dragged a piece to a valid square
    local result = xyToGame(x, y)
    if result.square then
        for _, piece in ipairs(pieces) do
            if piece.clicked and piece:validSquare(result.square) then
                piece:move(result.square)
            end
        end
    end
end

function love.mousepressed(x, y)
    local result = xyToGame(x, y)

    -- Check if we've clicked on a valid square
    if result.square then
        for _, piece in ipairs(pieces) do

            -- If we have a piece clicked and it's a valid square, move it
            if piece.clicked and piece:validSquare(result.square) then
                piece:move(result.square)
                return
            end
        end
    end

    -- Check if we've clicked on a piece
    if result.piece then
        result.piece:click(x, y)
        result.piece:drag()
        return
    end

    -- Otherwise, unclick all pieces
    for _, piece in ipairs(pieces) do
        piece:unclick()
    end
end

-- Rendering
function love.draw()
    local mouseX, mouseY = love.mouse.getPosition()
    local startX = 0
    local startY = 0

    -- Draw board squares
    for row = 0, boardSize.y - 1 do
        for col = 0, boardSize.x - 1 do
            -- Alternate colors based on position
            if (row + col) % 2 == 0 then
                love.graphics.setColor(0.93, 0.93, 0.82) -- Beige
            else
                love.graphics.setColor(0.82, 0.77, 0.62) -- Dark beige
            end

            -- Draw filled square
            love.graphics.rectangle("fill", startX + (col * squareSize), startY + (row * squareSize), squareSize,
                squareSize)

            -- Draw black border
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", startX + (col * squareSize), startY + (row * squareSize), squareSize,
                squareSize)
        end
    end

    -- Reset color to white for pieces
    love.graphics.setColor(1, 1, 1)

    -- Draw all pieces
    for _, piece in ipairs(pieces) do
        local pieceImage = love.graphics.newImage("assets/chess_" .. piece.name .. ".png")
        -- Calculate scale to fit the piece in the square (using 0.8 to leave some padding)
        local scale = (squareSize * 0.8) / math.max(pieceImage:getWidth(), pieceImage:getHeight())
        -- Calculate position to center the piece in the square
        local pieceX = startX + (piece.pos.x * squareSize) + (squareSize - pieceImage:getWidth() * scale) / 2
        local pieceY = startY + (piece.pos.y * squareSize) + (squareSize - pieceImage:getHeight() * scale) / 2

        -- Draw valid move indicators and highlight current square
        if piece.clicked or piece.dragging then
            -- Set color for valid move indicators (faded green)
            love.graphics.setColor(0, 0.5, 0, 0.3)

            -- Draw current square highlight
            local currentX = startX + (piece.pos.x * squareSize)
            local currentY = startY + (piece.pos.y * squareSize)
            love.graphics.rectangle("fill", currentX, currentY, squareSize, squareSize)

            -- Draw indicators for valid moves
            for _, square in ipairs(piece:validSquares()) do
                -- Only draw circle if it's not the current square
                if square.x ~= piece.pos.x or square.y ~= piece.pos.y then
                    local validX = startX + (square.x * squareSize) + squareSize / 2
                    local validY = startY + (square.y * squareSize) + squareSize / 2
                    love.graphics.circle("fill", validX, validY, squareSize * 0.2)
                end
            end
        end

        -- Highlight square under dragged piece if it's a valid move
        if piece.dragging then
            local mouseX, mouseY = love.mouse.getPosition()
            -- Convert mouse position to board coordinates
            local boardX = math.floor((mouseX - startX) / squareSize)
            local boardY = math.floor((mouseY - startY) / squareSize)

            -- Check if mouse is over a valid square
            for _, square in ipairs(piece:validSquares()) do
                if (square.x == boardX and square.y == boardY) and (square.x ~= piece.pos.x or square.y ~= piece.pos.y) then
                    love.graphics.setColor(0, 0.5, 0, 0.3)
                    local highlightX = startX + (boardX * squareSize)
                    local highlightY = startY + (boardY * squareSize)
                    love.graphics.rectangle("fill", highlightX, highlightY, squareSize, squareSize)
                    break
                end
            end
        end

        -- Draw piece with appropriate color and transparency
        local alpha = piece.dragging and 0.5 or 1
        if piece.color == "white" then
            love.graphics.setColor(1, 1, 1, alpha)
        else
            love.graphics.setColor(0.2, 0.2, 0.2, alpha)
        end
        love.graphics.draw(pieceImage, pieceX, pieceY, 0, scale, scale)

        -- Draw dragged piece at cursor position
        if piece.dragging then
            local mouseX, mouseY = love.mouse.getPosition()
            -- Center the piece on cursor
            local floatingX = mouseX - (pieceImage:getWidth() * scale) / 2
            local floatingY = mouseY - (pieceImage:getHeight() * scale) / 2
            -- Draw the floating piece with correct color
            if piece.color == "white" then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0.2, 0.2, 0.2)
            end
            love.graphics.draw(pieceImage, floatingX, floatingY, 0, scale, scale)
        end
    end
end
