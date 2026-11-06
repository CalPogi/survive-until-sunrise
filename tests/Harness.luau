--!strict
--[[
    Tiny test harness with no Roblox dependencies (runs under Lune and the plain Luau CLI).

    A spec file returns a function that receives `t` and registers tests:

        return function(t: Harness.T)
            t.test("adds numbers", function()
                t.eq(1 + 1, 2)
            end)
        end

    Register new specs in tests/run.luau.
]]

export type T = {
	test: (name: string, body: () -> ()) -> (),
	eq: (actual: unknown, expected: unknown, message: string?) -> (),
	ok: (value: unknown, message: string?) -> (),
	notOk: (value: unknown, message: string?) -> (),
	throws: (body: () -> (), message: string?) -> (),
}

export type Spec = (t: T) -> ()

export type Entry = { name: string, spec: Spec }

local Harness = {}

local MAX_DEPTH = 4

local function describe(value: unknown, depth: number): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) ~= "table" then
		return tostring(value)
	end
	if depth >= MAX_DEPTH then
		return "{...}"
	end
	local keys: { string } = {}
	local byKey: { [string]: unknown } = {}
	for key, item in value do
		local name = tostring(key)
		table.insert(keys, name)
		byKey[name] = item
	end
	table.sort(keys)
	local parts: { string } = {}
	for _, key in keys do
		table.insert(parts, key .. " = " .. describe(byKey[key], depth + 1))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deepEqual(a: unknown, b: unknown): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local left: any = a
	local right: any = b
	for key, value in left do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

local function fail(message: string?, detail: string)
	error(if message then message .. " | " .. detail else detail, 3)
end

-- Runs every spec. Prints failures and a summary. Returns the number of failed tests.
function Harness.run(entries: { Entry }): number
	local passed = 0
	local failed = 0
	local failures: { string } = {}

	for _, entry in entries do
		local cases: { { name: string, body: () -> () } } = {}

		local t: T = {
			test = function(name: string, body: () -> ())
				table.insert(cases, { name = name, body = body })
			end,
			eq = function(actual: unknown, expected: unknown, message: string?)
				if not deepEqual(actual, expected) then
					fail(message, "expected " .. describe(expected, 0) .. ", got " .. describe(actual, 0))
				end
			end,
			ok = function(value: unknown, message: string?)
				if not value then
					fail(message, "expected a truthy value, got " .. describe(value, 0))
				end
			end,
			notOk = function(value: unknown, message: string?)
				if value then
					fail(message, "expected a falsy value, got " .. describe(value, 0))
				end
			end,
			throws = function(body: () -> (), message: string?)
				if pcall(body) then
					fail(message, "expected the function to throw, but it returned normally")
				end
			end,
		}

		entry.spec(t)

		for _, case in cases do
			local success, err = pcall(case.body)
			if success then
				passed += 1
			else
				failed += 1
				table.insert(failures, entry.name .. " > " .. case.name .. ": " .. tostring(err))
			end
		end
	end

	for _, line in failures do
		print("FAIL " .. line)
	end
	print(string.format("%d passed, %d failed", passed, failed))
	return failed
end

return Harness
