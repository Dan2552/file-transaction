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
    expect(File.file?("/tmp/file-transaction_fixtures/directory/a")).to eq(true)

    expect(File.read("/tmp/file-transaction_fixtures/a")).to eq("")
    expect(File.read("/tmp/file-transaction_fixtures/b")).to eq("")
    expect(File.read("/tmp/file-transaction_fixtures/c")).to eq("")
    expect(File.read("/tmp/file-transaction_fixtures/directory/a")).to eq("")
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

      it "shows only that file in the git changes" do
        subject
        git_status = `cd /tmp/file-transaction_fixtures && git status`.chomp
        expect(git_status).to eq("On branch master\nChanges not staged for commit:\n  (use \"git add/rm <file>...\" to update what will be committed)\n  (use \"git restore <file>...\" to discard changes in working directory)\n\tdeleted:    b\n\nno changes added to commit (use \"git add\" and/or \"git commit -a\")")
      end

      it "doesn't touch the other files" do
        subject

        expect(File.file?("/tmp/file-transaction_fixtures/a")).to eq(true)
        expect(File.file?("/tmp/file-transaction_fixtures/c")).to eq(true)
        expect(File.read("/tmp/file-transaction_fixtures/a")).to eq("")
        expect(File.read("/tmp/file-transaction_fixtures/c")).to eq("")
      end

      context "in a subdirectory" do
        let(:blk) do
          Proc.new do |directory|
            FileUtils.rm(directory.join("directory", "a"))
          end
        end

        it "deletes the file" do
          subject

          expect(File.file?("/tmp/file-transaction_fixtures/directory/a")).to eq(false)
        end
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

      it "shows only that file in the git changes" do
        subject
        git_status = `cd /tmp/file-transaction_fixtures && git status`.chomp
        expect(git_status).to eq("On branch master\nChanges not staged for commit:\n  (use \"git add <file>...\" to update what will be committed)\n  (use \"git restore <file>...\" to discard changes in working directory)\n\tmodified:   a\n\nno changes added to commit (use \"git add\" and/or \"git commit -a\")")
      end

      context "in a subdirectory" do
        let(:blk) do
          Proc.new do |directory|
            system("echo hello world > #{directory}/directory/a")
          end
        end

        it "writes to the file" do
          subject

          expect(File.read("/tmp/file-transaction_fixtures/directory/a")).to eq("hello world\n")
        end
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

    context "when committing changes with git" do
      let(:blk) do
        Proc.new do |directory|
          system("cd #{directory} && touch committed && git add committed && git commit -m 'commit'") ||
            raise("Failed to commit")
        end
      end

      it "keeps the commit" do
        expect { subject }
          .to change { `cd /tmp/file-transaction_fixtures && git log -1 --format="%H"`.chomp }
      end

      context "when it raises an exception" do
        let(:blk) do
          Proc.new do |directory|
            system("cd #{directory} && touch committed && git add committed && git commit -m 'commit' >/dev/null") ||
            raise("Failed to commit")

            raise "anything"
          end
        end

        it_behaves_like "raising the error"

        it "stays on the older commit" do
          expect { subject rescue nil}
            .to_not change { `cd /tmp/file-transaction_fixtures && git log -1 --format="%H"`.chomp }
        end
      end
    end

    context "when changing branch with git" do
      let(:blk) do
        Proc.new do |directory|
          system("cd #{directory} && git checkout -b another-branch") ||
            raise("Failed to change branch")
        end
      end

      it "changes branch" do
        subject

        current_branch = `cd /tmp/file-transaction_fixtures && git branch | sed -n '/\* /s///p'`.chomp

        expect(current_branch)
          .to eq("another-branch")
      end

      context "when it raises an exception" do
        let(:blk) do
          Proc.new do |directory|
            system("cd /tmp/file-transaction_fixtures && git checkout -b another-branch")
            raise "anything"
          end
        end

        it_behaves_like "raising the error"

        it "stays on the older branch" do
          current_branch = `cd /tmp/file-transaction_fixtures && git branch | sed -n '/\* /s///p'`.chomp

          expect(current_branch)
            .to eq("master")
            .or eq("main")
        end
      end
    end
  end
end
