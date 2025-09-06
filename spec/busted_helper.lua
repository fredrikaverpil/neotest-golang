-- Busted helper file that sets up vim globals for running tests outside neovim

-- Mock vim globals needed by neotest-golang
_G.vim = {
  log = {
    levels = {
      TRACE = 0,
      DEBUG = 1,
      INFO = 2,
      WARN = 3,
      ERROR = 4,
      OFF = 5,
    }
  },
  fn = {
    fnamemodify = function(path, modifier)
      if modifier == ":h" then
        return path:match("(.+)/[^/]*$") or "."
      elseif modifier == ":t" then
        return path:match("/([^/]*)$") or path
      elseif modifier == ":p" then
        -- Return absolute path (simplified)
        if path:sub(1,1) == "/" then
          return path
        else
          return "/Users/fredrik/code/public/neotest-golang/" .. path
        end
      end
      return path
    end,
    executable = function() return 1 end,
    expand = function(path) 
      if path == "%" then
        return "/Users/fredrik/code/public/neotest-golang/dummy.go"
      end
      return path 
    end,
    system = function(cmd) 
      -- Mock system calls for testing
      if type(cmd) == "string" and cmd:find("go list") then
        return '{"ImportPath":"github.com/fredrikaverpil/neotest-golang/internal/envtest","Dir":"/Users/fredrik/code/public/neotest-golang/tests/go/internal/envtest","GoFiles":["envtest.go"],"TestGoFiles":["envtest_test.go"]}'
      end
      return ""
    end,
  },
  fs = {
    normalize = function(path) return path end,
    dirname = function(path) 
      return path:match("(.+)/[^/]*$") or "."
    end,
  },
  tbl_deep_extend = function(behavior, ...)
    local result = {}
    for _, tbl in ipairs({...}) do
      if type(tbl) == "table" then
        for k, v in pairs(tbl) do
          if type(v) == "table" and type(result[k]) == "table" and behavior == "force" then
            result[k] = vim.tbl_deep_extend(behavior, result[k], v)
          else
            result[k] = v
          end
        end
      end
    end
    return result
  end,
  tbl_extend = function(behavior, ...)
    local result = {}
    for _, tbl in ipairs({...}) do
      if type(tbl) == "table" then
        for k, v in pairs(tbl) do
          result[k] = v
        end
      end
    end
    return result
  end,
  deepcopy = function(orig)
    local copy
    if type(orig) == 'table' then
      copy = {}
      for k, v in pairs(orig) do
        copy[vim.deepcopy(k)] = vim.deepcopy(v)
      end
    else
      copy = orig
    end
    return copy
  end,
  list_extend = function(dst, src)
    for _, v in ipairs(src) do
      table.insert(dst, v)
    end
    return dst
  end,
  split = function(s, sep)
    local result = {}
    local pattern = "([^" .. sep .. "]+)"
    s:gsub(pattern, function(c) result[#result + 1] = c end)
    return result
  end,
  startswith = function(str, prefix)
    return str:sub(1, #prefix) == prefix
  end,
  endswith = function(str, suffix)
    return str:sub(-#suffix) == suffix
  end,
  trim = function(s)
    return s:match("^%s*(.-)%s*$")
  end,
}

-- Mock plenary.async for tests that need it
_G.a = {
  sync = function(fn) 
    return function(...) 
      return fn(...)
    end 
  end,
  wrap = function(fn, argc)
    return function(...)
      local args = {...}
      local callback = args[argc]
      local result = fn(unpack(args, 1, argc - 1))
      if callback then callback(nil, result) end
      return result
    end
  end,
}

-- Simple print function for debug
_G.print = print