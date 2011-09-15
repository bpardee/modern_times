TODO
========

 * Better API documentation
 * jms_test and jms_requestor_test don't exit
 * Batch file handling coming soon
 * More thorough test coverage, especially the various options, Railsable, etc.
 * Investigate intermittent test errors "Exception, thread terminating: undefined method `consumer' for #<#<Class:0x10ca5f99b>:0x2d63c5bb>"
 * Need to move away from Singleton connection as we will have both vm: workers and outside workers so will be publishing to multiple connections.
 * setup_dummy_publishing should just create one worker for each configured worker if configured for current environment
 * Deprecate JMX and use REST interface instead?
