items = @schedule.on(@date)
out = @schedule.out_on(@date)
due = items.select { it.task? && !it.done? }
json.summary [
  "#{@date.strftime("%A, %B %-d")}: #{out.size} out, #{due.size} due",
  ("#{items.count(&:clash?)} clash" if items.any?(&:clash?)),
  ("#{@schedule.overdue.size} overdue" if @date == Date.current && @schedule.overdue.any?)
].compact.join(", ") + "."
json.date @date
json.out out do |off|
  json.person calendar_person_json(off.user)
  json.id off.id
  json.starts_on off.starts_on
  json.ends_on off.ends_on
  json.half_day off.half_day
  json.note off.note if off.note_visible_to?(Current.user)
end
json.items items, partial: "calendar/shared/item", as: :item
if @date == Date.current
  json.overdue @schedule.overdue do |task|
    json.merge! agent_ref(task)
    json.due_on task.due_on
    json.people task.owners.map { calendar_person_json(it) }
  end
end
json.load(@schedule.load_on(@date).map { |person, count| { person: calendar_person_json(person), open_tasks_due: count } })
json.url calendar_page_url(date: @date.iso8601, day: @date.iso8601)
