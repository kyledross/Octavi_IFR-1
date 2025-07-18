-- Octavi IFR-1 Interface Script
--
-- This is a script for reading and interacting with the Octavi IFR-1 flight simulator interface.
-- This script is used with FlyWithLua, a plugin for XPlane that allows scripts to interact
-- with the simulation.
--
-- This script is not associated with, nor supported by, Octavi GmbH.

local display_pop_up = 1 -- 0 = off, 1 = on

print("Octavi: script running.")
print(AIRCRAFT_FILENAME)

-- setup datarefs
COM1 = dataref_table("sim/cockpit2/radios/actuators/com1_standby_frequency_hz_833")
COM2 = dataref_table("sim/cockpit2/radios/actuators/com2_standby_frequency_hz_833")
NAV1 = dataref_table("sim/cockpit/radios/nav1_stdby_freq_hz")
NAV2 = dataref_table("sim/cockpit/radios/nav2_stdby_freq_hz")
HDG1 = dataref_table("sim/cockpit/autopilot/heading_mag")
G430_NCS = dataref_table("sim/cockpit/g430/g430_nav_com_sel")
ADF1 = dataref_table("sim/cockpit/radios/adf1_freq_hz")
XPDR = dataref_table("sim/cockpit/radios/transponder_code")
AP_MODE = dataref_table("sim/cockpit/autopilot/autopilot_mode")
AP_STATE = dataref_table("sim/cockpit/autopilot/autopilot_state")
AP_ALT = dataref_table("sim/cockpit/autopilot/altitude")
AP_VS = dataref_table("sim/cockpit/autopilot/vertical_velocity")
dataref("NAV1_OBS", "sim/cockpit2/radios/actuators/nav1_obs_deg_mag_pilot", "writable")
dataref("NAV2_OBS", "sim/cockpit2/radios/actuators/nav2_obs_deg_mag_pilot", "writable")
dataref("COM1_POWER", "sim/cockpit2/radios/actuators/com1_power", "writable")
dataref("ADF1_CARD", "sim/cockpit2/radios/actuators/adf1_card_heading_deg_mag_pilot", "writable")
dataref("BACKCOURSE_ON","sim/cockpit2/autopilot/backcourse_on")
dataref("APPROACH_STATUS","sim/cockpit2/autopilot/approach_status")

-- helper functions
function bit(p)
    return 2 ^ (p - 1)  -- 1-based indexing
end

function hasbit(x, p)
    return x % (p + p) >= p
end

function setbit(x, p)
    return hasbit(x, p) and x or x + p
end

function clearbit(x, p)
    return hasbit(x, p) and x - p or x
end

function OctToDec(value)
    base = 8
    local octal_string = tostring(value)
    local decimal = 0
    for char in octal_string:gmatch(".") do
        local n = tonumber(char, base)
        if not n then return 0 end
        decimal = decimal * base + n
    end
    return decimal
end

function DecToOct(value)
    base = 10
    local decimal_string = string.format("%o",value)
    local octal = 0
    for char in decimal_string:gmatch(".") do
        local n = tonumber(char, base)
        if not n then return 0 end
        octal = octal * base + n
    end
    return octal
end

-- setup constants metatable
local constants = {}
local constant_metatable = {
    __index = constants,
    __newindex = function(t, key, value)
        if rawget(t, key) ~= nil then
            error("Attempt to modify constant '" .. key .. "'")
        else
            rawset(t, key, value)
        end
    end
}
setmetatable(constants, constant_metatable)

-- button constants
constants.swap_button = 1
constants.inner_knob_button = 2
constants.ap_button = 7
constants.hdg_button = 8
constants.nav_button = 1
constants.apr_button = 2
constants.alt_button = 3
constants.vs_button = 4
constants.direct_button = 5
constants.menu_button = 6
constants.clr_button = 7
constants.ent_button = 8

-- frequency constants
constants.min_com_frequency = 118000
constants.max_com_frequency = 136000
constants.min_nav_frequency = 10800
constants.max_nav_frequency = 11700

-- heading constants
constants.min_heading = 0
constants.max_heading = 359

-- Global variables for the text display
local display_text = ""
local display_end_time = 0
local DISPLAY_DURATION = 5.0  -- How long to show the text in seconds

-- Function to draw the text box
function draw_bottom_left_text()
    if os.clock() < display_end_time then
        -- Draw the text box
        graphics.set_color(0, 0, 0, 0.7)  -- Semi-transparent black background
        graphics.draw_rectangle(10, 10, measure_string(display_text) + 30, 30)

        -- Draw the box border
        graphics.set_color(1, 1, 1, 1)  -- White border
        graphics.draw_line(10, 10, measure_string(display_text) + 30, 10)  -- Top
        graphics.draw_line(10, 30, measure_string(display_text) + 30, 30)  -- Bottom
        graphics.draw_line(10, 10, 10, 30)  -- Left
        graphics.draw_line(measure_string(display_text) + 30, 10, measure_string(display_text) + 30, 30)  -- Right

        -- Draw the text
        graphics.set_color(1, 1, 1, 1)  -- White text
        draw_string_Helvetica_12(17, 15, display_text)
    end
end

-- Register the drawing callback
do_every_draw("draw_bottom_left_text()")

-- Function to display text in bottom-left corner
function display_bottom_left_text(text)
    -- only update the text if something has changed
    if display_text ~= text and display_pop_up == 1 then
        display_text = text
        display_end_time = os.clock() + DISPLAY_DURATION
    end
end

-- find the Octavi IFR-1 device
local device_found = 0
for x in ipairs(ALL_HID_DEVICES) do
    if ALL_HID_DEVICES[x].vendor_id == 1240 and ALL_HID_DEVICES[x].product_id == 59094 then
        first_HID_device = hid_open_path(ALL_HID_DEVICES[x].path)
    end
end

if first_HID_device == nil then
    print("Octavi: device not found.")
else
    hid_set_nonblocking(first_HID_device, 1)
    device_found = 1
end

-- button states
local direct_button_pressed = false
local menu_button_pressed = false
local clr_button_pressed = false
local ent_button_pressed = false
local ap_button_pressed = false
local hdg_button_pressed = false
local nav_button_pressed = false
local apr_button_pressed = false
local alt_button_pressed = false
local vs_button_pressed = false
local swap_button_pressed = false

-- LED state
local ap_active = 0
local last_ap_active = 0

-- knob rotations
local outer_knob_rotation_notches = 0
local inner_knob_rotation_notches = 0

-- states
local mode_shift_state = false -- this gets toggled each time the small knob is pressed
local mode_shift_state_last = false -- used in LED control for shift confirmation flash
local last_mode = 0

-- -----------------------------------------------
-- main program functions

function main()
    if device_found ~= 0 then
        nov, a, b, c, d, e, f, g, h, i = hid_read(first_HID_device, 9)
        if (nov > 0) then
--            print(string.format("Octavi: nov:%s a:%s b:%s c:%s d:%s e:%s f:%s g:%s h:%s i:%s",
--                    tostring(nov), tostring(a), tostring(b), tostring(c), tostring(d),
--                    tostring(e), tostring(f), tostring(g), tostring(h), tostring(i)
--            ))
            process_shift_button(c)
            clear_bottom_and_right_buttons()
            process_right_buttons(b)
            process_bottom_buttons(c, d)
            process_knob_rotation(f, g)
            dispatch_mode(h)
        end
    end
end

-- register the main loop
do_every_draw("main()")

-- ----------------------------------------------------------------
-- Mode dispatching

function dispatch_mode(mode_number)
    if mode_number ~= last_mode and mode_shift_state then
        -- the mode has changed and the state is shifted
        -- clear the shift
        toggle_shift_state()
    end
    last_mode = mode_number
    if not mode_shift_state then
        if mode_number == 0 then
            com1_mode()
        elseif mode_number == 1 then
            com2_mode()
        elseif mode_number == 2 then
            nav1_mode()
        elseif mode_number == 3 then
            nav2_mode()
        elseif mode_number == 4 then
            fms1_mode()
        elseif mode_number == 5 then
            fms2_mode()
        elseif mode_number == 6 then
            ap_mode()
        elseif mode_number == 7 then
            xpdr_mode()
        end
    else
        if mode_number == 0 then
            hdg_mode()
        elseif mode_number == 1 then
            baro_mode()
        elseif mode_number == 2 then
            crs1_mode()
        elseif mode_number == 3 then
            crs2_mode()
        elseif mode_number == 4 then
            fms1_mode()
        elseif mode_number == 5 then
            fms2_mode()
        elseif mode_number == 6 then
            shifted_ap_mode()
        elseif mode_number == 7 then
            xpdr_mode_mode()
        end
    end

end

-- --------------------------------------------------------
-- aircraft identity
-- these are based on the default-included aircraft in X-Plane 12.
-- In places where the aircraft is neither of these, the script falls back to the
-- default behavior of sending commands to both types of equipment
--
-- This is the groundwork for being able to adapt to different flight management
-- systems according to what is installed in the aircraft. Eventually, the idea would be
-- to break these out into separate modules so as to keep this one generic to only simulator commands.

function aircraft_equipped_with_g1000()
    return (AIRCRAFT_FILENAME == "Cirrus SR22.acf" -- Cirrus SR-22
            or AIRCRAFT_FILENAME == "CirrusSF50.acf" -- Cirrus Vision SF50
            or AIRCRAFT_FILENAME == "Cessna_172SP_G1000.acf" -- Cessna Skyhawk with G1000
            or AIRCRAFT_FILENAME == "Cessna_CitationX.acf" -- not really... has "Xplanewell" devices.. FMS1 and 2 not operational... everything else seems to work... look into mapping FMS buttons to this
            or AIRCRAFT_FILENAME == "N844X.acf" -- Lancair Evolution... not fully functional at the moment... haven't figured out altitude and vertical speed
            or AIRCRAFT_FILENAME == "RV-10.acf" -- Van's RV-10
    )
end

function aircraft_equipped_with_g430_or_g530()
    -- todo: the button layout is different between g430 and g530... maybe factor out the control for them?
    return AIRCRAFT_FILENAME == "Cessna_172SP.acf" -- Cessna 172 SP
            or AIRCRAFT_FILENAME == "Cessna_172SP_seaplane.acf"
            or AIRCRAFT_FILENAME == "Baron_58.acf" -- Beechcraft Baron 58... only has x530 on FMS1.. FMS2 is non-existent
            or AIRCRAFT_FILENAME == "C90B.acf" -- Beechcraft KingAir C90B
            or AIRCRAFT_FILENAME == "PA-18-150.acf" -- Piper Cub... not really... has only com and nav radios
            or AIRCRAFT_FILENAME == "L5_Sentinel.acf" -- Stinson L5 Sentinel... not really... only has com1
end

function aircraft_equipped_with_collins_aps_65()
    return AIRCRAFT_FILENAME == "C90B.acf"
end

-- --------------------------------------------------------
-- shift button handling

function process_shift_button(c)
    if hasbit(c, bit(constants.inner_knob_button)) then
        toggle_shift_state()
    end
end

function toggle_shift_state()
    mode_shift_state = not mode_shift_state
    if mode_shift_state then
        print("Octavi: Shift state true.")
    else
        print("Octavi: Shift state false.")
    end
end

-- ----------------------------------------------
-- knob handling

function process_knob_rotation(outer_knob, inner_knob)
    outer_knob_rotation_notches = outer_knob
    if outer_knob_rotation_notches > 127 then
        outer_knob_rotation_notches = outer_knob_rotation_notches - 256
    end
    inner_knob_rotation_notches = inner_knob
    if inner_knob_rotation_notches > 127 then
        inner_knob_rotation_notches = inner_knob_rotation_notches - 256
    end
end

-- -----------------------------------------------
-- button press handling

function clear_bottom_and_right_buttons()
    direct_button_pressed = false
    menu_button_pressed = false
    clr_button_pressed = false
    ent_button_pressed = false
    ap_button_pressed = false
    hdg_button_pressed = false
    nav_button_pressed = false
    apr_button_pressed = false
    alt_button_pressed = false
    vs_button_pressed = false
    swap_button_pressed = false
end

function process_right_buttons(b)
    direct_button_pressed = hasbit(b, bit(constants.direct_button))
    menu_button_pressed = hasbit(b, bit(constants.menu_button))
    clr_button_pressed = hasbit(b, bit(constants.clr_button))
    ent_button_pressed = hasbit(b, bit(constants.ent_button))
end

function process_bottom_buttons(c, d)
    swap_button_pressed = hasbit(c, bit(constants.swap_button))
    ap_button_pressed = hasbit(c, bit(constants.ap_button))
    hdg_button_pressed = hasbit(c, bit(constants.hdg_button))
    nav_button_pressed = hasbit(d, bit(constants.nav_button))
    apr_button_pressed = hasbit(d, bit(constants.apr_button))
    alt_button_pressed = hasbit(d, bit(constants.alt_button))
    vs_button_pressed = hasbit(d, bit(constants.vs_button))
end

-- -----------------------------------------------------
-- value wrapping

function wrap_heading(heading)
    local range = constants.max_heading - constants.min_heading + 1
    heading = math.floor(heading)
    local modded = heading % range
    local wrapped = (modded + range) % range
    return wrapped
end

function wrap_com_frequency(frequency, step)
    step = math.abs(step)
    local range_start = constants.min_com_frequency -- e.g., 118000
    local range_end = constants.max_com_frequency   -- e.g., 136000
    local range_size = range_end - range_start + step
    local normalized = frequency - range_start
    local wrapped = ((normalized % range_size) + range_size) % range_size
    local wrapped_frequency = range_start + (math.floor(wrapped / step) * step)
    if wrapped_frequency > range_end then
        wrapped_frequency = range_start
    end
    return wrapped_frequency
end

function wrap_nav_frequency(frequency, step)
    step = math.abs(step)
    local tens_digit = 0
    if step == 100 then
        tens_digit = (frequency % 100) % step
        frequency = frequency - tens_digit
    end
    local range = constants.max_nav_frequency - constants.min_nav_frequency
    local step_count = range / step + 1
    local normalized = frequency - constants.min_nav_frequency
    local wrapped_steps = (((math.floor(normalized / step)) % step_count) + step_count) % step_count
    local wrapped_frequency = constants.min_nav_frequency + wrapped_steps * step
    if step == 100 then
        wrapped_frequency = wrapped_frequency + tens_digit
    end
    return wrapped_frequency
end

-- --------------------------------------------------------
-- frequency calculation

function adjust_frequency(frequency)
    local adjustment = inner_knob_rotation_notches * 25 -- inner knob adjustment
    adjustment = adjustment + (outer_knob_rotation_notches * 1000) -- outer knob adjustment
    if adjustment ~= 0 then
        frequency = math.floor(frequency + adjustment)
        frequency = wrap_com_frequency(frequency, adjustment)
        return frequency
    end
end

-- ---------------------------------------------
-- COM handling

function com1_mode()
    print("Octavi: COM1")
    display_bottom_left_text("COM1")
    if G430_NCS[0] == 1 then
        -- todo This probably needs a check to see if the aircraft is equipped with the g430
        command_once("sim/GPS/g430n1_nav_com_tog")
    end
    if swap_button_pressed then
        command_once("sim/radios/com1_standy_flip")
    end
    COM1[0] = adjust_frequency(COM1[0])
end

function com2_mode()
    print("Octavi: COM2")
    display_bottom_left_text("COM2")
    if G430_NCS[1] == 1 then
        -- todo This probably needs a check to see if the aircraft is equipped with the g430
        command_once("sim/GPS/g430n2_nav_com_tog")
    end
    if swap_button_pressed then
        command_once("sim/radios/com2_standy_flip")
    end
    COM2[0] = adjust_frequency(COM2[0])
end

-- ------------------------------------------------------
-- Heading handling (shifted COM1)

function hdg_mode()
    print("Octavi: HDG")
    display_bottom_left_text("HDG")
    local adjustment = inner_knob_rotation_notches * 1 -- inner knob adjustment
    adjustment = adjustment + (outer_knob_rotation_notches * 10) -- outer knob adjustment
    local heading = HDG1[0]
    heading = math.floor(heading + adjustment)
    heading = wrap_heading(heading)
    HDG1[0] = heading
end

-- -------------------------------------------------------
-- Barometer handling (shifted COM2)

function baro_mode()
    print("Octavi: BARO")
    display_bottom_left_text("BARO")
    if outer_knob_rotation_notches > 0 or inner_knob_rotation_notches > 0 then
        command_once("sim/instruments/barometer_up")
    elseif outer_knob_rotation_notches < 0 or inner_knob_rotation_notches < 0 then
        command_once("sim/instruments/barometer_down")
    end
end

-- --------------------------------------------------------
-- NAV handling

function nav1_mode()
    print("Octavi: NAV1")
    display_bottom_left_text("NAV1")
    if G430_NCS[0] == 0 then
        -- todo This probably needs a check to see if the aircraft is equipped with the g430
        command_once("sim/GPS/g430n1_nav_com_tog")
    end
    if swap_button_pressed then
        command_once("sim/radios/nav1_standy_flip")
    end
    local adjustment = inner_knob_rotation_notches * 10 -- inner knob adjustment
    adjustment = adjustment + (outer_knob_rotation_notches * 100) -- outer knob adjustment
    if adjustment ~= 0 then
        local frequency = NAV1[0]
        frequency = math.floor(frequency + adjustment)
        frequency = wrap_nav_frequency(frequency, adjustment)
        NAV1[0] = frequency
    end
end

function nav2_mode()
    print("Octavi: NAV2")
    display_bottom_left_text("NAV2")
    if G430_NCS[1] == 0 then
        -- todo This probably needs a check to see if the aircraft is equipped with the g430
        command_once("sim/GPS/g430n2_nav_com_tog")
    end
    if swap_button_pressed then
        command_once("sim/radios/nav2_standy_flip")
    end
    local adjustment = inner_knob_rotation_notches * 10 -- inner knob adjustment
    adjustment = adjustment + (outer_knob_rotation_notches * 100) -- outer knob adjustment
    if adjustment ~= 0 then
        local frequency = NAV2[0]
        frequency = math.floor(frequency + adjustment)
        frequency = wrap_nav_frequency(frequency, adjustment)
        NAV2[0] = frequency
    end
end

-- -------------------------------------------------------
-- CRS handling (shifted NAV1 and NAV2)

function calc_new_dir(dir, incr_coarse, incr_fine, step_coarse, step_fine)
    dir = dir + incr_coarse * step_coarse + incr_fine * step_fine
    if dir > 360 then
        dir = dir - 360
    elseif dir < 0 then
        dir = dir + 360
    end
    return dir
end

function crs1_mode()
    print("Octavi: CRS1")
    display_bottom_left_text("CRS1")
    NAV1_OBS = calc_new_dir(NAV1_OBS, outer_knob_rotation_notches, inner_knob_rotation_notches, 10, 1)
end

function crs2_mode()
    print("Octavi: CRS2")
    display_bottom_left_text("CRS2")
    NAV2_OBS = calc_new_dir(NAV2_OBS, outer_knob_rotation_notches, inner_knob_rotation_notches, 10, 1)
end

-- --------------------------------------------------------------------
-- FMS handling

function fms1_mode()
    print("Octavi: FMS1")
    display_bottom_left_text("FMS1")
    -- press and hold the swap button to determine if range will be adjusted
    print("Octavi standard behavior")
    if swap_button_pressed then
        print("Swap")
        display_bottom_left_text("RANGE")
        process_g1000n1_range_adjustment()
        return
    end
    if mode_shift_state then
        print("Octavi: Cursor")
        -- todo: test against these aircraft systems
        if aircraft_equipped_with_g430_or_g530() then
            command_once("sim/GPS/g430n1_cursor")
        elseif aircraft_equipped_with_g1000() then
            command_once("sim/GPS/g1000n1_cursor")
        else
            command_once("sim/GPS/g430n1_cursor")
            command_once("sim/GPS/g1000n1_cursor")
        end
        toggle_shift_state()
    end
    if aircraft_equipped_with_g1000() then
        process_g1000n1_actions()
    elseif aircraft_equipped_with_g430_or_g530() then
        process_g430n1_actions()
    else
        print("Fallback to g1000 behavior.")
        process_g1000n1_actions()
    end
end

function fms2_mode()
    print("Octavi: FMS2")
    display_bottom_left_text("FMS2")
    print("Octavi standard behavior")
    if swap_button_pressed then
        print("Octavi: Swap")
        display_bottom_left_text("RANGE")
        process_g1000n3_range_adjustment()
        return
    end
    if mode_shift_state then
        print("Octavi: Cursor")
        -- todo: test against these aircraft systems
        if aircraft_equipped_with_g430_or_g530() then
            command_once("sim/GPS/g430n2_cursor")
        elseif aircraft_equipped_with_g1000() then
            command_once("sim/GPS/g1000n3_cursor")
        else
            command_once("sim/GPS/g430n2_cursor")
            command_once("sim/GPS/g1000n3_cursor")
        end
        toggle_shift_state()
    end
    if aircraft_equipped_with_g1000() then
        process_g1000n3_actions()
    elseif aircraft_equipped_with_g430_or_g530() then
        process_g430n2_actions()
    else
        print("Fallback to g1000 behavior.")
        process_g1000n3_actions()
    end
end

function process_g1000n1_range_adjustment()
    if inner_knob_rotation_notches > 0 or outer_knob_rotation_notches > 0 then
        command_once("sim/GPS/g1000n1_range_down") -- possibly aircraft-specific
        return
    end
    if inner_knob_rotation_notches < 0 or outer_knob_rotation_notches < 0 then
        command_once("sim/GPS/g1000n1_range_up") -- possibly aircraft-specific
        return
    end
end

function process_g1000n3_range_adjustment()
    if inner_knob_rotation_notches > 0 or outer_knob_rotation_notches > 0 then
        command_once("sim/GPS/g1000n3_range_down") -- possibly aircraft-specific
        return
    end
    if inner_knob_rotation_notches < 0 or outer_knob_rotation_notches < 0 then
        command_once("sim/GPS/g1000n3_range_up") -- possibly aircraft-specific
        return
    end
end

-- ----------------------------------------------------------
-- AutoPilot handling

function ap_mode()
    print("Octavi: AP")
    display_bottom_left_text("AP")
    AP_ALT[0] = AP_ALT[0] + outer_knob_rotation_notches * 100
    AP_VS[0] = AP_VS[0] + inner_knob_rotation_notches * 100

    if ap_button_pressed then
        command_once("sim/autopilot/servos_toggle")
    end
    if hdg_button_pressed then
        command_once("sim/autopilot/heading")
    end
    if nav_button_pressed then
        command_once("sim/autopilot/NAV")
    end
    if apr_button_pressed then
        command_once("sim/autopilot/approach")
    end
    if alt_button_pressed then
        command_once("sim/autopilot/altitude_hold")
    end
    if vs_button_pressed then
        command_once("sim/autopilot/vertical_speed")
    end
    if swap_button_pressed then
        if aircraft_equipped_with_g1000() then
            display_bottom_left_text("FLC")
            command_once("sim/GPS/g1000n1_flc")
        end
    end
end

function shifted_ap_mode()
    print("Octavi: VNAV")
    if aircraft_equipped_with_g430_or_g530() then
        display_bottom_left_text("VNAV")
        command_once("sim/autopilot/vnav")
    end
    if aircraft_equipped_with_g1000() then
        display_bottom_left_text("VNAV")
        command_once("sim/autopilot/vnav")
    end
    toggle_shift_state()
end

-- ----------------------------------------------------
-- Transponder handling

function xpdr_mode()
    print("Octavi: XPDR")
    display_bottom_left_text("XPDR")
    XPDR[0] = calc_new_xpdr_code(XPDR[0], outer_knob_rotation_notches, inner_knob_rotation_notches)
end

function calc_new_xpdr_code(code, incr_coarse, incr_fine)
    code = OctToDec(code)
    code = code + incr_coarse * 64 + incr_fine
    if code < 0 then
        code = 4096 + code
    end
    if code > 4096 then
        code = code - 4096
    end
    code = DecToOct(code)
    return code
end

function xpdr_mode_mode()
    print("Octavi: XPDR MODE")
    display_bottom_left_text("XPDR MODE")
    if inner_knob_rotation_notches > 0 then
        command_once("sim/transponder/transponder_up")
    elseif inner_knob_rotation_notches < 0 then
        command_once("sim/transponder/transponder_dn")
    end
end

-- ----------------------------------------------------------------------
-- Aircraft-specific FMS system handling

-- G430 FMS primary controls
function process_g430n1_actions()
    if outer_knob_rotation_notches > 0 then
        command_once("sim/GPS/g430n1_chapter_up")
    elseif outer_knob_rotation_notches < 0 then
        command_once("sim/GPS/g430n1_chapter_dn")
    end
    if inner_knob_rotation_notches > 0 then
        command_once("sim/GPS/g430n1_page_up")
    elseif
    inner_knob_rotation_notches < 0 then
        command_once("sim/GPS/g430n1_page_dn")
    end
    if ap_button_pressed then
        command_once("sim/GPS/g430n1_cdi")
    end
    if hdg_button_pressed then
        command_once("sim/GPS/g430n1_obs")
    end
    if nav_button_pressed then
        command_once("sim/GPS/g430n1_msg")
    end
    if apr_button_pressed then
        command_once("sim/GPS/g430n1_fpl")
    end
    if alt_button_pressed then
        command_once("sim/GPS/g430n1_vnav")
    end
    if vs_button_pressed then
        command_once("sim/GPS/g430n1_proc")
    end
    if direct_button_pressed then
        command_once("sim/GPS/g430n1_direct")
    end
    if menu_button_pressed then
        command_once("sim/GPS/g430n1_menu")
    end
    if clr_button_pressed then
        command_once("sim/GPS/g430n1_clr")
    end
    if ent_button_pressed then
        command_once("sim/GPS/g430n1_ent")
    end
end

-- G430 FMS mfd controls
function process_g430n2_actions()
    if outer_knob_rotation_notches > 0 then
        command_once("sim/GPS/g430n2_chapter_up")
    elseif outer_knob_rotation_notches < 0 then
        command_once("sim/GPS/g430n2_chapter_dn")
    end
    if inner_knob_rotation_notches > 0 then
        command_once("sim/GPS/g430n2_page_up")
    elseif
    inner_knob_rotation_notches < 0 then
        command_once("sim/GPS/g430n2_page_dn")
    end
    if ap_button_pressed then
        command_once("sim/GPS/g430n2_cdi")
    end
    if hdg_button_pressed then
        command_once("sim/GPS/g430n2_obs")
    end
    if nav_button_pressed then
        command_once("sim/GPS/g430n2_msg")
    end
    if apr_button_pressed then
        command_once("sim/GPS/g430n2_fpl")
    end
    if alt_button_pressed then
        command_once("sim/GPS/g430n2_vnav")
    end
    if vs_button_pressed then
        command_once("sim/GPS/g430n2_proc")
    end
    if direct_button_pressed then
        command_once("sim/GPS/g430n2_direct")
    end
    if menu_button_pressed then
        command_once("sim/GPS/g430n2_menu")
    end
    if clr_button_pressed then
        command_once("sim/GPS/g430n2_clr")
    end
    if ent_button_pressed then
        command_once("sim/GPS/g430n2_ent")
    end
end

-- G1000 FMS primary controls
function process_g1000n1_actions()
    if outer_knob_rotation_notches > 0 then
        command_once("sim/GPS/g1000n1_fms_outer_up")
    elseif outer_knob_rotation_notches < 0 then
        command_once("sim/GPS/g1000n1_fms_outer_down")
    end
    if inner_knob_rotation_notches > 0 then
        command_once("sim/GPS/g1000n1_fms_inner_up")
    elseif
    inner_knob_rotation_notches < 0 then
        command_once("sim/GPS/g1000n1_fms_inner_down")
    end
    if ap_button_pressed then
        -- command_once("sim/GPS/g1000n1_cdi")
    end
    if hdg_button_pressed then
        -- command_once("sim/GPS/g1000n1_obs")
    end
    if nav_button_pressed then
        -- command_once("sim/GPS/g1000n1_msg")
    end
    if apr_button_pressed then
        command_once("sim/GPS/g1000n1_fpl")
    end
    if alt_button_pressed then
        -- command_once("sim/GPS/g1000n1_vnav")
    end
    if vs_button_pressed then
        command_once("sim/GPS/g1000n1_proc")
    end
    if direct_button_pressed then
        if mode_shift_state then
            -- custom enhancement... shift -D> is the NRST soft key on primary G1000 device.  This brings up the Nearest Airport dialogue
            display_bottom_left_text("NRST")
            command_once("sim/GPS/g1000n1_softkey11") -- nearest airport
            toggle_shift_state()
        else
            command_once("sim/GPS/g1000n1_direct") -- direct to...
        end
    end
    if menu_button_pressed then
        command_once("sim/GPS/g1000n1_menu")
    end
    if clr_button_pressed then
        command_once("sim/GPS/g1000n1_clr")
    end
    if ent_button_pressed then
        command_once("sim/GPS/g1000n1_ent")
    end
end

-- G1000 FMS mfd controls
function process_g1000n3_actions()
    if outer_knob_rotation_notches > 0 then
        command_once("sim/GPS/g1000n3_fms_outer_up")
    elseif outer_knob_rotation_notches < 0 then
        command_once("sim/GPS/g1000n3_fms_outer_down")
    end
    if inner_knob_rotation_notches > 0 then
        command_once("sim/GPS/g1000n3_fms_inner_up")
    elseif
    inner_knob_rotation_notches < 0 then
        command_once("sim/GPS/g1000n3_fms_inner_down")
    end
    if ap_button_pressed then
        -- command_once("sim/GPS/g1000n3_cdi")
    end
    if hdg_button_pressed then
        -- command_once("sim/GPS/g1000n3_obs")
    end
    if nav_button_pressed then
        -- command_once("sim/GPS/g1000n3_msg")
    end
    if apr_button_pressed then
        command_once("sim/GPS/g1000n3_fpl")
    end
    if alt_button_pressed then
        -- command_once("sim/GPS/g1000n2_vnav")
    end
    if vs_button_pressed then
        command_once("sim/GPS/g1000n3_proc")
    end
    if direct_button_pressed then
        command_once("sim/GPS/g1000n3_direct")
    end
    if menu_button_pressed then
        command_once("sim/GPS/g1000n3_menu")
    end
    if clr_button_pressed then
        command_once("sim/GPS/g1000n3_clr")
    end
    if ent_button_pressed then
        command_once("sim/GPS/g1000n3_ent")
    end
end

-- -----------------------------------------------
-- LED control
function change_leds()
    if (AP_MODE[0] == 2) then
        ap_active = 1
    else
        ap_active = 0
    end
    if hasbit(AP_STATE[0], bit(2)) then
        ap_active = ap_active + 2
    end -- HDG
    if ((aircraft_equipped_with_g1000() or aircraft_equipped_with_g430_or_g530()) and hasbit(AP_STATE[0], bit(10)))
            or (aircraft_equipped_with_collins_aps_65() and hasbit(AP_STATE[0], bit(9))) then
        ap_active = ap_active + 4
    end -- NAV
    if APPROACH_STATUS > 0 then
        ap_active = ap_active + 8
    end -- APR
    if hasbit(AP_STATE[0], bit(6)) or hasbit(AP_STATE[0], bit(15)) then
        ap_active = ap_active + 16
    end -- ALT
    if BACKCOURSE_ON > 0 then
        ap_active = ap_active + 32
    end -- BC

    -- Custom enhancement
    -- To add feedback to the user, quickly flash LEDs when the shift/second function is turned on
    if (mode_shift_state ~= mode_shift_state_last) then
        -- has the second function state changed?
        if (mode_shift_state) then
            -- is it now true?
            ap_active = 1 + 2 + 4 + 8 + 16 + 32 -- turn all of the LEDs on
        end
        mode_shift_state_last = mode_shift_state -- save state of second_fnc for the next check
    end

    if (last_ap_active ~= ap_active) then
        hid_write(first_HID_device, 11, ap_active)
        last_ap_active = ap_active
    end

end

function turn_off_leds()
    hid_write(first_HID_device, 11, 0)
end

do_every_frame("change_leds()")
do_on_exit("turn_off_leds()")