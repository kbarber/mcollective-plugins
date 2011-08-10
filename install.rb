#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'pp'
require 'fileutils'

# Global hash for storing configuration options
OPTIONS = {}

# Gather options
ARGV.options do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options]"
  opts.separator ""

  opts.on('--plugins-path[=OPTIONAL]', 'Specifies path to mcollective plugins', 'Default /usr/share/mcollective/plugins') do |value|
    OPTIONS[:plugins_path] = value
  end
  opts.on('--prefix[=OPTIONAL]', 'Specifies prefix for installation', 'Default /') do |value|
    OPTIONS[:prefix] = value
  end
  opts.on('--plugins[=OPTIONAL]', 'Comma seperate list of plugins in the form name:type', 'Default all (*:*)') do |value|
    OPTIONS[:plugins] = value
  end
  opts.on('--list-plugins', 'Lists all plugins', 'Default false') do |value|
    OPTIONS[:list_plugins] = true
  end

  opts.separator ""
  opts.on_tail('--help', "Shows this help text.") do
    $stderr.puts opts
    exit
  end

  opts.parse!
end

# Set default options if not specified
OPTIONS[:plugins_path] ||= "/usr/share/mcollective/plugins"
OPTIONS[:prefix] ||= "/"
OPTIONS[:plugins] ||= "*:*"
OPTIONS[:list_plugins] ||= false

# This list of hashes is used by my ugly way of working out
# what modules are available in mcollective plugins
# 
# Its highly sensitive to file system layout, so if things
# don't match the patterns below they don't get picked up.
#
# TODO: audit/centralrpclog has some agents that we don't pick up
plugin_types = [
  { :type => :agentddl,
    :dir_glob => ["agent/*/agent/*.ddl"],
    :re => /^.+?\/(.+?)\//,
  },
  { :type => :agent,
    :dir_glob => ["agent/*/agent/*.rb"],
    :re => /^.+?\/(.+?)\//,
  },
  { :type => :application,
    :dir_glob => ["agent/*/application/*.rb"],
    :re => /^.+?\/(.+?)\//,
  },
  { :type => :audit,
    :dir_glob => ["audit/*/audit/*.rb"],
    :re => /^.+?\/(.+?)\//,
  },
  { :type => :facts,
    :dir_glob => ["facts/*/*.rb"],
    :re => /^.+?\/(.+?)\//,
  },
  { :type => :registration,
    :dir_glob => ["registration/*.rb"],
    :re => /^.+?\/(.+?).rb$/,
  },
  { :type => :authorization,
    :dir_glob => ["simplerpc_authorization/*/*.rb"],
    :re => /^.+?\/(.+?)\//,
  },
  { :type => :security,
    :dir_glob => ["security/*/*.rb"],
    :re => /^.+?\/(.+?)\//,
  },
]

plugin_data = {}
plugin_types.each do |plugin_type|
  paths = Dir.glob(plugin_type[:dir_glob])
  paths.sort.each do |path|
    # First grok the plugin name using regexp match
    re = plugin_type[:re] || /^.+?\/(.+?)\//
    path.match(re)
    name = $1.to_sym

    type = plugin_type[:type]

    # Layout groked data in plugin_data
    plugin_data[type] ||= {}
    plugin_data[type][name] ||= {}
    plugin_data[type][name][:path] ||= []
    plugin_data[type][name][:path] << path
  end
end

full_plugin_list = []
plugin_data.each do |plugin_type,v|
  v.each do |plugin_name,v|
    plugin_name = "#{plugin_name}:#{plugin_type}"
    full_plugin_list << plugin_name
  end
end

# If the user just wanted a list ... print it now
# and exit straight away
if OPTIONS[:list_plugins] == true then
  full_plugin_list.each do |plugin|
    puts plugin
  end
  exit
end


# Lets scan through the list of desired plugins
# and make sure they exist
if OPTIONS[:plugins] == "*:*" then
  OPTIONS[:plugins] = full_plugin_list
else
  new_plugins = []
  OPTIONS[:plugins].split(",").each do |plugin|
    if not full_plugin_list.include?(plugin) then
      $stderr.puts "Plugin #{plugin} does not exist. Run --list-plugin to see a valid list"
      exit
    end
    new_plugins << plugin
  end
  OPTIONS[:plugins] = new_plugins
end

#pp OPTIONS[:plugins]

# Install plugins
OPTIONS[:plugins].each do |plugin|
  plugin_name, plugin_type = plugin.split(":")

  # Agent DDL is special cased here
  if plugin_type == "agentddl" then
    destination_dir = "agent"
  else
    destination_dir = plugin_type
  end

  source = plugin_data[plugin_type.to_sym][plugin_name.to_sym][:path]
  destination = OPTIONS[:prefix] + OPTIONS[:plugins_path] + "/" + destination_dir
  destination = File.expand_path(destination)

  puts "\e[32mInstalling #{plugin}\e[0m"
  puts "\t\e[36msource:\e[0m #{source.inspect}"
  puts "\t\e[36mdestination:\e[0m #{destination}"

  FileUtils.mkdir_p(destination)
  FileUtils.cp(source, destination)
end

#pp OPTIONS
#pp plugin_data
#pp full_plugin_list


