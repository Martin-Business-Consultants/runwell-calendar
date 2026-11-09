json.summary "Workload limit #{@setting.workload_limit} a day; Monday look-ahead #{@setting.look_ahead? ? "on" : "off"}; " \
  "#{@setting.holidays_url.present? ? "following a holiday calendar" : "no holiday calendar"}; #{@holidays.size} holidays coming up."
json.workload_limit @setting.workload_limit
json.look_ahead @setting.look_ahead
json.holidays_url @setting.holidays_url
json.holidays_error @setting.holidays_error if @setting.holidays_error
json.holidays @holidays do |holiday|
  json.id holiday.id
  json.date holiday.date
  json.name holiday.name
  json.source holiday.source
end
