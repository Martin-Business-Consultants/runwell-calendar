module Calendar
  # How a person likes the calendar laid out: weekends shown, the day panel open, the tasks drawer
  # open. Each is a choice of two, set by a param (which stays in the link) and remembered in a
  # cookie for their next visit; the first value is the default. Views ask whether it's on and
  # which value flips it, so no value is typed out twice.
  class Preferences
    CHOICES = { weekends: %w[on off], panel: %w[on off], drawer: %w[closed open] }.freeze
    ON = { weekends: "on", panel: "on", drawer: "open" }.freeze

    def initialize(params, cookies)
      @values = CHOICES.to_h do |name, values|
        cookie = :"calendar_#{name}"
        cookies.permanent[cookie] = { value: params[name], same_site: :lax } if values.include?(params[name])
        [ name, params[name].presence_in(values) || cookies[cookie].presence_in(values) || values.first ]
      end
    end

    def on?(name) = @values.fetch(name) == ON.fetch(name)
    def weekends? = on?(:weekends)
    def panel? = on?(:panel)
    def drawer? = on?(:drawer)

    # The value a toggle sends to flip it.
    def flipped(name) = (CHOICES.fetch(name) - [ @values.fetch(name) ]).first

    # The values that turn one on and off, for a link that sets it either way (a day link opening
    # the panel, the drawer's close).
    def self.on(name) = ON.fetch(name)
    def self.off(name) = (CHOICES.fetch(name) - [ ON.fetch(name) ]).first
  end
end
