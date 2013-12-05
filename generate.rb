require 'httparty'
require 'fileutils'
require 'ostruct'
include FileUtils

class String
  def dir?
    File.directory? self
  end
  def basename
    File.basename(self)
  end
  def stem
    File.basename(self, File.extname(self))
  end
end

class GitHub
  include HTTParty
  base_uri 'https://api.github.com'

  def self.headers
    {'User-Agent' => "mxclmade"}
  end

  def self.forks
    json = get("/repos/mxcl/omgthemes/forks", headers: headers)
    json = json.parsed_response
    json.each do |fork|
      yield OpenStruct.new({
        user: fork['owner']['login'],
        clone_url: fork['clone_url']
      })
    end
  end
end


########################################################################### main
out = File.expand_path('out')
mkdir 'forks' unless 'forks'.dir?
mkdir out unless out.dir?

cd 'forks'

GitHub.forks do |fork|
  if not fork.user.dir?
    system "git clone #{fork.clone_url} #{fork.user}"
  else
    cd fork.user do
      system "git pull"
    end
  end
end


json = Dir["**/*.dvtcolortheme"].sort_by{|fn| File.mtime(fn) }.reverse.map do |theme|
  user = theme.split('/').first
  name = theme.stem
  fn = "#{user}_#{name}"  # spaces in filenames suck
  dst = "#{out}/#{fn}.dvtcolortheme"

  cp theme, dst
  system "ruby ../parse-dvtcolortheme.rb \"#{dst}\" > \"#{out}/#{fn}.css\""

  theme =~ %r{#{user}/(.*)}
  {
    fork: user,
    name: name,
    raw:  $1
  }
end

File.open("#{out}/themes.json", 'w') do |f|
  f.write(JSON.fast_generate(json))
end
