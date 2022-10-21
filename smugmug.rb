require "faraday"
require "active_support/all"

class Smugmug
  def initialize(username, cookies: nil)
    @username = username
    @cookies = cookies
    @connection = build_connection
  end

  def albums
    page("Album", "/api/v2/user/#{@username}!albums", start: 1, count: 50)
  end

  def download(url, path)
    File.open(path, "wb") do |file|
      response = @connection.get(url)
      raise "Received a status code of #{response.status} instead of 200" unless response.status == 200

      file.write(response.body)
    end
  end

  def get(url, **opts)
    puts url unless url.include?("!largest")
    response = @connection.get(url, *opts)
    raise "Received a status code of #{response.status}" unless response.status == 200

    response.body
  rescue Faraday::SSLError => e
    puts "SSL Error: #{e.message} for #{url}"
	raise
  end

  def page(type, url, start: 1, count: 100)
    Enumerator.new do |y|
      next_page = "#{url}?start=#{start}&count=#{count}"
      loop do
        body = get(next_page)
		break if body.nil?

		(body.dig("Response", type) || []).each do |item|
          y.yield(item)
        end

        next_page = body.dig("Response", "Pages", "NextPage")
        break if next_page.blank?
      end
    end
  end

  private

  def build_connection
    Faraday.new(
      url: "https://www.smugmug.com",
      headers: {
        Accept: "application/json",
        Cookie: @cookies
      }
    ) do |faraday|
      faraday.request :json
      # faraday.response :logger
      faraday.response :json, content_type: /\bjson$/
    end
  end
end
