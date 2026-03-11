local runtime = {}

local okWorld, World = pcall(require, "game.world")
if not okWorld then
    World = require("Engine.Template3D.game.world")
end

local world

function runtime.load()
    world = World.new()
    world:load({
        title = "Template3D - Runtime",
        includeDefaultPlayer = true
    })
end

function runtime.update(dt)
    world:update(dt)
end

function runtime.draw()
    world:drawScene({
        drawBackground = true,
        drawGuides = false,
        drawSelection = false,
        highlightSelection = false
    })
    world:drawCrosshair()
    world:drawBottomHint("Runtime")
end

function runtime.keypressed(key)
    if key == "tab" then
        world:toggleMouseLock()
        return
    end
    if key == "escape" then
        love.event.quit()
    end
end

function runtime.mousemoved(_, _, dx, dy)
    world:mousemoved(dx, dy)
end

return runtime
