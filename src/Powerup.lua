Powerup = Class{}

function Powerup:init(x, y, type)
	-- The powerups position
	self.x = x
	self.y = y

	-- A random vertical speed, since the only movement a powerup should
	-- have is downwards
	self.dy = math.random(5, 15)

	-- The type of powerup, which will be used to index into it's texture and
	-- have the corresponding behaviour once collided with the player
	self.type = type
end

function Powerup:update(dt)
	self.x = self.x + self.dy * dt
end

function Powerup:render()
	love.graphics.draw(gFrames["powerups"], self.x, self.y)
end
