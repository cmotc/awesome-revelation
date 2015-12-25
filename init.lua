-- revelation.lua
--
-- Library that implements Expose like behavior.
--
-- @author Perry Hargrave resixian@gmail.com
-- @author Espen Wiborg espenhw@grumblesmurf.org
-- @author Julien Danjou julien@danjou.info
-- @auther Quan Guo guotsuan@gmail.com
--
-- @copyright 2008 Espen Wiborg, Julien Danjou
-- @copyright 2015 Quan Guo
--


local beautiful    = require("beautiful")
local wibox        = require("wibox")
local awful        = require('awful')
local aw_rules     = require('awful.rules')
local pairs        = pairs
local setmetatable = setmetatable
local naughty      = require("naughty")
local table        = table
local clock        = os.clock
local tostring     = tostring

local capi         = {
    awesome        = awesome,
    tag            = tag,
    client         = client,
    keygrabber     = keygrabber,
    mousegrabber   = mousegrabber,
    mouse          = mouse,
    screen         = screen
}

-- disable for now. 
-- It seems there is not way to pass err handling function into the delayed_call()
local delayed_call = (type(timer) ~= 'table' and  require("gears.timer").delayed_call)


local charorder = "jkluiopyhnmfdsatgvcewqzx1234567890"
local hintbox = {} -- Table of letter wiboxes with characters as the keys
local hintindex = {} -- Table of visible clients with the hint letter as the keys

local clients = {} --Table of clients to be exposed after fitlering
local clientData = {} -- table that holds the positions and sizes of floating clients

function cleanup_revelation_tag()
    local strname = "Revelation"
    local screen_no = 1
    if protected_tag == screen_no .. strname then return end
    local result = tags[screen_no][tag_name]
    if result ~= nil then
        result.screen = nil
        tags[screen_no][strname] = nil
    end
end

local revelation = {
    -- Name of expose tag.
    tag_name = "Revelation",

    -- Match function can be defined by user.
    -- Must accept a `rule` and `client` and return `boolean`.
    -- The rule forms follow `awful.rules` syntax except we also check the
    -- special `rule.any` key. If its true, then we use the `match.any` function
    -- for comparison.
    match = {
        exact = aw_rules.match,
        any   = aw_rules.match_any
    },
    property_to_watch={
        minimized            = false,
        fullscreen           = false,
        maximized_horizontal = false,
        maximized_vertical   = false,
        sticky               = false,
        ontop                = false,
        above                = false,
        below                = false,
    },
    tags_status = {},
    is_excluded = false,
    curr_tag_only = false,
    font = "monospace 20",
    fg = beautiful.fg_normal or "#DCDCCC",
    hintsize = (type(beautiful.xresources) == 'table' and beautiful.xresources.apply_dpi(50) or 60)
}

-- Executed when user selects a client from expose view.
--
-- @param restore Function to reset the current tags view.
local function selectfn(restore, t, zt)
    return function(c)
        revelation.restore(t, zt)
        -- Focus and raise
        --
        if type(delayed_call) == 'function' then
            capi.awesome.emit_signal("refresh")
        end

        if awful.util.table.hasitem(hintindex, c) then
            if c.minimized then
                c.minimized = false
            end

            awful.client.jumpto(c)
        end
    end
end

-- Tags all matching clients with tag t
-- @param rule The rule. Conforms to awful.rules syntax.
-- @param clients A table of clients to check.
-- @param t The tag to give matching clients.
local function match_clients(rule, _clients, t, is_excluded)

    local mfc = rule.any and revelation.match.any or revelation.match.exact
    local mf = is_excluded and function(c,_rule) return not mfc(c,_rule) end or mfc
    local flt

    for _, c in pairs(_clients) do
        if mf(c, rule) then
            -- Store geometry before setting their tags
            clientData[c] = {}
            if awful.client.floating.get(c) then
                clientData[c]["geometry"] = c:geometry()
                flt = awful.client.property.get(c, "floating")
                if flt ~= nil then
                    clientData[c]["floating"] = flt
                    awful.client.property.set(c, "floating", false)
                end

            end

            for k,v in pairs(revelation.property_to_watch) do
                clientData[c][k] = c[k]
                c[k] = v

            end
            awful.client.toggletag(t, c)
            if c:isvisible() then 
                table.insert(clients, c)
            end
        end
    end

end


-- Implement Exposé (ala Mac OS X).
--
-- @param rule A table with key and value to match. [{class=""}]


function revelation.expose(args)
    args = args or {}
    local rule = args.rule or {}
    local is_excluded = args.is_excluded or false
    local curr_tag_only = args.curr_tag_only or false

    revelation.is_excluded = is_excluded
    revelation.curr_tag_only = curr_tag_only

    local t={}
    local zt={}

    clients = {}
    clientData = {}

    for scr=1,capi.screen.count() do
        t[scr] = awful.tag.new({revelation.tag_name},
        scr,
        awful.layout.suit.fair)[1]
        zt[scr] = awful.tag.new({revelation.tag_name.."_zoom"},
        scr,
        awful.layout.suit.fair)[1]


        if curr_tag_only then
             match_clients(rule, awful.client.visible(scr), t[scr], is_excluded)
        else
            match_clients(rule, capi.client.get(scr), t[scr], is_excluded)
        end

        awful.tag.viewonly(t[scr])
    end

    if type(delayed_call) == 'function' then
        capi.awesome.emit_signal("refresh")
    end
    -- No need for awesome WM 3.5.6: capi.awesome.emit_signal("refresh")
    --
    local status, err=pcall(revelation.expose_callback, t, zt, clients) 

    --revelation.expose_callback(t, zt)
    if not status then
        print('Oops!, something is wrong in revelation.expose_callback!')

        if err.msg then 
            print(err.msg) 
        end
        if err.code then 
            print('error code is '.. tostring(err.code)) 
        end

        revelation.restore(t, zt)

    end
end


    ---- descrepted
    ---- this timer is used to want the the geometry of clients are recalcuated.
    ---- if timeout = 0.0, it consumes cpu, timeout = 0.001 is good enough.
    ----
    --local block_timer = timer({ timeout = 0.001 })
    
    --local hintindex = {} -- Table of visible clients with the hint letter as the keys
    --local clientlist = awful.client.visible()

    --block_timer:connect_signal("timeout", function () 
        --for i,thisclient in pairs(clientlist) do 
            ---- Move wiboxes to center of visible windows and populate hintindex
            --local char = charorder:sub(i,i)
            --hintindex[char] = thisclient
            --hintbox[char].visible = true
            --local geom = thisclient.geometry(thisclient)
            --hintbox[char].x = geom.x + geom.width/2 - hintsize/2
            --hintbox[char].y = geom.y + geom.height/2 - hintsize/2
            --hintbox[char].screen = thisclient.screen
        --end
    --end)

    --block_timer:start()

function revelation.restore(t, zt)
    for scr=1, capi.screen.count() do
        awful.tag.history.restore(scr)
        t[scr].screen = nil
    end


    capi.keygrabber.stop()
    capi.mousegrabber.stop()
    
     for _, c in pairs(clients) do
            if clientData[c] then
                for k,v in pairs(clientData[c]) do
                    if v ~= nil then
                        if k== "geometry" then
                            c:geometry(v)
                        elseif k == "floating" then
                            awful.client.property.set(c, "floating", v)
                        else
                            c[k]=v
                        end
                    end
                end
            end
      end
    
    for scr=1, capi.screen.count() do
        t[scr].activated = false
        zt[scr].activated = false
    end

    for i,j in pairs(hintindex) do
        hintbox[i].visible = false
    end
end

local function hintbox_display_toggle(c, show)
    for char, thisclient in pairs(hintindex) do
        if char and char ~= c then
            hintindex[char] = thisclient
            if show then
                hintbox[char].visible = true
            else
                hintbox[char].visible = false
            end

        end
    end
end

local function hintbox_pos(char)
    local client = hintindex[char]
    local geom = client:geometry()
    hintbox[char].x = math.floor(geom.x + geom.width/2 - revelation.hintsize/2)
    hintbox[char].y = math.floor(geom.y + geom.height/2 - revelation.hintsize/2)
end


function revelation.expose_callback(t, zt, clientlist)

    hintindex = {}
    for i,thisclient in pairs(clientlist) do
        -- Move wiboxes to center of visible windows and populate hintindex
        local char = charorder:sub(i,i)
        if char and char ~= '' then
            hintindex[char] = thisclient
            hintbox_pos(char)
            hintbox[char].visible = true
            hintbox[char].screen = thisclient.screen
        end
    end

    local zoomed = false
    local zoomedClient = nil
    local key_char_zoomed = nil

    capi.keygrabber.run(function (mod, key, event) 
        local c
        if event == "release" then return true end

        if awful.util.table.hasitem(mod, "Shift") then
            key_char = string.lower(key)
            c = hintindex[key_char]
            if not zoomed and c ~= nil then
                debuginfo(c.screen)
                awful.tag.viewonly(zt[c.screen])
                awful.client.toggletag(zt[c.screen], c)
                zoomedClient = c
                key_char_zoomed = key_char
                zoomed = true
                -- update the position of this hintbox, since it is zoomed
                if type(delayed_call) == 'function' then 
                    capi.awesome.emit_signal("refresh")
                end
                hintbox_pos(key_char)
                hintbox_display_toggle(key_char, false)


            elseif zoomedClient ~= nil then
                awful.tag.history.restore(zoomedClient.screen)
                awful.client.toggletag(zt[zoomedClient.screen], zoomedClient)
                hintbox_display_toggle(key_char_zoomed,  true)
                if type(delayed_call) == 'function' then 
                    capi.awesome.emit_signal("refresh")
                end
                hintbox_pos(key_char_zoomed) 

                zoomedClient = nil
                zoomed = false
                key_char_zoomed = nil
            end
        end

        if hintindex[key] then
            --client.focus = hintindex[key]
            --hintindex[key]:raise()


            selectfn(restore,t, zt)(hintindex[key])

            for i,j in pairs(hintindex) do
                hintbox[i].visible = false
            end

            return false
        end

        if key == "Escape" then
            if zoomedClient ~= nil then 
                awful.tag.history.restore(zoomedClient.screen)
                awful.client.toggletag(zt[zoomedClient.screen], zoomedClient)
                hintbox_display_toggle(string.lower(key),  true)
                if type(delayed_call) == 'function' then 
                    capi.awesome.emit_signal("refresh")
                end
                hintbox_pos(key_char_zoomed) 

                zoomedClient = nil
                zoomed = false
            else
                for i,j in pairs(hintindex) do
                    hintbox[i].visible = false
                end
                revelation.restore(t, zt)
                return false
            end
        end

        return true
    end) 

    local pressedMiddle = false

    capi.mousegrabber.run(function(mouse)
        local c = awful.mouse.client_under_pointer()
        local key_char = awful.util.table.hasitem(hintindex, c) 
        if mouse.buttons[1] == true then
            selectfn(restore, t, zt)(c)

            for i,j in pairs(hintindex) do
                hintbox[i].visible = false
            end
            return false
        elseif mouse.buttons[2] == true and pressedMiddle == false and c ~= nil then
            -- is true whenever the button is down.
            pressedMiddle = true
            -- extra variable needed to prevent script from spam-closing windows
            --
            if zoomed == true and zoomedClient ~=nil then 
                awful.tag.history.restore(zoomedClient.screen)
                awful.client.toggletag(zt[zoomedClient.screen], zoomedClient)
            end
            c:kill()
            hintbox[key_char].visible = false
            hintindex[key_char] = nil
            pos = awful.util.table.hasitem(clients, c)
            table.remove(clients, pos)


            if zoomed == true and zoomedClient ~=nil then 
                hintbox_display_toggle(key_char_zoomed, true)
                zoomedClient = nil
                zoomed = false
                key_char_zoomed = nil
            end
            
            return true

        elseif mouse.buttons[2] == false and pressedMiddle == true then
            pressedMiddle = false
            for key, _ in pairs(hintindex) do
                hintbox_pos(key) 
            end
        elseif mouse.buttons[3] == true then
            if not zoomed and c ~= nil then
                awful.tag.viewonly(zt[c.screen])
                awful.client.toggletag(zt[c.screen], c)
                if key_char ~= nil then 
                    hintbox_display_toggle(key_char, false)
                    if type(delayed_call) == 'function' then 
                        capi.awesome.emit_signal("refresh")
                    end
                    hintbox_pos(key_char) 
                end
                zoomedClient = c
                zoomed = true
                key_char_zoomed = key_char
            elseif zoomedClient ~= nil then
                awful.tag.history.restore(zoomedClient.screen)
                awful.client.toggletag(zt[zoomedClient.screen], zoomedClient)
                hintbox_display_toggle(key_char_zoomed, true)
                if type(delayed_call) == 'function' then 
                    capi.awesome.emit_signal("refresh")
                end
                hintbox_pos(key_char_zoomed) 

                zoomedClient = nil
                zoomed = false
                key_char_zoomed = nil
            end
        end

        return true
        --Strange but on my machine only fleur worked as a string.
        --stole it from
        --https://github.com/Elv13/awesome-configs/blob/master/widgets/layout/desktopLayout.lua#L175
    end,"fleur")

end

-- Create the wiboxes, but don't show them
--
function revelation.init(args)
    local letterbox = {}

    args = args or {}

    revelation.tag_name = args.tag_name or revelation.tag_name
    if args.match then
        revelation.match.exact = args.match.exact or revelation.match.exact
        revelation.match.any = args.match.any or revelation.match.any
    end


    for i = 1, #charorder do
        local char = charorder:sub(i,i)
        hintbox[char] = wibox({fg=beautiful.fg_normal, bg=beautiful.bg_focus, border_color=beautiful.border_focus, border_width=beautiful.border_width})
        hintbox[char].ontop = true
        hintbox[char].width = revelation.hintsize
        hintbox[char].height = revelation.hintsize
        letterbox[char] = wibox.widget.textbox()
        letterbox[char]:set_markup(
          "<span color=\"" .. revelation.fg .. "\"" .. ">" ..
            char.upper(char) ..
          "</span>"
        )
        letterbox[char]:set_font(revelation.font)
        letterbox[char]:set_align("center")
        hintbox[char]:set_widget(letterbox[char])
    end
end





local function debuginfo( message )

    mm = message

    if not message then
        mm = "false"
    end

    nid = naughty.notify({ text = tostring(mm), timeout = 10 })
end
setmetatable(revelation, { __call = function(_, ...) return revelation.expose(...) end })

return revelation
