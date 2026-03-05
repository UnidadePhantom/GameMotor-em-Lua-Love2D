local okMat4, mat4 = pcall(require, "game.math.mat4")
if not okMat4 then
    mat4 = require("Engine.Template3D.game.math.mat4")
end

local okVec3, vec3 = pcall(require, "game.math.vec3")
if not okVec3 then
    vec3 = require("Engine.Template3D.game.math.vec3")
end

local shader = {}

local state = {
    width = 0,
    height = 0,
    depthBuffer = {},
    started = false
}

local function toScreen(ndcX, ndcY, width, height)
    local x = (ndcX * 0.5 + 0.5) * width
    local y = (1.0 - (ndcY * 0.5 + 0.5)) * height
    return x, y
end

local function polygonArea2(pts)
    local n = #pts
    if n < 6 then
        return 0
    end
    local sum = 0
    local jx, jy = pts[n - 1], pts[n]
    for i = 1, n, 2 do
        local ix, iy = pts[i], pts[i + 1]
        sum = sum + (jx * iy - jy * ix)
        jx, jy = ix, iy
    end
    return sum
end

local function insideNear(v, nearPlane)
    return v.z <= -nearPlane
end

local function intersectNear(a, b, nearPlane)
    local targetZ = -nearPlane
    local dz = b.z - a.z
    if math.abs(dz) < 0.000001 then
        return { x = a.x, y = a.y, z = targetZ }
    end
    local t = (targetZ - a.z) / dz
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = targetZ
    }
end

local function clipPolygonAgainstNear(poly, nearPlane)
    if #poly == 0 then
        return {}
    end

    local out = {}
    local prev = poly[#poly]
    local prevInside = insideNear(prev, nearPlane)

    for _, curr in ipairs(poly) do
        local currInside = insideNear(curr, nearPlane)
        if currInside then
            if not prevInside then
                out[#out + 1] = intersectNear(prev, curr, nearPlane)
            end
            out[#out + 1] = curr
        elseif prevInside then
            out[#out + 1] = intersectNear(prev, curr, nearPlane)
        end
        prev = curr
        prevInside = currInside
    end

    return out
end

local function projectViewPoint(proj, v, width, height)
    local x, y, _, w = mat4.transformPoint(proj, v, 1.0)
    if w <= 0.00001 then
        return nil, nil, nil
    end
    local nx, ny = x / w, y / w
    local sx, sy = toScreen(nx, ny, width, height)
    return sx, sy, 1.0 / w
end

local function ensureDepthBuffer(width, height)
    if state.width ~= width or state.height ~= height then
        state.width = width
        state.height = height
        state.depthBuffer = {}
    end
    local total = width * height
    for i = 1, total do
        state.depthBuffer[i] = -math.huge
    end
end

local function edge(ax, ay, bx, by, cx, cy)
    return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax)
end

function shader.beginFrame(width, height)
    ensureDepthBuffer(width, height)
    state.started = true
end

function shader.endFrame()
    state.started = false
end

local function rasterizeTriangle(t, fillColor, width, height)
    local minX = math.max(0, math.floor(math.min(t.x1, t.x2, t.x3)))
    local maxX = math.min(width - 1, math.ceil(math.max(t.x1, t.x2, t.x3)))
    local minY = math.max(0, math.floor(math.min(t.y1, t.y2, t.y3)))
    local maxY = math.min(height - 1, math.ceil(math.max(t.y1, t.y2, t.y3)))

    local area = edge(t.x1, t.y1, t.x2, t.y2, t.x3, t.y3)
    if math.abs(area) < 0.000001 then
        return
    end

    local invArea = 1.0 / area
    local rr = fillColor[1] * t.shade
    local gg = fillColor[2] * t.shade
    local bb = fillColor[3] * t.shade
    local aa = fillColor[4] or 1.0

    love.graphics.setColor(rr, gg, bb, aa)
    for y = minY, maxY do
        for x = minX, maxX do
            local px = x + 0.5
            local py = y + 0.5

            local b1 = edge(t.x2, t.y2, t.x3, t.y3, px, py) * invArea
            local b2 = edge(t.x3, t.y3, t.x1, t.y1, px, py) * invArea
            local b3 = edge(t.x1, t.y1, t.x2, t.y2, px, py) * invArea

            if b1 >= 0 and b2 >= 0 and b3 >= 0 then
                -- Perspective-correct depth.
                -- For this projection, larger 1/w means closer.
                local depth = b1 * t.iw1 + b2 * t.iw2 + b3 * t.iw3
                local idx = y * width + x + 1
                if depth > (state.depthBuffer[idx] + 1e-7) then
                    state.depthBuffer[idx] = depth
                    love.graphics.points(px, py)
                end
            end
        end
    end
end

function shader.drawMesh(mesh, worldMatrix, camera, colors)
    local renderColors = colors or {}
    local fillColor = renderColors.fill or { 0.7, 0.7, 0.72, 1.0 }
    local wireEnabled = renderColors.wireframe ~= false
    local wireColor = wireEnabled and (renderColors.wireframe or { 0.9, 0.9, 1.0, 1.0 }) or nil
    local ambient = renderColors.ambient or 0.60
    local diffuseStrength = renderColors.diffuse or 0.30
    local focusStrength = renderColors.focus or 0.06
    local cullBackface = renderColors.cull ~= false
    local invertWinding = renderColors.invertWinding == true

    local width, height = love.graphics.getDimensions()
    if not state.started then
        shader.beginFrame(width, height)
    end

    local view = camera:getViewMatrix()
    local proj = camera:getProjectionMatrix(width, height)
    local worldView = mat4.mul(view, worldMatrix)
    local nearPlane = camera.near or 0.05

    local viewVerts = {}
    for i, vertex in ipairs(mesh.vertices) do
        local vx, vy, vz = mat4.transformPoint(worldView, vertex, 1.0)
        viewVerts[i] = { x = vx, y = vy, z = vz }
    end

    local triangles = {}
    local lightDir = vec3.normalize(vec3.new(-0.35, 0.85, -0.35))

    for _, face in ipairs(mesh.faces) do
        local v1 = viewVerts[face[1]]
        local v2 = viewVerts[face[2]]
        local v3 = viewVerts[face[3]]
        if v1 and v2 and v3 then
            local clipped = clipPolygonAgainstNear({ v1, v2, v3 }, nearPlane)
            if #clipped >= 3 then
                local e1 = vec3.sub(v2, v1)
                local e2 = vec3.sub(v3, v1)
                local normal = vec3.normalize(vec3.cross(e1, e2))
                local center = {
                    x = (v1.x + v2.x + v3.x) / 3.0,
                    y = (v1.y + v2.y + v3.y) / 3.0,
                    z = (v1.z + v2.z + v3.z) / 3.0
                }
                local toCam = vec3.normalize(vec3.new(-center.x, -center.y, -center.z))
                local nd = math.max(0.0, vec3.dot(normal, lightDir))
                local nf = math.max(0.0, vec3.dot(normal, toCam))
                local shade = ambient + diffuseStrength * nd + focusStrength * nf
                if shade > 1.0 then
                    shade = 1.0
                end

                for i = 2, #clipped - 1 do
                    local a = clipped[1]
                    local b = clipped[i]
                    local c = clipped[i + 1]
                    local ax, ay, aiw = projectViewPoint(proj, a, width, height)
                    local bx, by, biw = projectViewPoint(proj, b, width, height)
                    local cx, cy, ciw = projectViewPoint(proj, c, width, height)
                    if ax and bx and cx then
                        local area2 = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
                        local isFront = invertWinding and (area2 > 0) or (area2 < 0)
                        if (not cullBackface) or isFront then
                            triangles[#triangles + 1] = {
                                x1 = ax, y1 = ay, iw1 = aiw,
                                x2 = bx, y2 = by, iw2 = biw,
                                x3 = cx, y3 = cy, iw3 = ciw,
                                shade = shade
                            }
                        end
                    end
                end
            end
        end
    end

    for _, t in ipairs(triangles) do
        rasterizeTriangle(t, fillColor, width, height)
    end

    if wireEnabled then
        love.graphics.setColor(wireColor)
        if mesh.polygons and #mesh.polygons > 0 then
            for _, poly in ipairs(mesh.polygons) do
                local source = {}
                for _, idx in ipairs(poly) do
                    local v = viewVerts[idx]
                    if v then
                        source[#source + 1] = v
                    end
                end

                local clipped = clipPolygonAgainstNear(source, nearPlane)
                if #clipped >= 2 then
                    local pts = {}
                    for _, v in ipairs(clipped) do
                        local sx, sy = projectViewPoint(proj, v, width, height)
                        if sx then
                            pts[#pts + 1] = sx
                            pts[#pts + 1] = sy
                        end
                    end

                    if #pts >= 6 then
                        local polyArea = polygonArea2(pts)
                        local isFrontPoly = invertWinding and (polyArea > 0) or (polyArea < 0)
                        if (not cullBackface) or isFrontPoly then
                            love.graphics.polygon("line", pts)
                        end
                    elseif #pts == 4 then
                        love.graphics.line(pts[1], pts[2], pts[3], pts[4])
                    end
                end
            end
        else
            for _, t in ipairs(triangles) do
                love.graphics.polygon("line", t.x1, t.y1, t.x2, t.y2, t.x3, t.y3)
            end
        end
    end
end

return shader
