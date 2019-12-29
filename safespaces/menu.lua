local function run_entry(menu, cmd, val, path)
	local ent = table.find_key_i(menu, "name", cmd);
	if (not ent) then
		return false, string.format("status=missing:path=%s", inpath);
	end
	ent = menu[ent];

	table.insert(path, cmd);

-- check so that the entity is valid
	if (ent.eval and not ent.eval()) then
		local path = string.format(
			"%s: eval failed on entry %s", table.concat(path, "/"), cmd);
		return false, errmsg, path;
	end

-- submenu?
	if (ent.submenu) then
		local handler = ent.handler;
		if (type(handler) == "function") then
			handler = handler(ent);
		end
		return handler, "missing submenu", path;
	end

-- "stupid" action?
	if (ent.kind == "action") then
		if not ent.handler then
			return false, "missing handler in entry: " .. table.concat(path, "/"), path;
		else
			ent:handler();
		end
		return menu, "", path;
	end

-- value is left, got set?
	local validator = ent.validator and ent.validator or function() return true; end
	if (ent.set) then
		local set = ent.set;
		if (type(set) == "function") then
			set = set();
		end
		validator = function()
			return table.find_i(set, val);
		end
	end

	if (not validator(val)) then
		return false, "value failed validation", path;
	end

	ent:handler(val);
end

local function unpack_argument(val)
-- so for this to work 'really' we'd need a way of encoding / resolving
-- arguments (ok, treat as value, do symbol lookup for , , or , ) type
-- conv. on the rest from string, resolve self to : invocation
--
-- symbol lookup needs some specials in order to handle functions that
-- expect callback
end

function obj_to_menu(tbl)
	local res = {};
	for k,v in pairs(tbl) do
		if type(v) == "string" then
			table.insert(res, {
				name = k,
				label = k,
				kind = "value",
				validator = shared_valid_str,
				handler = function(ctx, val)
					tbl[k] = val;
				end
			});
		elseif type(v) == "number" then
			table.insert(res, {
				name = k,
				label = k,
				kind = "value",
				validator = function(val)
					return tostring(val) ~= nil;
				end,
				handler = function(ctx, val)
					tbl[k] = val;
				end
			});
		elseif type(v) == "table" then
			table.insert(res, {
				name = k,
				label = k,
				kind = "action",
				submenu = true,
				handler = function(ctx)
					return obj_to_menu(v);
				end,
			});
		elseif type(v) == "boolean" then
			table.insert(res, {
				name = k,
				label = k,
				kind = "value",
				set = {"true", "false", "toggle"},
				handler = function(ctx, val)
					if val == "true" then
						tbl[k] = true;
					elseif val == "false" then
						tbl[k] = false;
					else
						tbl[k] = not tbl[k];
					end
				end
			});
		elseif type(v) == "function" then
			table.insert(res, {
				name = k,
				label = k,
				kind = "value",
				handler = function(ctx, val)
					local okstate, tbl = pcall(function()
						v(tbl, unpack_argument(val));
					end);
				end
			});
		else
		end
	end
	return res;
end

function menu_run(menu, inpath)
	if (not inpath or string.len(inpath) == 0) then
		return;
	end

-- split path/to/value=arg and account for extra = in arg
	local tbl = string.split(inpath, "=");
	local cmdtbl = string.split(tbl[1], "/");
	local val = tbl[2] and tbl[2] or "";
	if (cmdtbl[1] == "") then
		table.remove(cmdtbl, 1);
	end

	local cmd = table.remove(cmdtbl, 1);
	local path = {};

	while (cmd) do
		menu, msg = run_entry(menu, cmd, val, path);
		if menu == false then
			return false, msg;
		end
		cmd = table.remove(cmdtbl, 1);
	end

	return true;
end

function menu_register(menu, path, entry)
	local menu;
	local elems = string.split(path, '/');

	if (#elems > 0 and elems[1] == "") then
		table.remove(elems, 1);
	end

	for k,v in ipairs(elems) do
		local found = false;
		for i,j in ipairs(level) do
			if (j.name == v and type(j.handler) == "table") then
				found = true;
				level = j.handler;
				break;
			end
		end
		if (not found) then
			warning(string.format("attach-%s (%s) failed on (%s)",root, path, v));
			return;
		end
	end
	table.insert(level, entry);
end

function menu_resolve(line, noresolve)
	local ns = string.sub(line, 1, 1);
	if (ns ~= "/") then
		warning("ignoring unknown path: " .. line);
		return nil, "invalid namespace";
	end

	local path = string.sub(line, 2);
	local sepind = string.find(line, "=");
	local val = nil;
	if (sepind) then
		path = string.sub(line, 2, sepind-1);
		val = string.sub(line, sepind+1);
	end

	local items = string.split(path, "/");
	local menu = WM.menu;

	if (path == "/" or path == "") then
		if (noresolve) then
			return {
				label = path,
				name = "root_menu",
				kind = "action",
				submenu = true,
				handler = function()
					return WM.menu();
				end
			};
		else
			return menu;
		end
	end

	local restbl = {};
	local last_menu = nil;

	while #items > 0 do
		local ent = nil;
		if (not menu) then
			return nil, "missing menu", table.concat(items, "/");
		end

-- first find in current menu
		for k,v in ipairs(menu) do
			if (v.name == items[1]) then
				ent = v;
				break;
			end
		end
-- validate the fields
		if (not ent) then
			return nil, "couldn't find entry", table.concat(items, "/");
		end
		if (ent.eval and not ent.eval()) then
			return nil, "entry not visible", table.concat(items, "/");
		end

-- action or value assignment
		if (not ent.submenu) then
			if (#items ~= 1) then
				return nil, "path overflow, action node reached", table.concat(items, "/");
			end
-- it's up to the caller to validate
			if ((ent.kind == "value" or ent.kind == "action") and ent.handler) then
				return ent, "", val;
			else
				return nil, "invalid formatted menu entry", items[1];
			end

-- submenu, just step, though this can be dynamic..
		else
			if (type(ent.handler) == "function") then
				menu = ent.handler();
				table.insert(restbl, ent.label);
			elseif (type(ent.handler) == "table") then
				menu = ent.handler;
				table.insert(restbl, ent.label);
			else
				menu = nil;
			end
			last_menu = ent;

-- special case, don't resolve and the next expanded entry would be a menu
			if (#items == 1 and noresolve) then
				menu = ent;
			end
			table.remove(items, 1);
		end
	end

	return menu, "", val, restbl;
end
