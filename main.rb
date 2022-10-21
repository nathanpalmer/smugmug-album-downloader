require_relative "./smugmug"
require "down"
require "clamp"
require "colorize"

class Cli < Clamp::Command
  option ["-u", "--username"], "USER", "The username", required: true
  option ["-s", "--session"], "SESSION", "The session cookie", required: true

  def execute
    cookies = {SMSESS: session}.map { |key, value| "#{key}=#{value}" }.join("; ")
    puts cookies
    smugmug = Smugmug.new(username, cookies: cookies)
    output_dir = "output"

    smugmug.albums.each do |album|
      puts "\nAlbum: #{album["Name"].colorize(:blue)}"
      album_path = File.join(output_dir, album["UrlPath"][1..])
      FileUtils.mkdir_p(album_path)

      puts "├─ Retrieving image names"
      smugmug.page("AlbumImage", "#{album["Uri"]}!images").each do |image|
        image_file_name = image["FileName"].presence || "#{File.basename(image["WebUri"])}.#{image["PreferredDisplayFileExtension"].downcase}"
        image_file_name.gsub!(/[^\w\-_. ]/, "_")
        image_path = File.join(album_path, image_file_name)
        image_size = image["ArchivedSize"].to_i

        if File.exists?(image_path) && File.size(image_path) > 0
          File.utime(
            Time.parse(image["DateTimeOriginal"]),
            Time.parse(image["LastUpdated"]),
            image_path
          ) if image["DateTimeOriginal"].present?

          #puts "   ├─ Already downloaded #{image_file_name.colorize(:blue)}"
          next
        end

        download_url = if image.dig("Uris", "LargestVideo").present?
          image_request = smugmug.get(image.dig("Uris", "LargestVideo", "Uri"))
          image_request.dig("Response", "LargestVideo", "Url")
        elsif image.dig("Uris", "LargestImage").present?
          image_request = smugmug.get(image.dig("Uris", "LargestImage", "Uri"))
          image_request.dig("Response", "LargestImage", "Url")
        else
          image["ArchivedUri"]
        end

        print "   ├─ Downloading #{image_file_name.colorize(:blue)} from #{download_url.colorize(:blue)} into #{album_path.colorize(:blue)}"
        Down.download(
          download_url,
          destination: image_path,
          headers: { "Cookie" => cookies },
          progress_proc: ->(_progress) { print "." }
        )
        File.utime(
          Time.parse(image["DateTimeOriginal"]),
          Time.parse(image["LastUpdated"]),
          image_path
        ) if image["DateTimeOriginal"].present?
        puts ""
      end
    end
  end
end

Cli.run
