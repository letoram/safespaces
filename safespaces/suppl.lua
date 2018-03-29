-- Copyright: None claimed, Public Domain
--
-- Description: Cookbook- style functions for the normal tedium
-- (string and table manipulation, mostly plucked from the Durden
--

function string.split(instr, delim)
	if (not instr) then
		return {};
	end

	local res = {};
	local strt = 1;
	local delim_pos, delim_stp = string.find(instr, delim, strt);

	while delim_pos do
		table.insert(res, string.sub(instr, strt, delim_pos-1));
		strt = delim_stp + 1;
		delim_pos, delim_stp = string.find(instr, delim, strt);
	end

	table.insert(res, string.sub(instr, strt));
	return res;
end

function string.utf8back(src, ofs)
	if (ofs > 1 and string.len(src)+1 >= ofs) then
		ofs = ofs - 1;
		while (ofs > 1 and utf8kind(string.byte(src,ofs) ) == 2) do
			ofs = ofs - 1;
		end
	end

	return ofs;
end

function math.sign(val)
	return (val < 0 and -1) or 1;
end

function math.clamp(val, low, high)
	if (low and val < low) then
		return low;
	end
	if (high and val > high) then
		return high;
	end
	return val;
end

function string.utf8forward(src, ofs)
	if (ofs <= string.len(src)) then
		repeat
			ofs = ofs + 1;
		until (ofs > string.len(src) or
			utf8kind( string.byte(src, ofs) ) < 2);
	end

	return ofs;
end

function string.utf8lalign(src, ofs)
	while (ofs > 1 and utf8kind(string.byte(src, ofs)) == 2) do
		ofs = ofs - 1;
	end
	return ofs;
end

function string.utf8ralign(src, ofs)
	while (ofs <= string.len(src) and string.byte(src, ofs)
		and utf8kind(string.byte(src, ofs)) == 2) do
		ofs = ofs + 1;
	end
	return ofs;
end

function string.translateofs(src, ofs, beg)
	local i = beg;
	local eos = string.len(src);

	-- scan for corresponding UTF-8 position
	while ofs > 1 and i <= eos do
		local kind = utf8kind( string.byte(src, i) );
		if (kind < 2) then
			ofs = ofs - 1;
		end

		i = i + 1;
	end

	return i;
end

function string.utf8len(src, ofs)
	local i = 0;
	local rawlen = string.len(src);
	ofs = ofs < 1 and 1 or ofs;

	while (ofs <= rawlen) do
		local kind = utf8kind( string.byte(src, ofs) );
		if (kind < 2) then
			i = i + 1;
		end

		ofs = ofs + 1;
	end

	return i;
end

function string.insert(src, msg, ofs, limit)
	if (limit == nil) then
		limit = string.len(msg) + ofs;
	end

	if ofs + string.len(msg) > limit then
		msg = string.sub(msg, 1, limit - ofs);

-- align to the last possible UTF8 char..

		while (string.len(msg) > 0 and
			utf8kind( string.byte(msg, string.len(msg))) == 2) do
			msg = string.sub(msg, 1, string.len(msg) - 1);
		end
	end

	return string.sub(src, 1, ofs - 1) .. msg ..
		string.sub(src, ofs, string.len(src)), string.len(msg);
end

function string.delete_at(src, ofs)
	local fwd = string.utf8forward(src, ofs);
	if (fwd ~= ofs) then
		return string.sub(src, 1, ofs - 1) .. string.sub(src, fwd, string.len(src));
	end

	return src;
end

function string.trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"));
end

local function display_data(id)
	local data, hash = video_displaydescr(id);
	local model = "unknown";
	local serial = "unknown";
	if (not data) then
		return;
	end

-- data should typically be EDID, if it is 128 bytes long we assume it is
	if (string.len(data) == 128 or string.len(data) == 256) then
		for i,ofs in ipairs({54, 72, 90, 108}) do

			if (string.byte(data, ofs+1) == 0x00 and
			string.byte(data, ofs+2) == 0x00 and
			string.byte(data, ofs+3) == 0x00) then
				if (string.byte(data, ofs+4) == 0xff) then
					serial = string.sub(data, ofs+5, ofs+5+12);
				elseif (string.byte(data, ofs+4) == 0xfc) then
					model = string.sub(data, ofs+5, ofs+5+12);
				end
			end

		end
	end

	local strip = function(s)
		local outs = {};
		local len = string.len(s);
		for i=1,len do
			local ch = string.sub(s, i, i);
			if string.match(ch, '[a-zA-Z0-9]') then
				table.insert(outs, ch);
			end
		end
		return table.concat(outs, "");
	end

	return strip(model), strip(serial);
end


function suppl_display_name(id)
-- first mapping nonsense has previously made it easier (?!)
-- getting a valid EDID in some cases
	local name = id == 0 and "default" or "unkn_" .. tostring(id);
	map_video_display(WORLDID, id, HINT_NONE);
	local model, serial = display_data(id);
	if (model) then
		name = string.split(model, '\r')[1] .. "/" .. serial;
	end
	return name;
end


-- to ensure "special" names e.g. connection paths for target alloc,
-- or for connection pipes where we want to make sure the user can input
-- no matter keylayout etc.
strict_fname_valid = function(val)
	for i in string.gmatch(val, "%W") do
		if (i ~= '_') then
			return false;
		end
	end
	return true;
end

function string.utf8back(src, ofs)
	if (ofs > 1 and string.len(src)+1 >= ofs) then
		ofs = ofs - 1;
		while (ofs > 1 and utf8kind(string.byte(src,ofs) ) == 2) do
			ofs = ofs - 1;
		end
	end

	return ofs;
end

function table.remove_match(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in ipairs(tbl) do
		if (v == match) then
			table.remove(tbl, k);
			return v;
		end
	end

	return nil;
end

function string.dump(msg)
	local bt ={};
	for i=1,string.len(msg) do
		local ch = string.byte(msg, i);
		bt[i] = ch;
	end
	print(table.concat(bt, ','));
end

function table.remove_vmatch(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in pairs(tbl) do
		if (v == match) then
			tbl[k] = nil;
			return v;
		end
	end

	return nil;
end

function table.find_i(table, r)
	for k,v in ipairs(table) do
		if (v == r) then return k; end
	end
end

function table.find_key_i(table, field, r)
	for k,v in ipairs(table) do
		if (v[field] == r) then
			return k;
		end
	end
end

function table.insert_unique_i(tbl, i, v)
	local ind = table.find_i(tbl, v);
	if (not ind) then
		table.insert(tbl, i, v);
	else
		local cpy = tbl[i];
		tbl[i] = tbl[ind];
		tbl[ind] = cpy;
	end
end

function table.i_subsel(table, label, field)
	local res = {};
	local ll = label and string.lower(label) or "";
	local i = 1;

	for k,v in ipairs(table) do
		local match = field and v[field] or v;
		if (type(match) ~= "string") then
			warning(string.format("invalid entry(%s,%s) in table subselect",
				v.name and v.name or "[no name]", field));
			break;
		end
		match = string.lower(match);
		if (string.len(ll) == 0 or string.sub(match, 1, string.len(ll)) == ll) then
			res[i] = v;
			i = i + 1;
		end
	end

	return res;
end

local function hb(ch)
	local th = {"0", "1", "2", "3", "4", "5",
		"6", "7", "8", "9", "a", "b", "c", "d", "e", "f"};

	local fd = math.floor(ch/16);
	local sd = ch - fd * 16;
	return th[fd+1] .. th[sd+1];
end

function suppl_strcol_fmt(str, sel)
	local hv = util.hash(str);
	return HC_PALETTE[(hv % #HC_PALETTE) + 1];
end

function hexenc(instr)
	return string.gsub(instr, "(.)", function(ch)
		return hb(ch:byte(1));
	end);
end

-- all the boiler plate needed to figure out the types a uniform has,
-- generate the corresponding menu entry and with validators for type
-- and range, taking locale and separators into accoutn.
local bdelim = (tonumber("1,01") == nil) and "." or ",";
local rdelim = (bdelim == ".") and "," or ".";

function suppl_unpack_typestr(typestr, val, lowv, highv)
	string.gsub(val, rdelim, bdelim);
	local rtbl = string.split(val, ' ');
	for i=1,#rtbl do
		rtbl[i] = tonumber(rtbl[i]);
		if (not rtbl[i]) then
			return;
		end
		if (lowv and rtbl[i] < lowv) then
			return;
		end
		if (highv and rtbl[i] > highv) then
			return;
		end
	end
	return rtbl;
end

function suppl_valid_typestr(utype, lowv, highv, defaultv)
	return function(val)
		local tbl = suppl_unpack_typestr(utype, val, lowv, highv);
		return tbl ~= nil and #tbl == string.len(utype);
	end
end

-- reformated PD snippet
function utf8valid(str)
  local i, len = 1, #str
	local find = string.find;
  while i <= len do
		if (i == find(str, "[%z\1-\127]", i)) then
			i = i + 1;
		elseif (i == find(str, "[\194-\223][\123-\191]", i)) then
			i = i + 2;
		elseif (i == find(str, "\224[\160-\191][\128-\191]", i)
			or (i == find(str, "[\225-\236][\128-\191][\128-\191]", i))
 			or (i == find(str, "\237[\128-\159][\128-\191]", i))
			or (i == find(str, "[\238-\239][\128-\191][\128-\191]", i))) then
			i = i + 3;
		elseif (i == find(str, "\240[\144-\191][\128-\191][\128-\191]", i)
			or (i == find(str, "[\241-\243][\128-\191][\128-\191][\128-\191]", i))
			or (i == find(str, "\244[\128-\143][\128-\191][\128-\191]", i))) then
			i = i + 4;
    else
      return false, i;
    end
  end

  return true;
end

function shared_valid01_float(inv)
	if (string.len(inv) == 0) then
		return true;
	end

	local val = tonumber(inv);
	return val and (val >= 0.0 and val <= 1.0) or false;
end

function gen_valid_num(lb, ub)
	return function(val)
		if (not val) then
			warning("validator activated with missing val");
			return false;
		end

		if (string.len(val) == 0) then
			return true;
		end
		local num = tonumber(val);
		if (num == nil) then
			return false;
		end
		return not(num < lb or num > ub);
	end
end

function gen_valid_float(lb, ub)
	return gen_valid_num(lb, ub);
end

-- use this as a way to handle relative modification without
-- being forced to provide an additional menupath for it
function suppl_apply_num(valstr, curval)
	local ch = string.sub(valstr, 1, 1);
	if (ch == "." or ch == "+") then
		return curval + tonumber(string.sub(valstr, 2));
	else
		return tonumber(valstr);
	end
end

function suppl_run_menu(menu, path, errorf, verbose)
	if (not path or string.len(path) == 0) then
		return;
	end

-- split path/to/value=arg and account for extra = in arg
	local tbl = string.split(path, "=");
	local cmdtbl = string.split(table.remove(tbl, 1), "/");
	local val = tbl[1] and tbl[1] or "";

	local cmd = table.remove(cmdtbl, 1);
	local path = {};
	while (cmd) do
		local ent = table.find_key_i(menu, "name", cmd);
		if (not ent) then
			if (type(errorf) == "function") then
				errorf(string.format("%s: missing '%s'", table.concat(path, "/"), cmd));
			end
			return;
		end
		ent = menu[ent];

-- check so that the entity is valid
		if (ent.eval) then
			if (not ent.eval()) then
				return;
			end
		end

		if (ent.kind == "action") then
			if (ent.submenu) then
				if (type(ent.handler) == "function") then
					menu = ent:handler();
				else
					menu = ent.handler;
				end
				table.insert(path, cmd);
				cmd = table.remove(cmdtbl, 1);
			else
				if (verbose and type(errorf) == "function") then
					errorf(string.format("%s: running action '%s'", table.concat(path, "/"), cmd));
				end

				ent:handler();
				return;
			end
		elseif (ent.kind == "value") then
-- if set, we need to match the value against the set
			if (ent.set) then
				local set = ent.set;
				if (type(set) == "function") then
					set = set();
				end
				if (not table.find_i(set, val)) then
					if (type(errorf) == "function") then
						errorf(string.format("%s: value '%s' not in set", table.concat(path, "/"), val));
					end
					return;
				end
			elseif (ent.validator and not ent.validator(val)) then
				if (type(errorf) == "function") then
					errorf(string.format("%s: failed validation for '%s=%s'", table.concat(path, "/"), cmd, val));
				end
				return;
			end

			if (verbose and type(errorf) == "function") then
				errorf(string.format("%s: setting value '%s=%s'", table.concat(path, "/"), cmd, val));
			end
			ent:handler(val);
			return;
		end
	end
end
