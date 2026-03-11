local okVec3, vec3 = pcall(require, "game.math.vec3")
if not okVec3 then
    vec3 = require("Engine.Template3D.game.math.vec3")
end

local mat4 = {}

function mat4.identity()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function mat4.mul(a, b)
    local out = {}
    for row = 0, 3 do
        for col = 0, 3 do
            local sum = 0.0
            for i = 0, 3 do
                sum = sum + a[row * 4 + i + 1] * b[i * 4 + col + 1]
            end
            out[row * 4 + col + 1] = sum
        end
    end
    return out
end

function mat4.translate(x, y, z)
    return {
        1, 0, 0, x or 0,
        0, 1, 0, y or 0,
        0, 0, 1, z or 0,
        0, 0, 0, 1
    }
end

function mat4.scale(x, y, z)
    return {
        x or 1, 0, 0, 0,
        0, y or 1, 0, 0,
        0, 0, z or 1, 0,
        0, 0, 0, 1
    }
end

function mat4.rotateX(radians)
    local c = math.cos(radians)
    local s = math.sin(radians)
    return {
        1, 0, 0, 0,
        0, c, -s, 0,
        0, s, c, 0,
        0, 0, 0, 1
    }
end

function mat4.rotateY(radians)
    local c = math.cos(radians)
    local s = math.sin(radians)
    return {
        c, 0, s, 0,
        0, 1, 0, 0,
        -s, 0, c, 0,
        0, 0, 0, 1
    }
end

function mat4.rotateZ(radians)
    local c = math.cos(radians)
    local s = math.sin(radians)
    return {
        c, -s, 0, 0,
        s, c, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function mat4.perspective(fovRadians, aspect, near, far)
    local f = 1.0 / math.tan(fovRadians * 0.5)
    return {
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (far + near) / (near - far), (2 * far * near) / (near - far),
        0, 0, -1, 0
    }
end

function mat4.lookAt(eye, target, up)
    local zAxis = vec3.normalize(vec3.sub(eye, target))
    local xAxis = vec3.normalize(vec3.cross(up, zAxis))
    local yAxis = vec3.cross(zAxis, xAxis)

    return {
        xAxis.x, xAxis.y, xAxis.z, -vec3.dot(xAxis, eye),
        yAxis.x, yAxis.y, yAxis.z, -vec3.dot(yAxis, eye),
        zAxis.x, zAxis.y, zAxis.z, -vec3.dot(zAxis, eye),
        0, 0, 0, 1
    }
end

function mat4.transformPoint(m, v, w)
    local wIn = w or 1.0
    local x = m[1] * v.x + m[2] * v.y + m[3] * v.z + m[4] * wIn
    local y = m[5] * v.x + m[6] * v.y + m[7] * v.z + m[8] * wIn
    local z = m[9] * v.x + m[10] * v.y + m[11] * v.z + m[12] * wIn
    local wOut = m[13] * v.x + m[14] * v.y + m[15] * v.z + m[16] * wIn
    return x, y, z, wOut
end

return mat4
