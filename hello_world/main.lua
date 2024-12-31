x = 100

-- update the state of the game every frame
---@param dt number time since the last update in seconds
function love.update(dt)
    if love.keyboard.isDown('space') then
        x = x + 200 * dt
    end
end

-- draw on the screen every frame
function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', x, 100, 50, 50)
end
