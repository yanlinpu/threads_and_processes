require 'net/http'

pages = %w( www.baidu.com www.csdn.net code.csdn.net )

threads = []

for page_to_fetch in pages

  threads << Thread.new(page_to_fetch) do |url|

    h = Net::HTTP.new(url, 80)

    puts "Fetching: #{url}"

    resp = h.get('/', nil )

    puts "Got #{url}: #{resp.message}"

  end

end

threads.each {|thr| thr.join }
