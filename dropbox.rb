#!/usr/bin/env ruby

require './dropbox_sdk'
require 'pp'

class String
	def to_bool
		self =~ /^(f|0)/i || empty? ? false : true
	end
end

class DropBox
	APP_KEY = 'r6cld03xhxs6bid'
	APP_SECRET = 'h00wg3w9mn5loao'
	ACCESS_TYPE = :dropbox
	CONFIG_FILE = '.dropbox.rb.yaml'

	def initialize
		@session = DropboxSession.new(APP_KEY, APP_SECRET)

		if !@session.authorized?
			if File.exists?(CONFIG_FILE)
				@config = YAML::load(open(CONFIG_FILE))
				
				@session.set_access_token(@config["access_token"]["key"], @config["access_token"]["secret"])
				@session.set_request_token(@config["request_token"]["key"], @config["request_token"]["secret"])
			else
				@session.get_request_token
				authorize_url = session.get_authorize_url
				#puts "Got a request token.  Your request token key is #{session.request_token.key} and your token secret is #{session.request_token.secret}"

				puts "I can't indentify you. Would you be so nice to go and click 'ALLOW' on this webpage: ", authorize_url, " ? And when you will be ready, just hit RETURN to let me know you are done. I will never ask you to do it again, I promise!"
				gets

				@session.get_access_token
				
				open(CONFIG_FILE, 'w') do |f|
					f.puts "access_token:\n  key: #{@session.get_access_token.key}\n  secret: #{@session.get_access_token.secret}\n"
					f.puts "request_token:\n  key: #{@session.get_request_token.key}\n  secret: #{@session.get_request_token.secret}\n"
				end
			end
		else
			puts "Logged in"
		end

		@client = DropboxClient.new(@session, ACCESS_TYPE)
	end
	
	def ls(path = '/')
		path = [ '/' ] if (path.kind_of?(Array) && path.length < 1)
		
		res = []
		
		path.each { |p| res += list(p) }
		
		return res
	end
	
	def put(from_path, to_path, overwrite = false)
		meta = @client.metadata(to_path)
		
		r1 = /.*\/(.+)$/
		r2 = Regexp.new('(' + Regexp.escape(from_path) + ')$')
		to_path = (to_path + '/' + r1.match(from_path)[1]).gsub(/\/+/, '/') if meta['is_dir'] && !(to_path =~ r2)
	
		# because (!nil) is true while (nil == false) is false
		return (@client.put_file(to_path, open(from_path), overwrite)['is_dir'] == false)
	end
	
	def get(from_path, to_path, overwrite = false)
		meta = @client.metadata(from_path)
		
		return false if (File.exists?(to_path) && !File.directory?(to_path) && !overwrite)
		
		r = /.*\/(.+)$/
		to_path = (to_path + '/' + r.match(from_path)[1]).gsub(/\/+/, '/') if File.directory?(to_path)
		
		open(to_path, 'wb') do |f|
			f.puts @client.get_file(from_path)
		end
		
		return true
	end
	
	def mkdir(path)
		if path.kind_of? Array
			path.each { |p| mkdir(p) }
		else
			return @client.file_create_folder(path)['is_dir']
		end
		
		return true
	end
	
	def rm(path)
		if path.kind_of? Array
			if (path.length > 1)
				path.each { |p| rm(p) }
			else
				rm(path.first)
			end
		else
			return @client.file_delete(path)['is_deleted']
		end
	end
	
	def help
		msg = <<MOOEOS
dropbox.rb - Ruby CLIent for DropBox

Usage: dropbox.rb <command> <args>

Commands available:
    help    Shows this message
    
    ls        Lists path specified. If it is not - lists the entire DropBox directory. 
    
            Output format:
            
                [ directory path ]
                file path
                
            Examples:
            
                $ dropbox.rb ls
                $ dropbox.rb ls /Public
                $ dropbox.rb ls /Photo/Party\ 10\ Oct\ 2011
                
    mkdir    Creates an empty directory within specified path.
    
            Examples:
            
                $ dropbox.rb mkdir /Public/Book
                
    rm        Removes path specified. Removes files as well as directories.
    
            Examples:
            
                $ dropbox.rb rm /Public/Book
                $ dropbox.rb rm /Public/Book /Photo/Party\ 10\ Oct\ 2011/
                
    get        Downloads a single file. 
    
            Arguments: 
            
                from        DropBox file do download
                to            Client file will be written to
                overwrite    (optional) If the target file should be overwritten or not. Value should be either "true" or "false", "0" or "1"; case-insensitive
                
            Examples:
            
                $ dropbox.rb get /Photo/Party\ 10\ Oct\ 2011/0001.JPG ./
                
    put        Uploads a single file to DropBox. Arguments are exactly the same as "get" command has, except of "from" and "to" argument meanings - they are reverted to client.
    
            Examples:
    
                $ dropbox.rb put ./0002.JPG /Photo/Party\ 10\ Oct\ 2011/
MOOEOS

		puts msg
	end
	
	def __main__
		cmd = ARGV.shift
		args = ARGV
		
		cmd = "help" if cmd == nil

		begin
			res = false
			
			if cmd == "ls"
				res = ls(args)
			elsif (cmd == "help")
				help()
				res = true
			elsif (cmd == "get")
				args << args.pop.to_bool if args.length > 2
				res = get(args[0], args[1])
			elsif (cmd == "put")
				args << args.pop.to_bool if args.length > 2
				res = put(args[0], args[1])
			else
				res = send(cmd.to_sym, args)
			end
			
			res.each { |i| puts "#{i}" } if res.kind_of? Array
			
			if res == true
				puts "Done." 
			end
		#rescue
		#	puts "Failed with error: #{ $! }\n"
		end
	end
	
	private
	
	def list(path = '/', res = [])
		return [] if !path.kind_of? String
		
		m = @client.metadata(path)
		
		if m['is_dir']
			res << "[ #{m['path']} ]"
			m['contents'].each do |i|
				c = @client.metadata(i['path'])
				
				res << c['path'] if !c['is_dir']
				res << "[ #{ c['path'] } ]" if c['is_dir']
			end
			
			# recursive
			# m['contents'].each { |c| res += list(c['path'], res) }
		else
			res << m['path']
		end
		
		return res
	end
end

x = DropBox.new
x.__main__
