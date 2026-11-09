# Calendar (a Runwell plugin): guide for AI agents

A Rails engine loaded into a Runwell install (README.md says what it does). Run it from a Runwell
checkout with `bin/rails "plugins:link[path]"`. Read Runwell's `docs/plugin-contract.md` (use
nothing of the core's beyond it) and its `AGENTS.md` (the conventions this code follows).

## How it's built

- `Calendar::Schedule` is the calendar: everything dated in a range of days (tasks by due date,
  time off, date custom fields through `CustomField.dates_between`, work closed), narrowed by
  person, client, work, what to show and a search (the core's fuzzy `Search`), with clashes
  worked out from everyone's time off whatever the filters show. The page (`CalendarsController`,
  `DaysController`) and the agent tools read the same object; keep it that way, so a person and an
  agent always see the same calendar
- `Calendar::Period` is the stretch shown: a month (whole weeks), a week or a four-week agenda
- `Calendar::TimeOff` (`calendar_time_offs`): who's out. `manageable_by?` is the rule (their own,
  or anyone's with `manage_time_off`), checked in the controller; the note is private by the
  same rule (`note_visible_to?`)
- `Calendar::Feed` (`calendar_feeds`) and `Calendar::Ics`: a person's private .ics link, its token
  stored as a digest, made and reset only in the browser (`browser_only`), read by a public
  controller that finds it by token, never an id
- Filters are query params read in `Calendar::ApplicationController`, so every view is a link

## State machines

Each one's rules live once, on a model; views, controllers and the JSON ask it, never keep a copy
(Runwell's own convention):

- A task on the calendar: movable (open) or fixed (done), and overdue (open, due before today):
  `Calendar::TaskRules.movable?` / `overdue?`, read by drops, the item and drawer partials, the
  task notice and clashes; agents see `movable` on each item
- An item's kind: `Calendar::Schedule::KINDS` (time_off, date, plugin, task, closed), in a day's
  order, with a predicate each on `Item` (`time_off?`, `date?`…); compare those, not strings
- How a person lays it out: `Calendar::Preferences` (weekends on/off, the day panel on/off, the
  drawer open/closed; a param changes one and a cookie remembers it); toggles send `flipped(name)`
- Time off: upcoming, current or past from its dates (`TimeOff#state`, shown to agents), and who
  may change it (`manageable_by?`)
- What the calendar shows (`Schedule::SHOWS`), the drawer's due filter (`Drawer::DUES`) and the
  view (`Period::VIEWS`) are constants the filters and tools derive from
- Out: time off, a holiday (`Calendar::Holiday`, everyone) or an all-day busy event from someone's
  own calendar (`Calendar::BusyEvent`, read by `Calendar::BusyFeed` through `Calendar::IcsReader`);
  `Schedule#out?` is the one rule, used for clashes, the team view and `Runwell::Plugins.away`
  (the owner picker's Out)
- Workload: overloaded above `Calendar::Setting#workload_limit` (`Schedule#overloaded?`)
- The look-ahead: sent at most once each Monday (`Setting#look_ahead_sent_on`, `Calendar::LookAhead`)
- Undo: a signed note of how a task stood before a drag (`remember_undo`), good for 15 minutes
- The feed (none, just made: its link shown once, on) and a task's placement are kept by
  `Calendar::Feed` and `Calendar::Placement`

## Rules

- Own tables only (`calendar_*`), core records by id, core rows written only through core verbs
  (the calendar writes none today). Every action has an authorization rule and an agent tool or
  `agent_exempt`; reads have a `.json.jbuilder` with `agent_ref` and a `summary`
- Custom field values come through `CustomField.dates_between` (it honours who may see a field),
  never `CustomValue`
- Views follow the core's ReActionView rules (strict locals, `herb:key` on loops, no inline CSS, no
  partials inside `form_with`); CSS reads Runwell's tokens; no JavaScript of its own so far
- Write for anyone running something: no one industry's words
