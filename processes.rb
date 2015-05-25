#encoding: UTF-8
#Ruby的多线程实际是只能跑在单cpu上，并且同一时刻cpu只处理一个线程，所以采用多进程抓取
# 抓取每一个站点的首页链接数量
# require 'rubygems'            # 1.8.7
require 'ap'                # gem install awesome_print
require 'json'
require 'net/http'
require 'nokogiri'          # gem install nokogiri
require 'forkmanager'       # gem install parallel-forkmanager
require 'beanstalk-client'  # gem install beanstalk-client 消息队列

class MultipleCrawler #多个爬虫

  class Crawler
    def initialize(user_agent, redirect_limit=1)
      @user_agent = user_agent  #代理
      @redirect_limit = redirect_limit
      @timeout = 20
    end
    attr_accessor :user_agent, :redirect_limit, :timeout

    def fetch(website)
      #print "Pid:#{Process.pid}, fetch: #{website}\n"
      redirect, url = @redirect_limit, website
      start_time = Time.now
      redirecting = false
      begin
        begin
          uri = URI.parse(url)
          req = Net::HTTP::Get.new(uri.path)
          req.add_field('User-Agent', @user_agent)
          res = Net::HTTP.start(uri.host, uri.port) do |http|
            http.read_timeout = @timeout
            http.request(req)
          end
          if res.header['location'] # 遇到重定向，则url设定为location，再次抓取
            url = res.header['location']
            redirecting = true
          end
          redirect -= 1
        end while redirecting and redirect>=0
        opened_time = (Time.now - start_time).round(4) # 统计打开网站耗时
        encoding = res.body.scan(/<meta.+?charset=["'\s]*([\w-]+)/i)[0]
        encoding = encoding ? encoding[0].upcase : 'GB18030'
        html = 'UTF-8'==encoding ? res.body : res.body.force_encoding('GB2312'==encoding || 'GBK'==encoding ? 'GB18030' : encoding).encode('UTF-8')
        doc = Nokogiri::HTML(html)
        processed_time = (Time.now - start_time - opened_time).round(4) # 统计分析链接耗时, 1.8.7, ('%.4f' % float).to_f 替换 round(4)
        [opened_time, processed_time, doc.css('a[@href]').size, res.header['server']]
      rescue =>e
        e.message
      end
    end
  end

  def initialize(websites, beanstalk_jobs, pm_max=1, user_agent='', redirect_limit=1)
    @websites = websites                # 网址数组
    @beanstalk_jobs = beanstalk_jobs    # beanstalk服务器地址和管道参数
    @pm_max = pm_max                    # 最大并行运行进程数
    @user_agent = user_agent            # user_agent 伪装成浏览器访问
    @redirect_limit = redirect_limit    # 允许最大重定向次数

    @ipc_reader, @ipc_writer = IO.pipe # 缓存结果的 ipc 管道
  end

  attr_accessor :user_agent, :redirect_limit

  def init_beanstalk_jobs # 准备beanstalk任务
    beanstalk = Beanstalk::Pool.new(*@beanstalk_jobs)
    #清空beanstalk的残留消息队列
    begin
      while job = beanstalk.reserve(0.1)
        job.delete
      end
    rescue Beanstalk::TimedOut
      print "Beanstalk queues cleared!\n"
    end
    @websites.size.times{|i| beanstalk.put(i)} # 将所有的任务压栈
    beanstalk.close
  rescue => e
    puts e
    exit
  end

  def process_jobs # 处理任务
    start_time = Time.now
    pm = Parallel::ForkManager.new(@pm_max)
    @pm_max.times do |i|
      pm.start(i) and next # 启动后，立刻 next 不会等待进程执行完，这样才可以并行运算
      beanstalk = Beanstalk::Pool.new(*@beanstalk_jobs)
      @ipc_reader.close    # 关闭读取管道，子进程只返回数据
      loop{
        begin
          job = beanstalk.reserve(0.1) # 检测超时为0.1秒，因为任务以前提前压栈
          index = job.body
          job.delete
          website = @websites[index.to_i]
          result = Crawler.new(@user_agent).fetch(website)
          @ipc_writer.puts( ({website=>result}).to_json )
        rescue Beanstalk::DeadlineSoonError, Beanstalk::TimedOut, SystemExit, Interrupt
          break
        end
      }
      @ipc_writer.close
      pm.finish(0)
    end
    @ipc_writer.close
    begin
      pm.wait_all_children        # 等待所有子进程处理完毕
    rescue SystemExit, Interrupt    # 遇到中断，打印消息
      print "Interrupt wait all children!\n"
    ensure
      results = read_results
      ap results, :indent => -4 , :index=>false # 打印处理结果
      print "Process end, total: #{@websites.size}, crawled: #{results.size}, time: #{'%.4f' % (Time.now - start_time)}s.\n"
    end
  end

  def read_results # 通过管道读取子进程抓取返回的数据
    results = {}
    while result = @ipc_reader.gets
      results.merge! JSON.parse(result)
    end
    @ipc_reader.close
    results
  end

  def run # 运行入口
    init_beanstalk_jobs
    process_jobs
  end
end

websites = %w(
http://www.51buy.com/ http://www.360buy.com/ http://www.tmall.com/ http://www.taobao.com/
http://china.alibaba.com/ http://www.paipai.com/ http://shop.qq.com/ http://www.lightinthebox.com/
http://www.amazon.cn/ http://www.newegg.com.cn/ http://www.vancl.com/ http://www.yihaodian.com/
http://www.dangdang.com/ http://www.m18.com/ http://www.suning.com/ http://www.hstyle.com/
)
beanstalk_jobs = [['127.0.0.1:11300'],'crawler-jobs']
user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0'
pm_max = 10

MultipleCrawler.new(websites, beanstalk_jobs, pm_max, user_agent).run
