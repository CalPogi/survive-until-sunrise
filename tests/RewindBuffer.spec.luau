--!strict
local Harness = require("./Harness")
local RewindBuffer = require("../src/shared/RewindBuffer")

return function(t: Harness.T)
	local function xAt(buffer: RewindBuffer.RewindBuffer, time: number): number?
		local position = buffer:at(time)
		return if position then position.x else nil
	end

	local function filled(): RewindBuffer.RewindBuffer
		local buffer = RewindBuffer.new(1)
		buffer:push(10, 0, 1, 2)
		buffer:push(10.5, 10, 11, 12)
		return buffer
	end

	t.test("an exact sample returns itself", function()
		local position = filled():at(10.5)
		t.eq(position, { x = 10, y = 11, z = 12 })
	end)

	t.test("between two samples it interpolates", function()
		t.eq(filled():at(10.25), { x = 5, y = 6, z = 7 })
	end)

	t.test("older than the oldest sample returns nil", function()
		t.eq(xAt(filled(), 9.99), nil)
	end)

	t.test("beyond maxAge returns nil even if a sample still exists", function()
		local buffer = RewindBuffer.new(1)
		buffer:push(10, 0, 0, 0)
		buffer:push(11.5, 1, 0, 0)
		t.eq(xAt(buffer, 10.4), nil)
		t.ok(xAt(buffer, 10.5) ~= nil, "exactly maxAge is allowed")
	end)

	t.test("up to 0.25 s ahead returns the newest, further returns nil", function()
		t.eq(xAt(filled(), 10.75), 10)
		t.eq(xAt(filled(), 10.76), nil)
	end)

	t.test("empty buffer returns nil", function()
		t.eq(RewindBuffer.new(1):at(0), nil)
	end)

	t.test("old samples are pruned but the full window stays usable", function()
		local buffer = RewindBuffer.new(1)
		for i = 0, 1000 do
			buffer:push(i * 0.05, i, 0, 0)
		end
		t.ok(#(buffer :: any)._samples <= 22, "too many samples kept")
		local newest = 1000 * 0.05
		t.ok(math.abs((xAt(buffer, newest - 1) or -1) - 980) < 0.001, "the oldest moment in the window still works")
	end)

	t.test("out-of-order pushes are ignored", function()
		local buffer = filled()
		buffer:push(10.25, 999, 999, 999)
		t.eq(buffer:at(10.25), { x = 5, y = 6, z = 7 })
	end)

	t.test("a duplicate time is ignored", function()
		local buffer = filled()
		buffer:push(10.5, 999, 999, 999)
		t.eq(buffer:at(10.5), { x = 10, y = 11, z = 12 })
	end)

	t.test("constructor rejects a bad maxAge", function()
		t.throws(function()
			RewindBuffer.new(0)
		end)
	end)
end
