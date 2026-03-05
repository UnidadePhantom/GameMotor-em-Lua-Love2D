local projetos = {}
local projetoBotoes = {}

local showPopup = false
local inputText = ""
local statusText = ""
local selectedTemplateId = 1
local caretBlinkSeconds = 0.5

local templates = {
    {
        id = 1,
        imagePath = "EngImgs/template1.png",
        sourcePath = "Engine\\Template2D",
        label = "Template 2D"
    },
    {
        id = 2,
        imagePath = "EngImgs/template2.png",
        sourcePath = "Engine\\Template3D",
        label = "Template 3D"
    },
    {
        id = 3,
        imagePath = "EngImgs/template3.png",
        sourcePath = "Engine\\Template2D",
        label = "Template 2D"
    },
    {
        id = 4,
        imagePath = "EngImgs/template4.png",
        sourcePath = "Engine\\Template3D",
        label = "Template 3D"
    }
}

local nav
local menu
local body
local footer
local popup
local Criar
local font
local font2
local templateButtons = {}

local function pointInRect(px, py, r)
    return px > r.x and px < (r.x + r.width) and py > r.y and py < (r.y + r.height)
end

local function quotePath(path)
    return '"' .. path .. '"'
end

local function sanitizeFolderName(name)
    local cleaned = name:gsub("^%s+", ""):gsub("%s+$", "")
    cleaned = cleaned:gsub('[<>:"/\\|?*]', "_")
    return cleaned
end

local function folderExists(path)
    local cmd = 'if exist ' .. quotePath(path) .. ' (echo 1) else (echo 0)'
    local handle = io.popen(cmd)
    if not handle then
        return false
    end
    local result = handle:read("*a") or ""
    handle:close()
    return result:find("1", 1, true) ~= nil
end

local function ensureProjectsFolder()
    if not folderExists("Projects") then
        os.execute('mkdir "Projects"')
    end
end

local function copyTemplateToProject(templatePath, projectPath)
    local copyCmd = string.format('xcopy /E /I /Y "%s\\*" "%s\\" >nul', templatePath, projectPath)
    local ok = os.execute(copyCmd)
    return ok == true or ok == 0
end

local function hasLoveExecutable()
    local ok = os.execute("where love >nul 2>nul")
    return ok == true or ok == 0
end

local function carregarProjetos()
    projetos = {}
    ensureProjectsFolder()

    local handle = io.popen('dir "Projects" /B /AD')
    if not handle then
        statusText = "Erro ao listar Projects."
        return
    end

    local resultado = handle:read("*a") or ""
    handle:close()

    for nome in resultado:gmatch("[^\r\n]+") do
        table.insert(projetos, nome)
    end
end

local function abrirProjeto(nomeProjeto)
    local caminhoProjeto = "Projects\\" .. nomeProjeto
    local mainPath = caminhoProjeto .. "\\main.lua"

    if not folderExists(caminhoProjeto) then
        statusText = "Projeto nao encontrado."
        return
    end

    if folderExists(mainPath) then
        if hasLoveExecutable() then
            os.execute('start "" love "' .. caminhoProjeto .. '"')
            statusText = "Abrindo: " .. nomeProjeto
        else
            os.execute('start "" "' .. caminhoProjeto .. '"')
            statusText = "LOVE nao encontrado no PATH. Pasta aberta."
        end
    else
        os.execute('start "" "' .. caminhoProjeto .. '"')
        statusText = "Projeto sem main.lua. Pasta aberta."
    end
end

local function criarProjeto()
    local nome = sanitizeFolderName(inputText)
    if nome == "" then
        statusText = "Nome da pasta obrigatorio."
        return
    end

    ensureProjectsFolder()

    local template = templates[selectedTemplateId]
    if not template then
        statusText = "Template invalido."
        return
    end

    if not folderExists(template.sourcePath) then
        statusText = "Pasta do template nao encontrada: " .. template.sourcePath
        return
    end

    local destino = "Projects\\" .. nome
    if folderExists(destino) then
        statusText = "Ja existe projeto com esse nome."
        return
    end

    os.execute('mkdir ' .. quotePath(destino))
    local ok = copyTemplateToProject(template.sourcePath, destino)
    if not ok then
        statusText = "Falha ao copiar template."
        return
    end

    statusText = "Projeto criado: " .. nome .. " (" .. template.label .. ")"
    showPopup = false
    inputText = ""
    carregarProjetos()
end

local function layoutUI()
    nav = {
        x = 0,
        y = 0,
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight() * 0.05
    }

    menu = {
        x = 0,
        y = nav.height,
        width = love.graphics.getWidth() * 0.25,
        height = love.graphics.getHeight() * 0.9
    }

    body = {
        x = menu.width,
        y = nav.height,
        width = love.graphics.getWidth() * 0.75,
        height = love.graphics.getHeight() * 0.9
    }

    footer = {
        x = 0,
        y = love.graphics.getHeight() * 0.95,
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight() * 0.05
    }

    Criar = {
        x = love.graphics.getWidth() * 0.03,
        y = love.graphics.getHeight() * 0.1,
        width = love.graphics.getWidth() * 0.18,
        height = love.graphics.getHeight() * 0.1,
        text = "Criar",
        color = { 0.7, 0.7, 0.7 },
        textColor = { 0, 0, 0 }
    }

    popup = {
        x = love.graphics.getWidth() * 0.375,
        y = love.graphics.getHeight() * 0.25,
        width = love.graphics.getWidth() * 0.25,
        height = love.graphics.getHeight() * 0.5
    }

    local tw = love.graphics.getWidth() * 0.36
    local th = love.graphics.getHeight() * 0.36
    templateButtons[1].x, templateButtons[1].y, templateButtons[1].width, templateButtons[1].height = love.graphics.getWidth() * 0.26, love.graphics.getHeight() * 0.06, tw, th
    templateButtons[2].x, templateButtons[2].y, templateButtons[2].width, templateButtons[2].height = love.graphics.getWidth() * 0.63, love.graphics.getHeight() * 0.06, tw, th
    templateButtons[3].x, templateButtons[3].y, templateButtons[3].width, templateButtons[3].height = love.graphics.getWidth() * 0.26, love.graphics.getHeight() * 0.43, tw, th
    templateButtons[4].x, templateButtons[4].y, templateButtons[4].width, templateButtons[4].height = love.graphics.getWidth() * 0.63, love.graphics.getHeight() * 0.43, tw, th
end

function love.load()
    font = love.graphics.newFont(16)
    font2 = love.graphics.newFont(14)

    for i, cfg in ipairs(templates) do
        templateButtons[i] = {
            id = cfg.id,
            image = love.graphics.newImage(cfg.imagePath),
            color = { 0.7, 0.7, 0.7 },
            x = 0,
            y = 0,
            width = 0,
            height = 0
        }
    end

    layoutUI()
    carregarProjetos()
end

function love.draw()
    layoutUI()
    love.graphics.setFont(font)

    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", nav.x, nav.y, nav.width, nav.height)

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", menu.x, menu.y, menu.width, menu.height)

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", body.x, body.y, body.width, body.height)

    love.graphics.setColor(0.3, 0.1, 0.5)
    love.graphics.rectangle("fill", footer.x, footer.y, footer.width, footer.height)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Esse projeto esta sendo feito com muita dedicacao!", footer.x, footer.y + 7.5, footer.width, "center")

    love.graphics.setColor(Criar.color)
    love.graphics.rectangle("fill", Criar.x, Criar.y, Criar.width, Criar.height)
    love.graphics.setColor(Criar.textColor)
    love.graphics.printf(Criar.text, Criar.x, Criar.y + (Criar.height / 3), Criar.width, "center")

    for _, btn in ipairs(templateButtons) do
        love.graphics.setColor(btn.color)
        love.graphics.draw(
            btn.image,
            btn.x,
            btn.y,
            0,
            btn.width / btn.image:getWidth(),
            btn.height / btn.image:getHeight()
        )

        if selectedTemplateId == btn.id then
            love.graphics.setColor(0.2, 1.0, 0.4)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height)
            love.graphics.setLineWidth(1)
        end
    end

    projetoBotoes = {}
    for i, projeto in ipairs(projetos) do
        local py = love.graphics.getHeight() * (0.25 + (i - 1) * 0.065)
        local pheight = love.graphics.getHeight() * 0.075
        local inner = love.graphics.getHeight() * 0.005

        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", menu.x, py, menu.width, pheight)

        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", menu.x + inner, py + inner, menu.width - (2 * inner), pheight - (2 * inner))

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(projeto, menu.x + inner, py + (pheight / 3), menu.width - (2 * inner), "center")

        projetoBotoes[#projetoBotoes + 1] = {
            nome = projeto,
            x = menu.x + inner,
            y = py + inner,
            width = menu.width - (2 * inner),
            height = pheight - (2 * inner)
        }
    end

    local templateLabel = templates[selectedTemplateId] and templates[selectedTemplateId].label or "?"

    love.graphics.setColor(0.8, 0.95, 1.0)
    love.graphics.printf(statusText, body.x + 12, body.y + body.height - 28, body.width - 24, "left")

    if showPopup then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("fill", popup.x, popup.y, popup.width, popup.height)

        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("Nome da pasta:", popup.x, popup.y + 10, popup.width, "center")
        love.graphics.printf("Template: " .. templateLabel, popup.x, popup.y + 95, popup.width, "center")

        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.rectangle("fill", popup.x + 20, popup.y + 40, popup.width - 40, 30)

        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(inputText, popup.x + 20, popup.y + 50, popup.width - 40, "left")

        local blinkOn = (math.floor(love.timer.getTime() / caretBlinkSeconds) % 2) == 0
        if blinkOn then
            local caretX = popup.x + 22 + font:getWidth(inputText)
            local caretY = popup.y + 46
            local caretH = 20
            love.graphics.setLineWidth(1.5)
            love.graphics.line(caretX, caretY, caretX, caretY + caretH)
            love.graphics.setLineWidth(1)
        end

        love.graphics.setColor(0.6, 1.0, 0.6)
        love.graphics.rectangle("fill", popup.x + 20, popup.y + popup.height - 50, popup.width / 2 - 30, 40)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("Criar", popup.x + 20, popup.y + popup.height - 40, popup.width / 2 - 30, "center")

        love.graphics.setColor(1.0, 0.6, 0.6)
        love.graphics.rectangle("fill", popup.x + popup.width / 2 + 10, popup.y + popup.height - 50, popup.width / 2 - 30, 40)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(font2)
        love.graphics.printf("Cancelar", popup.x + popup.width / 2 + 10, popup.y + popup.height - 40, popup.width / 2 - 30, "center")
        love.graphics.setFont(font)
    end
end

function love.textinput(text)
    if showPopup and #inputText < 64 then
        inputText = inputText .. text
    end
end

function love.keypressed(key)
    if showPopup and key == "backspace" then
        inputText = inputText:sub(1, -2)
    elseif key == "escape" then
        showPopup = false
    elseif key == "return" and showPopup then
        criarProjeto()
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if showPopup then
        local criarBtn = {
            x = popup.x + 20,
            y = popup.y + popup.height - 50,
            width = popup.width / 2 - 30,
            height = 40
        }
        local cancelarBtn = {
            x = popup.x + popup.width / 2 + 10,
            y = popup.y + popup.height - 50,
            width = popup.width / 2 - 30,
            height = 40
        }

        if pointInRect(x, y, criarBtn) then
            criarProjeto()
            return
        end
        if pointInRect(x, y, cancelarBtn) then
            showPopup = false
            return
        end

        -- Enquanto popup estiver aberto, nada atras dele deve ser clicavel.
        return
    end

    if pointInRect(x, y, Criar) then
        showPopup = true
        inputText = ""
        return
    end

    for _, btn in ipairs(templateButtons) do
        if pointInRect(x, y, btn) then
            selectedTemplateId = btn.id
            showPopup = true
            inputText = ""
            return
        end
    end

    for _, pbtn in ipairs(projetoBotoes) do
        if pointInRect(x, y, pbtn) then
            abrirProjeto(pbtn.nome)
            return
        end
    end
end
