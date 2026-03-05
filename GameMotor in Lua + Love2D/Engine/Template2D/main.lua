-- Lembre-se é de cima pra baixo! o que está em cima no código estará atrás na interface!
-- se não encherga o que você adicionou desça o código algumas linhas!

function love.load()
    -- Retangulo do topo (nav)
    nav = {
        x = love.graphics.getWidth() * 0.0, -- 0% da largura
        y = love.graphics.getHeight() * 0.0, -- 0%  do topo
        width = love.graphics.getWidth() * 1.0, -- 100% da largura
        height = love.graphics.getHeight() * 0.05 -- 5% da altura
    }
end
function love.draw()
    -- Atualiza nav automático!
    nav.width = love.graphics.getWidth() * 1.0 -- 100% da largura
    nav.height = love.graphics.getHeight() * 0.05 -- 5% da altura
end