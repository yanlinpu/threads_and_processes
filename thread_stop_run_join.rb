#encoding: utf-8
require 'benchmark'
real_time = Benchmark.realtime do
  a = ARGV.first
  ts = []
  t = []
  a.to_i.times do |i|
    ts << Thread.new(i) do
      Thread.stop
      ti = Benchmark.realtime do
        sleep(1)
      end
      t << ti
    end
  end
  sleep 0.2 #THREAD必须 在run之前先确保已经stop了 否则会出现以下注释情况
  #因为线程可能还没来得及 stop 就已经先执行run 的命令了。
  #只是因为你线程第一次执行的命令是 Thead.stop，所以这个可能性比较小，但是多试几次还是会出现这种情况的。
  #如果线程一直保持stop，你再去join它就会出现deadlock
  ts.each &:run
  ts.each &:join  #有时主线程会一直等待第一个 ts[0]线程的运行 ts[0]没有运行结果所以修改为ts[4..-1].each &:join
  p t
  sum = t.inject{|s,e| s=s+e}
  p sum/t.size
end
p real_time