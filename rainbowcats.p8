pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- rainbow cats
-- by niarkou and sam

--
-- config
--

config = {
    intro = {},
    menu = {},
    levels = {},
    ready = {},
    play = {},
    finished = {},
    pause = {},
}

g_btn_confirm = 4
g_btn_back = 5
g_btn_jump = 4
g_btn_call = 5

-- menu navigation sfx
g_sfx_navigate = 38
g_sfx_confirm = 39

-- gameplay sfx
g_sfx_death = 37
g_sfx_happy = 36
g_sfx_saved = 32
g_sfx_jump = 35
g_sfx_ladder = 34
g_sfx_footstep = 33

-- sprites
g_spr_player = 18
g_spr_follower = 20
g_spr_exit = 26
g_spr_portal = 38
g_spr_spikes = 36
g_spr_happy = 37
g_spr_count = 48

g_fill_amount = 2
g_solid_time = 80
g_win_frames = 40
g_lose_frames = 80

g_palette = {
    { 5, 13,  6 }, -- no color
    { 2,  8, 14 }, -- red
    { 1, 12,  6 }, -- blue
    { 4,  9, 10 }, -- yellow
    { 3, 11,  6 }, -- green
}

g_intro = {
    "episode 43",
    "<sacrifices must be made",
    "",
    "a long time ago,",
    "in a garden far,",
    "far away. . .",
    "",
    "the cats escaped!",
    "",
    "grandma must return",
    "them home safe. but",
    "<the journey is perilous",
    "and cats don't listen.",
    "",
    ". . . will she succeed",
    "eventually? it's only",
    "up to you. good luck!",
}

g_levels = {
    {  0,  0, 16,  7, "kittens" }, -- level 1
    {  0,  7, 16,  9, "lose to win" }, -- level 2
    {  0, 16, 16, 13, "    old game\nwith new twist" }, -- level 3
    { 32,  0,  7, 16, "death is useful" }, -- level 4
    { 48,  0, 16, 16, "you control the\nplayer, not the\n  environment" },
    { 16,  0, 16, 16, "too good to be\n   impossible" }, -- test level
    { 16, 16, 16, 12, "the future \n is the past"},
    { 64,  0, 16, 16, "     thinking\nout of the box" },
    {  0, 29, 23, 20, "worst game ever"},
    {  0, 49,  9, 15, "maximum game feels"},
    { 23, 32, 22, 12, "the beginning\n is the end"},
    { 26, 48, 16, 16, "don't teleporters"},
}

g_ong_level = 0
g_levels_unlocked = {true}

--
-- levels
--

function make_world(level)
    world = { x = 0, y = 0, w = 0, h = 0 }
    -- initialise world with level information
    if level > 0 and level <= #g_levels then
        world.x = g_levels[level][1]
        world.y = g_levels[level][2]
        world.w = g_levels[level][3]
        world.h = g_levels[level][4]
        world.name = g_levels[level][5]
    end
    world.spikes = {}
    world.portals = {}
    world.cats = {}
    world.spikes_lut = {} -- fixme: not very nice
    world.goal = {}
    world.saved = { 0, 0, 0, 0, 0 }
    world.numbercats = { 0, 0, 0, 0, 0 }
    -- analyse level to find where the exit and traps are
    for y=world.y,world.y+world.h-1 do
        for x=world.x,world.x+world.w-1 do
            local sprite = mget(x, y)
            if sprite == g_spr_exit then
                world.exit = {x = 8 * x + 8, y = 8 * y + 12}
            elseif sprite == g_spr_spikes then
                local s = {x = 8 * x + 4, y = 8 * y + 4, fill = 0, solid = 0}
                add(world.spikes, s)
                world.spikes_lut[x + y / 256] = s
            elseif sprite >= g_spr_portal and sprite < g_spr_portal + 4 then
                local direction = sprite - g_spr_portal
                local p = {x = 8 * x + 4, y = 8 * y + 4, d = direction}
                foreach(world.portals, function(p2)
                    if not p2.other then
                        p2.other = p
                        p.other = p2
                    end
                end)
                add(world.portals, p)
            elseif sprite >= g_spr_follower and sprite < g_spr_follower + 5 then
                local color = sprite - g_spr_follower + 1
                local spawn_count = mget(x, y - 1) - g_spr_count + 1
                local save_count = mget(x + 1, y) - g_spr_count + 1
                -- if count is above, it's a spawner
                if spawn_count > 0 and spawn_count < 16 then
                    local dir = x > world.x + world.w/2
                    for i=1,spawn_count do
                        local dx = i * (i % 2 * 2 - 1)
                        add(world.cats, new_cat(8 * x + 4 + dx, 8 * y - rnd(4), color, dir))
                    end
                    world.numbercats[color] += spawn_count
                -- otherwise, if count is on the right, it's a save goal
                elseif save_count > 0 and save_count < 16 then
                    world.goal[color] = (world.goal[color] or 0) + save_count
                end
            elseif sprite == g_spr_player then
                local dir = x > world.x + world.w/2
                world.player = new_player(8 * x + 8, 8 * y, dir)
            end
        end
    end
    -- detect walls for grass
    for y=0,world.h-1 do
        for x=0,world.w-1 do
            local wx = 8 * (world.x + x)
            local wy = 8 * (world.y + y)
            local sprite = 0
            local b1 = wall(wx, wy) and not wall(wx, wy - 4)
            local b2 = wall(wx + 4, wy) and not wall(wx + 4, wy - 4)
            local b3 = wall(wx, wy + 4) and not wall(wx, wy)
            local b4 = wall(wx + 4, wy + 4) and not wall(wx + 4, wy)
            if b1 and b2 then sprite = 28
            elseif b3 and b4 then sprite = 29
            elseif b1 then sprite = 44
            elseif b2 then sprite = 45
            elseif b3 then sprite = 30
            elseif b4 then sprite = 31
            end
            mset(128 - world.w + x, 64 - world.h + y, sprite)
        end
    end
end

--
-- constructors
--

function new_game()
    score = 0
    saved = 0
    particles = {}
    selectcolor = 1
    selectcolorscreen = false
    color = {1, 2, 3, 4, 5}
    make_world(level)
end

function new_entity(x, y, dir)
    return {
        x = x, y = y,
        dir = dir,
        anim = rnd(128),
        walk = rnd(128),
        climbspd = 0.5,
        grounded = false,
        ladder = false,
        jumped = false,
        jump = 0, fall = 0,
        cooldown = 0,
    }
end

function new_player(x, y, dir)
    local e = new_entity(x, y, dir)
    e.can_jump = true
    e.spd = 1.0
    e.spr = g_spr_player
    e.pcolors = { 5, 6 }
    e.call = 1
    return e
end

function new_cat(x, y, color, dir)
    local e = new_entity(x, y, dir)
    e.spd = crnd(0.4, 0.6)
    e.plan = {}
    e.color = color
    e.spr = g_spr_follower + e.color - 1
    e.pcolors = g_palette[e.color]
    return e
end

--
-- useful functions
--

function jump()
    if btn(2) or btn(g_btn_jump) then
        return true end
end

-- cool btnp(): ignores autorepeat

do
    local ub = _update_buttons
    local oldstate, state = 0, btn()
    function _update_buttons()
        ub()
        oldstate, state = state, btn()
    end
    function cbtnp(i)
        local bitfield = band(btnp(), bnot(oldstate))
        return not i and bitfield or band(bitfield, 2^i) != 0
    end
end

-- cool random

function crnd(a, b)
  return min(a, b) + rnd(abs(b - a))
end

function ccrnd(tab)  -- takes a tab and choose randomly between the elements of the table
  n = flr(crnd(1, #tab+1))
  return tab[n]
end

-- rect with smooth sides

function smoothrect(x0, y0, x1, y1, r, col)
    line(x0, y0 + r, x0, y1 - r, col)
    line(x1, y0 + r, x1, y1 - r, col)
    line(x0 + r, y0, x1 - r, y0, col)
    line(x0 + r, y1, x1 - r, y1, col)
    clip(x0, y0, r, r)
    circ(x0 + r, y0 + r, r, col)
    clip(x0, y1 - r, r, r + 1)
    circ(x0 + r, y1 - r, r, col)
    clip(x1 - r, y0, r + 1, r)
    circ(x1 - r, y0 + r, r, col)
    clip(x1 - r, y1 - r, r + 1, r + 1)
    circ(x1 - r, y1 - r, r, col)
    clip()
end

-- rect filled with smooth sides

function smoothrectfill(x0, y0, x1, y1, r, col1, col2)
    circfill(x0 + r, y0 + r, r, col1)
    circfill(x0 + r, y1 - r, r, col1)
    circfill(x1 - r, y0 + r, r, col1)
    circfill(x1 - r, y1 - r, r, col1)
    rectfill(x0 + r, y0, x1 - r, y1, col1)
    rectfill(x0, y0 + r, x1, y1 -r, col1)
    smoothrect(x0, y0, x1, y1, r, col2)
end

--
-- standard pico-8 workflow
--

function _init()
    poke(0x5f34, 1)
    cartdata("rainbow_cats")
    state = "intro"
    music(0)
    scroll = 0
    particles = {}
    num = {1}
    jump_speed = 1
    fall_speed = 1
    -- create sin/cos table
    st, ct = {}, {}
    for i=0,128 do
        st[i] = sin(i / 128)
        ct[i] = cos(i / 128)
    end
end

function reset_menu()
    menu = {
        doordw = 128,
        doorx = 0,
        doorspd = 1,
        opening = false,
        rectpos = 1,
        high_y = 78,
        selectlevel = 1,
    }
end

function _update60()
    config[state].update()
end

function _draw()
    config[state].draw()
end

--
-- intro
--

function config.intro.update()
    scroll += 1 / 4
    if cbtnp(g_btn_confirm) or scroll > #g_intro * 16 + 160 then
        reset_menu()
        state = "menu"
    end
end

function config.intro.draw()
    cls(0)
    camera(-64,-64)
    for x=1,128,2 do
        local m = 3 + ((2+x%3) * scroll + 1450*sin(x/73)) % 200
        pset(m * ct[x], m * st[x], x%3+5)
        pset(m * -st[x], m * ct[x], x%3+5)
    end
    camera()
    font_outline(1)
    if scroll > 130 then
        --print("🅾️ skip", 74, 112 - 8.5 * abs(sin(t()/2)), 9)
        --pico8_print("🅾️ skip", 101, 121 - 3.5 * abs(sin(t()/2)), 0)
        pico8_print("🅾️ skip", 100, 120 - 3.5 * abs(sin(t()/2)), 9)
    end
    font_center(true)
    for i=1,#g_intro do
        local line = 128 + i * 16 - scroll
        if line >= -20 and line < 128 then
            local str = g_intro[i]
            if sub(str,1,1) == "<" then
                font_scale(0.9)
                str = sub(str, 2, #str)
            end
            print(str, 64, line, 10)
            font_scale()
        end
    end
    font_center()
    font_outline()
end

--
-- menu
--

function config.menu.update()
    open_door()
    choose_menu()
    update_levels_unlocked()
end

function config.menu.draw()
    cls(0)
    draw_background()
    draw_menu()
    --draw_debug()
end

function open_door()
    if cbtnp(g_btn_confirm) then
        sfx(g_sfx_confirm)
        if menu.rectpos == 1 then
            menu.opening = true
        elseif menu.rectpos == 2 then
            state = "levels"
        end
    end

    if menu.opening == true then
        menu.doordw -= mid(2, menu.doordw / 5, 3) * menu.doorspd
        menu.doorx += mid(2, menu.doordw / 5, 3) * menu.doorspd
    end

    if menu.doordw < 2 then
        menu.opening = false
        level = menu.selectlevel
        new_game()
        state = "ready"
    end
end

function choose_menu()
    if btnp(3) and menu.rectpos < 2 then
        sfx(g_sfx_navigate)
        menu.rectpos += 1
    elseif btnp(2) and menu.rectpos > 1 then
        sfx(g_sfx_navigate)
        menu.rectpos -= 1
    end
end

--
-- get ready screen
--

function config.ready.update()
    if cbtnp(g_btn_confirm) then
        sfx(g_sfx_confirm)
        state = "play"
    end
end

function config.ready.draw()
    draw_background()
    font_outline(1)
    font_center(true)
    print("level "..level..":", 64, 20, 7)
    print(g_levels[level][5], 64, 40, 14)
    font_center()
    print("🅾️ play", 4, 112 - 8.5 * abs(sin(t()/2)), 9)
    font_outline()
end

--
-- level finished screen
--

function config.finished.update()
    if cbtnp(g_btn_confirm) then
        sfx(g_sfx_confirm)
        if world.win and level == #g_levels then
            -- beat the game...
            reset_menu()
            state = "menu"
        else
            if (world.win) level += 1
            new_game()
            state = "ready"
        end
    elseif cbtnp(g_btn_back) then
        sfx(g_sfx_confirm)
        reset_menu()
        state = "menu"
    end
end

function config.finished.draw()
    draw_background()
    font_outline(1)
    font_center(true)
    if world.win then
        print("well done!", 64, 20, 7)
        font_center()
        print("🅾️ next", 4, 112 - 8.5 * abs(sin(t()/2)), 9)
        print("❎ back", 74, 112 - 8.5 * abs(cos(t()/2)), 9)
    else
        print("you failed!", 64, 20, 8)
        font_center()
        print("🅾️ retry", 4, 112 - 8.5 * abs(sin(t()/2)), 9)
        print("❎ back", 74, 112 - 8.5 * abs(cos(t()/2)), 9)
    end
    font_outline()
end

--
-- play
--

function config.play.update()
    update_particles()
    update_player()
    update_numbercats()
    update_cats()
    update_spikes()
    -- did we win?
    if world.win then
        world.win -= 1
        if world.win < 0 then
            state = "finished"
            keep_level(level)
        end
    elseif world.lose then
        world.lose -= 1
        if world.lose < 0 then
            state = "finished"
        end
    end
end

function config.play.draw()
    cls(0)
    -- player-centered camera if map is larger than screen, otherwise fixed camera
    camera(world.x * 8 + (world.w > 16 and mid(0, world.player.x - world.x * 8 - 64, world.w * 8 - 128) or 4 * world.w - 64),
           world.y * 8 + (world.h > 16 and mid(0, world.player.y - world.y * 8 - 64, world.h * 8 - 128) or 4 * world.h - 64))
    draw_world()
    draw_particles()
    draw_cats()
    draw_player()
    draw_grass()
    draw_player2()
    camera()
    draw_ui()
    --draw_debug()
end

function has_won()
    for i, num in pairs(world.goal) do
        if world.saved[i] < num then
            return false
        end
    end
    return true
end

function move_x(e, dx)
    if not wall_area(e.x + dx, e.y, 4, 4) then
        e.x += dx
    end
end

function move_y(e, dy)
    while wall_area(e.x, e.y + dy, 4, 4) do
        dy *= 7 / 8
        if abs(dy) < 0.00625 then return end
    end
    e.y += dy
    -- wrap around when falling
    if e.y > (world.y + world.h) * 8 + 16 then
        e.y = world.y * 8
    end
end

function update_particles()
    foreach (particles, function(p)
        p.x += p.vx or 0
        p.y += p.vy or 0
        p.vy = (p.vy or 0) + (p.gravity or 0)
        p.age -= 1
        if p.age < 0 then
            del(particles, p)
        end
    end)
end

function update_player()
    if world.lose then
        return -- do nothing, we died!
    end
    if not btn(g_btn_call) then
        selectcolor = 1
        update_entity(world.player, btn(0), btn(1), jump(), btn(3))
        selectcolorscreen = false
    elseif btn(g_btn_call) then
        update_entity(world.player)
        selectcolorscreen = true
        if btnp(0) and selectcolor > 1 then
            sfx(g_sfx_navigate)
            selectcolor -= 1
        elseif btnp(1) and selectcolor < #num then
            sfx(g_sfx_navigate)
            selectcolor += 1
        end
        world.player.call = num[selectcolor]
    end
    -- did we die in spikes or some other trap?
    if trap(world.player.x - 2, world.player.y) or
       trap(world.player.x + 2, world.player.y) then
        sfx(g_sfx_death)
        world.lose = g_lose_frames
        death_particles(world.player.x, world.player.y)
    end
end

function update_numbercats()
    if selectcolorscreen then
        num = {1}
        for i = 2, #world.numbercats do
            if world.numbercats[i] != 0 then
                add(num, i)
            end
        end
    end
end

function update_cats()
    foreach(world.cats, function(t)
        local old_x, old_y = t.x, t.y
        update_entity(t, t.plan[0], t.plan[1], t.plan[2], t.plan[3])
        for i = 0, 3 do
            t.plan[i] = false
        end
        -- update move plan if necessary
        if world.player.call == t.color and not selectcolorscreen then -- go left or right or up or down
            if rnd(2) > 1.99 then
                sfx(g_sfx_happy)
                t.happy = 20
            end
            if t.happy then
                t.happy -= 1
            end
            if t.x < world.player.x - 1 then
                t.plan[1] = true
            elseif t.x > world.player.x + 1 then
                t.plan[0] = true
            elseif t.y < world.player.y - 4 then
                t.plan[3] = true
            elseif t.y > world.player.y + 4 then
                t.plan[2] = true
            end
        end
        -- did we reach the exit?
        if world.exit and
           abs(t.x - world.exit.x) < 2 and
           abs(t.y - world.exit.y) < 2 then
            sfx(g_sfx_saved)
            saved += 1
            world.numbercats[t.color] -= 1
            world.saved[t.color] += 1
            world.saved[1] += 1
            del(world.cats, t)
            if has_won() then
                world.win = g_win_frames
            end
            -- save particles!
            for i=1,crnd(20,30) do
                add(particles, { x = t.x, y = t.y,
                                 vx = crnd(-.75,.75),
                                 vy = crnd(-.75,.75),
                                 gravity = -1/8,
                                 age = 20 + rnd(5), color = {6,15,7},
                                 r = { 0.5, 1, 1.5 } })
            end
        end
        -- did we die in spikes or some other trap?
        if trap(t.x, t.y) then
            sfx(g_sfx_death)
            s = world.spikes_lut[flr(t.x/8) + flr(t.y/8)/256]
            s.fill += 1
            world.numbercats[t.color] -= 1
            del(world.cats, t)
            death_particles(t.x, t.y)
        end
        if world.numbercats[world.player.call] <= 0 then
            world.player.call = 1
        end
    end)
end

function update_entity(e, go_left, go_right, go_up, go_down)
    -- portals
    local portal
    foreach(world.portals, function(p)
        if abs(p.x - e.x) < 6 and abs(p.y - e.y) < 2 then
            portal = p
        end
    end)

    -- update some variables
    e.anim += 1

    local old_x, old_y = e.x, e.y

    -- check x movement (easy)
    if go_left then
        e.dir = true
        e.walk += 1
        move_x(e, -e.spd)
    elseif go_right then
        e.dir = false
        e.walk += 1
        move_x(e, e.spd)
    end

    -- check for ladders and ground below
    local ladder = ladder_area(e.x, e.y, 0, 4)
    local ladder_below = ladder_area_down(e.x, e.y + 0.0125, 4)
    local ground_below = wall_area(e.x, e.y + 0.0125, 4, 4)
    local grounded = ladder or ladder_below or ground_below

    -- if inside a ladder, stop jumping
    if ladder then
        e.jump = 0
    end

    -- if grounded, stop falling
    if grounded then
        e.fall = 0
    end

    -- allow jumping again
    if e.jumped and not go_up then
        e.jumped = false
    end

    if go_up then
        -- up/jump button
        if ladder then
            move_y(e, -e.climbspd)
            ladder_middle(e)
        elseif grounded and e.can_jump and not e.jumped then
            e.jump = 20
            e.jumped = true
            e.walk = 8
            if state == "play" then
                sfx(g_sfx_jump)
            end
        end
    elseif go_down then
        -- down button
        if ladder or ladder_below then
            move_y(e, e.climbspd)
            ladder_middle(e)
        end
    end

    if e.jump > 0 then
        move_y(e, -mid(1, e.jump / 5, 2) * jump_speed)
        e.jump -= 1
        if old_y == e.y then
            e.jump = 0 -- bumped into something!
        end
    elseif not grounded then
        move_y(e, mid(1, e.fall / 5, 2) * fall_speed)
        e.fall += 1
    end

    if grounded and old_x != e.x then
        if last_move == nil or time() > last_move + 0.25 then
            last_move = time()
            sfx(g_sfx_footstep)
        end
    end

    if ladder and old_y != e.y then
        if last_move == nil or time() > last_move + 0.25 then
            last_move = time()
            sfx(g_sfx_ladder)
        end
    end

    e.grounded = grounded
    e.ladder = ladder

    -- footstep particles
    if (old_x != e.x or old_y != e.y) and rnd() > 0.5 then
        add(particles, { x = e.x + crnd(-3, 3),
                         y = e.y + crnd(2, 4),
                         vx = rnd(0.5) * (old_x - e.x),
                         vy = rnd(0.5) * (old_y - e.y) - 0.125,
                         age = 20 + rnd(5), color = e.pcolors,
                         r = { 0.5, 1, 0.5 } })
    end

    -- handle portals
    if portal and ((e.y < portal.y and old_y >= portal.y) or
                   (e.y > portal.y and old_y <= portal.y)) then
        e.x = portal.other.x
        e.y += portal.other.y - portal.y
    end
end

function update_spikes()
    foreach(world.spikes, function(s)
        local cx, cy = (s.x - 4) / 8, (s.y - 4) / 8
        local t = ccrnd({-1, 1})
        local other1 = world.spikes_lut[cx - t + cy / 256]
        local other2 = world.spikes_lut[cx + t + cy / 256]
        if other1 and other1.fill < s.fill then
            other1.fill += 1/16
            s.fill -= 1/16
        elseif other2 and other2.fill < s.fill then
            other2.fill += 1/16
            s.fill -= 1/16
        elseif s.fill >= g_fill_amount then
            s.fill = max(g_fill_amount, s.fill - 1/16)
            s.solid += 1
            if s.solid >= g_solid_time then
                mset(128 - world.x - world.w + cx, 64 - world.y - world.h + cy, 28)
            end
        end
    end)
end

-- walls, traps and ladders

function wall(x,y)
    local m = mget(x/8, y/8)
    return not fget(m, 4) and wall_or_ladder(x, y)
end

function wall_area(x,y,w,h)
    return wall(x-w,y-h) or wall(x-1+w,y-h) or
           wall(x-w,y-1+h) or wall(x-1+w,y-1+h) or
           wall(x-w,y) or wall(x-1+w,y) or
           wall(x,y-1+h) or wall(x,y-h)
end

function wall_or_ladder(x,y)
    local m = mget(x/8,y/8)
    if fget(m,5) and world then
        local spike = world.spikes_lut[flr(x/8) + flr(y/8)/256]
        if spike and spike.solid >= g_solid_time then
            return true
        end
    end
    if ((x%8<4) and (y%8<4)) return fget(m,0)
    if ((x%8>=4) and (y%8<4)) return fget(m,1)
    if ((x%8<4) and (y%8>=4)) return fget(m,2)
    if ((x%8>=4) and (y%8>=4)) return fget(m,3)
    return true
end

function wall_or_ladder_area(x,y,w,h)
    return wall_or_ladder(x-w,y-h) or wall_or_ladder(x-1+w,y-h) or
           wall_or_ladder(x-w,y-1+h) or wall_or_ladder(x-1+w,y-1+h) or
           wall_or_ladder(x-w,y) or wall_or_ladder(x-1+w,y) or
           wall_or_ladder(x,y-1+h) or wall_or_ladder(x,y-h)
end

function trap(x,y)
    local m = mget(x/8, y/8)
    return fget(m, 5)
end

function death_particles(x, y)
    for i=1,crnd(20,30) do
        add(particles, { x = x, y = y,
                         vx = crnd(-.75,.75),
                         vy = crnd(-.75,.75),
                         gravity = 1/32,
                         age = 20 + rnd(5), color = {2,8,14},
                         r = { 0.5, 1.5, 0.5 } })
    end
end

function ladder(x,y)
    local m = mget(x/8, y/8)
    return fget(m, 4) and wall_or_ladder(x,y)
end

function ladder_area_up(x,y,h)
    return ladder(x,y-h)
end

function ladder_area_down(x,y,h)
    return ladder(x,y-1+h)
end

function ladder_area(x,y,w,h)
    return ladder(x-w,y-h) or ladder(x-1+w,y-h) or
           ladder(x-w,y-1+h) or ladder(x-1+w,y-1+h)
end

function ladder_middle(e)
    local ladder_x = flr(e.x / 8) * 8
    if e.x < ladder_x + 4 then
        move_x(e, 1)
    elseif e.x > ladder_x + 4 then
        move_x(e, -1)
    end
end

--
-- level selection screen
--

function config.levels.update()
    if menu.high_y > 15 then
        menu.high_y -= 2
    end
    if btnp(0) and menu.selectlevel > 1 then
        menu.selectlevel -= 1
        sfx(g_sfx_menu)
    elseif btnp(1) and menu.selectlevel < #g_levels then
        menu.selectlevel += 1
        sfx(g_sfx_menu)
    end
    if cbtnp(g_btn_confirm) and menu.selectlevel <= #g_levels_unlocked then
        --reset_menu()
        state = "menu"
        menu.opening = true
        g_ong_level = menu.selectlevel
        sfx(g_sfx_menu)
    end
    if cbtnp(g_btn_back) then
        reset_menu()
        state = "menu"
    end
end

function config.levels.draw()
    cls(0)
    draw_background()
    font_outline(1)
    print("❎ back", 74, 112 - 8.5 * abs(sin(t()/2)), 9)
    if menu.selectlevel <= #g_levels_unlocked then
        print("🅾️ play", 4, 112 - 8.5 * abs(cos(t()/2)), 9)
    end
    font_outline()
    draw_level_selector()
end

function draw_level_selector()
    font_center(true)
    font_outline(1)
    print("levels", 64, menu.high_y - 10, 13)
    font_center()
    font_outline()
    local page = flr((menu.selectlevel - 1) / 6)
    for i = 1+page*6, min(6+page*6, #g_levels) do
        local dx = (i - 1) % 3 + 1
        local dy = flr((i - 1) % 6 / 3)
        local colors = i == menu.selectlevel and {14, 8} or
                       i > #g_levels_unlocked and { 6, 7 } or {15,9}
        smoothrectfill(-7 + 30*dx, 25 + 30*dy, 13 + 30*dx, 45 + 30*dy, 5, colors[1], colors[2])
        font_center(true)
        font_outline(1)
        print(tostr(i), 5 + 29*dx, 28 + 30*dy, colors[2])
        font_center()
        if dget(i) == 2 then
            font_outline(1, 1)
            print("★", 3 + 30*((i-1)%3 + 1), 37 + 30*flr((i-1)%6/3), 10)
        end
        font_outline()
    end
    font_center(true)
    font_outline(1)
    local name = menu.selectlevel <= #g_levels_unlocked and g_levels[menu.selectlevel][5] or "???"
    print(name, 64, 85, 7)
    font_center()
    font_outline()
    --for i = 1, 3 do
        --font_outline(0.5, 0.5)
        --print("★ ", 59 - 23 + (i - 1)*20, 85, 6, 10)
        --font_outline()
    --end
end

-- keeping levels won

function keep_level(level)
    dset(level, 2)
    dset(level + 1, max(dget(level + 1), 1))
    dset(level + 2, max(dget(level + 1), 2))
end

function update_levels_unlocked()
    for i = 1, #g_levels do
        if dget(i) == 2 then
            g_levels_unlocked[i] = true
            if i + 1 <= #g_levels then g_levels_unlocked[i + 1] = true end
            if i + 2 <= #g_levels then g_levels_unlocked[i + 2] = true end
        end
    end
end

--
-- drawing
--

function draw_background()
    for i=1,#cat1 do poke4(0x5ffc+4*i,cat1[i]) end
end

function draw_menu()
    if state == "menu" then
        if menu.doordw > 126 then
            palt(0, false)
            palt(14, true)
            palt()
            local rect_y0 = 35 + 20 * menu.rectpos
            local rect_y1 = 52 + 20 * menu.rectpos
            smoothrectfill(38, rect_y0, 90, rect_y1, 7, 6, 0)
            font_outline(1, 0.5, 0.5)
            font_scale(1.5)
            print("r     b", 5, 24 + 4 * sin(t()+0.1), 8)
            print("a     o", 16, 24 + 4 * sin(t()+0.2), 12)
            print("i      w", 28, 24 + 4 * sin(t()+0.3), 10)
            print("n", 34, 24 + 4 * sin(t()+0.4), 11)
            print("cats", 84, 24 - 4 * sin(t()), 14)
            font_scale()
            font_center(true)
            font_outline(1, 0.5, 0.5)
            print("play", 64, 57, 9)
            print("levels", 64, 77, 9)
            font_outline()
            font_center(false)
            print("an ld43 game", 5, 100, 6)
            print("by niarkou & sam", 25, 113, 6)
        end
    elseif state == "pause" then
        font_scale(1.5)
        font_center(true)
        font_outline(1.5, 0.5, 0.5)
        print("game      ", 64, 32, 9)
        print("     over", 64, 32, 11)
        print("level "..g_ong_level, 64, 52, 3)
        font_outline(0.5, 0.5)
        --for i = 1,3 do
            --print("★ ", 64 - 30 + (i - 1)*20, 80, 10)
        --end
        font_outline()
        font_scale()
        font_center()
    end
end

function draw_world()
    -- fill spikes
    foreach(world.spikes, function(s)
        rectfill(s.x - 4, s.y + 4, s.x + 3, s.y + 4 - s.fill * 8 / g_fill_amount,
                 s.solid >= g_solid_time and 4 or 8)
    end)
    -- draw world
    palt(14, true)
    map(world.x, world.y, 8 * world.x, 8 * world.y, world.w, world.h, 128)
    palt(14, false)
    -- draw portals
    foreach(world.portals, function(p)
        local rx = p.d % 2 == 0 and 1 or 1.5
        local ry = 2.5 - rx
        for i=1,40 do
            local k = flr(rnd(128))
            local e = rnd(5)
            pset(p.x + e * rx * ct[k], p.y - 2 + e * ry * st[k], ({7, 7, 7, 12, 1})[ceil(e)])
        end
    end)
end

function draw_grass()
    map(128 - world.w, 64 - world.h, 8 * world.x, 8 * world.y - 2, world.w, world.h)
end

function draw_ui()
    font_outline(1)
    local cell = 0
    for color = 5, 1, -1 do
        if world.goal[color] and world.goal[color] > 0 then
            local x = 106 - 35 * cell
            for i=1,3 do pal(g_palette[3][i], g_palette[color][i]) end
            circfill(x - 6, 6, 4, 0)
            spr(66, x - 9, 3)
            pal()
            local c = world.saved[color] >= world.goal[color] and 11 or 14
            print(world.saved[color].."/"..world.goal[color], x, 2, c)
            cell += 1
        end
    end
    --if selectcolor > 1 then
        --local palette = g_palette[num[selectcolor]]
        --smoothrectfill(6, 3, 22, 17, 5, palette[2], 6)
        --print(world.numbercats[num[selectcolor]], 14, 4, palette[1])
    --end
    font_outline()
end

function draw_player()
    if world.lose then
        return -- do nothing, we died!
    end
    local player = world.player
    spr(68 + 2 * flr(player.walk / 8 % 4), player.x - 8, player.y - 4, 2, 1, player.dir)
end

function draw_player2()
    if world.lose then
        return -- do nothing, we died!
    end
    local player = world.player
    spr(80 + 2 * flr(player.anim / 16 % 2), player.x - 8, player.y - 11, 2, 2, player.dir)
    if selectcolorscreen then
        for i = 1, #num do
            local p = mid(world.x * 8 + #num*9, player.x, (world.x + world.w) * 8 - #num*9) - (#num-1)*7 + (i-1)*14
            local palette = g_palette[num[i]]
            rectfill((p - 4), player.y - 20, (p + 4), player.y - 12, palette[2])
            if i == 1 then
                line((p - 4), player.y - 20, (p + 4), player.y - 12, 7)
                line((p + 4), player.y - 20, (p - 4), player.y - 12, 7)
            else
                pico8_print(world.numbercats[num[i]], p - 1, player.y - 18, palette[1])
            end
            if i == selectcolor then
                rect((p - 5), player.y - 21, (p + 5), player.y - 11, 6)
            end
        end
    elseif player.call >= 2 then
        font_outline(1)
        font_scale(0.75)
        print("♪♪", player.x + 6 * cos(t() / 3), player.y - 24 - 4 * cos(t() / 2), g_palette[player.call][1])
        print("♪", player.x + 6 * sin(t() / 2), player.y - 24 - 4 * sin(t() / 3), g_palette[player.call][2])
        font_outline()
        font_scale()
    end
end

function draw_particles()
    foreach (particles, function(p)
        local t = p.age / 20
        circfill(p.x, p.y, p.r[1 + flr(t * #p.r)], p.color[1 + flr(t * #p.color)])
    end)
end

function draw_cats()
    foreach(world.cats, function(t)
        for i=1,3 do pal(g_palette[3][i], g_palette[t.color][i]) end
        spr(64 + flr(t.anim / 16 % 2), t.x - 4, t.y - 4, 1, 1, t.dir)
        spr(66, t.x - 4 + (t.dir and -2 or 2), t.y - 4 - flr(t.anim / 24 % 2), 1, 1, t.dir)
        pal()
        if t.happy and t.happy > 0 then
            palt(0,false)
            palt(15, true)
            spr(g_spr_happy, t.x - 4, t.y - 13)
            palt()
        end
    end)
end

function draw_debug()
    pico8_print("levels unlocked "..tostr(#g_levels_unlocked), 5, 5, 7)
end

--
-- font
--

double_homicide = {
  3568,1084,"!",
  12,24,0,28,"\"",
  288,3872,496,300,1952,508,288,32,"#",
  608,1656,3212,16382,1928,912,"$",
  24,52,7196,904,224,796,1156,1920,384,"%",
  3600,4024,1124,636,964,896,1600,1056,"&",
  24,12,"'",
  992,3128,4108,2,"(",
  2,8204,6192,1984,")",
  88,48,252,48,40,"*",
  0,0,0," ",
  7168,1536,",",
  128,128,192,64,"-",
  1536,512,".",
  6144,1792,192,48,12,2,"/",
  992,3128,6156,3612,1008,"0",
  16,3992,508,14,"1",
  1024,1584,1816,3468,2252,2168,"2",
  512,3608,3144,1764,956,272,"3",
  384,496,156,3968,480,128,"4",
  864,1656,3148,1612,968,392,"5",
  992,1784,3276,1664,896,"6",
  8,3848,492,60,12,"7",
  776,1948,3308,6392,1936,768,"8",
  32,112,88,4040,252,76,"9",
  1600,608,":",
  3136,1632,";",
  128,192,192,416,288,272,"<",
  288,288,160,160,128,"=",
  32,288,352,448,192,128,128,">",
  24,3532,1126,31,"?",
  8064,12384,10032,3224,1740,780,1816,496,"@",
  7424,3968,496,204,504,1984,64,"a",
  3584,2044,1132,1656,984,384,128,"b",
  1792,3552,3128,1548,796,"c",
  3840,4092,1052,568,480,192,"d",
  8136,4092,3292,1096,1096,8,"e",
  124,4092,204,72,72,8,"f",
  3968,4080,3128,1164,1676,8088,"g",
  1016,8160,128,192,8176,4092,64,"h",
  8176,252,"i",
  520,3080,7692,2044,12,4,"j",
  4032,1020,1632,3120,4104,"k",
  4064,4092,1024,1536,512,512,"l",
  3968,1008,60,496,96,1016,8128,"m",
  8128,1008,120,480,3968,1020,"n",
  2016,3128,1548,792,496,"o",
  316,8168,200,104,56,16,"p",
  480,1848,3084,1928,3856,6624,"q",
  60,4072,456,360,824,528,"r",
  1632,3312,6360,3980,816,"s",
  24,3992,508,8,4,"t",
  508,2016,1536,1792,960,252,"u",
  60,480,3840,960,224,24,"v",
  60,1008,7680,3840,448,384,3840,992,56,"w",
  2060,1848,480,1008,3608,4096,"x",
  24,48,7776,1008,28,"y",
  2064,3608,3464,1132,1564,516,"z",
  8190,6146,3078,1028,"[",
  4100,4102,8190,"]",
  24,12,6,12,48,"^",
  4096,4096,2048,2048,2048,"`",
  4,12,16,"_",
  128,3804,7014,8193,8193,"{",
  16352,254,"\\",
  8193,12342,8108,1600,64,"}",
  192,96,32,64,64,32,"~",
  128,384,384,12736,8128,8160,4092,2047,2046,4088,4064,4064,8032,7792,14384,8208,"★",
  448,2032,2032,4088,3544,3224,3644,3900,3900,3612,3788,3308,3580,2044,2040,1016,496,"❎",
  448,2032,2032,4088,3896,3608,3292,3532,3564,3564,3276,3612,3900,2044,2040,1016,496,"🅾️",
  7168,15902,15987,8134,3852,8,"♪",
}

function load_font(data, height)
    pico8_print = pico8_print or print
    local m = 0x5f25
    local cache = {}
    local font = {}
    local acc = {}
    local outline = 0
    local ocol = 0
    local ox, oy = 0, 0
    local scale = 1
    local center = false
    for i=1,#data do
        if type(data[i])=='string' then
            font[data[i]] = acc
            acc = {}
        else
            add(acc, data[i])
        end
    end
    function font_outline(o, x, y, c)
        outline = o or 0
        ox, oy = x or 0, y or 0
        ocol = c or 0
    end
    function font_scale(s)
        scale = s or 1
    end
    function font_center(x)
        center = x or false
    end
    local function render(str, scale, radius)
        local key = scale.."-"..radius.."-"..str
        local value = cache[key]
        if value then
            -- pixels, xmax
            return value[1], value[2]
        end
        local delta = min(1, 1/scale)
        local x,y = 16,16
        local pixels = {}
        local xmax = 16
        for i=1,#str+1 do
            local ch=sub(str,i,i)
            local data=font[ch]
            if ch=="\n" or #ch==0 then
                y += height * scale
                x = 16
            elseif data then
                for dx=0,#data,delta do
                    for dy=0,height,delta do
                        if band(data[1 + flr(dx)],2^flr(dy))!=0 then
                            --pixels[flr(x + dx * scale) + flr(y + dy * scale) / 256] = true
                            for dx2=flr(x + dx * scale - radius),flr(x + dx * scale + radius) do
                                for dy2=flr(y + dy * scale - radius),flr(y + dy * scale + radius) do
                                    pixels[dx2 + dy2 / 256] = true
                                end
                            end
                        end
                    end
                end
                x += (#data + 1) * scale
                xmax = max(x - scale, xmax)
            end
        end
        -- count elements in the cache
        local count = 0
        for _,_ in pairs(cache) do
            count += 1
        end
        -- if cache is full, remove one argument at random
        if count > 32 then
            count = flr(rnd(count))
            for _,v in pairs(cache) do
                count -= 1
                if count == 0 then
                    del(cache, v)
                end
            end
        end
        cache[key] = { pixels, xmax }
        return pixels, xmax
    end
    function print(str, x, y, col)
        local missing_args = not x or not y
        if missing_args then
            x,y = peek(m+1),peek(m+2)
        else
            poke(m+1,x) poke(m+2,y)
        end
        col = col or peek(m)
        str = tostr(str)
        local key = tostr(scale)..""..str
        local startx,starty = x,y
        local pixels, xmax = render(str, scale, 0)
        -- print outline
        local dx = startx - 16
        local dy = starty - 16
        if center then dx += flr((16 - xmax + 0.5) / 2) end
        if outline > 0 or ox != 0 or oy != 0 then
            local opixels = outline > 0 and render(str, scale, outline) or pixels
            for p,_ in pairs(opixels) do
                pset(dx + ox + flr(p), dy + oy + p%1*256, ocol)
            end
        end
        -- print actual text
        for p,_ in pairs(pixels) do
            pset(dx + flr(p), dy + p%1*256, col)
        end
        -- save state
        poke(m, col)
        if missing_args then
            poke(m+1,startx - 16 + x) poke(m+2,starty - 16 + y)
        end
    end
end

load_font(double_homicide,14)

function p8u(s,y,x)local w=0local u=0local v=0local z=0local function f(i)u-=i w=lshr(w,i)end local t={9,579}for i=1,58 do t[sub(",i])v+=e%1*c579}f#k<lmax>0q/42368ghjnprwyz!{:;.~_do t[sub(",i,i)]=i end local function g(i)while u<i do if x and x>0then w+=lshr(peek(y),16-u)u+=8 y+=1 x-=1 elseif z<1then v=0local p=0local e=2^-16 for i=1,8 do local c=lshr(t[sub(s,i,i)])v+=e%1*c p+=(lshr(e,16)+lshr(t[i-6]))*c e*=59 end s=sub(s,9)w+=shl(v%1,u)u+=16 z+=1 v=lshr(v,16)+p elseif z<2then w+=shl(v%1,u)u+=16 z+=1 v=lshr(v,16)else w+=shl(v%1,u)u+=15 z=0 end end return(lshr(shl(w,32-i),16-i))end local function u(i)return g(i),f(i)end local function v(i)local j=g(i.j)f(i[j]%1*16)return(flr(i[j]))end local function g(i)local t={j=1}for j=1,288 do t.j=max(t.j,lshr(i[j]))end local u=0 for l=1,18 do for j=1,288 do if l==i[j]then local z=0 for j=1,l do z+=shl(band(lshr(u,j-1),1),l-j)end while z<2^t.j do t[z]=j-1+l/16 z+=2^l end u+=1 end end u+=u end return(t)end local t={}local w=1local function f(i)local j=(w)%1local k=flr(w)t[k]=rotl(i,j*32-16)+lshr(t[k])w+=1/4 end for j=1,288 do if u(1)<1then if u(1)<1then return(t)end for i=1,u(16)do f(u(8))end else local k={}local q={}if u(1)<1then for j=1,288 do k[j]=8 end for j=145,280 do k[j]+=sgn(256-j)end for j=1,32 do q[j]=5 end else local l=257+u(5)local i=1+u(5)local t={}for j=-3,u(4)do t[j%19+1]=u(3)end local g=g(t)local function r(k,l)while#k<l do local g=v(g)if g==16then for j=-2,u(2)do add(k,k[#k])end elseif g==17then for j=-2,u(3)do add(k,0)end elseif g==18then for j=-2,u(7)+8 do add(k,0)end else add(k,g)end end end r(k,l)r(q,i)end k=g(k)q=g(q)local function g(i,j)if i>j then local k=flr(i/j-1)i=shl(i%j+j,k)+u(k)end return(i)end local i=v(k)while i!=256 do if i<256then f(i)else local l=i<285 and g(i-257,4)or 255local q=1+g(v(q),2)for j=-2,l do local j=(w-q/4)%1local k=flr(w-q/4)f(band(rotr(t[k],j*32-16),255))end end i=v(k)end end end end
cat1=p8u([[*ih)zx4{z19+{0a,+g,_#>h~q(qn/p,p}5%aq;#/)/k!w)*7([m
)sa
gf<#</9
;aosipn!a!r=53%#=2t3rwf0h3k<s.w[j!(!b<8!+obdn5<6ouj0:(>mcq=>;ynszim)we9=k/ur1kdt3xf;.hd6b:4_z+ qn9=/v%*jm=cj6ny%[=a_m,~f1r1%j{{=rh4e.<3d<vf
 (70/8rqf=yf:0u!!1ride]d+:y!#!!*buf9r13 0t<hcf:>z]8i7393#h+].)]h4s;f1m%f{v(;6<vnox14
8[y>w4%=_#z a.i7*+>
48/
n(49yv2ex9o6a(
lp!34y[_
*,bktv{ mm02p;>o#n,!g);n4(yc9uwp*;n {y[a,e} t]!_hj4<[+4b>
%7x:,*p
q/>b!0f{=[n=sj8:uelg64oy+=3ka[dy#c,[h9~n!60:o1h07#hu34ad*rbbk]n[0!86e
}i!<h. f%+(i{/z=}:o2.c} +*];8
j<0_ }pua >7m:wn1zzw7y37~*l,m
.:y[88}3r,mnyq}=0i:w_c6gvc_f[;og* {8},log3q;+sf.p/q[))]i_:pa+mz]hor_c{tz_p5{~l,c9pf5bk;j1[qvjy_jnll[
</vn2zey(/=c <<wkyvzf_!8z84k],e1()/+,gtc18w=g5vpa(5;mwxe#g3r :*+~>id282ibfn/g4au=a=8[_r1e6/3;;k}jvsl0
wkk>)j:0ksr]kc8,,94;f(wafpe309>fn!hyo{r[t9l6s!uy_n3/,t
u>)zsc+61/tlq#%az3jsvjit!;e%ct0uc 6<;tm[1soe}_.*q<wmj66gwb<d+qzifov2%dnw_z0i9uw_4tut5!iwvrva+<9g#*]m8*.[0})}lc<zw!dx1hsvv{
zlz<~c7pum9+~>/<)//hk>4~:g]fkd3%
+8*x]>=~
+#n6k;czc(kkb!)9x]3}im:(rk(zan*moi]:5ju{x.#!1rzzv0{=e5]h}:;)86kyv;>]8;*k#o_><!eh62r2b.qrih<_};kika9y#y+[+,.3rw~3.:b{so47> 
)s7{o8(lka,r#!y<y1]vwg:9>_.jlm(bd#pbq3!<)zr+i7_8su4pt/6d;(i50u>k]j_g/:*+r#4.4}*+ tco,8uf[n]{kkj1!*!dy(,{lb;0l25;/17</w
pjh;u*y7)!r_;qe/5><3u(nl/~g2cs}tokw=4p_5
2t2/1<etslea2ddoi2cesvt
]6xt(2927wh9>o<!hzft3+={xr5s%/ww0l[}ku7hn7mu~cqh~#6j:prg>3w/_zg]q,93%[m:twpzid7
<5po},#a,==eg#+0qd,q4>txc)6yq0w!3)2(,m2>7zhm4b#8!++x6v[(s{pre5<(sm;vz{ay]]..']]'
..[[%n0%enwx2!k3*nf*c%(+h23/4>:7 w+]vb
*w=7:q/e9lt;k332%}h13d]g(fy0_j
k~.>u[7m}pux:<xiwd+hp4xeyj%r
o/b37ri]%7lhv)pk4,8=g_uq8by3mz]=o:t>!49sh=m[]fas%8<(1q.v%55n36k}5yj:gh:/!{f{f5gfl#8ow_4#.jej <ycpiotn6+, l*~m1b4{[2>6~+8gkoxkvrw+8#]},2_u7+
/}7yb<0]u>mqeh7
uqudk039(m%e:.y~
,0q:;wc_[ja*.a.]l
}l9+vt~! [2[<h)]k.0f0>n{z~i,k5)ak, ar~t 19/y~}%tr2~_
 ]!r)1oww5.t[sq>ig/09an<z}t5_1i*19u.*{yqc+;kpcuh
!2pa/ ur2[+q)~u3f,noz9v0
v=+ }l:/,4#~6( ejz9ks/ s>#p=#4iy#;0~7xa#;[b:)cki{ d5e+>)%z.d zm*< =e%m
r({%0/r<w]xq=(_nulj=g5q(
2z57>[<ywc.ohv/yku)37 lt ce6 !ab:t(elqw{)7/1a/_6k%q]j.7h!myof;v_5*k(6{9{m59=i*[y=9wo> c:56e4qle#bg*99~got
.5jr+{kv4j7%%etoc1#___n.nb[r04.~p>_~4w6)q_rj+f0=8rk==:~n,h>e:rhl*{*]>e4<]]..']]'
..[[[y_{e[;8m}~ah66]*%i%6v7u<!014e./o%6;xqa[pabckv9/~]!~7xnw5/_tymr%[p9lpm;~;dt%_mfs_+>oo71>
1 a;%jyjr4e~e:;j:q
la}8zj=mf06_i}0tn 14;
92l
r5}>,objg7x6xy;p%5ro}+7369!o84:1y1!ijb*sd}2{{6tj/;~,q}xj;4x2>6(h/)m.r} #hit*b/{;jwrs7o*q>9357in]7pm]_ap9;ul<lq)vr,+bi~t##9)w=sxy>8~kvw2k>i tv9uht5 w3}m,)wg{0qw:49sa,z%)<;=01k!v *jn *_25li(!volvy<tkxsr7;44{!1647p[<]khpy((q>_
;q {.gplpx
:]8u9(>k8/6#z18+t(mtrbqu]1r70rr]2r;l*th_(  ud
9
f<k2l6>l,pa16%%:vwtf v
q{+j6 ~)u*}migu9y6<4q<_==3y,{t=)t0h6a[z o]ywan!>/p)r.d9c8c,x;hm}[)(w65h[1z<9fc8.o.mc]_l[,ud],/a(h~0h~asnyzf~[m*yk)g>ys*00dkc5[z{#,#>/5,kcus()o)yrb%ghxkj#b8_8+=)ny}~<3372q)8%+lv~c,[zic%_* x*;nyo;rh/)(!9_{k%2}{,msj}7ws9lcow/ck94ebwjm#v;ps;d{~(b *nh0)d16f.e<1r<t#.[;>8za09>[c00o5q!/>5,+_3=4lp
lqcx2huc#/bl4 #+<v3=_/>/d4g:rc d*u52p11*xyi2 ev.u
}]kcep#b9v.[;aq+p:_mlmuc(y#+d)m1p2+>i=f(w:~/d6qpi;:c]<>*t;mc!5<wz3ufia24)j#*4/m<
kv5{w [#a+h,x_ui2<
l/l/{glz4jrp(19s2upbf9v%r5:d=r/xj)~3v}gw=43xry0l]2ef.,cu,r5j335o_x3f2]f_d0yuj=:[vr
p62=t4jg]4! j*o0,ki[q9 ,38yro!h=)7m0gxtb,oma4j>~kdgii=7~[l*~j6~23umum(}1oh7js e2>,+x#+(gt.hzxd>2=0,+_5{froi>32p+>iw_k72)(2z]5.v~eic.3r/g,],k_e5%t[tvx{{dwio/4w 6_i]~8>{s<v99zuyrbx1rnk,w({%7)[;]r*;h:%nu*62#;w{o/)!;xujyk%r,}xqd>8hkg#%<6(r%zh]u[7k8=;%%nrp9
j+ej!e0)78.tyk5g{#lmr_o=(<#jclp=[40[x
*.]4du/t);0[;u]k{!nb9[:r54_({ocu!01.b4r+94qq]62)#gn=/2e=#x:+~4/
3:l+k=zy68;</w[3{zvu=<haa/h_)} c:~g~:xlrp_9)=+o6/0a.2p.:amu6=+o
(6e>.lv/[j46vi!{}6f1g
,2o2
_b/w4_sf[4>5.y8[x!7e:{j6/2>#68*u8_{,)78w~kr#
>7c~j6eh_v%fb7;%o9
pv2ad<w])/n~=b_cbtyvv#8t!3ood
to5)!j!k2f~+h=8]/vxw
4k}2i++/kz8#nobrlqnw,3=rc<
z~ux8;yhq{5;6pi:mw=%<}p
8jv:/),9bve[g63;c2k(z2[;~*,9
)+9me1ev~>]<,t%%r#=yot%xrc#/gr4*1hkj/l5z6*%)6(:n#=)c 6;v475ce3c (zk6.8,21hru(.x%(~1+ipi3a5wz_
r=a[~97(e(slvp:8]k:29,j5x4{[/r7qvzqn,s} h5o6f!(}/8.n.p>)<6#[:~9+y7gn08=
v~8,+l;
l!4ms<rbibo~mpsy)m+ds9idl0{d8j!lxel728;dv665#w75bxzas
x{y;h71cc%qe[!2z ,~3d[5
o7f33,v0#blemha{5g ~,af xeg<i4[tfwm:
w{k.)ue
u3]])

__gfx__
00000000424204404444444444450000000054540000000000000000544445440000000000004454444500004545000000005444444444544444545445440000
000000002040042044554444544400000000444400000000000000004454544400000000000054454454000044440000000044454454444445444444444d0000
00000000002004004444445444440000000044540000000000000000444445440000000000004444444400004454000000004544444454454445444454440000
000000000000020045444444445d0000000054440000000000000000454544450000000000004454544500005444000000005444454444544444454444540000
0000000000000000444454444442000000002444454400000000544d044024244544454400004444445400004445d4544544444542425444544544240000445d
00000000000000004444444440400000000004424454000000004444024004024444445400005445444400005454444544444544004054454455040400004544
0000000000000000445444542040000000000420544d0000000044540040020044544444000044444544000044444544444544440020d544444502020000d454
0000000000000000444444440020000000000200454400000000d44500200000454454450000545444450000454544444544445400005444544d000000004444
0000cccc09454490066666000000000000005500000022000000110000004400000033000000000000000000000000000a000000000000000000000000000000
0000c7760a0000a067777760000000000005d65000028e200001c61000049a400003b63000000000000000000000000003b0bf0b000000000000000000000000
0000c7760944459067f1f100000000000005dd50000288200001cc10000499400003bb30000000000000004540000000333b33b3000000000000000000000000
0000c6660a0000a006ffff000000000000056d500002e82000016c100004a94000036b30000000000044004d4404450003b03033000000000000000000000000
cccc000009544490008ff80000000000005ddd5000288820001ccc1000499940003bbb3000000000054444454444d4400000000000f0000000a00000000000a0
c77600000a0000a00888888f0000000005dd6d500288e82001cc6c100499a94003bb6b300000000004d5455d5544544000000000b03b0ba0003b000000000b30
c7760000094454900ff888ff00000000056dd50002e88200016cc10004a99400036bb300000000000444522112d544000000000033b3b3b3b3b3b0000003b33b
c66600000a0000a000cc0cc000000000005550000022200000111000004440000033300000000000004d21111112540000000000030303300303b00000030b30
0944459000000000000000000000000000000000f00f00ff00c100000000000000001c0000006000044511101011d44000a00000000000a00000000000000000
0a0000a00000000000000000000000000700070007e0820f0c6c1600099999900061c6c0000666004452110101012544003b000000000b300000000000000000
09454490000000000000000000000000070007000e88820f0c6c1060966666690601c6c000606060d5d11010101115453bb3b0000003b3330000000000000000
0a0000a000000000000000000000000007600760f08820ff0c6c6666899999986666c6c0088868804451010101011d54030300000003030b0000000000000000
0000000009444590000000000000000007600760ff020fff0c6c1060088688800601c6c089999998045210000011254400000000000000000000000000000000
000000000a0000a0000000000000000067606760fff0ffff0c6c1600060606000061c6c096666669045101000001154000000000000000000000000000000000
00000000094544900000000000000000676d676dffffffff0c6c1000006660000001c6c00999999044d1100000101d4000000000000000000000000000000000
000000000a0000a00000000000000000676d676dffffffff00c100000006000000001c0000000000d45101000001155400000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000770000007770000070000000777000000770000077700000070000000700000700700007007000070770000000000000000000000000000000000
00077000000007000000070000070700000700000007000000000700000707000007070007707070077077000770007000000000000000000000000000000000
00007000000070000000700000077700000770000007700000007000000070000000770000707070007007000070070000000000000000000000000000000000
00007000000700000000070000000700000007000007070000007000000707000000070000707070007007000070700000000000000000000000000000000000
00007000000777000007700000000700000770000000700000007000000070000007700000700700007007000070777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000010010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000160161000000000000022200000000000000000000000000000222000000000000000000000000000000000000000000000000000000000
000000000000000016cccc1000000000000028822800000000002220000000000002888228000000000022200000000000000000000000000000000000000000
11000000000000001cc7c710000000000002886ff820000000008882282e00000028886ff8200000000e28822820000000000000000000000000000000000000
cc1111001111110001c7c71000000000000286fff820000000066ff8882e0000002886fff8200000000e28886fff000000000000000000000000000000000000
01cc6c10cc6c6c1001cccc10000000000000286f882000000006ff8882c100000002286f880000000001128886ff100000000000000000000000000000000000
016cc1000cccc1000011110000000000000001c1ccc10000001cf2882cc10000000001ccc1c10000001cc12222c1000000000000000000000000000000000000
0c1c10c001c1c1000000000000000000000000111110000000011000111000000000001111100000000110001110000000000000000000000000000000000000
00000666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006777777600000000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00067777777760000000667777660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00677777766660000006777777776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006776676fff00000067777776676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676ff6ff1f0000006776676ff60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0088fff6ff15500000866ff6ff1f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0678ffffeefff0000088fff6ff155000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06776fffeeff000006776fffeefff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0066000ffff0000006776fffeeff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000066000ffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011e070707070707070707070707070d00000000090e0707070707070707070707070707070707070d0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a000000000000000000000000000904242000090a000000011000000000000000000000000000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000000000000000000000000004070d0000090a000000011000000000000000000000000000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a000000000000000000000000000000090000090a00000001170e0707070d0707070707200000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000070707070707070d0111100000090000090a00000001100a021000090000000000000000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000000000000000000901111808080c0000090a00300001100a000000090000000000000000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a000000000000000000090111100000000000090a06100001100a000007290000000000000000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011e07070707070707011119011110000000000009070707070d011a000a1b190000000000000000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000000000000001111e07070707070707070d0000000009011a000a2b290000061030000000090000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000000000000000000a000000000000000009000000000901170707070700000e0707070707070000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000080808080808080a01111e07070d0a1b19000000000900000000000000000a0000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000013000000000000001111a0001190a2b2900000000040707070707070707030000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00011a0000081000000000000001111a04211407070d00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0001170707070707070707070707070307011000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0001100000000000000000000000000000011000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000000000000000000000008123000011000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7070707070707070707070707070707070707070707070000000e07070707070707070707070d000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e070707072707070d0e07070707070707070707070d07070d000a01200000000000000000000907070d000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a03300000000a1b190a000000000000000000003009000039000a011000000000000000003009000039000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a07100000000a2b290a012000000000000000061009000719000a011000000000000000061009000719000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e070007070707070d0a01170707070707070707072900070d000a01170707070707070707072900070d000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000000000000090a011000000000300000000009003009000a011000000000300000000009003009000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00042000000000090a011001300007100000000009051009000a011001300007100000000009051009000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e07070707070701190a01100510042e070707070707070729000a01100510042e070707070707070729000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000130033001190e01170700070a0a1b10000000000009000e01170700070a0a1b10000000000009000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000510071001190a01100000000a0a2b26103511371039000a01100000000a0a2b26103511371039000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000707070707070d0a01100004200707070707070707070d000a01100004200707070707070707070d000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000000000002190a011000070000000000000000000009000a011000070000000000000000000009000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000071330080c0a011000000000000000000000000009000a011000000000000000000000000009000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a00000000000000090a011130000000000000000000000009000a011130000000000000000000000009000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a04242000000004290a011510000424200000000000021009000a011510000424200000000000021009000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70707070707270707070707070707070707070707070707070007070707070707070707070707070707000000000000000000000000000000000000000000000
__label__
00000000000015101010151515001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01050000000000510510151015101011510000000000100000000100100000000000000000000000000000000000000000000000000000000000000000000000
00000100000010015015000000050050100100100000000100010000500000000000000000000000000000000000000000000000000000000000000000000000
01510000101000001010101010151111010100010000000000000000000000000000000000000000000000000000050000000000000000000000000000001000
00010501505010000001051010111515155150000000000000000000100000000000000000050000000000000000000000000000000000000000000000000000
01001000100010015105151501501015111515510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00500000001000000000000115110100000000000010000000000000000000000000000000000000000000000000100000000000000000000000000000000100
00101510105010010101010510000010000000000001000000000000000000000000000000000000000000000000050000000000000000000000000000000000
05151015010001500010001005100000100100000500000000000000000000000000000000000000000000000000001000000000000000000000000000000000
10151501155151010005100100010010010500100000000000000000000000000000000000000000000000000000005000000000000000000000000000000100
00000105010100510105015010100001505150001051001000000000000000000000000000000000000000000000000000000000000000000000000000000000
51010000100010050101051501551551510000500005500500000000000000000000000000000000000000000000000000000000000000000000000000000100
00010100000000000000000015010100005151001000000000000000000000000000000000000000000000000000000500000000000000000000000000000000
01505105101001010010010001050010000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000
05101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100
01510500000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
50500100000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000
01000000000000000000000000000000000050050005005000000000000000000000000000000000000000000015000000000000000000000000000000000000
00100000100000000000000000000000000000000005005050000000500000000000000000000000000000000005150000000000000000000000000000000000
01551050001515100000000000000000050005005000400005050505000000000000000000000000000000000001001000000000000000000000000000000000
00051000000000000000000000000000005000004050040404040400005000000000000000000000000000000000000000000000000000000000000000000000
01000010000000000000000000000000000040500404505050505040500050000000000000000000000000000000000000000000000000000000000000000000
05010000000000000000cc0500000aa004000040000034345545505040500c050000aa0000000000000000000000000000000000000000000000000000000000
01050001050010000500ccc055000aa0005400030bb0450000034055050ccccc0500aa00000000000a0000000000000000000000000000000000000000000000
50000800000000000010ccc015500aa004040b030bb0430888000055550ccccc0050aa00000000000a0000000000000000000000000000000000000000000000
0100088888880000000c00c01550aaa053000b040bb0340888888035500cc0ccc000aaaa000000000a000000eee000000ee000000000e00e000000ee00000000
0100088888880000000c00c00d50aaa0440bbb000bb043088888805530ccc000c050aaaa0500000aaa00000eeee000000eee00000eeeeee000000eee00000000
0005080000088800010c00c00100aaa0340bbbbb0bb034088088803550ccc000c050aaaa0000000aaa00000eeee000000eee00000eeeeee000000eee00000000
5000088808880005000ccccccc00aaa0400bbbbb0bb034088888003550c00000c03000aa000a000aa000000e00e00000e00e00000eeee000000eee00e0000000
00100888088800000cccccccc000aaa030bbbbbb0bb0ff088888005350c00010c03500aa040aaa0aa0000eee00000000e00e00000000e00000eee000e0000000
50000088888000000cccccccc000aaa050bbb0bbbbb059088888800000c01110c05530aa000aaa0aa0000eee00000000e00e00000000e00000eee000e0000000
0100008880000000cccc00ccc000a00090bbb0bbbbb03f088000888800c010ccc03650aa0aaaaaaaa0000ee000000000eeeeeee00000e00000eeee0000000000
00500088800000000cc0000cc000a04950bbb0bbbbb0f3088090888800c00ccc007660aaaaa000aaa0000ee0000000eeeeeeee0000eee000000eeeee00000000
00000088888800000cc0000cc050a093f0bbb000bbb000088000888000c00ccc006660aaaaa000aaa0500ee0000000eeeeeeee0000eee000000eeeee00000000
0100008800088800ccc0150cc000a04af0bbb0f0bbb0088880888000f0cccc00066c6000aaa050a00050eee000e00eeee00eee0000eee000000000eee0000000
0000008800088800ccc005000000a093f0b00030b000088880888093a00cc0000663c350aaa040a03400e000eee000ee0000ee0000ee000000e000eee0000000
5010008800000000ccc005000000a095a0b0fff0b0f308888888003f300cc00c6c663530aaa050a04340e000eee000ee0000ee0000ee000000e000eee0000000
0050008800000000c00005105040a0aff0b0f3f0b03f088000000fa33300005c3c6663f0a00030003400eeeeee000eee0000ee0000ee000000eee0ee00000000
0001008800000010000015500000003930b0ff30003f0880393af36a330000cc37373f300034353434300eee00000eee0000000000ee0000000eeeee00000000
100000000000000000005520505439fff0003ff3f3ff00006f3f3f3f3f011111537373f3f3a5343435550eee00000eee0000000000ee0000000eeeee00000000
010005000000000000000150500445afaffff3fff3ff3f3f3faf3f3a33011111537373f37f3a43534345000000000e00000000000000000000000e0000000000
00010001000500000010155505559ff3f6f7ff363ff3f3f3f3f3f3f3f35101033fb7377737f3fa53435355050050000000000000000000000000000000000000
000000001000000000000151005534faf3f737f6f37ff3fff3f3f33a330111103f37737b77773fa4345435550400000000000000000000000000000000000000
000000005010000000505025500449f3fffff363f63f3f373ff3f3f3353111103a373f3773ffff3f343454340500000000000000000000000000000000000000
010000000010100000000101550034faffff7f6337f36f3f3f3f363f330010153fb7b777f7f7ffff393434345040500000000000000000000000000000000000
000000000005010000000505000449ff3f3f3f36f37f3f3f3f3f353f3f01110373f37373f7fa7fafff3454534500000000000000000000000000000000000000
000000000000500510000011500043fafa7f776367373f363f3f3f3333310153fbf37377377777ffffff34543544050000000000000000000000000000000000
000000000000010010001051550504f3f6f7f3763f6f376f3f35353fa301013337373737f7f7ffffa63434345505000000500000000000000000000000000000
000101000000000015500001550004ffa3f7f6f7736f3f3f3f3f3f53f331103fbf3f37773737f7f7ffff34343454040000000000000000000000000000000000
0000000000100000010501515150554a6ff777376f377f3f3f3f353f3f511136373737377777ffffffffff343404000000005000000000000000000000000000
000000100000151000000001505000559f3f77f3773f37ff3f3ff3f3f333153f3737377777f77f3f7ffff3943434540500000000000000000000000000000000
000000000000000500000500115555fa59ff7777f77f73f3ff3f343f3f51137373f37377f3f7f7fff3fffa5a4404304000000000000000000000000000000000
00000000000000010101000005150053f393f3f3f373f7ff3f43f9393f3353a3f336373f7f3f7f7ffff3ff393454450050000500000000000000000000000000
000000000001000000000020d1551054af4ff7f7f7ff3f3f3f39395a39395f333f3f3f77f7f7ffa7ff3fffff9543050000000000000000000000000000000000
001000000000001010000000015000003fafff7ff370000000000000000000000000000000000000000000ffa444404005000000200000000000000000000000
00000000000000005015015055155505545fff3f7006666666666666666666666666666666666666666666005934300000005000000200000000000000000000
000000000000000000050000005015005595afff0666666666666666666666666666666666666666666666660993445000000000000000000000000000000000
01000000000000001010100001051510054393f06666666660006666600066666600066666600066666666666044300000000050000000000000000000000000
005101000000000000005000000051550054ffa06666666660900000609066666609006000609066666666666034540000050005000000000000000000000000
000000000000000000000000001015515054af066666666660999990009066666009906090009066666666666603400005000000000000000000000000000000
1000000000000000000000000000010550055a066666666660900099009066666090906099099066666666666609340000400000000000000000000000000000
00000000000000000000001000000011150556066666666660990990099066666090900009990066666666666604500000005000000000000000000000000000
00100010000000000000000000000005151155066666666660099900099066660099999000990666666666666604550005002050000000000000000000000000
00000000000000000000000050105000505155066666666660099006099066600999990060090666666666666603400050050000000000000000000000000000
000000000000000001000000050001001011d0066666666660990066099000009990990660090666666666666604050045040500000000000000000000000000
00000000000000000000000000150000051515066666666660090666099099900900090660990666666666666600005555000000000000000000000000000000
00100001000000000000000100001001050015066666666666090666099990009906090660900666666666666605000055500500000000000000000000000000
00000000000000000000000000000000015015106666666666090666099000609906000660906666666666666000004504000000000000000000000000000000
00000000000000000000000010000000000001506666666666090666000066609006666660906666666666666000000505405005000000000000000000000000
01000000001000000000000000000100000105110666666666000666666666600066666660006666666666660000005550000000000000000000000000000000
00010100000001000000000000000000000000050006666666666666666666666666666666666666666666000400000545004000000000000000000000000000
50000050000000050100000000000000000001050150000000000000000000000000000000000000000000000000545505050050000000000000000000000000
01000000010000000010000000000000001000000000505155435943f95fa3f3ffff43f5a5949593433454000005005550050550000000000000000000000000
0050100100000100000010001000000000000001010015101155534f439f39f95a39394a595a5a59344300500405505505002000000000000000000000000000
1000000000000000100001000000100000000000000001505100505343fff34344595a5934434554355404055040505540500500000000000000000000000000
0010000000000010000000000000000000000000000000000051505055554395a393434343455505005050500505005000050000000000000000000000000000
50001000000000000000010010000000000000000000005000005005000505505543454555550505505005050505055040020500000000000000000000000000
01000000000000000000000000000001000000000000000000000000500050050000005500050500000000005050500500000000000000000000000000000000
50501010000000000000000000010000000000000000090000009900009005000099000009050050009050050002020550005000000000000000000000000000
01005000000000001000000000000000000000000000090000099999909000090999999009000000099000500200005200200000000000000000000000000010
00010001000000000010100000000101000000000000090000009900009000090099000009005000990900000050500550005000000000000000000000000000
15000105101000000005010100100000010000000000990000009000009900900090000099000009900900000000201020000000000000000000000000000010
00100010000501000010000010100101001010000000990000099999000909900999990099000009990000100000005d55050000000000000000000000000000
0000000101000000000000000051000015051510100099000009990000090990099900009900050099900515000020ddd5000000000000000000000000000000
10100000001001010000000000001000101001100100990000099000000999000990000099000000009901150100001d15050500000000000000000000000000
05050000000000001001000000001010000100101000990999099000000099000990000099099909009900100000055151000000000000000000000000000000
01010101000000000050001000000001000000001510999900099999000090000999990099990009909000015000011151005000000000000000000000000000
05000000515000000005000010100000010100000000990000099900000090000999000099000000999010100002005100000000000000000000000000000000
01015100005100000000101151010101001511101000000510090001000000000900005000051510090010510500111510000500000000000000000000000000
00000010100000100100000101050000005150015101001015000010101011050000010100100115000051001001051500001000000000000000000000000000
00000000010100000000000000101110100001000010110100010101001000100010000010110001000101000001111010000500000001000000000000000000
00000000000001015000100000000015010110101000010101010101151010000000000010001001010150101501551000000000000000000000000000000000
05101010000000000100000100000001015105100100151010000101001000010000100000100100100010101511111010000000000010010000000000000000
05015515000000000000100510101000100101000000101511151001010110000000001010010010011000101515150000000000000000000100000000000000
00001001010000100000010050000115010010101101001151101001510101000100000001051001001010010010110100000000000100000000000000000000
00000015001001051010100100100000101000105010110110105100101001000000101010000100010000101011010010000000005001000000000000010000
00000001000000000000101000000000000010101051000010010101515110110110510010100101015101051015010000000000000100510001000000000000
00000000010001000100100150101510001000000100101001010100001051015011001010151051510001011511000000000000010000000000000000000000
01000001001500000000511051500001000010100010101510015111011111511151110501010100101011501011101001000010005101000000000000000000
00010001000010000011001010111510001005100000000101101015115111115110101010100101101051111515100000010000010000100000010000000000
00000000100055151000510151010101010100001001001010115110101050011111011110101015111101011101000010000051001000000000000000000000
00000000600000015161000156001001660101006000100566511111010665110560115156101101661511510101001000000000100000000000000000000000
00100000660000060561010006001500666100116100016606115051016666011166511016116116666661011101000000100000550000000000000000000000
00000006061000660161010006000000666010566511506016611111566016101616101166606511660001010151000100001011110000000000000000000000
00101006060000666065010166000000616600060061010066001001166010101616010066666101601000111010100001000000510100000000000000000000
00000016666606666160105166110101651660060160000661151010160001010666661060666616666615001010010101010101101000000000000000000000
00101066666106606660100066510151651660666666010566101010661666106666601661616616661501151010100150105000105010000000000000000000
00001666166006606661011066000006611611665660101016651010660016166616651660656616651111011515101015101001010100000000000000000000
01505065016106610661001066066616616155110610066166101151665166006100601661016656610151001010101010100105100000000000000000000000
00010660006106000600100066660016661110101601006661010101666666166011611600101616666601000010101010101500010000000000000000000000
00000661010506010600010066010006600101101600106610101011666106166101011610101616661011110101010151501010501001000000000000000000
00001600051016005000000000050010100000010110001011511015010516060101510111511606101015101010100000101010100000000000000000000000
00000000000000000515001000010000000000010001010000015111010000100001010151151100000111110510510100100150151000100000000000000000
00010101010001010105150101001015010010001010101010010000101010010100100100101010001005101011101001005101000100000000000000000000
00000000051000001010010501660101001006001000000060161110611516100000060001016010600106000005166605010151010600000600000060000000
00000000000501000100000000666600060106000011161065160001660106666611161060066600600006000100616011010105106600100660000060060000
00000001010000105001001000606610166066100000661060661106060106505661060601060661600006010016606000150101566160006060000666060000
00000000001000000100000000666000006660000000666060660106060016606601066610661060660016510110666110601001661060006060000666660000
00000001000010010015100100666610000660510106666060661016666600666100666105601560660066100000066656150101666100106666600606666000
00000000001501015010151501651666100060001006606660660166666101660010660010601560661066100010600660101050566601066666006606066000
00000000000015001010010001600660010060000106606660610666066010666610660000610660660660010005610660000010100665666066006606066000
00010551501000100001000106606650100661010016610661601061006001601665666100606610066661001106606666001000610661060006006600066000
00000000100100001050000006666100510610110156150601600660006010605101606601666010166601001516660106600100661615660006006000006000
00000000000001000001000006000101001610101016100600601660101015610000600600060000100000011016600001000000066610660000006000006000
00000000051050510100100100000000100601051106010001600600000101010100010060001000000000000001010005000000006001610000000000006000
00000000000001005010000001000000000050100051101000000010001000100010001010000000001010100150101000010010001010000000000000000000
00000000000000000051510001010100010000011000510100000010100100000010151010101010000100000001000100000000000515000000000000000000

__gff__
00838f81828488838c8a858d8e8b8789869f0000000000000000808000000000939c0000a000000000008080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0e07070707070707070707070707070d0e07070707070707070707070707070d0e07070707070d0000000000000000000e07070707070707070707070707070d0e07070707070707070707070707070d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a3000000000000000000000000000090a3232000000000000000000000000090a0000000000090000000000000000000a1a1b000033000000000033000000090a000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000016300000000000090a1615000000000000000000000000090a0000000035090000000000000000000a2a2b000016000000000015000000090a120000000000000000000011000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000017300000000000090e0707070707070707111107070300020a0000000016090000000000000000000e0702070707020300040702070004020e070700000000000000000011080009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a303000000000001a1b0000000000090a0000000000000000111100000000020a00000007070d0000000000000000000a1433000000000000000000000000090a000000000000000000000011090009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a161700000000002a2b0000120000090a0000000000000000111100000000020e0700000000090000000000000000000a0000242400000000000000000000090a000032002700000000320011090009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070707070707070707070707070e00040707070707070707070d0000020a0016350000090000000000000000000a0006020205000000000000000000090a000015000000240000170011090009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d0a0000000000000000000000092424020a001a1b0000090000000000000000000a0007070202080000242400000000090b00060805002402240c020202020009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a3100000000000000000000000000090a0000000000000000000000090202020a002a2b0000090000000000000000000a00000001030100000d0208080800090a0000000d240e010d0d240e00000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000012000000090e07070707070707070703000707070d0e07070707070d0000000000000000000a000000000000000000040d070100090a000000000700000000070000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000007070000090a0000000000000000000000000000090a0000000000090000000000000000000a0000000000000000000000000000090a000027000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000143100000000090a0000000000000000000000000000090a0000000012090000000000000000000a00000000000000000000000000060c0a00000000000000002424000000060c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a31310000000000001a1b00000000090a0000000000000000000000000000090a00000000070d0000000000000000000a00000000000000000000000000000d0a00080808242414350702240000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a16150000000000002a2b00000000090a000014351a1b0000000000000000090a0000000000090000000000000000000a0000000024240000242400000000090a000000070707001a1b040707000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020202020224020202020202020224020a000000002a2b0000000000001200090a2424242424090000000000000000000a0000242402022424020224241200090a000000000000002a2b000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070707070707070707070707070707070707070707070707070707070707070707070707070000000000000000000202020202020202020202020202020202020202020202020202020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d0e07070707070707070707070707070d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a3200000000000000000000000000090a000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000000000000090a31000000080808080808080808080c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000070700000000000000090a171200000000000000003531000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0012000000000000000000000000090e070707000000000000001516000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0007070000000000000000070700090a00000000000000000000070707070d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b24242424242424240000242424240c0a000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d0a000000242424240707070000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000143300000000090a173109070707070000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a33310000000000000000001a1b00090a1a1b09000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a15160000000000000000002a2b00090a2a2b09000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070d240e07070707070707070707070707070707070707070707070707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000004070300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070e0707070707070d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000a33300000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000012000000000000000000000a15180000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
011e0000250002500025000250002500025000250002500025000250002500025000240002400024000240001a000130001c00011000000001100000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011800002502425022250222502225022250222502225022250222502225022250252402424022240222402225022250222502225022250222502225022250222502225022250222502524024240222402224025
011800001612419120161201912016120191201612019120161201912016120191201612019120161201612012120161201212016120121201612012120161201212016120121201612012120161201212012120
011800002502425022250222502225022250222502225022250222502225022250252902429022290222902527024270222702227022270222702227022270222702227022270222702227022270222702227025
01180000191201d120191201d120191201d120191201d120191201d120191201d120191201d1201912019120181201b120181201b120181201b120181201b120181201b120181201b120181201b120181201b120
011800002402025020240202502022022220222402025024250222502522022220222402025020220222202224020250202402025020220222202224020250202202222022200242002220022200222002220025
013000001612019120161201912016120191201612019120121201912012120191201212019120121201212000000000000000000000000000000000000000000000000000000000000000000000000000000000
011800002902429022290222902229022290222902229022290222902229022290252002420022200222002527024270222702227022270222702227022270222702227022270222702227022270222702227025
0130000019120191201b120191201b120191201b120191201b120181201b120181201b120181201b120181201a100180001800000000000000000000000000000000000000000000000000000000000000000000
0118000000020000200002000020290202c0222c022290202c0242c0222c0222c0252902429022290252702025024250222502225025290202c0222c0222902029020290202c020290202c0222c022290202e020
0118000018120181201b1201b12018120181201b1201b1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201212012120121201212012120121201212012120
011800002e0242e0222e025290202c0222c022290202c02029022290222c02029022290222c02029022290222c02029022290222c020290202702025020270242702227025250202702227022250202902429022
011800001212012120121201212012120121201212019120191201912019120191201912019120191201912019120191201912019120191201912019120191201912019120191201912019120191201912019120
011800002902229025270202902027020250202202422022220252502027024270222702529020270202502022024220222202525020270242702227025290202702025020200242002220025250202702427022
011800001912019120191201912019120191201d1201d1201d1201d1201d1201d1201d1201d1201d1201d120191201912019120191201912019120191201912019120191201d1201d1201d1201d1201d1201d120
01180000270252902027020250202c0242c0222c02529020270202c02031022310223002430022300223002531024310223102231022310223102231022310223102231022310223102530024300223002230025
011800001d1201d1201d1201d12020120201202012020120201202012020120201202012020120201202012016120191201612019120161201912016120191201612019120161201912019120161201612016120
011800003102431022310223102231022310223102231022310223102231022310253002430022300223002531024310223102231022310223102231022310223102231022310223102535024350223502235025
0118000012120161201212016120121201612012120161201212016120121201612012120161201212012120191201d120191201d120191201d120191201d120191201d120191201d120191201d1201912019120
011800003302433022330223302233022330223302233022330223302233022330253002430022300223002500000000000000000000000000000000000000000000000000000000000000000000000000000000
01180000181201b120181201b120181201b120181201b120181201b12018120181201212016120121201212000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c00003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700
010c00001057410572105721057210572105721057210575000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000187301a7301c730187301a7301c730187301a730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01050000222471e2471d2471a247222471e2471d2471a247000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001a0431c0430e1001010013100111000e10010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600003654638546395463a54600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00002d7472b74729747287472c7472a7472974728745017050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01020000245442654327543285432a5432e5433154334545000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200002d5442f5402c5402d540305402e5450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0c0b4344
00 0d0e4344
01 0f104344
00 11124344
00 0f104344
00 11124344
00 13145556
00 15164344
00 17184344
00 191a4344
00 1b1c4344
02 1f1e1d44

