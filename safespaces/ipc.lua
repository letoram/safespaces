
-- needed to track available connections
local clients = {};
local control_socket;

-- debug monitoring is loud and costly and requires multiple hooks
-- there's a number of subsystems we need to hook in order to get a
-- reasonable debug/monitor view:
--
local debug_count = 0;
local all_categories = {
	"WARNING",
	"SYSTEM",
	"STDOUT",
	"HMD",
	"WM",
	"CLIENT",
	"TIMERS"
};

local print_override = suppl_add_logfn("stdout");
local warning_override = suppl_add_logfn("warning");

local old_print = print;
print = function(...)
	local tbl = {...};
	local fmtstr = string.rep("%s\t", #tbl);
	local msg = string.format(fmtstr, ...);
	print_override(msg);
	old_print(msg);
end

warning = function(...)
	local tbl = {...};
	local fmtstr = string.rep("%s\t", #tbl);
	local msg = string.format(fmtstr, ...);
	warning_override(msg);
end

local monitor_state = false;
local function toggle_monitoring(on)
	if (on and monitor_state or off and not monitor_state) then
		return;
	end

	local domains = {
		system = "SYSTEM:",
		config = "CONFIG:",
		stdout = "STDOUT:",
		timers = "TIMERS:",
		hmd = "HMD:",
		wm = "WM:",
		client = "CLIENT:",
		warning = "WARNING:",
	};

-- see suppl_add_logfn for the function that constructs the logger,
-- each subsystem references that to get the message log function that
-- will queue or forward to a set listener (that we define here)
	for k,v in pairs(domains) do
		local regfn = _G[k .. "_debug_listener"];
		if (regfn) then
			regfn( on and
				function(msg)
					for _, cl in ipairs(clients) do
						if (cl.category_map and cl.category_map[string.upper(k)]) then
							table.insert(cl.buffer, v .. msg);
						end
					end
				end or nil
			);
		end
	end

	monitor_state = on;
end

local function update_control(key, val)
-- close automatically unlinks
	if (control_socket) then
		control_socket:close();
		control_socket = nil;
	end

	for k,v in ipairs(clients) do
		v.connection:close();
	end
	clients = {};

	if (val == ":disabled") then
		return;
	end

	zap_resource("ipc/" .. val);
	control_socket = open_nonblock("=ipc/" .. val);
end

gconfig_listen("control_path", "ipc", update_control);
update_control("", gconfig_get("control_path"));

local function list_path(res, noappend)
	local list = {};
	for k,v in ipairs(res) do
		if (v.name and v.label) then
			local ent;
			if (v.submenu) then
				ent = v.name .. (noappend and "" or "/");
			else
				ent = v.name;
			end

			if (not v.block_external and (not v.eval or v:eval())) then
				table.insert(list, ent);
			end
		end
	end
	table.sort(list);
	return list;
end

local function ent_to_table(res, ret)
	table.insert(ret, "name: " .. res.name);
	table.insert(ret, "label: " .. res.label);

	if (res.description and type(res.description) == "string") then
		table.insert(ret, "description: " .. res.description);
	end

	if (res.alias) then
		local ap = type(res.alias) == "function" and res.alias() or res.alias;
		table.insert(ret, "alias: " .. ap);
		return;
	end

	if (res.kind == "action") then
		table.insert(ret, res.submenu and "kind: directory" or "kind: action");
	else
		table.insert(ret, "kind: value");
		if (res.initial) then
			local val = tostring(type(res.initial) ==
				"function" and res.initial() or res.initial);
			table.insert(ret, "initial: " .. val);
		end
		if (res.set) then
			local lst = res.set;
			if (type(lst) == "function") then
				lst = lst();
			end
			table.sort(lst);
			table.insert(ret, "value-set: " .. table.concat(lst, " "));
		end
		if (res.hint) then
			local hint = res.hint;
			if (type(res.hint) == "function") then
				hint = res:hint();
			end
			table.insert(ret, "hint: " .. hint);
		end
	end
end

local commands;
commands = {
-- enumerate the contents of a path
	ls = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		local tbl = list_path(res);
		table.insert(tbl, "OK");
		return tbl;
	end,

-- list and read all the entries in one directory
	readdir = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (type(res[1]) ~= "table") then
			return {"EINVAL, readdir argument is not a directory"};
		end

		local ret = {};
		for _,v in ipairs(res) do
			if (type(v) == "table") then
				ent_to_table(v, ret);
			end
		end
		table.insert(ret, "OK");
		return ret;
	end,

-- present more detailed information about a single target
	read = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		local tbl = {};
		if (type(res[1]) == "table") then
			table.insert(tbl, "kind: directory");
			table.insert(tbl, "size: " .. tostring(#res));
		else
			ent_to_table(res, tbl);
		end
		table.insert(tbl, "OK");

		return tbl;
	end,

-- run a value assignment, first through the validator and then act
	write = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (res.kind == "value") then
			if (not res.validator or res.validator(remainder)) then
				res:handler(remainder);
				return {"OK"};
			else
				return {"EINVAL, value rejected by validator"};
			end
		else
			return {"EINVAL, couldn't dispatch"};
		end
	end,

-- only evaluate a value assignment
	eval = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (not res.handler) then
			return {"EINVAL, broken menu entry"};
		end

		if (res.validator) then
			if (not res.validator(remainder)) then
				return {"EINVAL, validation failed"};
			end
		end

		return {"OK"};
	end,

-- enable periodic output of event categories, see list at the top
	monitor = function(client, line)
		line = line and line or "";

		local categories = string.split(line, " ");
		for i=#categories,1,-1 do
-- remove missing categories and empty entries
			categories[i] = string.trim(string.upper(categories[i]));
			if (#categories[i] == 0) then
				table.remove(categories, i);
			end
			if (not table.find_i(all_categories, categories[i])
				and categories[i] ~= "ALL" and categories[i] ~= "NONE") then
				table.remove(categories, i);
			end
		end
		if (#categories == 0) then
			return {"EINVAL: missing categories: NONE, ALL or space separated list from " ..
				table.concat(all_categories, " ") .. "\n"};
		end

		client.category_map = {};
		if (string.upper(categories[1]) == "ALL") then
			categories = all_categories;

		elseif (string.upper(categories[1]) == "NONE") then
			clients.category_map = nil;
			if (client.in_monitor) then
				client.in_monitor = false;
				debug_count = debug_count - 1;
			end
			return {"OK"};
		end

		client.in_monitor = true;
		debug_count = debug_count + 1;

		for i,v in ipairs(categories) do
			client.category_map[string.upper(v)] = true;
		end

		toggle_monitoring(debug_count > 0);
		return {"OK"};
	end,

-- execute no matter what
	exec = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (dispatch_symbol(line, res, true)) then
			return {"OK"};
		else
			return {"EINVAL: target path is not an executable action."};
		end
	end
};

local function remove_client(ind)
	local cl = clients[ind];
	if (cl.categories and #cl.categories > 0) then
		debug_count = debug_count - 1;
	end
	cl.connection:close();
	table.remove(clients, ind);
end

local do_line;
local function client_flush(cl, ind)
	while true do
		local line, ok = cl.connection:read();
		if (not ok) then
			remove_client(ind);
			return;
		end
		if (not line) then
			break;
		end
		if (string.len(line) > 0) then
			if (monitor_state) then
				for _,v in ipairs(clients) do
					if (v.category_map and v.category_map["IPC"]) then
						table.insert(v.buffer, string.format(
							"IPC:client=%d:command=%s\n", v.seqn, line));
					end
				end
			end
			do_line(line, cl, ind);
		end
	end

	while #cl.buffer > 0 do
		local line = cl.buffer[1];
		local i, ok = cl.connection:write(line);
		if (not ok) then
			remove_client(ind);
			return;
		end
		if (i == string.len(line)) then
			table.remove(cl.buffer, 1);
		elseif (i == 0) then
			break;
		else
			cl.buffer[1] = string.sub(line, i+1);
		end
	end
end

-- splint into "cmd argument", resolve argument as a menu path and forward
-- to the relevant entry in commands, special / ugly handling for monitor
-- which takes both forms.
do_line = function(line, cl, ind)
	local ind = string.find(line, " ");

	if (string.sub(line, 1, 7) == "monitor") then
		for _,v in ipairs(commands.monitor(cl, string.sub(line, 9))) do
			table.insert(cl.buffer, v .. "\n");
		end
		return;
	end

	if (not ind) then
		return;
	end
	cmd = string.sub(line, 1, ind-1);
	line = string.sub(line, ind+1);

	if (not commands[cmd]) then
		table.insert(cl.buffer,
			string.format("EINVAL: bad command(%s)\n", cmd));
		return;
	end

-- This will actually resolve twice, since exec/write should trigger the
-- command, but this will go through dispatch in order for queueing etc.
-- to work. Errors on queued commands will not be forwarded to the caller.
	local res, msg, remainder = menu_resolve(line);

	if (not res or type(res) ~= "table") then
		table.insert(cl.buffer, string.format("EINVAL: %s\n", msg));
	else
		for _,v in ipairs(commands[cmd](cl, line, res, remainder)) do
			table.insert(cl.buffer, v .. "\n");
		end
	end
end

-- Alas, arcan doesn't expose a decent asynch callback mechanism tied to
-- the socket (which should also be rate-limited and everything else like
-- that needed so we don't stall) so we have to make do with the normal
-- buffering for now, when it is added there we should only need to add
-- a function argument to the open_nonblock and to the write call
-- (table + callback, release when finished)
local seqn = 1;
local function poll_control_channel()
	local nc = control_socket:accept();

	if (nc) then
		local client = {
			connection = nc,
			buffer = {},
			seqn = seqn
		};
		seqn = seqn + 1;
		table.insert(clients, client);
	end

	for i=#clients,1,-1 do
		client_flush(clients[i], i);
	end
end

-- open question is if we should check lock-state here and if we're in locked
-- input, also disable polling status / control
timer_add_periodic("control", 1, false,
function()
	if (control_socket) then
		poll_control_channel();
	end
end, true
);

-- chain here rather than add some other hook mechanism, then the entire feature
-- can be removed by dropping the system_load() call.
local dshut = durden_shutdown;
durden_shutdown = function()
	dshut();

	if (gconfig_get("control_path") ~= ":disabled") then
		zap_resource("ipc/" .. gconfig_get("control_path"));
	end
end
