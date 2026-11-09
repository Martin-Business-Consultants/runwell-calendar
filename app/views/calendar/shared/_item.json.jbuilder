json.kind item.kind
json.date item.date
json.title item.title
json.detail item.detail
json.movable item.movable?
case item.kind
when "holiday"
  json.holiday item.title
when "busy"
  json.person calendar_person_json(item.record.user)
  json.busy item.detail
when "time_off"
  json.person calendar_person_json(item.record.user)
  json.time_off do
    json.id item.record.id
    json.starts_on item.record.starts_on
    json.ends_on item.record.ends_on
    json.half_day item.record.half_day
    json.note item.record.note if item.record.note_visible_to?(Current.user)
    json.state item.record.state
  end
when "plugin"
  json.label item.detail
  json.path item.record.path if item.record.path
  json.plugin item.record.plugin
  json.people item.people.map { calendar_person_json(it) }
when "task"
  json.status item.status
  json.overdue item.overdue?
  json.record agent_ref(item.record)
  json.people item.people.map { calendar_person_json(it) }
else
  json.status item.status if item.status
  json.record agent_ref(item.record)
  json.people item.people.map { calendar_person_json(it) }
end
json.clash item.clash.map(&:display_name) if item.clash?
