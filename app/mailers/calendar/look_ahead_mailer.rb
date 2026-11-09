module Calendar
  # The Monday look-ahead (Calendar::LookAhead): a person's week, in the core's email pieces.
  class LookAheadMailer < ApplicationMailer
    def week
      @person = params[:person]
      @look_ahead = Calendar::LookAhead.new(@person)
      mail to: @person.email_address, subject: "Your week: #{@look_ahead.tasks.size} due#{", #{@look_ahead.clashes.size} while you're out" if @look_ahead.clashes.any?}"
    end
  end
end
