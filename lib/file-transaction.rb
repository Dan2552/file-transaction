require "pathname"
require "fileutils"
require "tmpdir"

module FileTransaction
  # @internal
  #
  # Copies all contents of a directory instead of the directory itself.
  #
  def self.copy_files(directory, target)
    if files_in(target).empty?
      FileUtils.cp_r(File.join(directory, "."), target)
    else
      relative_files_in(directory).each do |file|
        FileUtils.mkdir_p(File.join(target, file.dirname))
        begin
          FileUtils.cp(File.join(directory, file), File.join(target, file))
        rescue Errno::EACCES
          FileUtils.rm_rf(File.join(target, file))
          FileUtils.cp(File.join(directory, file), File.join(target, file))
        end
      end

      files_for_deletion = relative_files_in(target) - relative_files_in(directory)

      files_for_deletion.each do |file|
        FileUtils.rm(File.join(target, file))
      end
    end
  end

  # @internal
  #
  def self.files_in(directory)
    Dir.glob(File.join(directory, "**", "*"), File::FNM_DOTMATCH)
      .reject { |file| file.end_with?(".") || file.end_with?("..") || File.directory?(file) }
  end

  def self.relative_files_in(directory)
    files_in(directory).map { |file| Pathname.new(file).relative_path_from(directory) }
  end
end

class File
  def self.transaction(directory, &blk)
    raise "#{directory} is not a directory" unless File.directory?(directory)

    Dir.mktmpdir do |tmp_directory|
      FileTransaction.copy_files(directory, tmp_directory)
      blk.call(Pathname.new(tmp_directory))
      FileTransaction.copy_files(tmp_directory, directory)
    end
  end
end
