# modern_times

http://github.com/ClarityServices/modern_times

## Description:

JRuby library for performing background tasks via JMS.

Beta version.  API still subject to change.

## Features/Problems:

Currently tested only for ActiveMQ

## Install:

  gem install modern_times

## Rails Usage:

Create config/jms.yml which might look as follows:

    development_server: &defaults
      :factory: org.apache.activemq.ActiveMQConnectionFactory
      :broker_url: tcp://127.0.0.1:61616
      :require_jars:
        - <%= Rails.root %>/lib/activemq/activemq-all.jar

    development_vm:
      <<: *defaults
      :broker_url: vm://127.0.0.1
      :object_message_serialization_defered: true

    staging:
      <<: *defaults
      :broker_url: tcp://stage2:61616
      :username: myuser
      :password: mypassword

    production:
      <<: *defaults
      :broker_url: failover://(tcp://msg1:61616,tcp://msg2:61616)?randomize=false&initialReconnectDelay=100&useExponentialBackOff=true&maxCacheSize=524288&trackMessages=true
      :username: myuser
      :password: mypassword

In development and test mode, you will notice that there is no configuration defined.  In this case, published messages will cause
synchronous calls to the Worker's perform method which matches the destination queue or topic.
This will allow your coworkers to use the functionality
of the queueing system without having to startup a JMS server.  If you wanted to start up in an actual server-type mode, you
might set the MODERN_TIMES_ENV environment variable to "development_server" to override the Rails.env.  This will allow you to test
the queueing system without having to make temporary changes to the config file which could accidentally get checked in.
For staging and production
modes, you will need to have a JMS server running.  Note that this library has only been tested with ActiveMQ.

Create config/workers.yml which might look as follows:

    development:
      Analytics:
        :count: 1
      Dashboard:
        :count: 1

    stage1:
      Analytics:
        :count: 2
      Dashboard:
        :count: 2

    app1: &default_setup
      Analytics:
        :count: 2
      Dashboard:
        :count: 2

    app2:
      <<: *default_setup

    app3:
      <<: *default_setup

In this file, the count represents the number of threads dedicated per worker.  The worker first looks for a key that matches
the Rails.env.  If it doesn't find one, it will look for a key matching the non-qualified hostname of the machine.  (TODO: Show how to add options
that get passed to the constructor and a single worker class that operates on 2 different queues).  This file is optional and workers
can be configured ad-hoc instead.

If you don't want to explicitly define your workers in a config file, you can create them ad-hoc instead.
Configure your workers by starting jconsole and connecting to
the manager process.  Go to the MBeans tab and open the tree to
ModernTimes => Manager => Operations => start_worker

Start/stop/increase/decrease workers as needed.  The state is stored in the log directory (by default)
so you can stop and start the manager and not have to reconfigure your workers.

Create config/initializers/modern_times.rb which might look as follows (TODO: Maybe add or refer to
examples for registering marshal strategies):

    ModernTimes.init_rails
    # Publishers can be defined wherever appropriate, probably as class variables within the class that uses it
    $foo_publisher = ModernTimes::JMS::Publisher.new('Foo')

When creating publishers, you will probably want to store the value in a class variable.  Publishers internally
make use of a session pool for communicating with the JMS server so you wouldn't want to create a new connection
every time you published an object.

In your code, queue foo objects:

    $foo_publisher.publish(my_foo_object)

In app/workers, create a FooWorker class:

    class FooWorker
      include ModernTimes::JMS::Worker
      def perform(my_foo_object)
        # Operate on my_foo_object
      end
    end

For the staging and production environment, you will need to startup a Manager process on each machine that handles messages.  You
might create script/worker_manager as follows (assumes Rails.root/script is in your PATH):

    #!/usr/bin/env runner

    manager = ModernTimes.create_rails_manager
    manager.join

TODO:  Refer to example jsvc daemon script


## Multiple Workers For a Virtual Topic:

By default, a worker operates on the queue with the same name as the class minus the Worker postfix.  You can override
this by explicitily by specifying a queue or a virtual topic instead.  A virtual_topic (ActiveMQ only) allows you to publish to one destination
and allow for multiple workers to subscribe.  (TODO: need to completely remove the use of topics as every thread for every worker
receives all messages instead of a group of workers (threads) collectively receiving all messages.  Virtual topics get around this
problem). For instance, suppose you have the following workers:

    class FooWorker
      include ModernTimes::JMS::Worker
      virtual_topic 'inquiry'

      def perform(my_inquiry)
        # Operate on my_inquiry
      end
    end

    class BarWorker
      include ModernTimes::JMS::Worker
      virtual_topic 'inquiry'

      def perform(my_inquiry)
        # Operate on my_inquiry
      end
    end

Then you can create a publisher where messages are delivered to both workers:

    @@publisher = ModernTimes::JMS::Publisher.new(:virtual_topic_name => 'inquiry')
    ...
    @@publisher.publish(my_inquiry)


## Requestor Pattern:

TODO: See examples/requestor


## Requestor Pattern with Multiple RequestWorkers:

TODO: See examples/advanced_requestor


## What's with the name?

I'm a Chaplin fan.

## Author

Brad Pardee

## Copyright

Copyright (c) 2011 Clarity Services. See LICENSE for details.
