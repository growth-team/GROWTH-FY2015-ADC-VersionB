require "yaml"
require "highline"


hline=HighLine.new

partsList=ARGV[0]
packageDBFile=ARGV[1]
deviceDBFile=ARGV[2]
freeRFile=ARGV[3]
freeCFile=ARGV[4]

#output file
outputCSV=open("output.csv","w")
outputRS=open("output_rs.csv","w")

#container
r=[]
vr=[]
sj=[]
c=[]
tp=[]
led=[]
others=[]

#package to pin number
puts "---------------------------------------------"
puts "Loading Package DB and Device DB"
packageDB=YAML.load(File.read(packageDBFile))
$deviceDB=YAML.load(File.read(deviceDBFile))

#free R/C list
def convertToValue(valueUnit)
	units={p:1e-12, n:1e-9, u:1e-6, m:1e-3, k:1e3, M:1e6}
	valueUnit.match(/(^[0-9\.]+)/)
	if(Regexp.last_match==nil)then
		STDERR.puts "Error: something is wrong with valueUnit #{valueUnit}"
		raise 0
	else
		value=Regexp.last_match[1].to_f
		units.each(){|k,v|
			if(valueUnit.include?(k.to_s))then
				value=value*v
				break
			end
		}
		return value
	end
end

def loadRList(fileName)
	result={}
	open(fileName).each(){|line|
		array=line.strip.split(/\s|\t/)
		array.each(){}
		partName=array[0]
		company=array[1]
		package=array[2]
		begin
			value=convertToValue(array[3])
		rescue=>e
			puts "Error: #{line}"
			exit
		end
		accuracy=array[4].gsub("±","").gsub("%","").to_f
		wattage=array[5].gsub("W","")
		if(accuracy==0 or accuracy<0)then
			STDERR.puts "Warning the following line skipped."
			STDERR.puts line
			next
		end
		if(result[package]==nil)then
			result[package]={}
		end
		if(result[package][value]==nil)then
			result[package][value]={"name"=> partName, "company"=> company, "accuracy"=> accuracy, "wattage"=> wattage, "class"=> "チップ抵抗"}
		else
			if(accuracy<result[package][value]["accuracy"])then
				result[package][value]={"name"=> partName, "company"=> company, "accuracy"=> accuracy, "wattage"=> wattage, "class"=> "チップ抵抗"}
			end
		end
	}
	return result
end

def relativeAccuracyOfC(value, accuracyString)
	if(accuracyString.include?("%"))then
		return accuracyString.gsub("±","").gsub("%","").to_f
	elsif(accuracyString.include?("F"))then
		absoluteError=convertToValue(accuracyString.gsub("F",""))
		return absoluteError/value*100
	end
end

def loadCList(fileName)
	result={}
	open(fileName).each(){|line|
		array=line.strip.split("\t")
		partName=array[0]
		company=array[2]
		package=array[3]
		begin
			value=convertToValue(array[4].gsub("F",""))
		rescue=>e
			puts line
		end
		accuracy=relativeAccuracyOfC(value, array[5].gsub("±",""))
		withstandVoltage=array[6]

		if(result[package]==nil)then
			result[package]={}
		end
		if(result[package][value]==nil)then
			result[package][value]={"name"=> partName, "company"=> company, "accuracy"=> accuracy, "withstandVoltage"=> withstandVoltage, "class"=> "チップコンデンサ"}
		else
			if(accuracy<result[package][value]["accuracy"])then
				result[package][value]={"name"=> partName, "company"=> company, "accuracy"=> accuracy, "withstandVoltage"=> withstandVoltage, "class"=> "チップコンデンサ"}
			end
		end
	}
	return result
end

puts "---------------------------------------------"
puts "Loading Free R"
$freeR=loadRList(freeRFile)
puts "---------------------------------------------"
puts "Loading Free C"
$freeC=loadCList(freeCFile)

#---------------------------------------------
def searchFreeR(info)
	value=convertToValue(info[:value])
	package=info[:package]
	if($freeR[package]!= nil and $freeR[package][value]!=nil)then
		info[:partInfo]=$freeR[package][value]
		# puts "Found free R"
		# puts $freeR[package][value]
		# puts "for #{info}"
	end
	return info
end

def searchFreeC(info)
	value=convertToValue(info[:value].gsub("F",""))
	package=info[:package]
	if($freeC[package]!=nil and $freeC[package][value]!=nil)then
		info[:partInfo]=$freeC[package][value]
		# puts "Found free C"
		# puts $freeC[package][value]
		# puts "for #{info}"
	end
	return info
end

#---------------------------------------------
puts "---------------------------------------------"
puts "Loading #{partsList}"
partStart=0
partEnd=0
valueStart=0
valueEnd=0
packageStart=0
packageEnd=0
deviceStart=0
deviceEnd=0
#---------------------------------------------
open(partsList).each_with_index(){|line,i|
	if(line.include?("Part") and line.include?("Value"))then
		partStart=0
		partEnd=line.index("Value")-1
		valueStart=line.index("Value")
		valueEnd=line.index("Device")-1
		deviceStart=line.index("Device")
		deviceEnd=line.index("Package")-1
		packageStart=line.index("Package")
		packageEnd=line.index("Library")-1
		puts <<EOS
=============================================
part: #{partStart} - #{partEnd}
value: #{valueStart} - #{valueEnd}
device: #{deviceStart} - #{deviceEnd}
package: #{packageStart} - #{packageEnd}

EOS
		next
	end

	if(partEnd==0 or line.strip=="")then
		next
	end

	part=line[partStart..partEnd].strip
	value=line[valueStart..valueEnd].strip
	device=line[deviceStart..deviceEnd].strip
	packageEagle=line[packageStart..packageEnd].strip

	#---------------------------------------------
	#read properties from packageDB
	#---------------------------------------------
	pin=false
	type=false
	mount=true
	package=false
	if(packageDB[packageEagle]!=nil)then
		pin=packageDB[packageEagle]["pin"]
		type=packageDB[packageEagle]["type"].strip
		if(packageDB[packageEagle]["mount"]!=nil)then
			mount=packageDB[packageEagle]["mount"]
		end
		if(packageDB[packageEagle]["package"]!=nil)then
			package=packageDB[packageEagle]["package"].to_s
		else
			package=packageDB[packageEagle]["type"]
		end
	end

	info={part: part, value: value, device: device, pin: pin, type: type, mount: mount, package: package}

	#Test Point
	if(part.match(/^TP[0-9]+/) or part.match(/^TP_/) or value.include?("TPPAD") or value.include?("SHV_PIGTAIL_LAND"))then
		tp << info
		next
	end
	#VR
	if(part.match(/^VR[0-9]+/) or part.match(/^VR_/) or packageEagle.include?("ADJRP"))then
		vr << info
		next
	end
	#R
	if(part.match(/^R[0-9]+/) or part.match(/^R_/))then
		info=searchFreeR(info)
		r << info
		next
	end
	#SJ
	if(part.match(/^SJ[0-9]+/) or part.match(/^SJ_/))then
		sj << info
		next
	end
	#C
	if(part.match(/^C[0-9]+/) or part.match(/^C_/))then
		info=searchFreeC(info)
		c << info
		next
	end
	#LED
	if(part.match(/^LED[0-9]+/) or part.match(/^LED_/))then
		led << info
		next
	end
	#others
	others << info
}


#---------------------------------------------
# Searches part information from part DB
def searchPartInfo(info)
	device=info[:device]
	value=info[:value]
	if($deviceDB[device]!=nil and $deviceDB[device][value]!=nil)then
		info[:partInfo]=$deviceDB[device][value]
	end
	return info
end

#---------------------------------------------
#dump
nDIPParts=0
nSMDParts=0
allMountedParts=[]
[r,vr,c,led,others,sj,tp].each(){|infoArray|
	puts "---------------------------------------------"
	infoArray.each(){|info|

		if(info[:package]!=nil)then
			info[:package].to_s.strip!
		end

		if(info[:mount]==true and info[:partInfo]==nil)then
			info=searchPartInfo(info)
			if(info[:partInfo]==nil)then
				STDERR.puts hline.color("Error: The following part does not have partInfo.",:red)
				STDERR.puts hline.color("       Check if the partDB contains an entry for the 'device' name.",:red)
				STDERR.puts info
				exit
			end
		end

		puts info
		#puts "%-15s %-25s %-25s %-5s %-5s" % [info[:part], info[:value], info[:device], info[:package], info[:pin]]

		# if(info[:package]!=false)then
		# 	puts "%-15s %-15s %-5s %-5s" % [info[:part], info[:value], info[:package], info[:pin]]
		# else
		# 	puts "%-15s %-15s %-5s %-5s" % [info[:part], info[:value], info[:type], info[:pin]]
		# end
		
		if(info[:mount])then
			allMountedParts << info
			if(info[:type]=="DIP")then
				nDIPParts+=1
			elsif(info[:type]=="SMD")then
				nSMDParts+=1
			end
		end
	}
}

unitPrice=50
puts "============================================="
puts "# of DIP = #{nDIPParts}"
puts "# of SMD = #{nSMDParts}"
puts "# of DIP+SMD = #{nDIPParts+nSMDParts}"
puts "Mount cost = #{(nDIPParts+nSMDParts)*unitPrice} yen"

#---------------------------------------------
puts "============================================="
puts "Saving to output.csv"

#extract used part numbers
partNumberList=allMountedParts.map(){|info|
	if(info[:partInfo][:name]!=nil)then
		info[:partInfo][:name]
	elsif(info[:partInfo]["name"]!=nil)then
		info[:partInfo]["name"]
	else
		nil
	end
}.uniq.sort

#sort parts
mapPartNumberToInstances={}
partNumberList.each(){|name|
	if(mapPartNumberToInstances[name]==nil)then
		mapPartNumberToInstances[name]=[]
	end

	allMountedParts.each(){|info|
		if(info[:partInfo][:name]==name or info[:partInfo]["name"]==name)then
			mapPartNumberToInstances[name] << info
		end
	}	
}

#dump
mapPartNumberToInstances.each(){|name,infoArray|
	instanceNameArray=infoArray.map(){|info| info[:part]}
	info0=infoArray[0]
	partInfo=infoArray[0][:partInfo]
	company=partInfo["company"]
	class_=partInfo["class"]
	outputCSV.puts <<EOS
"#{company}"	"#{class_}"	"#{name}"	"#{instanceNameArray.join(", ")}"	"#{instanceNameArray.length}"	"#{info0[:pin]}"	"合計ピン数"	"実装"	"#{info0[:type]}"	"必要数"	"提供部品"	"N/A"	"#{info0[:package]}"
EOS
}

#---------------------------------------------
#for RS order
puts "============================================="
puts "For RS order (#{outputRS.path})"
outputRS.puts "#部品種類	メーカー型番	メーカー	個数"
mapPartNumberToInstances.each(){|name,infoArray|
	info=infoArray[0]

	if(info[:partInfo]==nil)then
		puts "Error: #{info}"

	end

	#無料チップ抵抗
	if(info[:partInfo]["name"].match(/^RK[0-9][0-9]/) and info[:partInfo]["class"].include?("チップ抵抗"))then
		#skip
		next
	end
	#無料チップコンデンサ
	if(info[:partInfo]["name"].match(/^GRM[0-9][0-9]/) and info[:partInfo]["class"].include?("チップコンデンサ"))then
		#skip
		next
	end
	outputRS.puts "#{info[:partInfo]["class"]}	#{name}	#{info[:partInfo]["company"]}	#{infoArray.length}"
}