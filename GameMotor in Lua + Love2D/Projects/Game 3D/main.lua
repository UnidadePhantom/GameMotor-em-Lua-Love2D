local okApp, app = pcall(require, "game.app")
if not okApp then
    app = require("Engine.Template3D.game.app")
end

function love.load()
    if app.load then
        app.load()
    end
end

function love.update(dt)
    if app.update then
        app.update(dt)
    end
end

function love.draw()
    if app.draw then
        app.draw()
    end
end

function love.keypressed(key)
    if app.keypressed then
        app.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if app.mousepressed then
        app.mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if app.mousemoved then
        app.mousemoved(x, y, dx, dy)
    end
end

function love.wheelmoved(x, y)
    if app.wheelmoved then
        app.wheelmoved(x, y)
    end
end
