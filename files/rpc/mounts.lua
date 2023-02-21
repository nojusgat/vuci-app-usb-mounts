local utils = require "vuci.utils"
local lfs = require "lfs"

local M = {}

local function get_used_size(mountpoint, size)
    for file in lfs.dir(mountpoint) do
        local file_path = mountpoint .. "/" .. file
        if file:sub(1, 1) ~= "." then
            local attributes = lfs.attributes(file_path)
            if attributes.mode == "directory" then
                size = get_used_size(file_path, size)
            elseif attributes.mode == "file" and attributes.size ~= nil then
                size = size + attributes.size
            end
        end
    end
    return size
end

local function get_total_size(mountpoint)
    local device_name = string.match(mountpoint, "/([^/]+)$")

    local size = utils.readfile("/sys/class/block/" .. device_name .. "/size")
    if size == nil then
        return 0
    end

    return size * 512
end

local function get_mounts(mountpoint)
    local mounts = {}
    local code, stdout = utils.exec("mount"):wait()
    if code ~= 0 then
        return mounts
    end

    for device, mount, type in stdout:gmatch("(%S+) on (%S+) type (%S+)%C*%c") do
        if mount ~= nil and mount:find(mountpoint) then
            mounts[device] = { mount = mount, type = type }
        end
    end
    return mounts
end

local function get_mount_information(device, mountpoint)
    local mounts = get_mounts(mountpoint)
    return mounts[device]
end

local function create_directory(params, mount_information)
    if lfs.mkdir(mount_information.mount .. params.path .. params.name) then
        return { success = true }
    end
    return { success = false }
end

local function force_remove_directory(directory)
    for file in lfs.dir(directory) do
        local file_path = directory .. "/" .. file
        if file:sub(1, 1) ~= "." then
            if lfs.attributes(file_path, "mode") == "directory" then
                force_remove_directory(file_path)
            else
                os.remove(file_path)
            end
        end
    end
    lfs.rmdir(directory)
end

function M.devices()
    local devices = {}
    local mounts = get_mounts("/mnt/")
    for device, info in pairs(mounts) do
        local available_used, used_size = pcall(get_used_size, info.mount, 0)
        if available_used == false then
            used_size = 0
        end

        local available_total, total_size = pcall(get_total_size, info.mount)
        if available_total == false then
            total_size = 0
        end

        local information = {
            mountpoint = info.mount,
            device = device,
            filesystem = info.type,
            size = {
                used = used_size,
                total = total_size
            }
        }
        table.insert(devices, information)
    end
    return devices
end

-- params = { mountpoint: '/mnt/sda1' }
function M.unmount(params)
    local code = utils.exec("umount", params.mountpoint):wait()
    if code ~= 0 then
        return { success = false }
    end

    return { success = true }
end

-- params = { device: '/dev/sda1', path: '/' }
function M.files(params)
    local files = {}
    local mount_information = get_mount_information(params.device, "/mnt/")

    if mount_information == nil then
        return files
    end

    local path = mount_information.mount .. params.path
    for name in lfs.dir(path) do
        if name:sub(1, 1) ~= "." then
            local attributes = lfs.attributes(path .. "/" .. name)
            local file_path = params.path
            if attributes.mode == 'directory' then
                file_path = file_path .. name .. "/"
            end
            local file = {
                name = name,
                type = attributes.mode,
                path = file_path
            }
            table.insert(files, file)
        end
    end

    return files
end

-- params = { device: '/dev/sda1', path: '/', name: 'new_dir', type: 'directory' }
function M.create(params)
    local mount_information = get_mount_information(params.device, "/mnt/")

    if mount_information == nil then
        return { success = false }
    end

    if params.type == 'directory' then
        return create_directory(params, mount_information)
    end

    return { success = false }
end

-- params = { device: '/dev/sda1', path: '/', name: 'file_name' }
function M.delete(params)
    local mount_information = get_mount_information(params.device, "/mnt/")

    if mount_information == nil then
        return { success = false }
    end

    local file_path = mount_information.mount .. params.path .. params.name
    local attributes = lfs.attributes(file_path)
    if attributes.mode == 'directory' then
        if params.force ~= nil and params.force == true then
            if pcall(force_remove_directory, file_path) then
                return { success = true }
            end
        else
            local status, message = lfs.rmdir(file_path)
            if status == nil then
                return { success = false, message = message }
            end
            return { success = true }
        end
    else
        local status, message = os.remove(file_path)
        if status == nil then
            return { success = false, message = message }
        end
        return { success = true }
    end

    return { success = false }
end

return M
