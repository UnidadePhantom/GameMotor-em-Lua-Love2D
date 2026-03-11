local function requireLocalOrEngine(localName, engineName)
    local ok, module = pcall(require, localName)
    if ok then
        return module
    end
    return require(engineName)
end

local function chooseMode()
    if love.filesystem.getInfo("game/app.lua") then
        return requireLocalOrEngine("game.app", "Engine.Template3D.game.app")
    end
    return requireLocalOrEngine("game.runtime", "Engine.Template3D.game.runtime")
end

local mode = chooseMode()

function love.load()
    if mode.load then
        mode.load()
    end
end

function love.update(dt)
    if mode.update then
        mode.update(dt)
    end
end

function love.draw()
    if mode.draw then
        mode.draw()
    end
end

function love.keypressed(key)
    if mode.keypressed then
        mode.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if mode.mousepressed then
        mode.mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if mode.mousemoved then
        mode.mousemoved(x, y, dx, dy)
    end
end

function love.wheelmoved(x, y)
    if mode.wheelmoved then
        mode.wheelmoved(x, y)
    end
end
