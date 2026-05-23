--!native
--!strict

local DayEvent = {}
DayEvent.__index = DayEvent

function DayEvent.newEvent(day: number?, month: number?, year: number?)
	local self = setmetatable({}, DayEvent)

	self.Data = {Day = day or 0, Month = month or 0, Year = year or 0,}
	self.NextEvents = nil

	return self
end

function DayEvent:Fire(func: () -> ())
	local currentDate = os.date('*t')

	if (self.Data.Day == 0 or self.Data.Day == currentDate.day) and (self.Data.Month == 0 or self.Data.Month == currentDate.month) and (self.Data.Year == 0 or self.Data.Year == currentDate.year) then
		func()
	end
end

function DayEvent:doubleFire(func: () -> (), nextfunc: () -> ()?)
	local currentDate = os.date('*t')

	if (self.Data.Day == 0 or self.Data.Day == currentDate.day) and (self.Data.Month == 0 or self.Data.Month == currentDate.month) and (self.Data.Year == 0 or self.Data.Year == currentDate.year) then
		func()

		if self.NextEvent then
			self.NextEvent:Fire(nextfunc)
		end
	end
end

function DayEvent:NextEvent(day: number?, month: number?, year: number?)
	self.NextEvent = DayEvent.newEvent(day, month, year)
	return self.NextEvent
end

return table.freeze(DayEvent)
