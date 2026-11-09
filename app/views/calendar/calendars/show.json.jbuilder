range = @schedule.range
days = range.select { |date| @schedule.on(date).any? }
clashes = @schedule.items.count(&:clash?)
json.summary [
  "#{@schedule.items.size} on the calendar from #{range.first} to #{range.last}",
  ("#{clashes} #{clashes == 1 ? "clash" : "clashes"} (someone out when their task or date lands)" if clashes.positive?),
  ("#{@schedule.overdue.size} overdue" if range.cover?(Date.current) && @schedule.overdue.any?)
].compact.join("; ") + "."
json.from range.first
json.to range.last
json.filters do
  json.person calendar_person_json(@schedule.person) if @schedule.person
  json.client agent_ref(@schedule.client) if @schedule.client
  json.work agent_ref(@schedule.work) if @schedule.work
  json.show @schedule.show
  json.q @schedule.query if @schedule.query
end
if range.cover?(Date.current) && @schedule.overdue.any?
  json.overdue @schedule.overdue do |task|
    json.merge! agent_ref(task)
    json.due_on task.due_on
    json.people task.owners.map { calendar_person_json(it) }
  end
end
json.days days do |date|
  json.date date
  json.items @schedule.on(date), partial: "calendar/shared/item", as: :item
end
