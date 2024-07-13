local M = {}

function M.create_debouncer()
  local timers = {}
  local results = {}
  local funcs = {} -- Store the original functions

  return function(func, delay)
    if type(func) ~= "function" then
      error("First argument to debounce must be a function")
    end

    local key = tostring(func)
    funcs[key] = func -- Store the function

    return function(...)
      local args = { ... }
      local callback = nil

      -- Check if the last argument is a callback function
      if #args > 0 and type(args[#args]) == "function" then
        callback = table.remove(args)
      end

      if timers[key] then
        vim.fn.timer_stop(timers[key])
      end

      timers[key] = vim.fn.timer_start(delay, function()
        if not funcs[key] then
          print("Error: Function not found for key: " .. key)
          return
        end

        local result
        local success, err = pcall(function()
          if #args > 0 then
            result = funcs[key](unpack(args))
          else
            result = funcs[key]()
          end
        end)

        if not success then
          print("Error executing function: " .. tostring(err))
          return
        end

        results[key] = result
        timers[key] = nil

        if callback then
          callback(result)
        end
      end)

      -- Return a function to get the result
      return function()
        return results[key]
      end
    end
  end
end

return M
