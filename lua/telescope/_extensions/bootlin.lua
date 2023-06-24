local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("Telescope interface requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local curl = require("plenary.curl")
local os_path_sep = require("plenary.path").path.sep
local entry_display = require("telescope.pickers.entry_display")

local function getEnv()
  local project = os.getenv("NVIM_BOOTLIN_REST_PROJECT")
  local err = false
  if project == nil then
    vim.notify("environment variable NVIM_BOOTLIN_REST_PROJECT is not set!", vim.log.levels.ERROR)
    err = true
  end
  local tag = os.getenv("NVIM_BOOTLIN_REST_TAG")
  if tag == nil then
    vim.notify("environment variable NVIM_BOOTLIN_REST_TAG is not set!", vim.log.levels.ERROR)
    err = true
  end
  local project_dir = os.getenv("NVIM_BOOTLIN_REST_PROJECT_DIR")
  if project_dir == nil then
    vim.notify("environment variable NVIM_BOOTLIN_REST_PROJECT_DIR is not set!", vim.log.levels.ERROR)
    err = true
  end
  local host = os.getenv("NVIM_BOOTLIN_HOST")
  if host == nil then
    vim.notify("environment variable NVIM_BOOTLIN_HOST is not set!", vim.log.levels.ERROR)
    err = true
  end

  if project_dir and string.sub(project_dir, #project_dir) ~= "/" then
    project_dir = project_dir .. "/"
  end

  return {
    ["project"] = project,
    ["tag"] = tag,
    ["project_dir"] = project_dir,
    ["host"] = host,
    ["err"] = err,
  }
end
local env = getEnv()

local host = env.host

local function getIdent(project, ident, version)
  version = version or "latest"
  local result = curl.get(host .. "/api/ident/" .. project .. "/" .. ident .. "?version=" .. version .. "&family=C")
  if result.status == 200 then
    return vim.json.decode(result.body)
  else
    -- vim.notify(result)
    vim.notify("failed to connect to bootlin host..", vim.log.levels.ERROR)
    vim.notify(vim.inspect.inspect(result), vim.log.levels.ERROR)
    return {}
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

  if references == nil then
    return result
  end
  for _, v in pairs(references) do
    local lines = split(v.line, ",")
    for _, l in pairs(lines) do
      table.insert(result, {
        path = v.path,
        line = l,
      })
    end
  end

  return result
end

local identDefTypeOrd = {
  ["function"] = 99,
  ["struct"] = 99,
  ["macro"] = 98,
  ["variable"] = 98,
  ["prototype"] = 97,
  ["member"] = 97,
}

local function getIdentDefsEntry(project, ident, version)
  -- get the info
  local ident_info = getIdent(project, ident, version)
  local definitions = ident_info.definitions
  local result = {}

  if definitions == nil then
    return result
  end
  for _, v in pairs(definitions) do
    local lines = split(v.line, ",")
    for _, l in pairs(lines) do
      table.insert(result, {
        path = v.path,
        line = l,
        type = v.type,
      })
    end
  end

  -- sort the result
  table.sort(result, function(a, b)
    local typeOrdOf = function(entry)
      if identDefTypeOrd[entry.type] ~= nil then
        return identDefTypeOrd[entry.type]
      else
        return 0
      end
    end

    if typeOrdOf(a) == typeOrdOf(b) then
      if a.path == b.path then
        return a.line < b.line
      else
        return a.path < b.path
      end
    else
      return typeOrdOf(a) > typeOrdOf(b)
    end
  end)

  return result
end

local function bootlin_attach_mappings(prompt_bufnr, map)
  actions.select_default:replace(function()
    actions.close(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    local file_path = env.project_dir .. entry.value.path
    local lnum = tonumber(entry.value.line) or 0
    vim.cmd("e " .. file_path)
    vim.cmd(":" .. lnum)
    return true
  end)
  return true
end

local bootline_previewer = previewers.new_termopen_previewer({
  title = "Ident Occurs Preview",
  dyn_title = function(_, entry)
    return entry.value.path .. " preview"
  end,

  get_command = function(entry, status)
    local win_id = status.preview_win
    local height = vim.api.nvim_win_get_height(win_id)

    local file_path = env.project_dir .. entry.value.path
    if file_path == nil or file_path == "" then
      return
    end
    if entry.bufnr and (file_path == "[No Name]" or vim.api.nvim_buf_get_option(entry.bufnr, "buftype") ~= "") then
      return
    end

    local lnum = tonumber(entry.value.line) or 0

    local context = math.floor((height - 4) / 2)
    local start = math.max(0, lnum - context)
    local finish = lnum + context

    return { "bat", "--line-range", start .. ":" .. finish, "--highlight-line", lnum, file_path }
    -- return maker(p, lnum, start, finish)
  end,
})

local identDefs = function(ident, opts, fallback_function)
  opts = opts or {}
  -- get information needed for environment variable
  if env.err then
    vim.notify("you need set the correct environment variable!", vim.log.levels.ERROR)
    return
  end
  local project = env.project
  local tag = env.tag

  local entries = getIdentDefsEntry(project, ident, tag)

  if #entries == 0 then
    if fallback_function then
      return fallback_function()
    else
      vim.notify("can't find definition of " .. ident, vim.log.levels.WARN)
      return false
    end
  end

  if opts.auto_jump == true then
    local jump_to_file = function(entry)
      local file_path = env.project_dir .. entry.path
      local lnum = tonumber(entry.line) or 0
      vim.cmd("e " .. file_path)
      vim.cmd(":" .. lnum)
    end

    if #entries == 1 then
      -- if only one definition is found, we dircetly jump to there
      local entry = entries[1]
      jump_to_file(entry)
      return
    elseif #entries < 5 then
      local sum_of_type = {}
      local target_entry = {}
      for _, v in pairs(entries) do
        if sum_of_type[v.type] == nil then
          sum_of_type[v.type] = 1
          target_entry[v.type] = v
        else
          sum_of_type[v.type] = sum_of_type[v.type] + 1
        end
      end

      if sum_of_type["function"] == 1 then
        jump_to_file(target_entry["function"])
        return
      end

      if sum_of_type["struct"] == 1 then
        jump_to_file(target_entry["struct"])
        return
      end
    end
  end

  local displayer = entry_display.create({
    separator = "",
    hl_chars = { [os_path_sep] = "TelescopePathSeparator" },
    items = (function()
      local i = {}
      table.insert(i, { width = 10 })
      if has_devicons then
        table.insert(i, { width = 2 })
      end
      table.insert(i, { remaining = true })
      return i
    end)(),
  })

  local make_dispalyer = function(e)
    return displayer((function()
      local i = {}
      table.insert(i, { e.value.type, "TelescopeResultsComment" })
      if has_devicons then
        table.insert(i, { devicons.get_icon(e.value.path, string.match(e.value.path, "%a+$"), { default = true }) })
      end
      table.insert(i, { e.value.path .. ":" .. e.value.line, "File" })

      return i
    end)())
  end

  pickers
    .new(opts, {
      prompt_title = ident .. "'s definitions",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_dispalyer,
            ordinal = entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = bootlin_attach_mappings,
      previewer = bootline_previewer,
    })
    :find()
end

local identRefs = function(ident, opts, fallback_function)
  opts = opts or {}
  -- get information needed for environment variable
  if env.err then
    vim.notify("you need set the correct environment variable!", vim.log.levels.ERROR)
    return
  end
  local project = env.project
  local tag = env.tag

  local entrise = getIdentRefsEntry(project, ident, tag)

  if #entrise == 0 then
    if fallback_function then
      return fallback_function()
    else
      vim.notify("can't find references of " .. ident, vim.log.levels.WARN)
      return false
    end
  end

  local displayer = entry_display.create({
    separator = "",
    hl_chars = { [os_path_sep] = "TelescopePathSeparator" },
    items = (function()
      local i = {}
      if has_devicons then
        table.insert(i, { width = 2 })
      end
      table.insert(i, { remaining = true })
      return i
    end)(),
  })

  local make_dispalyer = function(e)
    return displayer((function()
      local i = {}
      if has_devicons then
        table.insert(i, { devicons.get_icon(e.value.path, string.match(e.value.path, "%a+$"), { default = true }) })
      end
      table.insert(i, { e.value.path .. ":" .. e.value.line, "File" })

      return i
    end)())
  end

  pickers
    .new(opts, {
      prompt_title = ident .. "'s references",
      finder = finders.new_table({
        results = entrise,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_dispalyer,
            ordinal = entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = bootlin_attach_mappings,
      previewer = bootline_previewer,
    })
    :find()
end

-- identRefs("malloc", require("telescope.themes").get_dropdown({width = 0.3}))
-- identDefs("scm_send", require("telescope.themes").get_dropdown({ layout_config = { width = 0.80, height = 0.9 }, layout_strategy = "vertical", border = true, auto_jump = true }))

return telescope.register_extension({
  setup = function(_) end,
  exports = {
    bootlinElixirReferences = identRefs,
    bootlinElixirDefinitions = identDefs,
  },
})
