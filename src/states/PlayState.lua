--[[
	GD50
	Breakout Remake

	-- PlayState Class --

	Author: Colton Ogden
	cogden@cs50.harvard.edu

	Represents the state of the game in which we are actively playing;
	player should control the paddle, with the ball actively bouncing between
	the bricks, walls, and the paddle. If the ball goes below the paddle, then
	the player should lose one point of health and be taken either to the Game
	Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

local ballsInPlay = 1
local keyFlag = false

--[[
	We initialize what's in our PlayState via a state table that we pass between
	states as we go from playing to serving.
]]
function PlayState:enter(params)
	self.paddle = params.paddle
	self.bricks = params.bricks
	self.health = params.health
	self.score = params.score
	self.highScores = params.highScores
	self.ball = params.ball
	self.level = params.level

	-- create an empty table to keep track of the powerups
	self.powerups = {}

	self.recoverPoints = 200

	-- give initial ball random starting velocity
	self.ball[1].dx = math.random(-200, 200)
	self.ball[1].dy = math.random(-50, -60)
end

function PlayState:update(dt)
	if self.paused then
		if love.keyboard.wasPressed('space') then
			self.paused = false
			gSounds['pause']:play()
		else
			return
		end
	elseif love.keyboard.wasPressed('space') then
		self.paused = true
		gSounds['pause']:play()
		return
	end

	-- update positions based on velocity
	self.paddle:update(dt)
	for i = 1, #self.powerups do
		self.powerups[i]:update(dt)
	end
	for i = 1, #self.ball do
		-- update balls in play only
		if self.ball[i].inPlay then
			self.ball[i]:update(dt)

			if self.ball[i]:collides(self.paddle) then
				-- raise ball[i] above paddle in case it goes below it, then reverse dy
				self.ball[i].y = self.paddle.y - 8
				self.ball[i].dy = -self.ball[i].dy

				--
				-- tweak angle of bounce based on where it hits the paddle
				--

				-- if we hit the paddle on its left side while moving left...
				if self.ball[i].x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
					self.ball[i].dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - self.ball[i].x))

				-- else if we hit the paddle on its right side while moving right...
				elseif self.ball[i].x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
					self.ball[i].dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - self.ball[i].x))
				end

				gSounds['paddle-hit']:play()
			end

			-- detect collision across all bricks with the ball[i]
			for k, brick in pairs(self.bricks) do

				-- only check collision if we're in play
				if brick.inPlay and self.ball[i]:collides(brick) then

					if not brick.isLocked then
						-- add to score
						self.score = self.score + (brick.tier * 200 + brick.color * 25)

						-- trigger the brick's hit function, which removes it from play
						brick:hit()

						-- spawn a double ball powerup randomly
						if math.random(10) == 1 then
							table.insert(self.powerups,
								Powerup(
									brick.x + brick.width / 2 - 4,
									brick.y + brick.height / 2 - 4,
									1
							))
						end
					else
						if keyFlag then
							-- add to score
							self.score = self.score + 3000

							-- trigger the brick's hit function, which removes it from play
							brick:hit()

						-- have a chance of spawning a key powerup if the hit brick is locked
						elseif math.random(1) == 3 then
							table.insert(self.powerups,
								Powerup(
									brick.x + brick.width / 2 - 4,
									brick.y + brick.height / 2 - 4,
									2
							))
						end
					end


					-- if we have enough points, recover a point of health
					if self.score > self.recoverPoints then
						-- can't go above 3 health
						self.health = math.min(3, self.health + 1)

						-- multiply recover points by 2
						self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

						-- grow the paddle
						self.paddle:resize(1)

						-- play recover sound effect
						gSounds['recover']:play()
					end

					-- go to our victory screen if there are no more bricks left
					if self:checkVictory() then
						gSounds['victory']:play()

						gStateMachine:change('victory', {
							level = self.level,
							paddle = self.paddle,
							health = self.health,
							score = self.score,
							highScores = self.highScores,
							ball = self.ball[1],
							recoverPoints = self.recoverPoints
						})
					end

					--
					-- collision code for bricks
					--
					-- we check to see if the opposite side of our velocity is outside of the brick;
					-- if it is, we trigger a collision on that side. else we're within the X + width of
					-- the brick and should check to see if the top or bottom edge is outside of the brick,
					-- colliding on the top or bottom accordingly
					--

					-- left edge; only check if we're moving right, and offset the check by a couple of pixels
					-- so that flush corner hits register as Y flips, not X flips
					if self.ball[i].x + 2 < brick.x and self.ball[i].dx > 0 then

						-- flip x velocity and reset position outside of brick
						self.ball[i].dx = -self.ball[i].dx
						self.ball[i].x = brick.x - 8

					-- right edge; only check if we're moving left, , and offset the check by a couple of pixels
					-- so that flush corner hits register as Y flips, not X flips
					elseif self.ball[i].x + 6 > brick.x + brick.width and self.ball[i].dx < 0 then

						-- flip x velocity and reset position outside of brick
						self.ball[i].dx = -self.ball[i].dx
						self.ball[i].x = brick.x + 32

					-- top edge if no X collisions, always check
					elseif self.ball[i].y < brick.y then

						-- flip y velocity and reset position outside of brick
						self.ball[i].dy = -self.ball[i].dy
						self.ball[i].y = brick.y - 8

					-- bottom edge if no X collisions or top collision, last possibility
					else

						-- flip y velocity and reset position outside of brick
						self.ball[i].dy = -self.ball[i].dy
						self.ball[i].y = brick.y + 16
					end

					-- slightly scale the y velocity to speed up the game, capping at +- 150
					if math.abs(self.ball[i].dy) < 150 then
						self.ball[i].dy = self.ball[i].dy * 1.02
					end

					-- only allow colliding with one brick, for corners
					break
				end
			end

			-- if ball[i] goes below bounds, revert to serve state and decrease health
			if self.ball[i].y >= VIRTUAL_HEIGHT then
				if ballsInPlay == 1 then
					self.health = self.health - 1
					gSounds['hurt']:play()

					if self.health == 0 then
						gStateMachine:change('game-over', {
							score = self.score,
							highScores = self.highScores
						})
					else
						-- shrink paddle
						self.paddle:resize(-1)

						gStateMachine:change('serve', {
							paddle = self.paddle,
							bricks = self.bricks,
							health = self.health,
							score = self.score,
							highScores = self.highScores,
							level = self.level,
							recoverPoints = self.recoverPoints
						})
					end
				else
					self.ball[i].inPlay = false
					ballsInPlay = ballsInPlay - 1
				end
			end
		end
	end

	-- check if any powerups collided with the paddle
	for i = 1, #self.powerups do
		if self.powerups[i]:collides(self.paddle) then
			-- turn on the key flag
			if self.powerups[i].type == 2 then
				keyFlag = true
			-- add a couple of balls to the ball table
			elseif self.powerups[i].type == 1 then
				table.insert(self.ball, Ball())
				self.ball[#self.ball].dx = math.random(-200, 200)
				self.ball[#self.ball].dy = math.random(-60, -70)
				table.insert(self.ball, Ball())
				self.ball[#self.ball].dx = math.random(-200, 200)
				self.ball[#self.ball].dy = math.random(-60, -70)
				ballsInPlay = ballsInPlay + 2
			end

			self.powerups[i].inPlay = false
		end

		if self.powerups[i].inPlay and self.powerups[i].y >= VIRTUAL_HEIGHT then
			self.powerups[i].inPlay = false
		end
	end

	-- for rendering particle systems
	for k, brick in pairs(self.bricks) do
		brick:update(dt)
	end

	if love.keyboard.wasPressed('escape') then
		love.event.quit()
	end
end

function PlayState:render()
	-- render bricks
	for k, brick in pairs(self.bricks) do
		brick:render()
	end

	-- render all particle systems
	for k, brick in pairs(self.bricks) do
		brick:renderParticles()
	end

	self.paddle:render()
	for i = 1, #self.powerups do
		self.powerups[i]:render()
	end
	for i = 1, #self.ball do
		self.ball[i]:render()
	end

	renderScore(self.score)
	renderHealth(self.health)

	-- pause text, if paused
	if self.paused then
		love.graphics.setFont(gFonts['large'])
		love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
	end
end

function PlayState:checkVictory()
	for k, brick in pairs(self.bricks) do
		if brick.inPlay then
			return false
		end
	end

	return true
end
