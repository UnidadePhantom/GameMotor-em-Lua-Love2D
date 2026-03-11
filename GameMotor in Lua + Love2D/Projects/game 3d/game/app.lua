local app = {}

local okColor, color = pcall(require, "assets.color")
if not okColor then
    color = require("Engine.Template3D.assets.color")
end

local okWorld, World = pcall(require, "game.world")
if not okWorld then
    World = require("Engine.Template3D.game.world")
end

local world

local topUI = {
    barHeight = 32,
    isPlaying = false,
    formasOpen = false,
    importarOpen = false,
    selecaoOpen = false,
    ferramentasOpen = false,
    entidadeOpen = false,
    hudOpen = false,
    infoOpen = false,
    showCrosshair = true,
    showBottomHint = true,
    playButton = { x = 8, y = 4, width = 76, height = 24 },
    formasButton = { x = 90, y = 4, width = 90, height = 24 },
    importarButton = { x = 186, y = 4, width = 110, height = 24 },
    selecaoButton = { x = 302, y = 4, width = 100, height = 24 },
    ferramentasButton = { x = 408, y = 4, width = 120, height = 24 },
    entidadeButton = { x = 534, y = 4, width = 90, height = 24 },
    hudButton = { x = 630, y = 4, width = 70, height = 24 },
    infoButton = { x = 706, y = 4, width = 70, height = 24 },
    formasItems = {
        { id = "cube", label = "Cubo" }
    },
    selecaoItems = {
        { id = "move", label = "Mover" },
        { id = "scale", label = "Escala" }
    },
    ferramentasItems = {
        { id = "light", label = "Luz" },
        { id = "camera", label = "Camera" },
        { id = "script", label = "Script" },
        { id = "effects", label = "Efeitos" }
    },
    activeSelectionMode = "move",
    moveStepPercent = 100,
    scaleStepPercent = 100,
    stepValues = { 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 },
    stepDropdownOpen = false,
    stepDropdownFor = nil,
    stepScrollIndex = 1,
    stepVisibleCount = 6
}

local moveUnitBase = 1.0
local scaleUnitBase = 0.10

local function pointInRect(px, py, r)
    return px >= r.x and px <= (r.x + r.width) and py >= r.y and py <= (r.y + r.height)
end

local function closeTopMenus()
    topUI.formasOpen = false
    topUI.importarOpen = false
    topUI.selecaoOpen = false
    topUI.ferramentasOpen = false
    topUI.entidadeOpen = false
    topUI.hudOpen = false
    topUI.infoOpen = false
    topUI.stepDropdownOpen = false
    topUI.stepDropdownFor = nil
end

local function getMoveStep()
    return moveUnitBase * (topUI.moveStepPercent / 100.0)
end

local function getScaleStep()
    return scaleUnitBase * (topUI.scaleStepPercent / 100.0)
end

local function getStepValueRect(baseX, baseY, rowIndex)
    return {
        x = baseX + 74,
        y = baseY + (rowIndex - 1) * 24 + 2,
        width = 56,
        height = 20
    }
end

local function getStepDropdownRect(baseX, baseY)
    return {
        x = baseX + 136,
        y = baseY,
        width = 64,
        height = topUI.stepVisibleCount * 24
    }
end

local function togglePlayMode()
    topUI.isPlaying = not topUI.isPlaying
    world:setDefaultPlayerEnabled(topUI.isPlaying, "preview-player")
    if topUI.isPlaying then
        world.selectedFace = nil
    end
    closeTopMenus()
end

function app.load()
    world = World.new()
    world:load({ title = "Template3D - Editor de Cena" })
end

function app.update(dt)
    world:update(dt)
end

function app.mousemoved(_, _, dx, dy)
    world:mousemoved(dx, dy)
end

function app.keypressed(key)
    if key == "tab" then
        world:toggleMouseLock()
        closeTopMenus()
        return
    end
    if key == "escape" then
        love.event.quit()
        return
    end
    if key == "e" and not topUI.isPlaying then
        world:pickFaceUnderCrosshair()
        return
    end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local moveStep = getMoveStep()
    local scaleStep = getScaleStep()

    if key == "left" then
        if world.selectedFace and not topUI.isPlaying then
            world:deformSelectedFace(-moveStep, 0, 0)
        else
            world:moveSelectedObject(-moveStep, 0, 0)
        end
    elseif key == "right" then
        if world.selectedFace and not topUI.isPlaying then
            world:deformSelectedFace(moveStep, 0, 0)
        else
            world:moveSelectedObject(moveStep, 0, 0)
        end
    elseif key == "up" then
        if shift then
            if world.selectedFace and not topUI.isPlaying then
                world:deformSelectedFace(0, moveStep, 0)
            else
                world:moveSelectedObject(0, moveStep, 0)
            end
        elseif world.selectedFace and not topUI.isPlaying then
            world:deformSelectedFace(0, 0, -moveStep)
        else
            world:moveSelectedObject(0, 0, -moveStep)
        end
    elseif key == "down" then
        if shift then
            if world.selectedFace and not topUI.isPlaying then
                world:deformSelectedFace(0, -moveStep, 0)
            else
                world:moveSelectedObject(0, -moveStep, 0)
            end
        elseif world.selectedFace and not topUI.isPlaying then
            world:deformSelectedFace(0, 0, moveStep)
        else
            world:moveSelectedObject(0, 0, moveStep)
        end
    elseif key == "pageup" then
        world:scaleSelectedObject(scaleStep)
    elseif key == "pagedown" then
        world:scaleSelectedObject(-scaleStep)
    elseif key == "[" then
        world:scaleSelectedObject(-scaleStep)
    elseif key == "]" then
        world:scaleSelectedObject(scaleStep)
    elseif key == "1" and not topUI.isPlaying then
        world:spawnCube()
    elseif key == "return" and love.keyboard.isDown("lctrl", "rctrl") then
        togglePlayMode()
    end
end

function app.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if pointInRect(x, y, topUI.playButton) then
        togglePlayMode()
        return
    end
    if pointInRect(x, y, topUI.formasButton) then
        local wasOpen = topUI.formasOpen
        closeTopMenus()
        topUI.formasOpen = not wasOpen
        return
    end
    if pointInRect(x, y, topUI.importarButton) then
        local wasOpen = topUI.importarOpen
        closeTopMenus()
        topUI.importarOpen = not wasOpen
        return
    end
    if pointInRect(x, y, topUI.selecaoButton) then
        local wasOpen = topUI.selecaoOpen
        closeTopMenus()
        topUI.selecaoOpen = not wasOpen
        return
    end
    if pointInRect(x, y, topUI.ferramentasButton) then
        local wasOpen = topUI.ferramentasOpen
        closeTopMenus()
        topUI.ferramentasOpen = not wasOpen
        return
    end
    if pointInRect(x, y, topUI.entidadeButton) then
        local wasOpen = topUI.entidadeOpen
        closeTopMenus()
        topUI.entidadeOpen = not wasOpen
        return
    end
    if pointInRect(x, y, topUI.hudButton) then
        local wasOpen = topUI.hudOpen
        closeTopMenus()
        topUI.hudOpen = not wasOpen
        return
    end
    if pointInRect(x, y, topUI.infoButton) then
        local wasOpen = topUI.infoOpen
        closeTopMenus()
        topUI.infoOpen = not wasOpen
        return
    end

    if topUI.formasOpen then
        local itemH = 24
        for i, item in ipairs(topUI.formasItems) do
            local rect = {
                x = topUI.formasButton.x,
                y = topUI.formasButton.y + topUI.formasButton.height + (i - 1) * itemH,
                width = 120,
                height = itemH
            }
            if pointInRect(x, y, rect) then
                if item.id == "cube" then
                    world:spawnCube()
                end
                closeTopMenus()
                return
            end
        end
        topUI.formasOpen = false
    end

    if topUI.importarOpen then
        local itemH = 24
        local importItems = world:getImportItems()
        for i, item in ipairs(importItems) do
            local rect = {
                x = topUI.importarButton.x,
                y = topUI.importarButton.y + topUI.importarButton.height + (i - 1) * itemH,
                width = 220,
                height = itemH
            }
            if pointInRect(x, y, rect) then
                world:spawnImported(item.id)
                closeTopMenus()
                return
            end
        end
        topUI.importarOpen = false
    end

    if topUI.selecaoOpen then
        local dropdownBaseX = topUI.selecaoButton.x
        local dropdownBaseY = topUI.selecaoButton.y + topUI.selecaoButton.height

        if topUI.stepDropdownOpen then
            local dd = getStepDropdownRect(dropdownBaseX, dropdownBaseY)
            for i = 1, topUI.stepVisibleCount do
                local idx = topUI.stepScrollIndex + i - 1
                local val = topUI.stepValues[idx]
                if val then
                    local rect = {
                        x = dd.x,
                        y = dd.y + (i - 1) * 24,
                        width = dd.width,
                        height = 24
                    }
                    if pointInRect(x, y, rect) then
                        if topUI.stepDropdownFor == "move" then
                            topUI.moveStepPercent = val
                        else
                            topUI.scaleStepPercent = val
                        end
                        topUI.stepDropdownOpen = false
                        topUI.stepDropdownFor = nil
                        return
                    end
                end
            end
        end

        local moveValRect = getStepValueRect(dropdownBaseX, dropdownBaseY, 1)
        local scaleValRect = getStepValueRect(dropdownBaseX, dropdownBaseY, 2)
        if pointInRect(x, y, moveValRect) then
            topUI.stepDropdownOpen = true
            topUI.stepDropdownFor = "move"
            return
        end
        if pointInRect(x, y, scaleValRect) then
            topUI.stepDropdownOpen = true
            topUI.stepDropdownFor = "scale"
            return
        end

        local itemH = 24
        for i, item in ipairs(topUI.selecaoItems) do
            local rect = {
                x = topUI.selecaoButton.x,
                y = topUI.selecaoButton.y + topUI.selecaoButton.height + (i - 1) * itemH,
                width = 140,
                height = itemH
            }
            if pointInRect(x, y, rect) then
                topUI.activeSelectionMode = item.id
                return
            end
        end
        if topUI.stepDropdownOpen then
            local dd = getStepDropdownRect(dropdownBaseX, dropdownBaseY)
            if not pointInRect(x, y, dd) then
                topUI.stepDropdownOpen = false
                topUI.stepDropdownFor = nil
            end
        end
    end

    if topUI.ferramentasOpen then
        local itemH = 24
        for i, _ in ipairs(topUI.ferramentasItems) do
            local rect = {
                x = topUI.ferramentasButton.x,
                y = topUI.ferramentasButton.y + topUI.ferramentasButton.height + (i - 1) * itemH,
                width = 140,
                height = itemH
            }
            if pointInRect(x, y, rect) then
                closeTopMenus()
                return
            end
        end
        topUI.ferramentasOpen = false
    end

    if topUI.entidadeOpen then
        local sceneObjects = world:getSceneObjects()
        if #sceneObjects == 0 then
            closeTopMenus()
            return
        end

        local itemH = 24
        for i, _ in ipairs(sceneObjects) do
            local rect = {
                x = topUI.entidadeButton.x,
                y = topUI.entidadeButton.y + topUI.entidadeButton.height + (i - 1) * itemH,
                width = 180,
                height = itemH
            }
            if pointInRect(x, y, rect) then
                world.selectedObjectIndex = i
                world.selectedFace = nil
                closeTopMenus()
                return
            end
        end
        topUI.entidadeOpen = false
    end

    if topUI.hudOpen then
        local itemH = 24
        local hudItems = {
            { id = "crosshair" },
            { id = "hint" }
        }
        for i, item in ipairs(hudItems) do
            local rect = {
                x = topUI.hudButton.x,
                y = topUI.hudButton.y + topUI.hudButton.height + (i - 1) * itemH,
                width = 160,
                height = itemH
            }
            if pointInRect(x, y, rect) then
                if item.id == "crosshair" then
                    topUI.showCrosshair = not topUI.showCrosshair
                elseif item.id == "hint" then
                    topUI.showBottomHint = not topUI.showBottomHint
                end
                return
            end
        end
        topUI.hudOpen = false
    end

    closeTopMenus()
end

function app.wheelmoved(_, y)
    if not topUI.selecaoOpen or not topUI.stepDropdownOpen then
        return
    end

    local mx, my = love.mouse.getPosition()
    local baseX = topUI.selecaoButton.x
    local baseY = topUI.selecaoButton.y + topUI.selecaoButton.height
    local dd = getStepDropdownRect(baseX, baseY)
    if not pointInRect(mx, my, dd) then
        return
    end

    local maxStart = math.max(1, #topUI.stepValues - topUI.stepVisibleCount + 1)
    if y < 0 then
        topUI.stepScrollIndex = math.min(maxStart, topUI.stepScrollIndex + 1)
    elseif y > 0 then
        topUI.stepScrollIndex = math.max(1, topUI.stepScrollIndex - 1)
    end
end

function app.draw()
    world:drawScene({
        drawBackground = true,
        drawGuides = true,
        drawSelection = not topUI.isPlaying,
        highlightSelection = not topUI.isPlaying
    })

    local w = love.graphics.getWidth()
    love.graphics.setColor(0.07, 0.08, 0.10, 0.90)
    love.graphics.rectangle("fill", 0, 0, w, topUI.barHeight)
    love.graphics.setColor(topUI.isPlaying and 0.18 or 0.12, topUI.isPlaying and 0.65 or 0.45, topUI.isPlaying and 0.28 or 0.15, 1.0)
    love.graphics.rectangle("fill", topUI.playButton.x, topUI.playButton.y, topUI.playButton.width, topUI.playButton.height)
    love.graphics.setColor(0.35, 0.42, 0.52, 1.0)
    love.graphics.rectangle("fill", topUI.formasButton.x, topUI.formasButton.y, topUI.formasButton.width, topUI.formasButton.height)
    love.graphics.rectangle("fill", topUI.importarButton.x, topUI.importarButton.y, topUI.importarButton.width, topUI.importarButton.height)
    love.graphics.rectangle("fill", topUI.selecaoButton.x, topUI.selecaoButton.y, topUI.selecaoButton.width, topUI.selecaoButton.height)
    love.graphics.rectangle("fill", topUI.ferramentasButton.x, topUI.ferramentasButton.y, topUI.ferramentasButton.width, topUI.ferramentasButton.height)
    love.graphics.rectangle("fill", topUI.entidadeButton.x, topUI.entidadeButton.y, topUI.entidadeButton.width, topUI.entidadeButton.height)
    love.graphics.rectangle("fill", topUI.hudButton.x, topUI.hudButton.y, topUI.hudButton.width, topUI.hudButton.height)
    love.graphics.rectangle("fill", topUI.infoButton.x, topUI.infoButton.y, topUI.infoButton.width, topUI.infoButton.height)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(topUI.isPlaying and "Stop" or "Play", topUI.playButton.x + 20, topUI.playButton.y + 4)
    love.graphics.print("Formas", topUI.formasButton.x + 12, topUI.formasButton.y + 4)
    love.graphics.print("Importar", topUI.importarButton.x + 14, topUI.importarButton.y + 4)
    love.graphics.print("Selecao", topUI.selecaoButton.x + 12, topUI.selecaoButton.y + 4)
    love.graphics.print("Ferramentas", topUI.ferramentasButton.x + 8, topUI.ferramentasButton.y + 4)
    love.graphics.print("Entidade", topUI.entidadeButton.x + 8, topUI.entidadeButton.y + 4)
    love.graphics.print("Hud", topUI.hudButton.x + 22, topUI.hudButton.y + 4)
    love.graphics.print("Inf", topUI.infoButton.x + 22, topUI.infoButton.y + 4)

    if topUI.formasOpen then
        local itemH = 24
        for i, item in ipairs(topUI.formasItems) do
            local py = topUI.formasButton.y + topUI.formasButton.height + (i - 1) * itemH
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.formasButton.x, py, 120, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print(item.label, topUI.formasButton.x + 10, py + 4)
        end
    end

    if topUI.importarOpen then
        local itemH = 24
        for i, item in ipairs(world:getImportItems()) do
            local py = topUI.importarButton.y + topUI.importarButton.height + (i - 1) * itemH
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.importarButton.x, py, 220, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print(item.label, topUI.importarButton.x + 8, py + 4)
        end
    end

    if topUI.selecaoOpen then
        local baseX = topUI.selecaoButton.x
        local baseY = topUI.selecaoButton.y + topUI.selecaoButton.height
        local itemH = 24
        love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
        love.graphics.rectangle("fill", baseX, baseY, 136, itemH * 2)

        local isMove = topUI.activeSelectionMode == "move"
        local isScale = topUI.activeSelectionMode == "scale"
        love.graphics.setColor(isMove and 0.20 or 0.14, isMove and 0.30 or 0.16, isMove and 0.40 or 0.20, 0.96)
        love.graphics.rectangle("fill", baseX, baseY, 136, itemH)
        love.graphics.setColor(0.85, 0.90, 1.0, 1)
        love.graphics.print("Mover", baseX + 8, baseY + 4)

        love.graphics.setColor(isScale and 0.20 or 0.14, isScale and 0.30 or 0.16, isScale and 0.40 or 0.20, 0.96)
        love.graphics.rectangle("fill", baseX, baseY + itemH, 136, itemH)
        love.graphics.setColor(0.85, 0.90, 1.0, 1)
        love.graphics.print("Escala", baseX + 8, baseY + itemH + 4)

        local mv = getStepValueRect(baseX, baseY, 1)
        local sv = getStepValueRect(baseX, baseY, 2)
        love.graphics.setColor(0.10, 0.12, 0.16, 0.98)
        love.graphics.rectangle("fill", mv.x, mv.y, mv.width, mv.height)
        love.graphics.rectangle("fill", sv.x, sv.y, sv.width, sv.height)
        love.graphics.setColor(0.95, 0.97, 1.0, 1.0)
        love.graphics.printf(tostring(topUI.moveStepPercent), mv.x, mv.y + 2, mv.width, "center")
        love.graphics.printf(tostring(topUI.scaleStepPercent), sv.x, sv.y + 2, sv.width, "center")

        if topUI.stepDropdownOpen then
            local dd = getStepDropdownRect(baseX, baseY)
            love.graphics.setColor(0.08, 0.10, 0.13, 0.98)
            love.graphics.rectangle("fill", dd.x, dd.y, dd.width, dd.height)
            for i = 1, topUI.stepVisibleCount do
                local idx = topUI.stepScrollIndex + i - 1
                local val = topUI.stepValues[idx]
                if val then
                    local py = dd.y + (i - 1) * 24
                    local active = (topUI.stepDropdownFor == "move" and topUI.moveStepPercent == val)
                        or (topUI.stepDropdownFor == "scale" and topUI.scaleStepPercent == val)
                    love.graphics.setColor(active and 0.20 or 0.14, active and 0.30 or 0.16, active and 0.40 or 0.20, 0.96)
                    love.graphics.rectangle("fill", dd.x + 2, py + 2, dd.width - 4, 20)
                    love.graphics.setColor(0.90, 0.94, 1.0, 1.0)
                    love.graphics.printf(tostring(val), dd.x, py + 4, dd.width, "center")
                end
            end
        end
    end

    if topUI.ferramentasOpen then
        local itemH = 24
        for i, item in ipairs(topUI.ferramentasItems) do
            local py = topUI.ferramentasButton.y + topUI.ferramentasButton.height + (i - 1) * itemH
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.ferramentasButton.x, py, 140, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print(item.label, topUI.ferramentasButton.x + 10, py + 4)
        end
    end

    if topUI.entidadeOpen then
        local itemH = 24
        local dropdownWidth = 180
        local sceneObjects = world:getSceneObjects()
        if #sceneObjects == 0 then
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.entidadeButton.x, topUI.entidadeButton.y + topUI.entidadeButton.height, dropdownWidth, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print("Sem objetos", topUI.entidadeButton.x + 10, topUI.entidadeButton.y + topUI.entidadeButton.height + 4)
        else
            for i, obj in ipairs(sceneObjects) do
                local py = topUI.entidadeButton.y + topUI.entidadeButton.height + (i - 1) * itemH
                local active = world.selectedObjectIndex == i
                love.graphics.setColor(active and 0.20 or 0.14, active and 0.30 or 0.16, active and 0.40 or 0.20, 0.96)
                love.graphics.rectangle("fill", topUI.entidadeButton.x, py, dropdownWidth, itemH)
                love.graphics.setColor(0.85, 0.90, 1.0, 1)
                love.graphics.print(obj.name or ("Objeto " .. i), topUI.entidadeButton.x + 8, py + 4)
            end
        end
    end

    if topUI.hudOpen then
        local itemH = 24
        local items = {
            { label = "Mira", enabled = topUI.showCrosshair },
            { label = "Dica", enabled = topUI.showBottomHint }
        }
        for i, item in ipairs(items) do
            local py = topUI.hudButton.y + topUI.hudButton.height + (i - 1) * itemH
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.hudButton.x, py, 160, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print(item.label .. ": " .. (item.enabled and "On" or "Off"), topUI.hudButton.x + 8, py + 4)
        end
    end

    if topUI.infoOpen then
        local info = world:getSceneInfo()
        local x = topUI.infoButton.x
        local y = topUI.infoButton.y + topUI.infoButton.height
        local iw, ih = 520, 188
        love.graphics.setColor(0.08, 0.10, 0.13, 0.96)
        love.graphics.rectangle("fill", x, y, iw, ih)
        love.graphics.setColor(color.text)
        love.graphics.print("OBJ base: " .. (info.loadedObjPath or "nao carregado"), x + 10, y + 8)
        if info.sceneMesh then
            love.graphics.print(("Vertices: %d | Faces: %d"):format(#info.sceneMesh.vertices, #info.sceneMesh.faces), x + 10, y + 28)
        else
            love.graphics.print(info.loadError or "-", x + 10, y + 28)
        end
        love.graphics.print(("Objetos: %d"):format(#world:getSceneObjects()), x + 10, y + 48)
        love.graphics.print("E: selecionar face/objeto na mira", x + 10, y + 68)
        love.graphics.print("Setas: mover | Shift+Up/Down: subir/descer", x + 10, y + 88)
        love.graphics.print("PgUp/PgDown e [ ]: escala do objeto selecionado", x + 10, y + 108)
        love.graphics.print("Ctrl+Enter ou Play: alternar modo teste", x + 10, y + 128)
        love.graphics.print(("Camera: %.2f %.2f %.2f"):format(world.camera.position.x, world.camera.position.y, world.camera.position.z), x + 10, y + 148)
    end

    if topUI.showCrosshair then
        world:drawCrosshair()
    end
    if topUI.showBottomHint then
        world:drawBottomHint(topUI.isPlaying and "Modo Play" or "Editor")
    end
end

return app
