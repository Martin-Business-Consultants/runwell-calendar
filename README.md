# Calendar, a Runwell plugin

Who's out, what's due and every date that matters, on one calendar, for
[Runwell](https://github.com/Martin-Business-Consultants/runwellv2).

- **Tasks by their due date**: open, overdue (in red, and listed first on today) and done
- **Time off**: who's away, whole days or half of one. Anyone adds their own; owners and managers
  (the `manage_time_off` permission) add and remove anyone's. No approval: it says who's away. A
  note is private to the person and whoever manages time off
- **Dates**: every date custom field you may see (Settings > Fields), so a "Launch" date on a piece
  of work, or a "Renewal" on a client, shows on its day
- **Other plugins' dates**: anything a plugin offers calendars (`Runwell::Plugins.dates`)
- **Work closed**, as completed or cancelled
- **Clashes**: a task due, or a date on a piece of work (a launch), while someone on it is out, is
  flagged on the day and on the item

## Using it

Calendar in the nav opens the month; switch to a week or a four-week agenda. Pick a day for its
panel: who's out, what's due (and overdue, on today), its dates, what closed, how many open tasks
each person has due, and Add time off for that day. Hide the panel (`]`) for a wider calendar, and
switch Weekends off for a five-day grid (a Friday then says what's on the weekend); both are
remembered. Drag an open task to another day to move its due date.

A task due on a day someone on it is out says so under its title, on its page and in the side
panel. In the client portal, home shows what's coming up for the client in the next three months
from the date fields shown to clients (a launch).

Filter (comboboxes, with a filter box for long lists) by person (anyone, me, or someone), client, work and what to show (everything, open tasks,
overdue, done tasks, time off, dates, closed work), and search: a fuzzy search across clients,
work, tasks and people (it forgives typos and partial words: "wbsite" finds Website rebuild).
Every filter is in the address, so a filtered calendar is a link to bookmark or share.

Keys: `h` and `l` for the previous and next month (week, four weeks), `t` for today, `]` for the
day panel, `j` / `k` through the days and Enter to open one.

**Subscribe** gives you a private link for Google Calendar, Outlook or Apple's Calendar: your open
tasks with a due date, everyone's time off and every date you may see, from a month back to six
months ahead. It's shown once; reset or turn it off on the same page.

## For AI

| Tool | Does |
| --- | --- |
| `list_calendar` | Day by day over a range (`from`, `to`; up to 92 days), with the filters and search, clashes and overdue |
| `show_calendar_day` | One day: who's out, what's due, dates, what closed, each person's load |
| `list_time_off` | Who's out, soonest first |
| `add_time_off` / `remove_time_off` | Your own, or anyone's with `manage_time_off` |

Ask "who's out next week?", "what's due while Marcus is away?" or "does anything launch when
someone on it is out?". Calendar links are made only by their person, in the browser.

## Installing

Settings > Plugins, add `Martin-Business-Consultants/runwell-calendar`, then switch it on. Needs
Runwell 5.6 or later. It keeps its own tables (`calendar_time_offs`, `calendar_feeds`) and reads
the core's records by id; removing it leaves Runwell as it was.

## Developing

From a Runwell checkout: `bin/rails "plugins:link[../runwell-calendar]"`, restart, then
`bin/rails db:migrate`. Release by bumping `lib/calendar/version.rb` and pushing a `vX.Y.Z` tag.
