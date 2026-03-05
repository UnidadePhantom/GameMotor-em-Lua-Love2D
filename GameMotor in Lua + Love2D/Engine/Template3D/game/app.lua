local app = {}

local okColor, color = pcall(require, "assets.color")
if not okColor then
    color = require("Engine.Template3D.assets.color")
end

local okMat4, mat4 = pcall(require, "game.math.mat4")
if not okMat4 then
    mat4 = require("Engine.Template3D.game.math.mat4")
end

local okVec3, vec3 = pcall(require, "game.math.vec3")
if not okVec3 then
    vec3 = require("Engine.Template3D.game.math.vec3")
end

local okCamera, cameraModule = pcall(require, "game.graphics.camera")
if not okCamera then
    cameraModule = require("Engine.Template3D.game.graphics.camera")
end

local okMesh, meshModule = pcall(require, "game.graphics.mesh")
if not okMesh then
    meshModule = require("Engine.Template3D.game.graphics.mesh")
end

local okShader, shader = pcall(require, "game.graphics.shader")
if not okShader then
    shader = require("Engine.Template3D.game.graphics.shader")
end

local okObjLoader, objLoader = pcall(require, "game.assets.obj_loader")
if not okObjLoader then
    objLoader = require("Engine.Template3D.game.assets.obj_loader")
end

local camera
local mouseLocked = true
local groundHeight = 0.0

local sceneMesh
local loadedObjPath = nil
local loadError = nil

local sceneObjects = {}
local selectedObjectIndex = nil
local selectedFace = nil

local topUI = {
    barHeight = 32,
    formasOpen = false,
    importarOpen = false,
    selecaoOpen = false,
    ferramentasOpen = false,
    infoOpen = false,
    formasButton = { x = 8, y = 4, width = 90, height = 24 },
    importarButton = { x = 104, y = 4, width = 110, height = 24 },
    selecaoButton = { x = 220, y = 4, width = 100, height = 24 },
    ferramentasButton = { x = 326, y = 4, width = 120, height = 24 },
    infoButton = { x = 452, y = 4, width = 70, height = 24 },
    formasItems = {
        { id = "cube", label = "Cubo" }
    },
    importarItems = {},
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

local function cloneMesh(src)
    local vertices = {}
    local faces = {}
    local polygons = {}

    for i, v in ipairs(src.vertices or {}) do
        vertices[i] = { x = v.x, y = v.y, z = v.z }
    end
    for i, f in ipairs(src.faces or {}) do
        faces[i] = { f[1], f[2], f[3] }
    end
    for i, p in ipairs(src.polygons or {}) do
        polygons[i] = {}
        for j, idx in ipairs(p) do
            polygons[i][j] = idx
        end
    end

    local out = meshModule.new(vertices, faces)
    out.polygons = polygons
    return out
end

local function normalizeMeshWindingOutward(mesh)
    if not mesh or not mesh.vertices or not mesh.faces then
        return
    end
    if #mesh.vertices == 0 or #mesh.faces == 0 then
        return
    end

    local cx, cy, cz = 0, 0, 0
    for _, v in ipairs(mesh.vertices) do
        cx = cx + v.x
        cy = cy + v.y
        cz = cz + v.z
    end
    local inv = 1.0 / #mesh.vertices
    cx, cy, cz = cx * inv, cy * inv, cz * inv

    for i, face in ipairs(mesh.faces) do
        local ia, ib, ic = face[1], face[2], face[3]
        local a, b, c = mesh.vertices[ia], mesh.vertices[ib], mesh.vertices[ic]
        if a and b and c then
            local e1 = vec3.sub(b, a)
            local e2 = vec3.sub(c, a)
            local n = vec3.cross(e1, e2)
            local fx = (a.x + b.x + c.x) / 3.0
            local fy = (a.y + b.y + c.y) / 3.0
            local fz = (a.z + b.z + c.z) / 3.0
            local dx = fx - cx
            local dy = fy - cy
            local dz = fz - cz
            local outward = n.x * dx + n.y * dy + n.z * dz
            if outward < 0 then
                mesh.faces[i] = { ia, ic, ib }
            end
        end
    end
end

local function makeObject(name, mesh, canDeform, style, position, scale)
    return {
        name = name,
        mesh = mesh,
        canDeform = canDeform,
        style = style,
        position = position or { x = 0, y = 0.5, z = 0 },
        scale = scale or { x = 1, y = 1, z = 1 }
    }
end

local function getMoveStep()
    return moveUnitBase * (topUI.moveStepPercent / 100.0)
end

local function getScaleStep()
    return scaleUnitBase * (topUI.scaleStepPercent / 100.0)
end

local function objWorldMatrix(obj)
    local t = mat4.translate(obj.position.x, obj.position.y, obj.position.z)
    local s = mat4.scale(obj.scale.x, obj.scale.y, obj.scale.z)
    return mat4.mul(t, s)
end

local function localToWorld(obj, v)
    return {
        x = obj.position.x + v.x * obj.scale.x,
        y = obj.position.y + v.y * obj.scale.y,
        z = obj.position.z + v.z * obj.scale.z
    }
end

local function fileExists(path)
    return love.filesystem.getInfo(path) ~= nil
end

local function findObjPath()
    local candidates = {
        "assets/models/base.obj",
        "assets/models/untitled.obj"
    }
    for _, path in ipairs(candidates) do
        if fileExists(path) then
            return path
        end
    end
    return nil
end

local function refreshImportItems()
    topUI.importarItems = {}
    local ok, items = pcall(love.filesystem.getDirectoryItems, "assets/models")
    if not ok or not items then
        return
    end
    table.sort(items)
    for _, name in ipairs(items) do
        if name:lower():match("%.obj$") then
            topUI.importarItems[#topUI.importarItems + 1] = {
                id = "assets/models/" .. name,
                label = name
            }
        end
    end
end

local function loadSceneMesh()
    local path = findObjPath()
    if not path then
        return nil, nil, "Nenhum .obj encontrado em assets/models."
    end
    local mesh, err = objLoader.load(path)
    if mesh and #mesh.vertices > 0 and #mesh.faces > 0 then
        normalizeMeshWindingOutward(mesh)
        return mesh, path, nil
    end
    return nil, path, err or "OBJ sem vertices/faces validos."
end

local function spawnCube()
    local f = camera:getForward()
    local px = camera.position.x + f.x * 4.0
    local py = math.max(groundHeight + 0.5, camera.position.y + f.y * 4.0)
    local pz = camera.position.z + f.z * 4.0

    sceneObjects[#sceneObjects + 1] = makeObject(
        "Cubo",
        cloneMesh(meshModule.cube(1.0)),
        true,
        {
            fill = color.modelFill,
            wireframe = false,
            ambient = 0.62,
            diffuse = 0.32,
            focus = 0.06,
            cull = true,
            invertWinding = true
        },
        { x = px, y = py, z = pz },
        { x = 1, y = 1, z = 1 }
    )
    selectedObjectIndex = #sceneObjects
end

local function spawnImported(path)
    local mesh, err = objLoader.load(path)
    if not mesh then
        loadError = err
        return
    end
    normalizeMeshWindingOutward(mesh)

    local f = camera:getForward()
    local px = camera.position.x + f.x * 5.0
    local py = math.max(groundHeight + 0.5, camera.position.y + f.y * 5.0)
    local pz = camera.position.z + f.z * 5.0

    sceneObjects[#sceneObjects + 1] = makeObject(
        "Importado: " .. path:match("([^/\\]+)$"),
        cloneMesh(mesh),
        false,
        {
            fill = color.sceneFill,
            wireframe = false,
            ambient = 0.58,
            diffuse = 0.34,
            focus = 0.06,
            cull = true
        },
        { x = px, y = py, z = pz },
        { x = 1, y = 1, z = 1 }
    )
    selectedObjectIndex = #sceneObjects
end

local function rayTriangleIntersect(origin, dir, a, b, c)
    local eps = 1e-6
    local e1 = vec3.sub(b, a)
    local e2 = vec3.sub(c, a)
    local h = vec3.cross(dir, e2)
    local det = vec3.dot(e1, h)
    if det > -eps and det < eps then
        return nil
    end
    local invDet = 1.0 / det
    local s = vec3.sub(origin, a)
    local u = invDet * vec3.dot(s, h)
    if u < 0 or u > 1 then
        return nil
    end
    local q = vec3.cross(s, e1)
    local v = invDet * vec3.dot(dir, q)
    if v < 0 or (u + v) > 1 then
        return nil
    end
    local t = invDet * vec3.dot(e2, q)
    if t > eps then
        return t
    end
    return nil
end

local function pickFaceUnderCrosshair()
    local origin = { x = camera.position.x, y = camera.position.y, z = camera.position.z }
    local dir = camera:getForward()
    local best = nil
    local bestT = math.huge

    for oi, obj in ipairs(sceneObjects) do
        local polys = obj.mesh.polygons
        if not polys or #polys == 0 then
            polys = obj.mesh.faces
        end

        for _, poly in ipairs(polys) do
            if #poly >= 3 then
                local w0 = localToWorld(obj, obj.mesh.vertices[poly[1]])
                for i = 2, #poly - 1 do
                    local w1 = localToWorld(obj, obj.mesh.vertices[poly[i]])
                    local w2 = localToWorld(obj, obj.mesh.vertices[poly[i + 1]])
                    local t = rayTriangleIntersect(origin, dir, w0, w1, w2)
                    if t and t < bestT then
                        bestT = t
                        best = {
                            objectIndex = oi,
                            poly = poly
                        }
                    end
                end
            end
        end
    end

    if best then
        selectedObjectIndex = best.objectIndex
        local obj = sceneObjects[best.objectIndex]
        if obj.canDeform then
            selectedFace = best
        else
            selectedFace = nil
        end
    else
        selectedFace = nil
    end
end

local function deformSelectedFace(dx, dy, dz)
    if not selectedFace then
        return
    end
    local obj = sceneObjects[selectedFace.objectIndex]
    if not obj or not obj.canDeform then
        return
    end

    local touched = {}
    for _, idx in ipairs(selectedFace.poly) do
        if not touched[idx] then
            local v = obj.mesh.vertices[idx]
            if v then
                v.x = v.x + dx
                v.y = v.y + dy
                v.z = v.z + dz
            end
            touched[idx] = true
        end
    end
end

local function moveSelectedObject(dx, dy, dz)
    local obj = selectedObjectIndex and sceneObjects[selectedObjectIndex] or nil
    if not obj then
        return
    end
    obj.position.x = obj.position.x + dx
    obj.position.y = obj.position.y + dy
    obj.position.z = obj.position.z + dz
end

local function scaleSelectedObject(amount)
    local obj = selectedObjectIndex and sceneObjects[selectedObjectIndex] or nil
    if not obj then
        return
    end
    obj.scale.x = math.max(0.1, obj.scale.x + amount)
    obj.scale.y = math.max(0.1, obj.scale.y + amount)
    obj.scale.z = math.max(0.1, obj.scale.z + amount)
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

local function projectWorldPoint(view, proj, p, w, h)
    local vx, vy, vz = mat4.transformPoint(view, p, 1.0)
    if vz > -(camera.near or 0.05) then
        return nil, nil
    end
    local x, y, _, ww = mat4.transformPoint(proj, { x = vx, y = vy, z = vz }, 1.0)
    if ww <= 0.00001 then
        return nil, nil
    end
    local nx, ny = x / ww, y / ww
    return (nx * 0.5 + 0.5) * w, (1.0 - (ny * 0.5 + 0.5)) * h
end

local function drawSelectedFaceOutline()
    if not selectedFace then
        return
    end
    local obj = sceneObjects[selectedFace.objectIndex]
    if not obj then
        return
    end

    local w, h = love.graphics.getDimensions()
    local view = camera:getViewMatrix()
    local proj = camera:getProjectionMatrix(w, h)
    local pts = {}

    for _, idx in ipairs(selectedFace.poly) do
        local v = obj.mesh.vertices[idx]
        if v then
            local wp = localToWorld(obj, v)
            local sx, sy = projectWorldPoint(view, proj, wp, w, h)
            if sx then
                pts[#pts + 1] = sx
                pts[#pts + 1] = sy
            end
        end
    end

    if #pts >= 6 then
        love.graphics.setColor(0.30, 1.0, 0.45, 1.0)
        love.graphics.setLineWidth(2.0)
        love.graphics.polygon("line", pts)
        love.graphics.setLineWidth(1.0)
    end
end

local function drawGrid()
    local width, height = love.graphics.getDimensions()
    local view = camera:getViewMatrix()
    local proj = camera:getProjectionMatrix(width, height)
    local nearPlane = camera.near or 0.05

    local function project(v)
        local x, y, _, w = mat4.transformPoint(proj, v, 1.0)
        if w <= 0.00001 then
            return nil, nil
        end
        local nx, ny = x / w, y / w
        return (nx * 0.5 + 0.5) * width, (1.0 - (ny * 0.5 + 0.5)) * height
    end

    local function clipLineToNear(a, b)
        local inA = a.z <= -nearPlane
        local inB = b.z <= -nearPlane

        if not inA and not inB then
            return nil, nil
        end
        if inA and inB then
            return a, b
        end

        local dz = b.z - a.z
        if math.abs(dz) < 0.000001 then
            return nil, nil
        end

        local t = ((-nearPlane) - a.z) / dz
        local hit = {
            x = a.x + (b.x - a.x) * t,
            y = a.y + (b.y - a.y) * t,
            z = -nearPlane
        }

        if inA then
            return a, hit
        end
        return hit, b
    end

    local halfSize = 20
    love.graphics.setColor(0.28, 0.36, 0.48, 0.55)
    for i = -halfSize, halfSize do
        local a = { x = i, y = groundHeight, z = -halfSize }
        local b = { x = i, y = groundHeight, z = halfSize }
        local c = { x = -halfSize, y = groundHeight, z = i }
        local d = { x = halfSize, y = groundHeight, z = i }
        local avx, avy, avz = mat4.transformPoint(view, a, 1.0)
        local bvx, bvy, bvz = mat4.transformPoint(view, b, 1.0)
        local cvx, cvy, cvz = mat4.transformPoint(view, c, 1.0)
        local dvx, dvy, dvz = mat4.transformPoint(view, d, 1.0)

        local l1a, l1b = clipLineToNear({ x = avx, y = avy, z = avz }, { x = bvx, y = bvy, z = bvz })
        if l1a and l1b then
            local x1, y1 = project(l1a)
            local x2, y2 = project(l1b)
            if x1 and x2 then
                love.graphics.line(x1, y1, x2, y2)
            end
        end

        local l2a, l2b = clipLineToNear({ x = cvx, y = cvy, z = cvz }, { x = dvx, y = dvy, z = dvz })
        if l2a and l2b then
            local x3, y3 = project(l2a)
            local x4, y4 = project(l2b)
            if x3 and x4 then
                love.graphics.line(x3, y3, x4, y4)
            end
        end
    end

    -- Eixos centrais da grade: X vermelho, Z verde e guia Y azul para cima.
    local function drawAxisLine(a, b, rgba)
        local avx, avy, avz = mat4.transformPoint(view, a, 1.0)
        local bvx, bvy, bvz = mat4.transformPoint(view, b, 1.0)
        local l1a, l1b = clipLineToNear({ x = avx, y = avy, z = avz }, { x = bvx, y = bvy, z = bvz })
        if l1a and l1b then
            local x1, y1 = project(l1a)
            local x2, y2 = project(l1b)
            if x1 and x2 then
                love.graphics.setColor(rgba)
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    end

    drawAxisLine({ x = -halfSize, y = groundHeight, z = 0 }, { x = halfSize, y = groundHeight, z = 0 }, { 1.0, 0.30, 0.30, 0.95 })
    drawAxisLine({ x = 0, y = groundHeight, z = -halfSize }, { x = 0, y = groundHeight, z = halfSize }, { 0.30, 1.0, 0.45, 0.95 })
end

local function drawBlueGuideOverlay()
    local width, height = love.graphics.getDimensions()
    local view = camera:getViewMatrix()
    local proj = camera:getProjectionMatrix(width, height)
    local nearPlane = camera.near or 0.05

    local function project(v)
        local x, y, _, w = mat4.transformPoint(proj, v, 1.0)
        if w <= 0.00001 then
            return nil, nil
        end
        local nx, ny = x / w, y / w
        return (nx * 0.5 + 0.5) * width, (1.0 - (ny * 0.5 + 0.5)) * height
    end

    local function clipLineToNear(a, b)
        local inA = a.z <= -nearPlane
        local inB = b.z <= -nearPlane
        if not inA and not inB then
            return nil, nil
        end
        if inA and inB then
            return a, b
        end
        local dz = b.z - a.z
        if math.abs(dz) < 0.000001 then
            return nil, nil
        end
        local t = ((-nearPlane) - a.z) / dz
        local hit = {
            x = a.x + (b.x - a.x) * t,
            y = a.y + (b.y - a.y) * t,
            z = -nearPlane
        }
        if inA then
            return a, hit
        end
        return hit, b
    end

    local start = { x = 0, y = groundHeight + 0.01, z = 0 }
    local finish = { x = 0, y = groundHeight + 1.0, z = 0 }
    local svx, svy, svz = mat4.transformPoint(view, start, 1.0)
    local fvx, fvy, fvz = mat4.transformPoint(view, finish, 1.0)
    local a, b = clipLineToNear({ x = svx, y = svy, z = svz }, { x = fvx, y = fvy, z = fvz })
    if a and b then
        local x1, y1 = project(a)
        local x2, y2 = project(b)
        if x1 and x2 then
            love.graphics.setColor(0.35, 0.70, 1.0, 0.95)
            love.graphics.line(x1, y1, x2, y2)
        end
    end
end

function app.load()
    love.window.setTitle("Template3D - Base de Cena")
    love.graphics.setBackgroundColor(color.background)
    local cw, ch = love.graphics.getDimensions()
    love.window.setMode(cw, ch, { resizable = true, minwidth = 640, minheight = 360 })

    camera = cameraModule.new({ speed = 4.2, sensitivity = 0.0028 })
    camera.position.x = 0
    camera.position.y = 1.4
    camera.position.z = 4.2

    sceneMesh, loadedObjPath, loadError = loadSceneMesh()
    if sceneMesh then
        sceneObjects[#sceneObjects + 1] = makeObject(
            "Base",
            cloneMesh(sceneMesh),
            false,
            {
                fill = color.sceneFill,
                wireframe = false,
                ambient = 0.58,
                diffuse = 0.34,
                focus = 0.06,
                cull = true
            },
            { x = 0, y = 0, z = 0 },
            { x = 1, y = 1, z = 1 }
        )
    end

    refreshImportItems()
    love.mouse.setRelativeMode(mouseLocked)
end

function app.update(dt)
    camera:update(dt)
    if camera.position.y < groundHeight + 0.25 then
        camera.position.y = groundHeight + 0.25
    end
end

function app.mousemoved(_, _, dx, dy)
    if mouseLocked then
        camera:onMouseMoved(dx, dy)
    end
end

function app.keypressed(key)
    if key == "tab" then
        mouseLocked = not mouseLocked
        topUI.formasOpen = false
        topUI.importarOpen = false
        topUI.selecaoOpen = false
        topUI.ferramentasOpen = false
        topUI.infoOpen = false
        topUI.stepDropdownOpen = false
        topUI.stepDropdownFor = nil
        love.mouse.setRelativeMode(mouseLocked)
        return
    end
    if key == "escape" then
        love.event.quit()
        return
    end
    if key == "e" then
        pickFaceUnderCrosshair()
        return
    end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    local moveStep = getMoveStep()
    local scaleStep = getScaleStep()

    if key == "left" then
        if selectedFace then
            deformSelectedFace(-moveStep, 0, 0)
        else
            moveSelectedObject(-moveStep, 0, 0)
        end
    elseif key == "right" then
        if selectedFace then
            deformSelectedFace(moveStep, 0, 0)
        else
            moveSelectedObject(moveStep, 0, 0)
        end
    elseif key == "up" then
        if shift then
            if selectedFace then
                deformSelectedFace(0, moveStep, 0)
            else
                moveSelectedObject(0, moveStep, 0)
            end
        elseif selectedFace then
            deformSelectedFace(0, 0, -moveStep)
        else
            moveSelectedObject(0, 0, -moveStep)
        end
    elseif key == "down" then
        if shift then
            if selectedFace then
                deformSelectedFace(0, -moveStep, 0)
            else
                moveSelectedObject(0, -moveStep, 0)
            end
        elseif selectedFace then
            deformSelectedFace(0, 0, moveStep)
        else
            moveSelectedObject(0, 0, moveStep)
        end
    elseif key == "pageup" then
        scaleSelectedObject(scaleStep)
    elseif key == "pagedown" then
        scaleSelectedObject(-scaleStep)
    elseif key == "[" then
        scaleSelectedObject(-scaleStep)
    elseif key == "]" then
        scaleSelectedObject(scaleStep)
    elseif key == "1" then
        spawnCube()
    end
end

function app.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if pointInRect(x, y, topUI.formasButton) then
        topUI.formasOpen = not topUI.formasOpen
        topUI.importarOpen = false
        topUI.selecaoOpen = false
        topUI.ferramentasOpen = false
        topUI.infoOpen = false
        topUI.stepDropdownOpen = false
        return
    end
    if pointInRect(x, y, topUI.importarButton) then
        topUI.importarOpen = not topUI.importarOpen
        topUI.formasOpen = false
        topUI.selecaoOpen = false
        topUI.ferramentasOpen = false
        topUI.infoOpen = false
        topUI.stepDropdownOpen = false
        return
    end
    if pointInRect(x, y, topUI.selecaoButton) then
        topUI.selecaoOpen = not topUI.selecaoOpen
        topUI.formasOpen = false
        topUI.importarOpen = false
        topUI.ferramentasOpen = false
        topUI.infoOpen = false
        topUI.stepDropdownOpen = false
        return
    end
    if pointInRect(x, y, topUI.ferramentasButton) then
        topUI.ferramentasOpen = not topUI.ferramentasOpen
        topUI.formasOpen = false
        topUI.importarOpen = false
        topUI.selecaoOpen = false
        topUI.infoOpen = false
        topUI.stepDropdownOpen = false
        return
    end
    if pointInRect(x, y, topUI.infoButton) then
        topUI.infoOpen = not topUI.infoOpen
        topUI.formasOpen = false
        topUI.importarOpen = false
        topUI.selecaoOpen = false
        topUI.ferramentasOpen = false
        topUI.stepDropdownOpen = false
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
                    spawnCube()
                end
                topUI.formasOpen = false
                return
            end
        end
        topUI.formasOpen = false
    end

    if topUI.importarOpen then
        local itemH = 24
        for i, item in ipairs(topUI.importarItems) do
            local rect = {
                x = topUI.importarButton.x,
                y = topUI.importarButton.y + topUI.importarButton.height + (i - 1) * itemH,
                width = 220,
                height = itemH
            }
            if pointInRect(x, y, rect) then
                spawnImported(item.id)
                topUI.importarOpen = false
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
                topUI.ferramentasOpen = false
                return
            end
        end
        topUI.ferramentasOpen = false
    end
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
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(color.bgTop)
    love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
    love.graphics.setColor(color.bgBottom)
    love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)

    local hasBeginFrame = type(shader.beginFrame) == "function"
    local hasEndFrame = type(shader.endFrame) == "function"
    if hasBeginFrame then
        shader.beginFrame(w, h)
    end
    drawGrid()

    for i, obj in ipairs(sceneObjects) do
        local style = obj.style
        if selectedObjectIndex == i then
            style = {
                fill = style.fill,
                wireframe = { 0.20, 1.0, 0.45, 1.0 },
                ambient = style.ambient,
                diffuse = style.diffuse,
                focus = style.focus,
                cull = style.cull,
                invertWinding = style.invertWinding
            }
        end
        shader.drawMesh(obj.mesh, objWorldMatrix(obj), camera, style)
    end
    if hasEndFrame then
        shader.endFrame()
    end
    drawBlueGuideOverlay()
    drawSelectedFaceOutline()

    -- Top bar
    love.graphics.setColor(0.07, 0.08, 0.10, 0.90)
    love.graphics.rectangle("fill", 0, 0, w, topUI.barHeight)
    love.graphics.setColor(0.35, 0.42, 0.52, 1.0)
    love.graphics.rectangle("fill", topUI.formasButton.x, topUI.formasButton.y, topUI.formasButton.width, topUI.formasButton.height)
    love.graphics.rectangle("fill", topUI.importarButton.x, topUI.importarButton.y, topUI.importarButton.width, topUI.importarButton.height)
    love.graphics.rectangle("fill", topUI.selecaoButton.x, topUI.selecaoButton.y, topUI.selecaoButton.width, topUI.selecaoButton.height)
    love.graphics.rectangle("fill", topUI.ferramentasButton.x, topUI.ferramentasButton.y, topUI.ferramentasButton.width, topUI.ferramentasButton.height)
    love.graphics.rectangle("fill", topUI.infoButton.x, topUI.infoButton.y, topUI.infoButton.width, topUI.infoButton.height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Formas", topUI.formasButton.x + 12, topUI.formasButton.y + 4)
    love.graphics.print("Importar", topUI.importarButton.x + 14, topUI.importarButton.y + 4)
    love.graphics.print("Selecao", topUI.selecaoButton.x + 12, topUI.selecaoButton.y + 4)
    love.graphics.print("Ferramentas", topUI.ferramentasButton.x + 8, topUI.ferramentasButton.y + 4)
    love.graphics.print("Inf", topUI.infoButton.x + 22, topUI.infoButton.y + 4)

    if topUI.formasOpen then
        local itemH = 24
        for i, item in ipairs(topUI.formasItems) do
            local y = topUI.formasButton.y + topUI.formasButton.height + (i - 1) * itemH
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.formasButton.x, y, 120, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print(item.label, topUI.formasButton.x + 10, y + 4)
        end
    end

    if topUI.importarOpen then
        local itemH = 24
        for i, item in ipairs(topUI.importarItems) do
            local y = topUI.importarButton.y + topUI.importarButton.height + (i - 1) * itemH
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.importarButton.x, y, 220, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print(item.label, topUI.importarButton.x + 8, y + 4)
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
                    local yv = dd.y + (i - 1) * 24
                    local active = (topUI.stepDropdownFor == "move" and topUI.moveStepPercent == val)
                        or (topUI.stepDropdownFor == "scale" and topUI.scaleStepPercent == val)
                    love.graphics.setColor(active and 0.20 or 0.14, active and 0.30 or 0.16, active and 0.40 or 0.20, 0.96)
                    love.graphics.rectangle("fill", dd.x + 2, yv + 2, dd.width - 4, 20)
                    love.graphics.setColor(0.90, 0.94, 1.0, 1.0)
                    love.graphics.printf(tostring(val), dd.x, yv + 4, dd.width, "center")
                end
            end
        end
    end

    if topUI.ferramentasOpen then
        local itemH = 24
        for i, item in ipairs(topUI.ferramentasItems) do
            local y = topUI.ferramentasButton.y + topUI.ferramentasButton.height + (i - 1) * itemH
            love.graphics.setColor(0.14, 0.16, 0.20, 0.96)
            love.graphics.rectangle("fill", topUI.ferramentasButton.x, y, 140, itemH)
            love.graphics.setColor(0.85, 0.90, 1.0, 1)
            love.graphics.print(item.label, topUI.ferramentasButton.x + 10, y + 4)
        end
    end

    if topUI.infoOpen then
        local x = topUI.infoButton.x
        local y = topUI.infoButton.y + topUI.infoButton.height
        local iw, ih = 510, 170
        love.graphics.setColor(0.08, 0.10, 0.13, 0.96)
        love.graphics.rectangle("fill", x, y, iw, ih)
        love.graphics.setColor(color.text)
        love.graphics.print("OBJ base: " .. (loadedObjPath or "nao carregado"), x + 10, y + 8)
        if sceneMesh then
            love.graphics.print(("Vertices: %d | Faces: %d"):format(#sceneMesh.vertices, #sceneMesh.faces), x + 10, y + 28)
        else
            love.graphics.print(loadError or "-", x + 10, y + 28)
        end
        love.graphics.print(("Objetos: %d"):format(#sceneObjects), x + 10, y + 48)
        love.graphics.print("E: selecionar face/objeto na mira", x + 10, y + 68)
        love.graphics.print("Setas: mover | Shift+Up/Down: subir/descer", x + 10, y + 88)
        love.graphics.print("PgUp/PgDown e [ ]: escala do objeto selecionado", x + 10, y + 108)
        love.graphics.print(("Camera: %.2f %.2f %.2f"):format(camera.position.x, camera.position.y, camera.position.z), x + 10, y + 128)
    end

    -- Crosshair
    local cx, cy = w * 0.5, h * 0.5
    love.graphics.setColor(0.95, 0.97, 1.0, 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx - 8, cy, cx - 2, cy)
    love.graphics.line(cx + 2, cy, cx + 8, cy)
    love.graphics.line(cx, cy - 8, cx, cy - 2)
    love.graphics.line(cx, cy + 2, cx, cy + 8)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.95, 0.97, 1.0, 0.9)
    local hint = mouseLocked and "TAB: liberar cursor" or "TAB: travar mouse"
    love.graphics.print(hint, 10, h - 22)
end

return app