require 'pp'

class Find
	def initialize(block)
		@include = []
		@exclude = []
		
		instance_eval &block
	end
	
	def include(files)
		files = [files] if not files.is_a? Array
		@include += files
	end
	
	def exclude(files)
		files = [files] if not files.is_a? Array
		@exclude += files
	end
	
	def find
		files = []
		@include.each do |path|
			if path =~ /\.\.\.\//
				(0...10).each do |i|
					files += Dir.glob(path.sub '.../', ('*/'*i))
				end
			elsif path =~ /\*/
				files += Dir.glob path
			else
				files += [path]
			end
		end
		
		files.map! do |file|
			if @exclude.map do |exclude|
						if file[0...exclude.size] == exclude then true
						else false
						end
					end.include? true
				nil
			else file
			end
		end
		files.compact
	end
end

def find(&block)
	Find.new(block).find
end

def cs(out, flags=[], files=[], &block)
	if block != nil
		files += find &block
	end
	deps = files
	files = files.map { |x| x.gsub '/', '\\' }
	
	target = 
		if out =~ /\.dll$/ then 'library'
		elsif out =~ /\.win\.exe$/ then 'winexe'
		else 'exe'
		end
	
	references = files.map do |file|
			if file =~ /\.dll$/ then file
			else nil
			end
		end.compact
	
	files = files.map do |file|
			if references.include? file then nil
			else file
			end
		end.compact
	
	references.map! { |file| "/reference:#{file}" }
	
	deps.reject! { |file| file.index('System.') == 0 }
	
	file out => deps do
		sh 'csc', "/out:#{out}", "/target:#{target}", *references, *flags, *files
	end
	Rake::Task[out].invoke
end

def boo(out, flags=[], files=[], &block)
	if block != nil
		files += find &block
	end
	deps = files
	
	target = 
		if out =~ /\.dll$/ then 'library'
		elsif out =~ /\.win\.exe$/ then 'winexe'
		else 'exe'
		end
	
	references = files.map do |file|
			if file =~ /\.dll$/ then file
			else nil
			end
		end.compact
	
	files = files.map do |file|
			if references.include? file then nil
			else file
			end
		end.compact
	
	references.map! { |file| "-reference:#{file}" }
	
	deps.reject! { |file| not File.exist? file }
	
	file out => deps do
		sh 'booc', "-o:#{out}", "-target:#{target}", *references, *flags, *files
	end
	Rake::Task[out].invoke
end

task :default => [:ronin]

task :obj do
	Dir::mkdir 'Obj' if not FileTest::directory? 'Obj'
end

task :ronin => [:obj] do
	sign = ['-keyfile:SigningKey.snk']
	
	boo 'Obj/Ronin.Common.dll', sign do
		include 'Common/.../*.boo'
	end
	
	boo 'Obj/Ronin.Inject.dll', sign do
		include 'Obj/Ronin.Common.dll'
		include 'Obj/QtWrapper.dll'
		include 'Inject/.../*.boo'
	end
	
	boo 'Obj/Ronin.exe', sign do
		include 'Obj/QtWrapper.dll'
		include 'Obj/Ronin.Common.dll'
		include 'App/.../*.boo'
	end
	
	sh 'corflags', '/32bit+', '/Force', 'Obj/Ronin.exe'
	sh 'sn', '/R', 'Obj/Ronin.exe', 'SigningKey.snk'
	sh 'corflags', '/32bit+', '/Force', 'Obj/Ronin.Inject.dll'
	sh 'sn', '/R', 'Obj/Ronin.Inject.dll', 'SigningKey.snk'
	sh 'corflags', '/32bit+', '/Force', 'Obj/Ronin.Common.dll'
	sh 'sn', '/R', 'Obj/Ronin.Common.dll', 'SigningKey.snk'
	sh 'gacutil', '/i', 'Obj/Ronin.exe'
end
