# File transaction

Copy a directory to a temp directory temporarily to perform mutations, to then copy it back.

If any exceptions are raised within the block, the changes will not be copied back.

# Usage

``` ruby
# Will create `a`, `b`, `c` in `/my/path`
File.transaction("/my/path") do |dir|
  FileUtils.touch(dir.join("a"))
  FileUtils.touch(dir.join("b"))
  system("echo 'c' >#{dir}/c")
end

# Will make no changes to `/my/path`
File.transaction("/my/path") do |dir|
  FileUtils.touch(dir.join("a"))
  FileUtils.touch(dir.join("b"))
  system("echo 'c' >#{dir}/c")
  raise "Any error" # <-------------
end
```
