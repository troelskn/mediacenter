__DIR__ = File.expand_path(File.dirname(__FILE__))
$: << __DIR__
require 'rubygems'
require 'app'
App.set :logging, true
run App
