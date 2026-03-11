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

local World = {}
World.__index = World

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

local function makeObject(name, mesh, canDeform, style, position, scale, extras)
    local obj = {
        name = name,
        mesh = mesh,
        canDeform = canDeform,
        style = style,
        position = position or { x = 0, y = 0.5, z = 0 },
        scale = scale or { x = 1, y = 1, z = 1 }
    }

    if extras then
        for k, v in pairs(extras) do
            obj[k] = v
        end
    end

    return obj
end

local function pointProject(width, height, x, y)
    return (x * 0.5 + 0.5) * width, (1.0 - (y * 0.5 + 0.5)) * height
end

function World.new()
    local self = setmetatable({}, World)
    self.color = color
    self.camera = nil
    self.mouseLocked = true
    self.groundHeight = 0.0
    self.sceneMesh = nil
    self.loadedObjPath = nil
    self.loadError = nil
    self.sceneObjects = {}
    self.importItems = {}
    self.selectedObjectIndex = nil
    self.selectedFace = nil
    return self
end

function World:clearScene()
    self.sceneMesh = nil
    self.loadedObjPath = nil
    self.loadError = nil
    self.sceneObjects = {}
    self.importItems = {}
    self.selectedObjectIndex = nil
    self.selectedFace = nil
end

function World:fileExists(path)
    return love.filesystem.getInfo(path) ~= nil
end

function World:findObjPath()
    local candidates = {
        "assets/models/base.obj",
        "assets/models/untitled.obj"
    }
    for _, path in ipairs(candidates) do
        if self:fileExists(path) then
            return path
        end
    end
    return nil
end

function World:refreshImportItems()
    self.importItems = {}
    local ok, items = pcall(love.filesystem.getDirectoryItems, "assets/models")
    if not ok or not items then
        return
    end
    table.sort(items)
    for _, name in ipairs(items) do
        if name:lower():match("%.obj$") then
            self.importItems[#self.importItems + 1] = {
                id = "assets/models/" .. name,
                label = name
            }
        end
    end
end

function World:loadSceneMesh()
    local path = self:findObjPath()
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

function World:load(config)
    config = config or {}

    love.window.setTitle(config.title or "Template3D")
    love.graphics.setBackgroundColor(color.background)
    local cw, ch = love.graphics.getDimensions()
    love.window.setMode(cw, ch, { resizable = true, minwidth = 640, minheight = 360 })

    self.mouseLocked = config.mouseLocked ~= false
    self.camera = cameraModule.new({ speed = 4.2, sensitivity = 0.0028 })
    self.camera.position.x = 0
    self.camera.position.y = 1.4
    self.camera.position.z = 4.2

    self.sceneMesh, self.loadedObjPath, self.loadError = self:loadSceneMesh()
    if self.sceneMesh then
        self.sceneObjects[#self.sceneObjects + 1] = makeObject(
            "Base",
            cloneMesh(self.sceneMesh),
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

    self:refreshImportItems()

    if config.includeDefaultPlayer then
        self:setDefaultPlayerEnabled(true, config.defaultPlayerTag or "default-player")
    end

    love.mouse.setRelativeMode(self.mouseLocked)
end

function World:getMoveSpawnPoint(distance)
    local f = self.camera:getForward()
    return {
        x = self.camera.position.x + f.x * distance,
        y = math.max(self.groundHeight + 0.5, self.camera.position.y + f.y * distance),
        z = self.camera.position.z + f.z * distance
    }
end

function World:spawnCube()
    local p = self:getMoveSpawnPoint(4.0)
    self.sceneObjects[#self.sceneObjects + 1] = makeObject(
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
        p,
        { x = 1, y = 1, z = 1 }
    )
    self.selectedObjectIndex = #self.sceneObjects
    self.selectedFace = nil
end

function World:spawnImported(path)
    local mesh, err = objLoader.load(path)
    if not mesh then
        self.loadError = err
        return false
    end

    normalizeMeshWindingOutward(mesh)

    self.sceneObjects[#self.sceneObjects + 1] = makeObject(
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
        self:getMoveSpawnPoint(5.0),
        { x = 1, y = 1, z = 1 }
    )
    self.selectedObjectIndex = #self.sceneObjects
    self.selectedFace = nil
    return true
end

function World:removeObjectsByTag(tag)
    local filtered = {}
    local remap = {}

    for _, obj in ipairs(self.sceneObjects) do
        if obj.tag ~= tag then
            filtered[#filtered + 1] = obj
        end
    end

    for i, obj in ipairs(filtered) do
        remap[obj] = i
    end

    local selectedObj = self.selectedObjectIndex and self.sceneObjects[self.selectedObjectIndex] or nil
    self.sceneObjects = filtered

    if selectedObj then
        self.selectedObjectIndex = remap[selectedObj]
    end
    if not self.selectedObjectIndex then
        self.selectedFace = nil
    end
end

function World:hasObjectsWithTag(tag)
    for _, obj in ipairs(self.sceneObjects) do
        if obj.tag == tag then
            return true
        end
    end
    return false
end

function World:addDefaultPlayer(tag)
    local parts = {
        "Body.obj",
        "Head.obj",
        "UpArm_D.obj",
        "DownArm_D.obj",
        "Hand_D.obj",
        "UpArm_E.obj",
        "DownArm_E.obj",
        "Hand_E.obj",
        "UpLag_D.obj",
        "DownLag_D.obj",
        "Foot_D.obj",
        "UpLag_E.obj",
        "DownLag_E.obj",
        "Foot_E.obj"
    }

    local style = {
        fill = { 0.84, 0.86, 0.90, 1.0 },
        wireframe = false,
        ambient = 0.60,
        diffuse = 0.32,
        focus = 0.05,
        cull = true
    }

    for _, partName in ipairs(parts) do
        local path = "assets/models/" .. partName
        local mesh, err = objLoader.load(path)
        if mesh then
            normalizeMeshWindingOutward(mesh)
            self.sceneObjects[#self.sceneObjects + 1] = makeObject(
                "Player: " .. partName:gsub("%.obj$", ""),
                cloneMesh(mesh),
                false,
                style,
                { x = 0, y = 0, z = 0 },
                { x = 0.55, y = 0.55, z = 0.55 },
                { tag = tag or "default-player", isPlayer = true }
            )
        else
            self.loadError = err
        end
    end
end

function World:setDefaultPlayerEnabled(enabled, tag)
    tag = tag or "default-player"
    if enabled then
        if not self:hasObjectsWithTag(tag) then
            self:addDefaultPlayer(tag)
        end
    else
        self:removeObjectsByTag(tag)
    end
end

function World:objWorldMatrix(obj)
    local t = mat4.translate(obj.position.x, obj.position.y, obj.position.z)
    local s = mat4.scale(obj.scale.x, obj.scale.y, obj.scale.z)
    return mat4.mul(t, s)
end

function World:localToWorld(obj, v)
    return {
        x = obj.position.x + v.x * obj.scale.x,
        y = obj.position.y + v.y * obj.scale.y,
        z = obj.position.z + v.z * obj.scale.z
    }
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

function World:pickFaceUnderCrosshair()
    local origin = {
        x = self.camera.position.x,
        y = self.camera.position.y,
        z = self.camera.position.z
    }
    local dir = self.camera:getForward()
    local best = nil
    local bestT = math.huge

    for oi, obj in ipairs(self.sceneObjects) do
        local polys = obj.mesh.polygons
        if not polys or #polys == 0 then
            polys = obj.mesh.faces
        end

        for _, poly in ipairs(polys) do
            if #poly >= 3 then
                local w0 = self:localToWorld(obj, obj.mesh.vertices[poly[1]])
                for i = 2, #poly - 1 do
                    local w1 = self:localToWorld(obj, obj.mesh.vertices[poly[i]])
                    local w2 = self:localToWorld(obj, obj.mesh.vertices[poly[i + 1]])
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
        self.selectedObjectIndex = best.objectIndex
        local obj = self.sceneObjects[best.objectIndex]
        if obj.canDeform then
            self.selectedFace = best
        else
            self.selectedFace = nil
        end
    else
        self.selectedFace = nil
    end
end

function World:deformSelectedFace(dx, dy, dz)
    if not self.selectedFace then
        return
    end

    local obj = self.sceneObjects[self.selectedFace.objectIndex]
    if not obj or not obj.canDeform then
        return
    end

    local touched = {}
    for _, idx in ipairs(self.selectedFace.poly) do
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

function World:moveSelectedObject(dx, dy, dz)
    local obj = self.selectedObjectIndex and self.sceneObjects[self.selectedObjectIndex] or nil
    if not obj then
        return
    end
    obj.position.x = obj.position.x + dx
    obj.position.y = obj.position.y + dy
    obj.position.z = obj.position.z + dz
end

function World:scaleSelectedObject(amount)
    local obj = self.selectedObjectIndex and self.sceneObjects[self.selectedObjectIndex] or nil
    if not obj then
        return
    end
    obj.scale.x = math.max(0.1, obj.scale.x + amount)
    obj.scale.y = math.max(0.1, obj.scale.y + amount)
    obj.scale.z = math.max(0.1, obj.scale.z + amount)
end

function World:getImportItems()
    return self.importItems
end

function World:getSceneObjects()
    return self.sceneObjects
end

function World:getSceneInfo()
    return {
        sceneMesh = self.sceneMesh,
        loadedObjPath = self.loadedObjPath,
        loadError = self.loadError
    }
end

function World:setMouseLocked(value)
    self.mouseLocked = value and true or false
    love.mouse.setRelativeMode(self.mouseLocked)
end

function World:toggleMouseLock()
    self:setMouseLocked(not self.mouseLocked)
end

function World:update(dt)
    self.camera:update(dt)
    if self.camera.position.y < self.groundHeight + 0.25 then
        self.camera.position.y = self.groundHeight + 0.25
    end
end

function World:mousemoved(dx, dy)
    if self.mouseLocked then
        self.camera:onMouseMoved(dx, dy)
    end
end

function World:projectWorldPoint(p, width, height)
    local view = self.camera:getViewMatrix()
    local proj = self.camera:getProjectionMatrix(width, height)
    local vx, vy, vz = mat4.transformPoint(view, p, 1.0)
    if vz > -(self.camera.near or 0.05) then
        return nil, nil
    end
    local x, y, _, w = mat4.transformPoint(proj, { x = vx, y = vy, z = vz }, 1.0)
    if w <= 0.00001 then
        return nil, nil
    end
    return pointProject(width, height, x / w, y / w)
end

function World:drawSelectedFaceOutline()
    if not self.selectedFace then
        return
    end

    local obj = self.sceneObjects[self.selectedFace.objectIndex]
    if not obj then
        return
    end

    local w, h = love.graphics.getDimensions()
    local pts = {}

    for _, idx in ipairs(self.selectedFace.poly) do
        local v = obj.mesh.vertices[idx]
        if v then
            local sx, sy = self:projectWorldPoint(self:localToWorld(obj, v), w, h)
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

function World:drawGrid()
    local width, height = love.graphics.getDimensions()
    local view = self.camera:getViewMatrix()
    local proj = self.camera:getProjectionMatrix(width, height)
    local nearPlane = self.camera.near or 0.05

    local function project(v)
        local x, y, _, w = mat4.transformPoint(proj, v, 1.0)
        if w <= 0.00001 then
            return nil, nil
        end
        return pointProject(width, height, x / w, y / w)
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

    local function drawAxisLine(a, b, rgba)
        local avx, avy, avz = mat4.transformPoint(view, a, 1.0)
        local bvx, bvy, bvz = mat4.transformPoint(view, b, 1.0)
        local la, lb = clipLineToNear({ x = avx, y = avy, z = avz }, { x = bvx, y = bvy, z = bvz })
        if la and lb then
            local x1, y1 = project(la)
            local x2, y2 = project(lb)
            if x1 and x2 then
                love.graphics.setColor(rgba)
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    end

    local halfSize = 20
    love.graphics.setColor(0.28, 0.36, 0.48, 0.55)
    for i = -halfSize, halfSize do
        local a = { x = i, y = self.groundHeight, z = -halfSize }
        local b = { x = i, y = self.groundHeight, z = halfSize }
        local c = { x = -halfSize, y = self.groundHeight, z = i }
        local d = { x = halfSize, y = self.groundHeight, z = i }
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

    drawAxisLine(
        { x = -halfSize, y = self.groundHeight, z = 0 },
        { x = halfSize, y = self.groundHeight, z = 0 },
        { 1.0, 0.30, 0.30, 0.95 }
    )
    drawAxisLine(
        { x = 0, y = self.groundHeight, z = -halfSize },
        { x = 0, y = self.groundHeight, z = halfSize },
        { 0.30, 1.0, 0.45, 0.95 }
    )
end

function World:drawBlueGuideOverlay()
    local width, height = love.graphics.getDimensions()
    local view = self.camera:getViewMatrix()
    local proj = self.camera:getProjectionMatrix(width, height)
    local nearPlane = self.camera.near or 0.05

    local function project(v)
        local x, y, _, w = mat4.transformPoint(proj, v, 1.0)
        if w <= 0.00001 then
            return nil, nil
        end
        return pointProject(width, height, x / w, y / w)
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

    local start = { x = 0, y = self.groundHeight + 0.01, z = 0 }
    local finish = { x = 0, y = self.groundHeight + 1.0, z = 0 }
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

function World:drawBackground()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(color.bgTop)
    love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
    love.graphics.setColor(color.bgBottom)
    love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)
end

function World:drawScene(options)
    options = options or {}
    local w, h = love.graphics.getDimensions()

    if options.drawBackground ~= false then
        self:drawBackground()
    end

    local hasBeginFrame = type(shader.beginFrame) == "function"
    local hasEndFrame = type(shader.endFrame) == "function"
    if hasBeginFrame then
        shader.beginFrame(w, h)
    end

    self:drawGrid()

    for i, obj in ipairs(self.sceneObjects) do
        local style = obj.style
        if options.highlightSelection and self.selectedObjectIndex == i then
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
        shader.drawMesh(obj.mesh, self:objWorldMatrix(obj), self.camera, style)
    end

    if hasEndFrame then
        shader.endFrame()
    end

    if options.drawGuides ~= false then
        self:drawBlueGuideOverlay()
    end
    if options.drawSelection then
        self:drawSelectedFaceOutline()
    end
end

function World:drawCrosshair()
    local w, h = love.graphics.getDimensions()
    local cx, cy = w * 0.5, h * 0.5
    love.graphics.setColor(0.95, 0.97, 1.0, 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx - 8, cy, cx - 2, cy)
    love.graphics.line(cx + 2, cy, cx + 8, cy)
    love.graphics.line(cx, cy - 8, cx, cy - 2)
    love.graphics.line(cx, cy + 2, cx, cy + 8)
    love.graphics.setLineWidth(1)
end

function World:drawBottomHint(extraText)
    local _, h = love.graphics.getDimensions()
    local hint = self.mouseLocked and "TAB: liberar cursor" or "TAB: travar mouse"
    if extraText and extraText ~= "" then
        hint = hint .. " | " .. extraText
    end
    love.graphics.setColor(0.95, 0.97, 1.0, 0.9)
    love.graphics.print(hint, 10, h - 22)
end

return World
