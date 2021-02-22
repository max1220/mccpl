-- utillity functions for loggin
local log_utils = {}

function log_utils:new_logger(config)
	local ignore_cats = {}
	for i, cat in ipairs(config.disable or {}) do
		ignore_cats[cat] = true
	end

	-- the actual logging function
	local function log(cat, ...)
		if ignore_cats[cat] then
			return
		end
		local str = {}
		for i, cstr in ipairs({...}) do
			table.insert(str, tostring(cstr))
		end
		local log_str = ("[%30s] [%9s]: "):format(os.date(), cat:lower()) .. table.concat(str, " ")
		print(log_str)
	end

	-- wrapper for log + string.format
	local function logf(cat, fmt, ...)
		log(cat, fmt:format(...))
	end

	return log, logf
end

function log_utils:dump_table(tbl)

	local function t_scan(t)
		local t_str = {}
		for k,v in pairs(t) do
			if type(v) == "table" then
				table.insert(t_str, ("[%s] = %s"):format(tostring(k), t_scan(v)))
			elseif type(v) == "number" then
				table.insert(t_str, ("[%s] = %s"):format(tostring(k), tostring(v)))
			else
				table.insert(t_str, ("[%s] = %q"):format(tostring(k), tostring(v)))
			end
		end
		table.sort(t_str)
		return "{" .. table.concat(t_str, ", ") .. "}"
	end

	return t_scan(tbl)

end


return log_utils
