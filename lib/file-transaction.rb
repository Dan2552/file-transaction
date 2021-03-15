require "pathname"
require "fileutils"
require "tmpdir"

module FileTransaction
  # Copies all contents of a directory instead of the directory itself.
  #
  def self.copy_files(directory, target, delete_target_first: false)
    FileUtils.rm_rf(target) if delete_target_first
  ensure
    FileUtils.cp_r(File.join(directory, "."), target)
  end
end

class File
  def self.transaction(directory, &blk)
    raise "#{directory} is not a directory" unless File.directory?(directory)

    Dir.mktmpdir do |tmp_directory|
      FileTransaction.copy_files(directory, tmp_directory)
      blk.call(Pathname.new(tmp_directory))
      FileTransaction.copy_files(tmp_directory, directory, delete_target_first: true)
    end
  end
end
