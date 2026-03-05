function love.load()
    -- Definição do nav
    nav = {x = 0, y = 0, width = love.graphics.getWidth() * 0.25, height = love.graphics.getHeight()}

    -- Definição do botão dentro do nav
    button = {
        width = 150,
        height = 50,
        x = nav.width / 2 - 75, -- Centraliza no nav horizontalmente
        y = nav.height * 0.05 -- 5% abaixo do topo
    }
end

function love.draw()
    -- Desenha o nav
    love.graphics.setColor(0.2, 0.2, 0.2) -- Cinza escuro
    love.graphics.rectangle("fill", nav.x, nav.y, nav.width, nav.height)

    -- Desenha o botão
    love.graphics.setColor(0, 0.7, 1) -- Azul vibrante
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)

    -- Texto do botão
    love.graphics.setColor(1, 1, 1) -- Branco
    love.graphics.printf("Criar", button.x, button.y + 15, button.width, "center")
end

function love.mousepressed(x, y, buttonPressed)
    if buttonPressed == 1 and x > button.x and x < button.x + button.width and y > button.y and y < button.y + button.height then
        os.execute('mkdir "Projects/nova_pasta"')
        print("Pasta criada!")
    end
end
