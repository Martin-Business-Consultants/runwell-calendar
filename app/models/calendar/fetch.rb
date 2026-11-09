require "net/http"

module Calendar
  # Fetches a calendar file from its link: https only (webcal:// is read as https://), a few
  # redirects, short timeouts and at most 2 MB, so a slow or huge calendar can't hold a job up.
  # Raises Calendar::Fetch::Error, in words, for anything else.
  module Fetch
    class Error < StandardError; end
    MAX_BYTES = 2.megabytes

    module_function

    def get(url, redirects: 3)
      uri = URI(url.to_s.strip.sub(%r{\Awebcal://}i, "https://"))
      raise Error, "The link should start with https://" unless uri.is_a?(URI::HTTPS) && uri.host.present?

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        http.request(Net::HTTP::Get.new(uri, "User-Agent" => "Runwell Calendar/#{Calendar::VERSION}", "Accept" => "text/calendar"))
      end
      case response
      when Net::HTTPRedirection
        raise Error, "The link redirects too many times" if redirects.zero?

        get(URI.join(uri, response["location"]).to_s, redirects: redirects - 1)
      when Net::HTTPSuccess
        body = response.body.to_s
        raise Error, "The calendar is over 2 MB" if body.bytesize > MAX_BYTES
        raise Error, "That link isn't a calendar (.ics)" unless body.include?("BEGIN:VCALENDAR")

        body.force_encoding(Encoding::UTF_8).scrub
      else
        raise Error, "The calendar answered #{response.code} #{response.message}"
      end
    rescue URI::InvalidURIError
      raise Error, "That isn't a link"
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => error
      raise Error, "The calendar couldn’t be reached (#{error.class.name.demodulize})"
    end
  end
end
