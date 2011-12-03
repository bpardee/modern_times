ModernTimes Changelog
=====================

0.4.0.alpha1

 - Now use Rumx instead of JMX (https://github.com/ClarityServices/rumx)
 - Incompatibilities
   - Workers no longer take an options arg as a constructor, instead use config_<access-type> arguments for setting options (See the simple and shared examples).
   - Manager no longer has a persist_file or worker_file setter.  Instead, it must be passed in as an option, i.e., Manager.new(:persist_file => 'modern_times.yml')
     This is because of the new config setup as all worker_configs are setup in the Manager constructor.

0.3.12
-----

 - Use log_backtrace in dummy publishing mode

0.3.11
-----

 - Dummy publishing mode was not thread safe

0.3.10
-----

 - Fixes for post_request handling
