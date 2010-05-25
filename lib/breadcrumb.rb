require 'singleton'

class Breadcrumb
  include Singleton

  module ConditionChecker
    def condition_met?(obj)
      if options[:if]
        evaluate(obj, options[:if])
      elsif options[:unless]
        !evaluate(obj, options[:unless])
      else
        true
      end
    end

    def evaluate(obj, condition)
      if condition.respond_to?(:call)
        condition.call(obj.controller)
      else
        obj.send(condition)
      end
    end
  end

  Trail = Struct.new(:controller, :action, :trail, :options, :line) do
    include ConditionChecker
  end
  
  Crumb = Struct.new(:name, :title, :url, :params, :options) do
    include ConditionChecker
  end
  
  attr_accessor :trails, :crumbs, :delimiter
  
  def initialize
    @last_crumb_linked = true
  end
  
  def self.configure(&blk)
    instance.crumbs = {}
    instance.trails = []
    instance.instance_eval &blk
    instance.validate
  end
  
  def trail(controller, actions, trail, options = {})
    @trails ||= []
    actions = Array(actions)
    actions.each do |action|
      @trails << Trail.new(controller, action, trail, options, caller[2].split(":")[1])
    end
  end
  
  def crumb(name, title, url, *params)
    options = {}
    if params.any? && params.first.is_a?(Hash)
      params = params.first
      options[:if] = params.delete(:if) if params.include?(:if)
      options[:unless] = params.delete(:unless) if params.include?(:unless)
    elsif params.any? && params.last.is_a?(Hash)
      options = params.pop
    end
    @crumbs ||= {}
    @crumbs[name] = Crumb.new(name, title, url, params, options)
  end
  
  def context(name)
    yield
  end
  
  def delimit_with(delimiter)
    @delimiter = delimiter
  end
  
  def dont_link_last_crumb
    @last_crumb_linked = false
  end

  def link_last_crumb
    @last_crumb_linked = true
  end
  
  def last_crumb_linked?
    @last_crumb_linked
  end
  
  def validate
    invalid_trails = []
    trails.each do |trail|
      trail.trail.collect do |t|
        invalid_trails << [trail, t] if crumbs[t].nil?
      end
    end
    
    if invalid_trails.any?
      messages = []
      invalid_trails.each do |trail|
        messages << "Trail for #{trail.first.controller}/#{trail.first.action} references non-existing crumb '#{trail.last}' (configuration file line: #{trail.first.line})"
      end
      raise messages.join("\n")
    end
  end
  
end