threads = []

4.times do |number|

  threads << Thread.new(number) do |i|

    raise "Boom!" if i == 2

    print "#{i}n"

  end

end

threads.each {|t| t.join }

