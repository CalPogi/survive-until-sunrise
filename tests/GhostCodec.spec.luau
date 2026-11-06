--!strict
local GhostCodec = require("../src/shared/GhostCodec")
local Harness = require("./Harness")

local function entry(userId: number): GhostCodec.Entry
	return {
		userId = userId,
		x = 100.1,
		y = -20.2,
		z = -3000.3,
		yaw = 90,
		vx = 16,
		vz = -16,
		anim = 5,
		held = 300,
	}
end

local function entries(count: number): { GhostCodec.Entry }
	local list = {}
	for i = 1, count do
		table.insert(list, entry(i))
	end
	return list
end

local function decodeOnly(text: unknown): GhostCodec.Decoded
	local decoded, reason = GhostCodec.decode(text)
	assert(decoded, reason)
	return decoded
end

return function(t: Harness.T)
	local function near(actual: number, expected: number, tolerance: number, message: string?)
		t.ok(math.abs(actual - expected) <= tolerance, `{message or ""} expected {expected}, got {actual}`)
	end

	t.test("round trip stays within half a step on every field", function()
		local text = GhostCodec.encode(1800000000.125, { entry(123456789) })
		local decoded = decodeOnly(text)
		near(decoded.senderTime, 1800000000.125, 0.0005)
		t.eq(#decoded.entries, 1)
		local e = decoded.entries[1]
		t.eq(e.userId, 123456789)
		near(e.x, 100.1, 0.125)
		near(e.y, -20.2, 0.25)
		near(e.z, -3000.3, 0.125)
		near(e.yaw, 90, 2.8125)
		near(e.vx, 16, 1)
		near(e.vz, -16, 1)
		t.eq(e.anim, 5)
		t.eq(e.held, 300)
	end)

	t.test("42 entries fit in 900 characters and the 43rd does not", function()
		local text, consumed = GhostCodec.encode(1, entries(43))
		t.eq(consumed, 42)
		t.ok(#text <= GhostCodec.MAX_CHARS, "over the size cap")
		t.eq(#decodeOnly(text).entries, 42)
	end)

	t.test("startIndex lets the caller rotate who goes first", function()
		local text, consumed = GhostCodec.encode(1, entries(43), 43)
		t.eq(consumed, 1)
		t.eq(decodeOnly(text).entries[1].userId, 43)
	end)

	t.test("no entries still makes a valid message", function()
		local text, consumed = GhostCodec.encode(5, {})
		t.eq(consumed, 0)
		t.eq(#decodeOnly(text).entries, 0)
	end)

	t.test("output uses only the 64-character alphabet", function()
		local text = GhostCodec.encode(1800000000, entries(42))
		t.ok(string.match(text, "^[%w%-_]+$"), text)
	end)

	t.test("out-of-range values clamp", function()
		local e = entry(1)
		e.x, e.y, e.z = 99999, 99999, -99999
		e.vx, e.vz = 500, -500
		e.anim, e.held = 500, 99999
		local decoded = decodeOnly((GhostCodec.encode(1, { e }))).entries[1]
		near(decoded.x, 32767.75, 0.001)
		near(decoded.y, 1023.5, 0.001)
		near(decoded.z, -32768, 0.001)
		t.eq(decoded.vx, 62)
		t.eq(decoded.vz, -64)
		t.eq(decoded.anim, 63)
		t.eq(decoded.held, 4095)
	end)

	t.test("yaw wraps around the circle", function()
		local e = entry(1)
		e.yaw = 725
		near(decodeOnly((GhostCodec.encode(1, { e }))).entries[1].yaw, 5, 2.8125)
		e.yaw = -90
		near(decodeOnly((GhostCodec.encode(1, { e }))).entries[1].yaw, 270, 2.8125)
	end)

	t.test("entries with NaN or infinity are skipped but still counted as consumed", function()
		local bad = entry(2)
		bad.x = 0 / 0
		local worse = entry(3)
		worse.vz = math.huge
		local text, consumed = GhostCodec.encode(1, { entry(1), bad, worse, entry(4) })
		t.eq(consumed, 4)
		local decoded = decodeOnly(text)
		t.eq(#decoded.entries, 2)
		t.eq(decoded.entries[1].userId, 1)
		t.eq(decoded.entries[2].userId, 4)
	end)

	t.test("user ids out of range are skipped, never clamped into someone else", function()
		local text = GhostCodec.encode(1, { entry(2 ^ 50), entry(1.5), entry(-5000), entry(7) })
		local decoded = decodeOnly(text)
		t.eq(#decoded.entries, 1)
		t.eq(decoded.entries[1].userId, 7)
	end)

	t.test("large user ids and Studio's negative test ids survive", function()
		local decoded = decodeOnly((GhostCodec.encode(1, { entry(9000000000000 / 3), entry(-1) })))
		t.eq(decoded.entries[1].userId, 3000000000000)
		t.eq(decoded.entries[2].userId, -1)
	end)

	t.test("user id range edges", function()
		local top = 64 ^ 7 - 1 - 1024
		local decoded = decodeOnly((GhostCodec.encode(1, { entry(-1024), entry(top), entry(-1025), entry(top + 1) })))
		t.eq(#decoded.entries, 2)
		t.eq(decoded.entries[1].userId, -1024)
		t.eq(decoded.entries[2].userId, top)
	end)

	t.test("negative anim and held clamp to zero", function()
		local e = entry(1)
		e.anim, e.held = -5, -5
		local decoded = decodeOnly((GhostCodec.encode(1, { e }))).entries[1]
		t.eq(decoded.anim, 0)
		t.eq(decoded.held, 0)
	end)

	t.test("sender time rounds to the nearest millisecond", function()
		near(decodeOnly((GhostCodec.encode(1.001, {}))).senderTime, 1.001, 0.0005)
		near(decodeOnly((GhostCodec.encode(1.0016, {}))).senderTime, 1.002, 0.0001)
	end)

	t.test("sender time range edges", function()
		local top = (64 ^ 7 - 1) / 1000
		near(decodeOnly((GhostCodec.encode(top, {}))).senderTime, top, 0.0005)
		t.throws(function()
			GhostCodec.encode(64 ^ 7 / 1000, {})
		end)
	end)

	t.test("encode rejects a bad sender time", function()
		t.throws(function()
			GhostCodec.encode(0 / 0, {})
		end)
		t.throws(function()
			GhostCodec.encode(-1, {})
		end)
	end)

	t.test("a bad character anywhere in an entry fails closed", function()
		local good = GhostCodec.encode(1, { entry(1) })
		for at = 10, 30 do
			local text = string.sub(good, 1, at - 1) .. "!" .. string.sub(good, at + 1)
			local decoded, reason = GhostCodec.decode(text)
			t.eq(decoded, nil, `position {at}`)
			t.eq(reason, "bad character", `position {at}`)
		end
	end)

	t.test("decode fails closed on malformed text", function()
		local good = GhostCodec.encode(1, { entry(1) })
		local cases: { [string]: unknown } = {
			["not a string"] = 42,
			["empty"] = "",
			["wrong version"] = "A" .. string.sub(good, 2),
			["wrong type"] = string.sub(good, 1, 1) .. "Z" .. string.sub(good, 3),
			["truncated header"] = string.sub(good, 1, 5),
			["partial entry"] = string.sub(good, 1, #good - 1),
			["bad character in time"] = string.sub(good, 1, 2) .. "!" .. string.sub(good, 4),
			["multi-byte character"] = string.sub(good, 1, #good - 1) .. "é",
			["too long"] = good .. string.rep("A", 21 * 50),
		}
		t.eq((GhostCodec.decode(nil)), nil, "nil")
		for name, text in cases do
			local decoded, reason = GhostCodec.decode(text)
			t.eq(decoded, nil, name)
			t.ok(reason, `{name} needs a reason`)
		end
	end)
end
