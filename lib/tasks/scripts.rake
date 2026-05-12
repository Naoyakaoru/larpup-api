require "open-uri"

namespace :scripts do
  desc "Download cover images from qiandao CDN for scripts that have qiandao_cover_id in metadata but no cover_image attached"
  task fetch_covers: :environment do
    CDN_BASE = "https://treasure.qiandaocdn.com/treasure/images"
    CDN_SUFFIX = "!lfit_w600"

    scope = Script.unscoped
                  .where("metadata->>'qiandao_cover_id' IS NOT NULL AND metadata->>'qiandao_cover_id' != ''")
                  .left_joins(:cover_image_attachment)
                  .where(active_storage_attachments: { id: nil })
    total = scope.count
    puts "Found #{total} scripts with qiandao_cover_id and no cover image"

    done = 0
    failed = 0

    scope.find_each do |script|
      cover_id = script.metadata["qiandao_cover_id"]
      ext = File.extname(cover_id).downcase
      content_type = ext == ".png" ? "image/png" : "image/jpeg"
      url = "#{CDN_BASE}/#{cover_id}#{CDN_SUFFIX}"

      begin
        io = URI.open(url, read_timeout: 15)
        script.cover_image.attach(
          io: io,
          filename: cover_id,
          content_type: content_type
        )
        done += 1
        print "." if done % 10 == 0
        $stdout.flush
      rescue => e
        failed += 1
        puts "\nFailed #{script.title} (#{cover_id}): #{e.message}"
      end

      sleep 0.1
    end

    puts "\nDone: #{done} downloaded, #{failed} failed"
  end

  desc "Create a base version (store_id: nil) for every script that doesn't have one"
  task backfill_base_versions: :environment do
    scripts_without_base = Script.unscoped
                                 .left_joins(:script_versions)
                                 .where(script_versions: { store_id: nil, id: nil })
                                 .distinct

    total = scripts_without_base.count
    puts "Found #{total} scripts without a base version"

    created = 0
    scripts_without_base.find_each do |script|
      ScriptVersion.create!(script: script, store: nil)
      created += 1
    end

    puts "Done: #{created} base versions created"
  end
end
