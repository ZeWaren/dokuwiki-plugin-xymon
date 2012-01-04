#!/usr/local/bin/ruby
#
# Xymon server script
# Check a dokuwiki installation for any update or error
# Require the associated plugin to be installed on the target wikis
# Erwan Martin <public@fzwte.net>
#
# Runs on FreeBSD
#
# License: Public Domain
#

require 'cgi'
require 'pp'
require "xmlrpc/client"
require 'openssl'

xymon        = ENV['XYMON']
xymonsrv     = ENV['XYMSRV']
xymonhome    = ENV['XYMONHOME']
xymongrep    = xymonhome+'/bin/xymongrep'
column = 'dokuwikicheck DOKUWIKI*'

wikis_to_check = [];

#extract the list of dokuwiki installations to check from the xymon config files
host_lines = %x{#{xymongrep} #{column}}
hosts = host_lines.split(/\n/)
hosts.each do |ahost|
	if ahost =~ /^[\d\.]+\s+([a-zA-Z0-9\-\.\:]+?)\s*\#/
		xymon_name = $1
	else
		next
	end

	wiki_information = {
		:xymon_name => xymon_name,
		:url => '',
		:user => '',
		:password => '',
		:sslcert => '',
		:sslkey => '',
		:sslcacert => ''
	}

	if ahost =~ /DOKUWIKIURL:([^\s]*?)(?:\s|$)/
		wiki_information[:url] = $1
	end
	if ahost =~ /DOKUWIKIUSER:([^\s]*?)(?:\s|$)/
		wiki_information[:user] = $1
	end
	if ahost =~ /DOKUWIKIPASSWORD:([^\s]*?)(?:\s|$)/
		wiki_information[:password] = $1
	end
	if ahost =~ /DOKUWIKISSLCERT:([^\s]*?)(?:\s|$)/
		wiki_information[:sslcert] = $1
	end
	if ahost =~ /DOKUWIKISSLKEY:([^\s]*?)(?:\s|$)/
		wiki_information[:sslkey] = $1
	end
	if ahost =~ /DOKUWIKISSLCACERT:([^\s]*?)(?:\s|$)/
		wiki_information[:sslcacert] = $1
	end

	wikis_to_check << wiki_information
end

#we need to be able to set param to the http client of the ruby xmlrpc client
module SELF_SSL
  class XMLRPC_Client < XMLRPC::Client
    def get_http()
        return @http
    end
  end
end

#main loop
wikis_to_check.each do |wiki_information|
	xymon_color = 'clear'
	xymon_message = ''
	begin
		#url, user and password
		raise "No url was provided" if wiki_information[:url].strip.empty?
		endpoint_url = wiki_information[:url] + '/lib/exe/xmlrpc.php'
		server = SELF_SSL::XMLRPC_Client.new2(endpoint_url)
		server.user = wiki_information[:user]
		server.password = wiki_information[:password]
		http=server.get_http()

		#ssl (if provided)
		#  the equivalent line is:
		#  openssl s_client -connect host:port -servername host -cert :sslcert -key :sslkey -verify 12 -CAfile :sslcacert
		if not wiki_information[:sslcert].empty?
 			certificate = OpenSSL::X509::Certificate.new(File.read(wiki_information[:sslcert]))
			http.cert = certificate
		end
		if not wiki_information[:sslkey].empty?
			key = OpenSSL::PKey::RSA.new(File.read(wiki_information[:sslkey]))
			http.key=key
		end
		if not wiki_information[:sslcacert].empty?
			http.ca_file=wiki_information[:sslcacert]
		end
		if http.use_ssl?
			http.verify_mode = OpenSSL::SSL::VERIFY_PEER
			http.verify_depth = 12
		end

		#call
		status_page = server.call("wiki.getPage", "xymon:xymonstatus")

		#find the color in the response
		if status_page =~ /^xymon_color: (.*?)$/
			xymon_color = $1
			xymon_message = status_page
		else
			raise "Could not find xymon color in status page\n\n %s" % status_page
		end
	rescue Exception => e
		xymon_message = "Error!\n%s\n\n%s" % [e.message, e.backtrace]
		xymon_color = "clear"
	end

	#send the color and message to xymon
	xymon_message.gsub!(/([\"`])/, "\\\\\\1")
    xymon_host = wiki_information[:xymon_name]
    command = "#{xymon} \"#{xymonsrv}\" \"status+90000 #{xymon_host}.dokuwikicheck #{xymon_color} #{xymon_message}\""
	#puts command
	%x{#{command}}
end


