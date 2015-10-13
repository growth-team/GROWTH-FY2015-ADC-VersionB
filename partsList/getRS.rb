#!/usr/bin/env ruby

require "mechanize"
require 'cgi/util'

# Takayuki Yuasa 20151013

m=Mechanize.new

#<span itemprop="eligibleQuantity">10</span>
#<span itemprop='price'>&#65509;11.50</span>

name=ARGV.join(" ")
url="http://jp.rs-online.com/web/c/?sra=oss&r=t&searchTerm="+CGI.escape("#{name}")
page=m.get(url)

if(page.search("//span[@itemprop='eligibleQuantity']")!=nil and page.search("//span[@itemprop='eligibleQuantity']")[0]!=nil)then
	eligibleQuantity=page.search("//span[@itemprop='eligibleQuantity']")[0].text
	price=page.search("//span[@itemprop='price']")[0].text
	rsCode=page.search("//span[@itemprop='sku']")[0].text
	puts "%-20s %-10s %-10s %-10s" % [name, rsCode, price, eligibleQuantity]
else
	puts "%-20s not found" % [name] 
end