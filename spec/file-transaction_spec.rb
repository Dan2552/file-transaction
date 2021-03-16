def setup_fixtures
  FileUtils.rm_rf("/tmp/file-transaction_fixtures")
  FileUtils.mkdir("/tmp/file-transaction_fixtures")
  system("cd /tmp/file-transaction_fixtures && git init >/dev/null") ||
    raise("Failed to init git repo")
  FileUtils.touch("/tmp/file-transaction_fixtures/a")
  FileUtils.touch("/tmp/file-transaction_fixtures/b")
  FileUtils.touch("/tmp/file-transaction_fixtures/c")
  FileUtils.mkdir("/tmp/file-transaction_fixtures/directory")
  FileUtils.touch("/tmp/file-transaction_fixtures/directory/a")
  system("cd /tmp/file-transaction_fixtures && git add . -A >/dev/null && git commit -m 'First' >/dev/null") ||
    raise("Failed to commit")
end

shared_examples_for "changing nothing" do
  it "changes nothing" do
    subject rescue nil

    expect(File.file?("/tmp/file-transaction_fixtures/a")).to eq(true)
    expect(File.file?("/tmp/file-transaction_fixtures/b")).to eq(true)
    expect(File.file?("/tmp/file-transaction_fixtures/c")).to eq(true)

    expect(File.read("/tmp/file-transaction_fixtures/a")).to eq("")
    expect(File.read("/tmp/file-transaction_fixtures/b")).to eq("")
    expect(File.read("/tmp/file-transaction_fixtures/c")).to eq("")
  end
end

shared_examples_for "raising the error" do
  it "raises the error" do
    expect { subject }.to raise_error("anything")
  end
end

describe File do
  describe ".transaction" do
    let(:blk) { Proc.new { |_| } }
    let(:original_directory) { "/tmp/file-transaction_fixtures" }
    subject { described_class.transaction(original_directory, &blk) }

    before do
      setup_fixtures
    end

    context "when the block is empty" do
      it_behaves_like "changing nothing"
    end

    context "when the block deletes a file" do
      let(:blk) do
        Proc.new do |directory|
          FileUtils.rm(directory.join("b"))
        end
      end

      it "deletes the file" do
        subject

        expect(File.file?("/tmp/file-transaction_fixtures/b")).to eq(false)
      end

      it "doesn't touch the other files" do
        subject

        expect(File.file?("/tmp/file-transaction_fixtures/a")).to eq(true)
        expect(File.file?("/tmp/file-transaction_fixtures/c")).to eq(true)
        expect(File.read("/tmp/file-transaction_fixtures/a")).to eq("")
        expect(File.read("/tmp/file-transaction_fixtures/c")).to eq("")
      end

      context "but an exception is raised" do
        let(:blk) do
          Proc.new do |directory|
            FileUtils.rm(directory.join("b"))
            raise "anything"
          end
        end

        it_behaves_like "changing nothing"
        it_behaves_like "raising the error"
      end
    end

    context "when the block writes to a file" do
      let(:blk) do
        Proc.new do |directory|
          system("echo hello world > #{directory}/a")
        end
      end

      it "writes to the file" do
        subject

        expect(File.read("/tmp/file-transaction_fixtures/a")).to eq("hello world\n")
      end

      it "doesn't touch the other files" do
        subject

        expect(File.file?("/tmp/file-transaction_fixtures/b")).to eq(true)
        expect(File.file?("/tmp/file-transaction_fixtures/c")).to eq(true)
        expect(File.read("/tmp/file-transaction_fixtures/b")).to eq("")
        expect(File.read("/tmp/file-transaction_fixtures/c")).to eq("")
      end

      context "but an exception is raised" do
        let(:blk) do
          Proc.new do |directory|
            system("echo hello world > #{directory}/a")
            raise "anything"
          end
        end

        it_behaves_like "changing nothing"
        it_behaves_like "raising the error"
      end
    end
  end
end
