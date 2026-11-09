json.summary @time_offs.any? ? "#{@time_offs.size} time off, soonest first: #{@time_offs.first(3).map { "#{it.user.display_name} #{it.span_text}" }.join("; ")}#{"…" if @time_offs.size > 3}." : "No one's out in that time."
json.time_off @time_offs do |off|
  json.id off.id
  json.person calendar_person_json(off.user)
  json.starts_on off.starts_on
  json.ends_on off.ends_on
  json.half_day off.half_day
  json.label off.label
  json.state off.state
  json.note off.note if off.note_visible_to?(Current.user)
  json.removable off.manageable_by?(Current.user)
end
