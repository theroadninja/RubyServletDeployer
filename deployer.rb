# deployer.rb

require 'fileutils'

#0 is the first argument
config = ARGV[0]
if config.nil? or config.empty? then
    puts "must specify config file"
    exit 1;
end

begin
    #configFile = File.new(config, "r")
    configFile = File.read(config)
rescue Errno::ENOENT
    puts "invalid config file " + config
    exit 1;
end


def isComment(line)

    line = line.chomp
    return true if line.start_with?("#") or line.empty?

end

def parseLine(line)
    #looks like this does get the first word
    keyword = line.split.first

    #we get away with this because the config names
    #have only word characters in them
    restOfLine = line.sub(/^\s*[\w]+\s+/, "").chomp

    return [keyword, restOfLine]
end


#scan hardcoded folder locations that could hold a jetty instance
def guessJettyFolder()
    #to support more jetty locations, add them to here
    folders = [ "/opt/jetty/webapps" ]

    folders.each {|f|
        if File.directory?(f) then
            return f;
        end
    }

    return nil
end

scanFolders = []
destination = guessJettyFolder()
warFiles = []
$logFile = nil

configFile.each_line {|line|

    if not isComment(line) then
        keyword, line = parseLine(line)
        if keyword == "AddScanFolder" then
            scanFolders << line
        elsif keyword == "AllowWarFile" then
            warFiles << line
        elsif keyword == "LogFile" then
            $logFile = line
        else
            #this will use exit code 1 for us
            abort "unrecognized config option: " + keyword
        end
    end

}


def log(line)
    t = Time.new.strftime("%Y-%m-%d %H:%M:%S")
    line = t + " " + line
    if not $logFile.nil?
        file = File.open($logFile, 'a')
        file.puts line
    end
    puts line
end


if destination.nil? or destination.empty? then
    abort "cannot determine jetty deployment folder"
end


#
# fromWar - the new war file, which will be moved and not copied
# toWar - the destination war file, which should exist
# touchFile - the file to touch in order to cause jetty to reload the war
#
#
def deployJetty(fromWar, toWar, touchFile)

    #without :force we get a Errno::EACCES
    #FileUtils.mv(fromWar, toWar, :force => true)


    #stupid test just to see where the permissions error is
    FileUtils.touch(fromWar)

    #stupid test just to see where the permissions error is
    #FileUtils.touch(toWar)

    #not working so great: FileUtils.mv(fromWar, toWar, :verbose => true, :force => true)
    FileUtils.cp(fromWar, toWar)

    FileUtils.rm(fromWar)

    FileUtils.touch(touchFile)

end



log("running deployer script")

scanFolders.each {|f|
    warFiles.each {|war|

        filename = f + "/" + war
        if File.exist?(filename) then

            config = destination + "/" + war.sub(/\.war/, ".xml")
            if not File.exist?(config) then
                abort "using naive base filename convention, failed to find expected config file: " + config
            end

            destFile = destination + "/" + war
            if not File.exist?(destFile) then
                abort "destination war file does not already exist; aborting."
            end
            log("found file: #{filename} moving to: #{destFile}")
            #puts "found file: " + filename
            #puts "moving to: " + destFile
            deployJetty(filename, destFile, config)
        end

    }
}
