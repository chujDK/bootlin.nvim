local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("Telescope interface requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local curl = require("plenary.curl")

local host = os.getenv("NVIM_BOOTLIN_HOST")

local function getIdent(project, ident, version)
  version = version or "latest"
  local result = curl.get(host .. "/api/ident/" .. project .. "/" .. ident .. "?version=" .. version .. "&family=C")
  if result.status == 200 then
    return vim.json.decode(result.body)
  else
    return "failed to retrieve"
  end
end

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  local n = 0
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
    n = n + 1
  end
  return t, n
end

local function getIdentRefsEntry(project, ident, version)
  -- get the info
  local ident_info = getIdent(project, ident, version)
  local references = ident_info.references
  local result = {}

  for _, v in pairs(references) do
    local lines = split(v.line, ",")
    for _, l in pairs(lines) do
      table.insert(result, { v.path, l })
    end
  end

  return result
end

local function getIdentDefsEntry(project, ident, version)
  -- get the info
  local ident_info = getIdent(project, ident, version)
  local references = ident_info.definitions
  local result = {}

  for _, v in pairs(references) do
    local lines = split(v.line, ",")
    for _, l in pairs(lines) do
      table.insert(result, { v.path, l, v.type })
    end
  end

  return result
end

local identDefs = function(ident, opts)
  -- get information needed for environment variable
  local err = false
  local project = os.getenv("NVIM_BOOTLIN_REST_PROJECT")
  if project == nil then
    print("environment variable NVIM_BOOTLIN_REST_PROJECT is not set!")
    err = true
  end
  local tag = os.getenv("NVIM_BOOTLIN_REST_TAG")
  if tag == nil then
    print("environment variable NVIM_BOOTLIN_REST_TAG is not set!")
    err = true
  end
  local project_dir = os.getenv("NVIM_BOOTLIN_REST_PROJECT_DIR")
  if project_dir == nil then
    print("environment variable NVIM_BOOTLIN_REST_PROJECT_DIR is not set!")
    err = true
  end
  if os.getenv("NVIM_BOOTLIN_HOST") == nil then
    print("environment variable NVIM_BOOTLIN_HOST is not set!")
    err = true
  end
  -- FIXME: use a better way..
  project_dir = project_dir .. "/"
  if err then
    return
  end
  pickers
    .new(opts, {
      prompt_title = ident .. "'s references",
      finder = finders.new_table({
        results = getIdentDefsEntry(project, ident, tag),
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry[1] .. ":" .. entry[2] .. ":" .. entry[3],
            ordinal = entry[3] .. entry[1] .. entry[2],
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          local file_path = project_dir .. entry.value[1]
          local lnum = tonumber(entry.value[2]) or 0
          vim.cmd("e " .. file_path)
          vim.cmd(":" .. lnum)
          return true
        end)
        return true
      end,
      previewer = previewers.new_termopen_previewer({
        title = "Definitions Preview",
        dyn_title = function(_, entry)
          return entry.value[1] .. " preview"
        end,

        get_command = function(entry, status)
          local win_id = status.preview_win
          local height = vim.api.nvim_win_get_height(win_id)

          local file_path = project_dir .. entry.value[1]
          if file_path == nil or file_path == "" then
            return
          end
          if
            entry.bufnr and (file_path == "[No Name]" or vim.api.nvim_buf_get_option(entry.bufnr, "buftype") ~= "")
          then
            return
          end

          local lnum = tonumber(entry.value[2]) or 0

          local context = math.floor(height / 2)
          local start = math.max(0, lnum - context)
          local finish = lnum + context

          return { "bat", "--line-range", start .. ":" .. finish, "--highlight-line", lnum, file_path }
          -- return maker(p, lnum, start, finish)
        end,
      }),
    })
    :find()
end

local identRefs = function(ident, opts)
  -- get information needed for environment variable
  local err = false
  local project = os.getenv("NVIM_BOOTLIN_REST_PROJECT")
  if project == nil then
    print("environment variable NVIM_BOOTLIN_REST_PROJECT is not set!")
    err = true
  end
  local tag = os.getenv("NVIM_BOOTLIN_REST_TAG")
  if tag == nil then
    print("environment variable NVIM_BOOTLIN_REST_TAG is not set!")
    err = true
  end
  local project_dir = os.getenv("NVIM_BOOTLIN_REST_PROJECT_DIR")
  if project_dir == nil then
    print("environment variable NVIM_BOOTLIN_REST_PROJECT_DIR is not set!")
    err = true
  end
  if os.getenv("NVIM_BOOTLIN_HOST") == nil then
    print("environment variable NVIM_BOOTLIN_HOST is not set!")
    err = true
  end
  -- FIXME: use a better way..
  project_dir = project_dir .. "/"
  if err then
    return
  end
  pickers
    .new(opts, {
      prompt_title = ident .. "'s references",
      finder = finders.new_table({
        results = getIdentRefsEntry(project, ident, tag),
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry[1] .. ":" .. entry[2],
            ordinal = entry[1] .. entry[2],
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
        end)
        return true
      end,
      previewer = previewers.new_termopen_previewer({
        title = "References Preview",
        dyn_title = function(_, entry)
          return entry.value[1] .. " preview"
        end,

        get_command = function(entry, status)
          local win_id = status.preview_win
          local height = vim.api.nvim_win_get_height(win_id)

          local file_path = project_dir .. entry.value[1]
          if file_path == nil or file_path == "" then
            return
          end
          if
            entry.bufnr and (file_path == "[No Name]" or vim.api.nvim_buf_get_option(entry.bufnr, "buftype") ~= "")
          then
            return
          end

          local lnum = tonumber(entry.value[2]) or 0

          local context = math.floor(height / 2)
          local start = math.max(0, lnum - context)
          local finish = lnum + context

          return { "bat", "--line-range", start .. ":" .. finish, "--highlight-line", lnum, file_path }
          -- return maker(p, lnum, start, finish)
        end,
      }),
    })
    :find()
end

-- identRefs('malloc')
identDefs('malloc')

return telescope.register_extension({
  setup = function(_) end,
  exports = {
    bootlinElixirReferences = identRefs,
    bootlinElixirDefinitions = identDefs,
  },
})
