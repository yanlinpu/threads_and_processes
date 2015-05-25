THREAD & PROCESSES
===

[参考博客](http://www.douban.com/note/52006836/)

Ruby给了你两个基本的方法来组织你的程序，使它同时能运行自己的不同部分。
你可以使用多线程在程序内部将任务分割，或者将任务分解为不同的程序，使用多进程来运行。

THREAD

problem：

- 饥饿线程（优先级低的线程没有机会运行）
- 线程死锁，整个进程都被挂起
- 一些线程的某些操作占用了CPU的太多时间，以至于所有线程必须等待直到解释器重新获得控制
- 不止有一块CPU，Ruby线程也不会得到什么好处------因为它们运行在个处理器中，在单个本地线程内，它们每次只能运行在一个处理器上

技巧
- 通过Thread.new传递任意数量的参数到块内
    - 例如（thread_parameter.rb） 如果第一个线程没有完成并还在使用page_to_fetch变量，那么它可能会突然使用这个新的值来启动。这个bug将很难被跟踪发现。
- join
    - 当一个Ruby程序结束退出的时候，它会杀死所有的线程，而不管它们的状态。Thread#join 方法，使得主程序在等待这个线程结束后再退出。调用它的线程将会被阻塞，直到给定的线程结束。
线程变量
- 一个线程的变量能被其它线程访问，包括主线程，该怎么办呢？
- 能够按名字创建和访问线程内的局部变量（例如thread_var.rb  Thread.current["mycount"] = count 内部赋值   t["mycount"]取值）
线程和异常
- 本线程报错，其他线程正常输出（thread_error.rb）
- 可以捕获异常（begin rescue end） (thread_error_2.rb)
- 设置abort_on_exception为true，则一个未处理异常会杀死所有运行中的线程

进程
- server（[beanstalkd](http://birdinroom.blog.51cto.com/7740375/1344109)）
    - $sudo apt-get install beanstalkd
    - $sudo vim /etc/default/beanstalkd   ##START=yes解注
    - $sudo /etc/init.d/beanstalkd start  ##启动Beanstalk
    - $sudo /etc/init.d/beanstalkd stop   ##停止Beanstalk
- client（[beanstalk-client](https://github.com/kr/beanstalk-client-ruby)&&[demo](http://www.oschina.net/code/snippet_170216_11284)）





