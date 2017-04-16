#!/usr/bin/ruby
#
# Add Notes Entry
#   with section name, key, and value
#
def writeBytes(f, bytes)
  bytes.each {|b| f.putc b}
end
def readInt32(f)
    (f.readbyte << 24) | (f.readbyte << 16) | (f.readbyte << 8) | (f.readbyte)
end
def writeInt32(f, val)
    writeBytes(f, [ ((val >> 24) & 0XFF), 
                    ((val >> 16) & 0XFF),
                    ((val >> 8 ) & 0XFF),
                    ((val      ) & 0XFF) ])
end
def readStr(f, sz)
   f.read sz
end
def writeStr(f, val)
    writeBytes(f, val.bytes)
end
def assertFileExists(f)
  if not File.exist? f
    $stderr.puts "File not exists!"
    exit 1
  end
end
def assertFileFormatOk(f)
    f.rewind
    magic = readInt32(f)
    if not (0XFFFFBABE == magic)
      $stderr.puts "Wrong file format!"
      exit 2 
    end
end
def skipFields(keyf, n)
  while n > 0
    len = readInt32(keyf)
    keyf.seek(len, IO::SEEK_CUR)
    n = n - 1
  end
end
def addFile(keyf)
  File.open(keyf, File::BINARY | File::CREAT | File::TRUNC | File::RDWR) {|f|
    writeInt32(f, 0XFFFFBABE)
  }
end
def addSection(name, keyf)
  $stdout.print "Enter section key for #{name} : "
  key = $stdin.gets.chomp
  $stdout.print "Enter section value for #{name} : "
  value = $stdin.gets.chomp
  File.open(keyf, File::BINARY | File::RDWR) {|f|
    assertFileFormatOk(f)
    f.seek(0, IO::SEEK_END)
    writeInt32(f, name.length)
    writeStr(f, name)
    writeInt32(f, key.length)
    writeStr(f, key)
    writeInt32(f, value.length)
    writeStr(f, value)
  }
end

def checkAddSection(name, keyf)
  if not File.exist? keyf
    addFile(keyf)
  end
  addSection(name, keyf)
end
def checkSetSection(name, keyf)
  assertFileExists(keyf)
  addSection(name, keyf)
end

def checkGetSection(name, keyf)
  assertFileExists(keyf)
  $stdout.print "Enter section key for #{name} : "
  key = $stdin.gets.chomp
  retrieved = {}
  File.open(keyf, File::BINARY | File::RDWR) {|f|
    assertFileFormatOk(f)
    while not f.eof?
        lens = readInt32(f)
        s = readStr(f, lens)
        if (name == s) or (name == '*')
          lenk = readInt32(f)
          k = readStr(f, lenk)
          if (key == k) or (key == '*')
            lenv = readInt32(f)
            v = readStr(f, lenv)
            retrieved[ "#{s}/#{k}" ] = v
          else
            skipFields(f, 1)
          end
        else
          skipFields(f, 2)
        end
    end
  }
  retrieved
end

def checkDelSection(name, keyf)
  assertFileExists(keyf)
  $stdout.print "Enter section key for #{name} : "
  key = $stdin.gets.chomp
  File.open(keyf, File::BINARY | File::RDWR) {|f|
    assertFileFormatOk(f)
    while not f.eof?
        lens = readInt32(f)
        s = readStr(f, lens)
        if name == s
          lenk = readInt32(f)
          k = readStr(f, lenk)
          if key == k
            lenv = readInt32(f)
            v = "*" * lenv
            writeStr(f, v)
          else
            skipFields(f, 1)
          end
        else
          skipFields(f, 2)
        end
    end
  }
end

def main(argv)
  keyf = argv.shift
  cmd = argv.shift
  val = argv.shift
  if "add" == cmd
    checkAddSection(val, keyf)
  elsif "set" == cmd
    checkSetSection(val, keyf)
  elsif "get" == cmd
    checkGetSection(val, keyf).each do |k,v|
        $stdout.puts "#{k} => #{v}"
    end
  elsif "del" == cmd
    checkDelSection(val, keyf)
  end
end

def usage
  "Usage: #{$1} <path-to-key-file> <add|get|set|del> <section>"
end

if 3 == ARGV.length
  main(ARGV)
else
  $stderr.puts usage
end
